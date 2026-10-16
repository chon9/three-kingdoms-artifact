extends RefCounted
## Rules kernel (EFFECT_SYSTEM_SPEC.md §4): randomness, the event bus and
## trigger queue, the Pulse (deaths, look-back snapshots, Soulbound, Death
## Shield), modifiers with provenance, damage, lane opening and the end of the
## round. Static functions over the engine `e`; no instance members.
##
## Transient fields on the engine (never in state, reset per command):
##   _queue (trigger instances), _event_index, _pulse_depth, _ops_left,
##   _lookback (uid -> snapshot), _deploying, _deriving, _causes.

const Vocab = preload("res://scripts/core/rules/vocab.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Select = preload("res://scripts/core/rules/select.gd")
const VM = preload("res://scripts/core/rules/vm.gd")

const MAX_PULSE_LOOPS = 64
const MAX_PULSE_DEPTH = 16
## RQ-37: "per_batch" (glossary: all triggers happen simultaneously, one Pulse
## after each batch) or "per_trigger" (a Pulse after every trigger).
const BATCH_MODE = "per_batch"
## RQ-49: round 1's initial placement runs the deployment hooks.
const ROUND1_DEPLOYMENT_HOOKS = true
## RQ-24: hero active abilities start ready.
const HERO_ACTIVE_START_COOLDOWN = 0
## FX-3 (RQ-15): group damage is computed from one derived state, then
## applied (false: unit by unit, as the engine did before FX-3).
const SIMULTANEOUS_DAMAGE = true
## RQ-34/RQ-47: improvements per side of a lane.
const IMPROVEMENT_CAP = 16
## RQ-54: a Modify on a hero that died earlier in the same command (a trigger
## resolving from its look-back snapshot) reaches the hero in the Fountain
## (false: it fizzles like every other op on a unit that left play).
const MODIFY_REACHES_DEAD_HEROES = true
## RQ-29: a summoned hero (Divided We Stand's Meepo) joins its owner's roster,
## so when it dies it goes to the Fountain and is redeployed later, as the
## glossary says of every hero ("returns to the Fountain to be redeployed
## later"; nothing exempts summoned ones). false: it stays outside the roster
## and leaves the game when it dies (the default before M4).
const SUMMONED_HEROES_JOIN_ROSTER = true
const ZONE_RANK = {"unit": 0, "item": 1, "improvement": 2, "deed": 3, "snapshot": 0}

# --- Randomness (D1: the only functions that touch e.rng) ---------------------------

static func rand_index(e, count: int) -> int:
	return e.rng.randi_range(0, count - 1)

static func chance(e, percent: int) -> bool:
	return e.rng.randi_range(0, 99) < percent

static func shuffle(e, values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other = rand_index(e, index + 1)
		var original = values[index]
		values[index] = values[other]
		values[other] = original

# --- Event bus and trigger queue -----------------------------------------------------

## Collects the triggers of live sources for `kind` now (the intervening "if"
## is checked here) and queues them for the next batch.
static func emit(e, kind: String, payload: Dictionary) -> void:
	e._event_index += 1
	if not e.library.listening.has(kind) and not e.library.grant_listening.has(kind):
		return
	for listener in _live_listeners(e, kind, payload):
		var ctx: Dictionary = listener.ctx
		var side_rank = 0 if int(ctx.controller) == int(e.state.initiative) else 1
		var key = [e._event_index, side_rank, int(listener.lane), int(listener.zone), int(listener.position),
			int(listener.index), int(listener.id)]
		e._queue.append({"key": key, "ability": listener.ability, "event": payload, "ctx": ctx})

static func key_less(a: Array, b: Array) -> bool:
	for index in range(mini(a.size(), b.size())):
		if a[index] != b[index]:
			return a[index] < b[index]
	return false

static func _live_listeners(e, kind: String, payload: Dictionary) -> Array:
	var found: Array = []
	if kind == "death":
		# Only the dead unit itself listens to its own death (Death Effect).
		var ctx = Stats.unit_ctx(e, payload)
		ctx.src = payload
		ctx.host = payload
		_add_card_listeners(e, found, kind, payload, str(payload.get("card", "")), ctx, 0, int(payload.get("slot", 0)), int(payload.get("uid", 0)))
		_add_granted_listeners(e, found, kind, payload, payload.get("mods", []), ctx, 0, int(payload.get("slot", 0)), int(payload.get("uid", 0)))
		return found
	var listening: Dictionary = e.library.listening.get(kind, {})
	var granted = e.library.grant_listening.has(kind)
	for player in range(2):
		for lane_index in range(3):
			var row = e.state.lanes[lane_index].units[player]
			for slot in range(row.size()):
				var unit = row[slot]
				if unit == null:
					continue
				# A context is built only for a unit that can listen.
				var listens = listening.has(str(unit.card))
				var carries = granted and not unit.get("mods", []).is_empty()
				if listens or carries:
					var ctx = Stats.unit_ctx(e, unit)
					if listens:
						_add_card_listeners(e, found, kind, payload, str(unit.card), ctx, 0, slot, int(unit.uid))
					if carries:
						_add_granted_listeners(e, found, kind, payload, unit.mods, ctx, 0, slot, int(unit.uid))
				# Item triggers work only while the host is in a lane (RQ-38):
				# printed ones, then text granted to the item instance (M6).
				for slot_name in ["weapon", "armor", "accessory"]:
					if not unit.get("items", {}).has(slot_name):
						continue
					var item_card = str(unit.items[slot_name])
					var item_mods: Array = unit.get("item_state", {}).get(slot_name, {}).get("mods", []) if granted else []
					if not listening.has(item_card) and item_mods.is_empty():
						continue
					var item_ctx = Stats.item_ctx(e, unit, slot_name)
					var position = slot * 3 + int(Select.SLOT_RANK[slot_name])
					if listening.has(item_card):
						_add_card_listeners(e, found, kind, payload, item_card, item_ctx, 1, position, int(item_ctx.src.oid))
					if not item_mods.is_empty():
						_add_granted_listeners(e, found, kind, payload, item_mods, item_ctx, 1, position, int(item_ctx.src.oid))
	for player in range(2):
		for lane_index in range(3):
			for improvement in e.state.lanes[lane_index].get("improvements", [[], []])[player]:
				if listening.has(str(improvement.card)):
					_add_card_listeners(e, found, kind, payload, str(improvement.card), Stats.object_ctx(e, improvement),
						2, int(improvement.get("order", 0)), int(improvement.oid))
	for player in range(2):
		for deed in e.state.players[player].get("deeds", []):
			if listening.has(str(deed.card)):
				_add_card_listeners(e, found, kind, payload, str(deed.card), Stats.object_ctx(e, deed), 3, 0, int(deed.oid))
	return found

static func _add_card_listeners(e, found: Array, kind: String, payload: Dictionary, card_id: String, ctx: Dictionary,
		zone: int, position: int, id: int) -> void:
	var rules: Dictionary = e.library.rules(card_id)
	for index in rules.get("events", {}).get(kind, []):
		var ability: Dictionary = rules.abilities[index]
		_consider(e, found, kind, payload, ability, ctx, zone, position, index, id)

static func _add_granted_listeners(e, found: Array, kind: String, payload: Dictionary, mods: Array, ctx: Dictionary,
		zone: int, position: int, id: int) -> void:
	var count = 0
	for entry in mods:
		var ability = Stats.granted_ability(e, entry)
		if ability.is_empty():
			continue
		count += 1
		if str(ability.kind) == "trigger" and str(ability.on) == kind:
			var granted_ctx = ctx.duplicate()
			granted_ctx.card = str(ability.card)
			# Granted abilities come after printed ones (spec §4.2 ability_index).
			_consider(e, found, kind, payload, ability, granted_ctx, zone, position, 1000 + count, id)

static func _consider(e, found: Array, kind: String, payload: Dictionary, ability: Dictionary, ctx: Dictionary,
		zone: int, position: int, index: int, id: int) -> void:
	var source_lane = int(ctx.get("lane", -1))
	if kind in Vocab.LANE_EVENTS and str(ability.get("lane", "self")) == "self":
		# "lanes": a battle between units of two lanes is heard in both (Gank).
		if int(payload.get("lane", -2)) != source_lane and source_lane not in payload.get("lanes", []):
			return
	var check = ctx.duplicate()
	check["event"] = payload
	if not _filter_ok(e, ability.get("filter", {}), kind, payload, check):
		return
	if ability.get("where") != null and not VM.cond(e, ability.where, check):
		return
	if ability.has("once_per"):
		var mark = str(ability.id)
		if str(ability.once_per) == "lane_round":
			mark += ":%d" % int(payload.get("lane", -1))
		var holder = _once_holder(e, ctx.src)
		if holder == null:
			return
		if int(holder.get("used", {}).get(mark, -1)) == int(e.state.round):
			return
		if not holder.has("used"):
			holder["used"] = {}
		holder.used[mark] = int(e.state.round)
	found.append({"ability": ability, "ctx": check, "lane": source_lane, "zone": zone, "position": position,
		"index": index, "id": id})

## The state dictionary that stores once-per marks for a source.
static func _once_holder(e, source):
	match Select.kind_of(source):
		"unit", "improvement", "deed":
			return source
		"item":
			var host = e.find_unit(int(source.uid))
			return host.get("item_state", {}).get(str(source.slot)) if not host.is_empty() else null
	return null

## Filter sugar (spec §3.8); sides and players are relative to the controller.
static func _filter_ok(e, filter: Dictionary, kind: String, payload: Dictionary, ctx: Dictionary) -> bool:
	if filter.is_empty():
		return true
	var controller = int(ctx.get("controller", 0))
	for key in filter:
		var value = filter[key]
		match key:
			"player":
				var who = int(payload.get("player", -1))
				if (str(value) == "you") != (who == controller):
					return false
			"kind":
				if not _kind_matches(payload, value, kind):
					return false
			"not_kind":
				if _kind_matches(payload, value, kind):
					return false
			"color":
				var colors = value if value is Array else [value]
				if str(payload.get("color", "")) not in colors.map(func(entry): return str(entry)):
					return false
			"cost_max":
				if int(payload.get("cost", 0)) > int(value):
					return false
			"side":
				var owner = int(payload.get("owner", -1))
				if kind == "unit_entered":
					var unit = Select.resolve_unit(e, int(payload.get("unit", 0)))
					owner = int(unit.get("owner", -1))
				elif kind == "improvement_entered":
					owner = int(payload.get("owner", -1))
				if (str(value) == "ally") != (owner == controller):
					return false
			"card":
				var cards = value if value is Array else [value]
				if str(payload.get("card", "")) not in cards.map(func(entry): return str(entry)):
					return false
			"was":
				var host = ctx.get("host")
				if not host is Dictionary or host.is_empty():
					return false
				var host_uid = int(host.get("uid", -1))
				match str(value):
					"allied_neighbor":
						if host_uid not in payload.get("neighbors", []):
							return false
					"enemy_neighbor":
						if host_uid not in payload.get("enemy_neighbors", []):
							return false
					"blocker":
						# The dead unit was $host's combat target ("a unit
						# blocking it"), whether or not $host could attack.
						if host_uid not in payload.get("blocking", payload.get("attackers", [])):
							return false
			"role":
				var host = ctx.get("host")
				var host_uid = int(host.get("uid", -1)) if host is Dictionary else -1
				var field = "source" if str(value) == "dealer" else "target"
				if not (payload.get(field) is int and int(payload[field]) == host_uid):
					return false
			"target_kind":
				var target = payload.get("target")
				var is_tower = target is String
				match str(value):
					"tower":
						if not is_tower:
							return false
					"unit":
						if is_tower:
							return false
					"hero", "creep":
						if is_tower:
							return false
						var unit = Select.resolve_unit(e, int(target))
						if unit.is_empty() or bool(unit.get("hero", false)) != (str(value) == "hero"):
							return false
			"source_kind":
				var source = payload.get("source")
				if (str(value) == "tower") != (source is String):
					return false
			"in_combat":
				if bool(payload.get("in_combat", false)) != bool(value):
					return false
			"how":
				if str(payload.get("how", "")) != str(value):
					return false
	return true

static func _kind_matches(payload: Dictionary, value, kind: String) -> bool:
	var kinds = (value if value is Array else [value]).map(func(entry): return str(entry))
	if kind in ["unit_died", "death"]:
		return ("hero" if bool(payload.get("hero", false)) else "creep") in kinds
	return str(payload.get("kind", "")) in kinds

# --- The Pulse -------------------------------------------------------------------

## Continuous effects update, deaths are processed, and queued triggers
## resolve in batches until nothing is left (spec §4.1).
static func pulse(e) -> void:
	e._pulse_depth += 1
	if e._pulse_depth > MAX_PULSE_DEPTH:
		overflow(e)
		e._pulse_depth -= 1
		return
	for loop in range(MAX_PULSE_LOOPS):
		Stats.settle(e)
		var dying = _collect_dying(e)
		dying.units = _resolve_dying(e, dying.units)
		var removed = not dying.units.is_empty() or not dying.items.is_empty() or not dying.improvements.is_empty()
		if removed:
			var snapshots = _snapshot(e, dying.units)
			_remove(e, dying, snapshots)
			for snapshot in snapshots:
				emit(e, "death", snapshot)
				emit(e, "unit_died", snapshot)
			Stats.settle(e)
		if e._queue.is_empty():
			if not removed:
				break
			# A removal can end an aura whose loss drops another unit to 0
			# health (RQ-40, settled above): loop again so it dies in this Pulse.
			continue
		var batch: Array = e._queue
		e._queue = []
		batch.sort_custom(func(a, b): return key_less(a.key, b.key))
		for instance in batch:
			if e._ops_left <= 0:
				break
			_resolve_trigger(e, instance)
			if BATCH_MODE == "per_trigger":
				pulse(e)
		if loop == MAX_PULSE_LOOPS - 1:
			overflow(e)
	e._pulse_depth -= 1

static func _resolve_trigger(e, instance: Dictionary) -> void:
	var ability: Dictionary = instance.ability
	var ctx: Dictionary = instance.ctx.duplicate()
	ctx["event"] = instance.event
	ctx["choices"] = {}
	ctx["vars"] = {}
	# A source that left play resolves to its look-back snapshot (ops on it fizzle).
	var source = ctx.get("src")
	if Select.kind_of(source) == "unit" and not Select.in_play(e, source) and e._lookback.has(int(source.uid)):
		ctx.src = e._lookback[int(source.uid)]
		if Select.kind_of(ctx.get("host")) == "unit" and int(ctx.host.uid) == int(source.uid):
			ctx.host = ctx.src
	e._event("trigger", {"src": Select.key(ctx.src) if ctx.get("src") != null else "", "card": str(ability.get("card", "")),
		"ability": str(ability.get("id", "")), "p": int(ctx.get("controller", 0))})
	VM.run(e, ability.get("ops", []), ctx)

static func overflow(e) -> void:
	e._queue = []
	e._ops_left = 0
	e._event("rules_overflow")

# --- Deaths -----------------------------------------------------------------------

## Units in lanes with health 0 or less or condemned (lane, owner, slot order,
## exactly as the legacy cleanup), plus condemned items and improvements.
static func _collect_dying(e) -> Dictionary:
	var units: Array = []
	var items: Array = []
	var improvements: Array = []
	for lane_index in range(3):
		var lane: Dictionary = e.state.lanes[lane_index]
		for player in range(2):
			for unit in lane.units[player]:
				if unit == null:
					continue
				if int(unit.health) <= 0 or bool(unit.get("condemned", false)):
					units.append(unit)
			for improvement in lane.get("improvements", [[], []])[player]:
				if bool(improvement.get("condemned", false)):
					improvements.append(improvement)
	for unit in Stats.all_units(e):
		var instances: Dictionary = unit.get("item_state", {})
		if instances.is_empty():
			continue
		for slot in ["weapon", "armor", "accessory"]:
			if bool(instances.get(slot, {}).get("condemned", false)):
				items.append([unit, slot])
	return {"units": units, "items": items, "improvements": improvements}

## Death Shields first save units from the dying set; Soulbound then closes
## only from units that actually die, and a twin it adds may still be saved by
## its own shield (RQ-10, RQ-11, RQ-39).
static func _resolve_dying(e, dying: Array) -> Array:
	var dies = _consume_death_shields(e, dying)
	var closed = _close_soulbound(e, dies)
	if closed.size() == dies.size():
		return dies
	var members: Dictionary = {}
	for unit in dies:
		members[int(unit.uid)] = true
	var added: Array = []
	for unit in closed:
		if not members.has(int(unit.uid)):
			added.append(unit)
	for unit in _consume_death_shields(e, added):
		members[int(unit.uid)] = true
	return closed.filter(func(unit): return members.has(int(unit.uid)))

## Soulbound (RQ-39): a dying Soulbound unit condemns every other allied unit
## with the same card in any lane, in this same Pulse.
static func _close_soulbound(e, dying: Array) -> Array:
	var out = dying.duplicate()
	var members: Dictionary = {}
	for unit in out:
		members[int(unit.uid)] = true
	var index = 0
	while index < out.size():
		var unit: Dictionary = out[index]
		index += 1
		if not Stats.flag(e, unit, "soulbound"):
			continue
		for lane_index in range(3):
			for partner in e.state.lanes[lane_index].units[int(unit.owner)]:
				if partner == null or str(partner.card) != str(unit.card) or members.has(int(partner.uid)):
					continue
				partner["condemned"] = true
				members[int(partner.uid)] = true
				out.append(partner)
	if out.size() == dying.size():
		return dying
	# Keep the legacy cleanup order: lane, owner, slot.
	out.sort_custom(func(a, b): return Select.before(_death_order(e, a), _death_order(e, b)))
	return out

static func _death_order(e, unit: Dictionary) -> Array:
	return [int(unit.lane), int(unit.owner), Zones.slot_of(e, unit), int(unit.uid)]

## A dying unit with a Death Shield loses one shield and survives at 1
## health; it saves from condemn, Lethal and Soulbound alike (RQ-10, RQ-11).
## Only the shield is used up: the rest of the entry that carried it stays.
static func _consume_death_shields(e, dying: Array) -> Array:
	var out: Array = []
	for unit in dying:
		if not Stats.status(e, unit, "death_shield"):
			out.append(unit)
			continue
		_use_death_shield(unit)
		unit.health = 1
		unit["condemned"] = false
		e._event("shield", {"uid": int(unit.uid), "card": str(unit.card)})
	return out

## Removes one Death Shield: from a give entry first (an entry left with
## nothing else is dropped), otherwise from the unit's own keywords (a Modify
## and its provenance entry, or a printed shield).
static func _use_death_shield(unit: Dictionary) -> void:
	var mods: Array = unit.get("mods", [])
	for index in range(mods.size()):
		var entry: Dictionary = mods[index]
		if str(entry.get("k", "")) != "give" or int(entry.get("kw", {}).get("death_shield", 0)) <= 0:
			continue
		var keywords: Dictionary = entry.kw.duplicate()
		keywords.erase("death_shield")
		entry["kw"] = keywords
		if keywords.is_empty() and entry.get("st", {}).is_empty() and str(entry.get("ab", "")).is_empty():
			mods.remove_at(index)
		return
	var own: Dictionary = unit.get("kw", {})
	if int(own.get("death_shield", 0)) <= 0:
		return
	for entry in mods:
		if str(entry.get("k", "")) == "modify" and int(entry.get("kw", {}).get("death_shield", 0)) > 0:
			entry.kw["death_shield"] = int(entry.kw.death_shield) - 1
			if int(entry.kw.death_shield) <= 0:
				entry.kw.erase("death_shield")
			break
	own["death_shield"] = int(own.death_shield) - 1
	if int(own.death_shield) <= 0:
		own.erase("death_shield")

## Look-back snapshots, taken for every dying unit before any is removed.
static func _snapshot(e, units: Array) -> Array:
	var snapshots: Array = []
	for unit in units:
		var lane_index = int(unit.lane)
		var slot = Zones.slot_of(e, unit)
		var rows = e.state.lanes[lane_index].units
		var own = rows[int(unit.owner)]
		var enemy = rows[1 - int(unit.owner)]
		var neighbors: Array = []
		for index in [slot - 1, slot + 1]:
			if index >= 0 and index < own.size() and own[index] != null:
				neighbors.append(int(own[index].uid))
		var enemy_neighbors: Array = []
		for index in [slot - 1, slot, slot + 1]:
			if index >= 0 and index < enemy.size() and enemy[index] != null:
				enemy_neighbors.append(int(enemy[index].uid))
		var across = int(enemy[slot].uid) if slot >= 0 and slot < enemy.size() and enemy[slot] != null else 0
		var target = e.combat_target_of(unit)
		# `blocking`: every enemy unit whose combat target was this unit, the
		# units it was blocking (glossary: a unit is unblocked only when its
		# combat target is the tower; stun and disarm stop attacking, not
		# blocking). `attackers` leaves out disarmed and stunned ones (RQ-05).
		var attackers: Array = []
		var blocking: Array = []
		for index in range(enemy.size()):
			var attacker = enemy[index]
			if attacker == null:
				continue
			var aimed = e._combat_target(attacker, lane_index, index)
			if not aimed.is_empty() and int(aimed.uid) == int(unit.uid):
				blocking.append(int(attacker.uid))
				if not Stats.flag(e, attacker, "disarm"):
					attackers.append(int(attacker.uid))
		var derived = Stats.derive(e, unit)
		var snapshot = {"snap": true, "uid": int(unit.uid), "card": str(unit.card), "owner": int(unit.owner),
			"hero": bool(unit.hero), "color": str(unit.get("color", "neutral")), "lane": lane_index, "slot": slot,
			"neighbors": neighbors, "enemy_neighbors": enemy_neighbors, "across": across,
			"target": int(target.get("uid", 0)), "attackers": attackers, "blocking": blocking,
			"items": unit.get("items", {}).duplicate(),
			"attack": int(derived.attack), "armor": int(derived.armor), "max_health": int(derived.max_health),
			"kw": derived.kw, "mods": unit.get("mods", []).duplicate(true), "health": int(unit.health),
			"cause": e._causes.get(int(unit.uid), {})}
		e._lookback[int(unit.uid)] = snapshot
		snapshots.append(snapshot)
	return snapshots

## Removes the dying (spec §4.3): bounty to the opponent, attackers released,
## roster heroes (summoned ones included, RQ-29) to the Fountain, creeps out
## of the game.
static func _remove(e, dying: Dictionary, snapshots: Array) -> void:
	var lanes: Dictionary = {}
	for unit in dying.units:
		var lane_index = int(unit.lane)
		lanes[lane_index] = true
		Zones.align(e, lane_index)
		var slot = Zones.slot_of(e, unit)
		var player = int(unit.owner)
		# Classic bounty belongs to the opponent whenever a unit dies,
		# including friendly spells and symmetric board clears (RQ-02).
		var bounty = maxi(0, Stats.keyword(e, unit, "bounty"))
		e.state.players[1 - player].gold += bounty
		Zones.release_attackers(e, lane_index, unit, slot)
		unit["condemned"] = false
		if bool(unit.hero) and bool(unit.get("roster", true)):
			Zones.enter_fountain(e, unit, int(e.state.round) + (1 if Stats.flag(e, unit, "rapid_deployment") else 2))
		else:
			unit.lane = -1
		e._event("death", {"p": player, "uid": unit.uid, "card": unit.card, "gold": bounty})
		e.state.lanes[lane_index].units[player][slot] = null
	for entry in dying.items:
		var host: Dictionary = entry[0]
		var slot_name: String = entry[1]
		var card_id = str(host.items.get(slot_name, ""))
		host.items.erase(slot_name)
		host.item_state.erase(slot_name)
		e._event("item_gone", {"uid": int(host.uid), "slot": slot_name, "card": card_id})
	for improvement in dying.improvements:
		var row: Array = e.state.lanes[int(improvement.lane)].improvements[int(improvement.owner)]
		row.erase(improvement)
		e._event("improvement_gone", {"oid": int(improvement.oid), "card": str(improvement.card)})
	for lane_index in lanes:
		# Simultaneous deaths keep their positions until every corpse is
		# removed; then positions empty on both sides collapse.
		Zones.compact(e, lane_index)
		Zones.normalize_arrows(e, lane_index)

# --- Damage, healing and structures --------------------------------------------------

static func _damage_amount(e, unit: Dictionary, amount: int, piercing: bool) -> int:
	if Stats.flag(e, unit, "damage_immunity"):
		return 0
	return maxi(0, amount if piercing else amount - Stats.armor_of(e, unit))

## Spell and ability damage to units (not battle damage).
static func damage_units(e, units: Array, amount: int, piercing: bool, ctx: Dictionary) -> Array:
	var hits: Array = []
	if SIMULTANEOUS_DAMAGE:
		var amounts: Array = []
		for unit in units:
			amounts.append(_damage_amount(e, unit, amount, piercing))
		for index in range(units.size()):
			units[index].health = int(units[index].health) - int(amounts[index])
			hits.append([int(units[index].uid), int(amounts[index])])
	else:
		for unit in units:
			var dealt = _damage_amount(e, unit, amount, piercing)
			unit.health = int(unit.health) - dealt
			hits.append([int(unit.uid), dealt])
	for hit in hits:
		e._causes[int(hit[0])] = {"src": str(ctx.get("card", "")), "p": int(ctx.get("controller", 0))}
	if not hits.is_empty():
		e._event("damage", {"src": str(ctx.get("card", "")), "p": int(ctx.get("controller", 0)), "hits": hits, "pierce": piercing})
	return hits

## Heals units up to their derived maximum; `amount` -1 heals fully.
static func heal_units(e, units: Array, amount: int, ctx: Dictionary) -> void:
	var hits: Array = []
	for unit in units:
		var cap = Stats.max_health(e, unit)
		var healed = cap if amount < 0 else mini(cap, int(unit.health) + amount)
		hits.append([int(unit.uid), healed - int(unit.health)])
		unit.health = healed
	if not hits.is_empty():
		e._event("heal", {"src": str(ctx.get("card", "")), "p": int(ctx.get("controller", 0)), "hits": hits})

## Tower damage after tower armor (none when piercing). Returns the amount.
static func tower_damage(e, lane_index: int, defender: int, amount: int, piercing: bool) -> int:
	var dealt = maxi(0, amount if piercing else amount - int(Stats.tower(e, lane_index, defender).armor))
	damage_structure(e, lane_index, defender, dealt)
	return dealt

## Applies damage to a lane's standing structure: a tower falls into an
## 80-health ancient with no overflow. The only writer of round_log.tower_hit.
## `regeneration` (the combat phase only) heals the structure after the
## damage and before the fall check, up to 40 (80 for an ancient): it can
## keep a tower standing, but a tower that falls leaves a fresh 80-health
## ancient that this combat's Regeneration does not heal (RQ-09).
static func damage_structure(e, lane_index: int, defender: int, amount: int, regeneration: int = 0) -> void:
	var structure = e.state.lanes[lane_index].structures[defender]
	if structure.destroyed:
		return
	if amount > 0 and e.state.has("round_log"):
		e.state.round_log.tower_hit[defender][lane_index] = true
	structure.health -= amount
	if regeneration > 0:
		var cap = 80 if bool(structure.ancient) else 40
		structure.health = maxi(int(structure.health), mini(cap, int(structure.health) + regeneration))
	if structure.health <= 0:
		if structure.ancient:
			structure.destroyed = true
			structure.health = 0
			e._event("ancient_fall", {"p": defender})
		else:
			structure.ancient = true
			structure.health = 80
			e._event("tower_fall", {"p": defender})

# --- Modifiers --------------------------------------------------------------------

## Permanent Modify: deltas are written into the target's own fields and a
## provenance entry is recorded (coalesced per by/src) so Purge can reverse it.
static func modify(e, target, stats: Dictionary, keywords: Dictionary, grant: String, ctx: Dictionary) -> void:
	var by = int(ctx.get("controller", 0))
	var source = str(ctx.get("card", ""))
	match Select.kind_of(target):
		"unit":
			if int(target.get("lane", -1)) < 0 and not bool(target.get("roster", false)):
				return
			if int(target.get("lane", -1)) >= 0 and not Select.in_play(e, target):
				return
			var written: Dictionary = {}
			for stat in ["attack", "armor", "max_health"]:
				if stats.has(stat):
					target[stat] = int(target.get(stat, 0)) + int(stats[stat])
					written[stat] = int(stats[stat])
			if not target.has("kw"):
				target["kw"] = {}
			for keyword in keywords:
				target.kw[keyword] = int(target.kw.get(keyword, 0)) + int(keywords[keyword])
			_record(e, target, "modify", by, source, written, keywords, grant, "perm")
			e._event("mod", _with_grant({"id": int(target.uid), "card": str(target.card), "st": written, "kw": keywords, "perm": true, "src": source}, grant))
		"tower":
			var lane: Dictionary = e.state.lanes[int(target.lane)]
			var structure: Dictionary = lane.structures[int(target.p)]
			var written: Dictionary = {}
			if stats.has("armor"):
				structure["armor"] = int(structure.get("armor", 0)) + int(stats.armor)
				written["armor"] = int(stats.armor)
			if stats.has("mana"):
				Stats.add_mana_base(e, int(target.lane), int(target.p), int(stats.mana))
				written["mana"] = int(stats.mana)
			if not structure.has("kw"):
				structure["kw"] = {}
			for keyword in keywords:
				structure.kw[keyword] = int(structure.kw.get(keyword, 0)) + int(keywords[keyword])
			_record(e, structure, "modify", by, source, written, keywords, grant, "perm")
			e._event("mod", _with_grant({"id": Select.key(target), "tower": [int(target.lane), int(target.p)], "st": written, "kw": keywords, "perm": true, "src": source}, grant))
		"item":
			# M6: a Modify on an item instance ("Modify Stonehall Pike with
			# ...") records the granted text on that instance, where it works
			# like the item's printed text: host auras wherever the hero is,
			# other auras and triggers while the hero is in a lane (RQ-38).
			# The entries stack, leave with the instance when the item is
			# replaced or condemned, and Purge never reaches them (RQ-12). An
			# item has no stats or keywords of its own, so only grants apply.
			if grant.is_empty() or not Select.in_play(e, target):
				return
			var host = Select.resolve_unit(e, int(target.uid))
			var instance: Dictionary = host.get("item_state", {}).get(str(target.slot), {})
			if instance.is_empty():
				return
			_record(e, instance, "modify", by, source, {}, {}, grant, "perm")
			e._event("mod", _with_grant({"id": int(target.oid), "card": str(target.card), "st": {}, "kw": {}, "perm": true, "src": source}, grant))
		"snapshot":
			# RQ-54: a roster hero that died earlier in this command is in the
			# Fountain. Heroes keep modifications through death (glossary), and a
			# Pulse processes reactive abilities before it destroys units, so a
			# Modify that resolves after the removal still reaches that hero.
			if MODIFY_REACHES_DEAD_HEROES and bool(target.get("hero", false)):
				var hero = _fountain_hero(e, int(target.get("uid", 0)))
				if not hero.is_empty():
					modify(e, hero, stats, keywords, grant, ctx)

## The roster hero with `uid` while it is in the Fountain, or {}.
static func _fountain_hero(e, uid: int) -> Dictionary:
	for owner in e.state.players:
		for hero in owner.roster:
			if int(hero.uid) == uid and bool(hero.get("roster", true)) and int(hero.get("lane", -1)) < 0:
				return hero
	return {}

## A mod/status event carries the granted text's reference ("<card>#<index>")
## when the effect grants text, so the log can show that text.
static func _with_grant(payload: Dictionary, grant: String) -> Dictionary:
	if not grant.is_empty():
		payload["ab"] = grant
	return payload

## Temporary effect: an entry pulled at read time until `until` ends it.
static func give(e, target, stats: Dictionary, keywords: Dictionary, grant: String, until: String, ctx: Dictionary) -> void:
	var by = int(ctx.get("controller", 0))
	var source = str(ctx.get("card", ""))
	var granted = keywords.duplicate()
	match Select.kind_of(target):
		"unit":
			if not Select.in_play(e, target):
				return
			# A unit holds at most one Death Shield (RQ-11).
			if granted.has("death_shield") and Stats.status(e, target, "death_shield"):
				granted.erase("death_shield")
			if stats.is_empty() and granted.is_empty() and grant.is_empty():
				return
			_record(e, target, "give", by, source, stats, granted, grant, until)
			_stamp_combat(e, target, int(target.lane), until)
			e._event("status", _with_grant({"id": int(target.uid), "card": str(target.card), "st": stats, "kw": granted, "until": until, "src": source}, grant))
		"tower":
			var structure: Dictionary = e.state.lanes[int(target.lane)].structures[int(target.p)]
			_record(e, structure, "give", by, source, stats, granted, grant, until)
			_stamp_combat(e, structure, int(target.lane), until)
			e._event("status", _with_grant({"id": Select.key(target), "tower": [int(target.lane), int(target.p)], "st": stats, "kw": granted, "until": until, "src": source}, grant))

## A next_combat entry given while its own lane's combat resolves (a death
## or battle-damage trigger) lasts until the lane's next combat: it carries the
## combat's sequence number, which that combat's expiry skips.
static func _stamp_combat(e, holder: Dictionary, lane_index: int, until: String) -> void:
	if until == "next_combat" and int(e._combat_lane) >= 0 and lane_index == int(e._combat_lane):
		holder.mods.back()["seq"] = int(e.state.get("combat_seq", 0))

static func _record(e, holder: Dictionary, kind: String, by: int, source: String, stats: Dictionary,
		keywords: Dictionary, grant: String, duration: String) -> void:
	if not holder.has("mods"):
		holder["mods"] = []
	if kind == "modify" and grant.is_empty():
		for entry in holder.mods:
			if str(entry.k) == "modify" and int(entry.by) == by and str(entry.src) == source \
					and str(entry.d) == duration and str(entry.get("ab", "")).is_empty():
				for stat in stats:
					entry.st[stat] = int(entry.st.get(stat, 0)) + int(stats[stat])
				for keyword in keywords:
					entry.kw[keyword] = int(entry.kw.get(keyword, 0)) + int(keywords[keyword])
				return
	holder.mods.append({"id": next_oid(e), "k": kind, "by": by, "src": source, "st": stats.duplicate(),
		"kw": keywords.duplicate(), "ab": grant, "d": duration})

## Removes the opponent's (or everyone's) modify and give entries and reverses
## the written-through deltas of removed modify entries (RQ-12).
static func purge(e, target, from: String, ctx: Dictionary) -> void:
	var holder: Dictionary = {}
	var lane_index = -1
	var name = ""
	match Select.kind_of(target):
		"unit":
			if not Select.in_play(e, target):
				return
			holder = target
			name = str(target.card)
		"tower":
			holder = e.state.lanes[int(target.lane)].structures[int(target.p)]
			lane_index = int(target.lane)
		_:
			return
	var opponent = 1 - int(ctx.get("controller", 0))
	var kept: Array = []
	var removed = 0
	for entry in holder.get("mods", []):
		if from == "all" or int(entry.by) == opponent:
			removed += 1
			if str(entry.k) == "modify":
				for stat in entry.get("st", {}):
					if stat == "mana" and lane_index >= 0:
						Stats.add_mana_base(e, lane_index, int(target.p), -int(entry.st[stat]))
					else:
						holder[stat] = int(holder.get(stat, 0)) - int(entry.st[stat])
				for keyword in entry.get("kw", {}):
					holder.kw[keyword] = int(holder.kw.get(keyword, 0)) - int(entry.kw[keyword])
					if int(holder.kw[keyword]) == 0:
						holder.kw.erase(keyword)
			continue
		kept.append(entry)
	holder["mods"] = kept
	if removed > 0:
		e._event("purge", {"id": Select.key(target), "card": name, "n": removed})

## Marks a unit, item or improvement for death at the next Pulse.
static func condemn(e, target, ctx: Dictionary) -> void:
	match Select.kind_of(target):
		"unit":
			if not Select.in_play(e, target):
				return
			target["condemned"] = true
			e._causes[int(target.uid)] = {"src": str(ctx.get("card", "")), "p": int(ctx.get("controller", 0))}
			e._event("condemn", {"id": int(target.uid), "card": str(target.card)})
		"item":
			if not Select.in_play(e, target):
				return
			var host = Select.resolve_unit(e, int(target.uid))
			host.item_state[str(target.slot)]["condemned"] = true
			e._event("condemn", {"id": int(target.oid), "card": str(target.card)})
		"improvement":
			if not Select.in_play(e, target):
				return
			target["condemned"] = true
			e._event("condemn", {"id": int(target.oid), "card": str(target.card)})

## Sets a unit's combat target: "across" (straight ahead, legacy Forward
## Charge), 0 (the tower; the arrow is kept), or a unit (the arrow points at it).
static func retarget(e, unit: Dictionary, to) -> void:
	if not Select.in_play(e, unit):
		return
	if to is String and str(to) == "across":
		unit.arrow = 0
		unit.combat_target = -1
	elif to is int and int(to) == 0:
		unit.combat_target = 0
	elif Select.kind_of(to) == "unit" and Select.in_play(e, to):
		unit.combat_target = int(to.uid)
		unit.arrow = Zones.slot_of(e, to) - Zones.slot_of(e, unit)
	else:
		return
	e._event("retarget", {"uid": int(unit.uid), "card": str(unit.card), "target": int(unit.combat_target)})

static func charges_of(e, item) -> int:
	match Select.kind_of(item):
		"unit", "improvement", "snapshot":
			return int(item.get("charges", 0))
		"item":
			var host = Select.resolve_unit(e, int(item.uid))
			return int(host.get("item_state", {}).get(str(item.slot), {}).get("charges", 0))
	return 0

static func change_charges(e, target, op: Dictionary, ctx: Dictionary) -> void:
	var holder: Dictionary = {}
	var id = 0
	var name = ""
	match Select.kind_of(target):
		"unit", "improvement":
			if not Select.in_play(e, target):
				return
			holder = target
			id = int(target.get("uid", target.get("oid", 0)))
			name = str(target.get("card", ""))
		"item":
			if not Select.in_play(e, target):
				return
			holder = Select.resolve_unit(e, int(target.uid)).item_state[str(target.slot)]
			id = int(target.oid)
			name = str(target.card)
		_:
			return
	var before = int(holder.get("charges", 0))
	var after = VM.expr(e, op.set, ctx) if op.has("set") else before + VM.expr(e, op.get("add", 0), ctx)
	if op.has("min"):
		after = maxi(int(op.min), after)
	holder["charges"] = after
	if after != before:
		e._event("charges", {"id": id, "card": name, "n": after})

## Base gold cost of an item card id or item instance (Ravenhook).
static func price_value(e, item) -> int:
	if item is String:
		return int(e.library.get_card(str(item)).get("price", 0))
	if Select.kind_of(item) == "item":
		return int(e.library.get_card(str(item.card)).get("price", 0))
	if Select.kind_of(item) == "card":
		return int(e.library.get_card(str(item.card)).get("price", 0))
	return 0

## Secret Shop prices follow the rules layer (spec §3.11); others are base.
static func price_of(e, player: int, source: String, card_id: String) -> int:
	var base = int(e.library.get_card(card_id).get("price", 0))
	if source == "secret":
		return base - int(Stats.rules_of(e, player).secret_shop_discount) * base
	return base

static func next_oid(e) -> int:
	var oid = int(e.state.get("next_oid", 1000000))
	e.state["next_oid"] = oid + 1
	return oid

# --- Lanes and rounds ----------------------------------------------------------------

## A lane's action phase begins: before-action triggers, a Pulse, the winner check.
static func lane_open(e, lane_index: int) -> void:
	emit(e, "before_action", {"lane": lane_index})
	pulse(e)
	e._check_winner()

## Removes give entries of `duration` from units (and towers) in `lane_index`.
## next_combat entries given during this very combat stay (Kernel._stamp_combat).
static func expire(e, lane_index: int, duration: String) -> void:
	var keep_seq = int(e.state.get("combat_seq", 0)) if duration == "next_combat" else -1
	for row in e.state.lanes[lane_index].units:
		for unit in row:
			if unit != null:
				_drop_entries(unit, duration, keep_seq)
	for structure in e.state.lanes[lane_index].structures:
		_drop_entries(structure, duration, keep_seq)

static func _drop_entries(holder: Dictionary, duration: String, keep_seq: int = -1) -> void:
	if not holder.has("mods") or holder.mods.is_empty():
		return
	var kept: Array = []
	for entry in holder.mods:
		if not (str(entry.k) == "give" and str(entry.d) == duration) \
				or (keep_seq >= 0 and int(entry.get("seq", -1)) == keep_seq):
			kept.append(entry)
	holder["mods"] = kept

## End of the round (spec §4.6): round entries end, locks and cooldowns
## tick down, the round log clears, then a settle.
static func end_of_round(e) -> void:
	var units = Stats.all_units(e)
	for unit in units:
		_drop_entries(unit, "round")
		for slot in unit.get("item_state", {}):
			var instance: Dictionary = unit.item_state[slot]
			_drop_entries(instance, "round")
			instance["cd"] = maxi(0, int(instance.get("cd", 0)) - 1)
		# Cooldowns tick for roster heroes in any zone and for units in lanes.
		if bool(unit.get("roster", false)) or int(unit.get("lane", -1)) >= 0:
			unit["cooldown"] = maxi(0, int(unit.get("cooldown", 0)) - 1)
	for lane in e.state.lanes:
		for structure in lane.structures:
			_drop_entries(structure, "round")
		for row in lane.get("improvements", [[], []]):
			for improvement in row:
				_drop_entries(improvement, "round")
				improvement["cd"] = maxi(0, int(improvement.get("cd", 0)) - 1)
	for owner in e.state.players:
		for entry in owner.get("hand_state", []):
			if int(entry.get("lock", 0)) > 0:
				entry["lock"] = int(entry.lock) - 1
	if e.state.has("round_log"):
		e.state["round_log"] = new_round_log()
	Stats.settle(e)

static func new_round_log() -> Dictionary:
	return {"tower_hit": [[false, false, false], [false, false, false]], "hits": []}
