extends RefCounted
## Combat and battles (EFFECT_SYSTEM_SPEC.md §4.5). plan() is pure and reads
## one derived state; resolve() applies it atomically. Static functions over
## the engine `e`; no instance members.

const Stats = preload("res://scripts/core/rules/stats.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Select = preload("res://scripts/core/rules/select.gd")

static func tower_key(lane_index: int, player: int) -> String:
	return "t%d_%d" % [lane_index, player]

## Every strike of the lane's combat phase, computed from one derived state:
## {"unit_damage": {uid: n}, "tower_damage": [dealt by p0, dealt by p1],
##  "strikes": [[src, dst, n, part]], "heal": {uid: n}, "tower_heal": [n, n],
##  "condemn": [uid], "dies": [uid]}. Sources and targets are uids, or
## "t<lane>_<p>" for towers.
static func plan(e, lane_index: int) -> Dictionary:
	# A plan is a pure read: one derived state, cached for its duration.
	Stats.frame_begin(e)
	var result = _plan(e, lane_index)
	Stats.frame_end(e)
	return result

static func _plan(e, lane_index: int) -> Dictionary:
	var lane: Dictionary = e.state.lanes[lane_index]
	var result = {"unit_damage": {}, "tower_damage": [0, 0], "strikes": [], "heal": {}, "tower_heal": [0, 0],
		"condemn": [], "dies": []}
	var towers = [Stats.tower(e, lane_index, 0), Stats.tower(e, lane_index, 1)]
	var derived: Dictionary = {}
	for player in range(2):
		for unit in lane.units[player]:
			if unit != null:
				derived[int(unit.uid)] = Stats.derive(e, unit)
	for player in range(2):
		var row: Array = lane.units[player]
		for slot in range(row.size()):
			var attacker = row[slot]
			if attacker == null or Stats.flag(e, attacker, "disarm"):
				continue
			var mine: Dictionary = derived[int(attacker.uid)]
			var pierce = int(mine.kw.get("pierce", 0)) > 0
			var target = combat_target(e, attacker, lane_index, slot)
			if target.is_empty():
				# Unblocked: attack the tower; no siege, no cleave (RQ-07).
				var dealt = maxi(0, int(mine.attack) + int(mine.kw.get("bonus_tower", 0)) - (0 if pierce else int(towers[1 - player].armor)))
				_strike(result, int(attacker.uid), tower_key(lane_index, 1 - player), dealt, "attack")
				result.tower_damage[player] += dealt
				var retaliate = int(towers[1 - player].retaliate)
				if retaliate > 0:
					_unit_strike(e, result, tower_key(lane_index, 1 - player), attacker, maxi(0, retaliate - int(mine.armor)), "retaliate")
				continue
			var theirs: Dictionary = derived[int(target.uid)] if derived.has(int(target.uid)) else Stats.derive(e, target)
			var attack = int(mine.attack) + (int(mine.kw.get("bonus_hero", 0)) if bool(target.hero) else 0)
			_unit_strike(e, result, int(attacker.uid), target, maxi(0, attack - (0 if pierce else int(theirs.armor))), "attack")
			var cleave = int(mine.kw.get("cleave", 0))
			if cleave > 0:
				for neighbor in Select.related(e, "allied_neighbors", target):
					var armor = int((derived[int(neighbor.uid)] if derived.has(int(neighbor.uid)) else Stats.derive(e, neighbor)).armor)
					_unit_strike(e, result, int(attacker.uid), neighbor, maxi(0, cleave - (0 if pierce else armor)), "cleave")
			var siege = int(mine.kw.get("siege", 0))
			if siege > 0:
				var dealt = maxi(0, siege - (0 if pierce else int(towers[1 - player].armor)))
				_strike(result, int(attacker.uid), tower_key(lane_index, 1 - player), dealt, "siege")
				result.tower_damage[player] += dealt
			var retaliate = int(theirs.kw.get("retaliate", 0))
			if retaliate > 0:
				var their_pierce = int(theirs.kw.get("pierce", 0)) > 0
				_unit_strike(e, result, int(target.uid), attacker, maxi(0, retaliate - (0 if their_pierce else int(mine.armor))), "retaliate")
	# Regeneration heals in the combat phase, before the death check (RQ-09).
	for player in range(2):
		for unit in lane.units[player]:
			if unit == null:
				continue
			var regeneration = int(derived[int(unit.uid)].kw.get("regeneration", 0))
			if regeneration > 0:
				result.heal[str(unit.uid)] = regeneration
		result.tower_heal[player] = int(towers[player].regeneration)
	# Lethal: battle damage above 0 condemns the victim (RQ-10).
	for strike in result.strikes:
		if not strike[0] is int or not strike[1] is int or int(strike[2]) <= 0:
			continue
		var source: Dictionary = derived.get(int(strike[0]), {})
		var victim = e.find_unit(int(strike[1]))
		if source.is_empty() or victim.is_empty():
			continue
		if _lethal_to(source.kw, victim) and int(strike[1]) not in result.condemn:
			result.condemn.append(int(strike[1]))
	for player in range(2):
		for unit in lane.units[player]:
			if unit == null:
				continue
			var key = str(unit.uid)
			var health = mini(int(derived[int(unit.uid)].max_health),
				int(unit.health) - int(result.unit_damage.get(key, 0)) + int(result.heal.get(key, 0)))
			var shielded = Stats.status(e, unit, "death_shield")
			if not shielded and (health <= 0 or int(unit.uid) in result.condemn):
				result.dies.append(int(unit.uid))
	return result

static func _lethal_to(keywords: Dictionary, victim: Dictionary) -> bool:
	if int(keywords.get("lethal", 0)) > 0:
		return true
	if bool(victim.get("hero", false)):
		return int(keywords.get("lethal_heroes", 0)) > 0
	return int(keywords.get("lethal_creeps", 0)) > 0

static func _strike(result: Dictionary, source, target, amount: int, part: String) -> void:
	result.strikes.append([source, target, maxi(0, amount), part])

## A strike on a unit: Damage Immunity makes it 0; every targeted unit gets a
## unit_damage entry, even at 0 (the bot and the board read it).
static func _unit_strike(e, result: Dictionary, source, target: Dictionary, amount: int, part: String) -> void:
	var dealt = 0 if Stats.flag(e, target, "damage_immunity") else maxi(0, amount)
	var key = str(target.uid)
	result.unit_damage[key] = int(result.unit_damage.get(key, 0)) + dealt
	_strike(result, source, int(target.uid), dealt, part)

## Applies the lane's combat atomically, then its Pulse, the end of
## next-combat effects and the after-combat triggers.
static func resolve(e, lane_index: int) -> void:
	e.state["combat_seq"] = int(e.state.get("combat_seq", 0)) + 1
	var forecast = plan(e, lane_index)
	e._event("combat", {"lane": lane_index, "damage": [int(forecast.tower_damage[0]), int(forecast.tower_damage[1])],
		"strikes": forecast.strikes})
	# Capture all attacks before any casualties. Dead attackers still deal the
	# damage they committed in this simultaneous combat.
	for uid_string in forecast.unit_damage:
		var unit = e.find_unit(int(uid_string))
		if not unit.is_empty():
			unit.health -= int(forecast.unit_damage[uid_string])
	var before: Array = []
	for structure in e.state.lanes[lane_index].structures:
		before.append([bool(structure.ancient), bool(structure.destroyed)])
	for player in range(2):
		Kernel.damage_structure(e, lane_index, 1 - player, int(forecast.tower_damage[player]))
	for uid_string in forecast.heal:
		var unit = e.find_unit(int(uid_string))
		if not unit.is_empty():
			unit.health = mini(Stats.max_health(e, unit), int(unit.health) + int(forecast.heal[uid_string]))
	for player in range(2):
		var structure: Dictionary = e.state.lanes[lane_index].structures[player]
		var fell = bool(structure.ancient) != before[player][0] or bool(structure.destroyed)
		if int(forecast.tower_heal[player]) > 0 and not fell:
			var cap = 80 if bool(structure.ancient) else 40
			structure.health = mini(cap, int(structure.health) + int(forecast.tower_heal[player]))
	for uid in forecast.condemn:
		var unit = e.find_unit(int(uid))
		if not unit.is_empty():
			unit["condemned"] = true
	_record_hits(e, forecast.strikes, lane_index, true)
	Kernel.pulse(e)
	Kernel.expire(e, lane_index, "next_combat")
	Kernel.emit(e, "after_combat", {"lane": lane_index})
	Kernel.pulse(e)
	e._check_winner()

## Writes round_log.hits and emits battle_damage for every hit above 0
## (RQ-32, RQ-45; CF-4).
static func _record_hits(e, strikes: Array, lane_index: int, in_combat: bool) -> void:
	for strike in strikes:
		if int(strike[2]) <= 0:
			continue
		if strike[0] is int and e.state.has("round_log"):
			var kind = "tower"
			if strike[1] is int:
				var victim = Select.resolve_unit(e, int(strike[1]))
				kind = "hero" if bool(victim.get("hero", false)) else "creep"
			e.state.round_log.hits.append([int(strike[0]), kind])
		Kernel.emit(e, "battle_damage", {"source": strike[0], "target": strike[1], "amount": int(strike[2]),
			"lane": lane_index, "in_combat": in_combat, "part": str(strike[3])})

## Read-only forecast for the board and the bot: unit_damage (uid string to
## total), tower_damage ([p0, p1]), heal, dies and strikes.
static func preview(e, lane_index: int) -> Dictionary:
	var forecast = plan(e, lane_index)
	return {"unit_damage": forecast.unit_damage, "tower_damage": forecast.tower_damage, "heal": forecast.heal,
		"dies": forecast.dies, "strikes": forecast.strikes}

static func combat_target(e, unit: Dictionary, lane_index: int, slot: int) -> Dictionary:
	var forced = int(unit.get("combat_target", -1))
	if forced == 0:
		return {}
	if forced > 0:
		var selected = e.find_unit(forced)
		if not selected.is_empty() and selected.lane == lane_index and selected.owner != unit.owner:
			return selected
	var enemy_row = e.state.lanes[lane_index].units[1 - int(unit.owner)]
	var target_slot = slot + int(unit.arrow)
	if target_slot >= 0 and target_slot < enemy_row.size() and enemy_row[target_slot] != null:
		return enemy_row[target_slot]
	# Pathing never points at an empty position: attack forward instead, which
	# is the blocking unit if one exists, otherwise the tower.
	if slot < enemy_row.size() and enemy_row[slot] != null:
		return enemy_row[slot]
	return {}

## Attack against a target: hero and tower bonuses on top of derived attack.
static func battle_attack(e, attacker: Dictionary, target: Dictionary) -> int:
	var derived = Stats.derive(e, attacker)
	var bonus = 0
	if target.is_empty():
		bonus = int(derived.kw.get("bonus_tower", 0))
	elif bool(target.get("hero", false)):
		bonus = int(derived.kw.get("bonus_hero", 0))
	return int(derived.attack) + bonus

## A battle outside the combat phase (Berserker's Call, Duel, Gank...): `a`
## battles every unit of `defenders` simultaneously from one derived state.
## Retaliation answers each actual attacker; siege and cleave do not apply.
## Deaths wait for the caller's Pulse.
static func battle(e, a: Dictionary, defenders: Array, ctx: Dictionary) -> void:
	var lane_index = int(a.lane)
	var strikes: Array = []
	var mine = Stats.derive(e, a)
	var a_attacks = not Stats.flag(e, a, "disarm")
	var damage: Dictionary = {}
	for b in defenders:
		var theirs = Stats.derive(e, b)
		if a_attacks:
			var attack = int(mine.attack) + (int(mine.kw.get("bonus_hero", 0)) if bool(b.hero) else 0)
			_battle_hit(e, strikes, damage, a, b, attack - (0 if int(mine.kw.get("pierce", 0)) > 0 else int(theirs.armor)), "attack")
			if int(theirs.kw.get("retaliate", 0)) > 0:
				_battle_hit(e, strikes, damage, b, a, int(theirs.kw.retaliate) - (0 if int(theirs.kw.get("pierce", 0)) > 0 else int(mine.armor)), "retaliate")
		if not Stats.flag(e, b, "disarm"):
			var attack = int(theirs.attack) + (int(theirs.kw.get("bonus_hero", 0)) if bool(a.hero) else 0)
			_battle_hit(e, strikes, damage, b, a, attack - (0 if int(theirs.kw.get("pierce", 0)) > 0 else int(mine.armor)), "attack")
			if int(mine.kw.get("retaliate", 0)) > 0:
				_battle_hit(e, strikes, damage, a, b, int(mine.kw.retaliate) - (0 if int(mine.kw.get("pierce", 0)) > 0 else int(theirs.armor)), "retaliate")
	for uid in damage:
		var unit = e.find_unit(int(uid))
		if not unit.is_empty():
			unit.health = int(unit.health) - int(damage[uid])
	for strike in strikes:
		if int(strike[2]) <= 0:
			continue
		var source = e.find_unit(int(strike[0]))
		var victim = e.find_unit(int(strike[1]))
		if not source.is_empty() and not victim.is_empty() and _lethal_to(Stats.derive(e, source).kw, victim):
			victim["condemned"] = true
	e._event("battle", {"a": int(a.uid), "card": str(a.card), "p": int(a.owner), "bs": defenders.map(func(unit): return int(unit.uid)), "hits": strikes})
	_record_hits(e, strikes, lane_index, false)

static func _battle_hit(e, strikes: Array, damage: Dictionary, source: Dictionary, target: Dictionary, amount: int, part: String) -> void:
	var dealt = 0 if Stats.flag(e, target, "damage_immunity") else maxi(0, amount)
	damage[int(target.uid)] = int(damage.get(int(target.uid), 0)) + dealt
	strikes.append([int(source.uid), int(target.uid), dealt, part])
