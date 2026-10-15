extends RefCounted
## Global match invariants (EFFECT_SYSTEM_SPEC.md §13.3), shared by the bot
## match tests, the golden gate and the rules tests. Each check returns true
## when the invariant holds; the *violations() functions list every failed one
## by name.
##
## violations(engine)       I1 to I10: the structural invariants, cheap enough
##                          for every step of every recorded or bot game.
## write_through(engine)    I11: own stats and keywords = printed + modify
##                          entries (only for engine-created units; fixtures
##                          that write fields directly skip it).
## deep_violations(engine)  I12 privacy, I13 purity of the read-only API and
##                          I14 action and packet bounds. They call the whole
##                          read API, so callers sample steps.

const Vocab = preload("res://scripts/core/rules/vocab.gd")
const MOD_KINDS = ["modify", "give"]
## A modify entry lasts forever; give entries carry a Vocab duration.
const MOD_DURATIONS = ["perm", "round", "next_combat", "death", "equip", "used"]
const LEGAL_ACTIONS_LIMIT = 2000
const PACKET_LIMIT = 200000

## I1 + I2 + part of I3: both rows of every lane have equal length, no
## position is empty on both sides, every unit knows its lane and owner, a
## diagonal arrow only exists while the unit is unblocked and a unit stands on
## that diagonal (unless a forced combat target overrides the arrow), and a
## forced tower target only exists while the position across is empty (RQ-19).
static func board(engine) -> bool:
	for lane_index in range(3):
		var rows = engine.state.lanes[lane_index].units
		if rows[0].size() != rows[1].size():
			return false
		for slot in range(rows[0].size()):
			if rows[0][slot] == null and rows[1][slot] == null:
				return false
			for side in range(2):
				var unit = rows[side][slot]
				if unit == null:
					continue
				if int(unit.owner) != side or int(unit.lane) != lane_index:
					return false
				var enemies = rows[1 - side]
				if int(unit.get("combat_target", -1)) == 0 and enemies[slot] != null:
					return false
				if int(unit.arrow) != 0 and int(unit.combat_target) < 0:
					var diagonal = slot + int(unit.arrow)
					if enemies[slot] != null or diagonal < 0 or diagonal >= enemies.size() or enemies[diagonal] == null:
						return false
	return true

## I1 only: rows aligned and compacted (no position empty on both sides).
static func aligned(engine) -> bool:
	for lane in engine.state.lanes:
		if lane.units[0].size() != lane.units[1].size():
			return false
		for slot in range(lane.units[0].size()):
			if lane.units[0][slot] == null and lane.units[1][slot] == null:
				return false
	return true

## Names of the structural invariants (I1 to I10) that do not hold right now
## (empty when all hold). Checks that need rules state are skipped on engines
## without it (the frozen legacy engine).
static func violations(engine) -> Array:
	var failed: Array = []
	if not board(engine):
		failed.append("I1/I2 board")
	var state: Dictionary = engine.state
	var seen: Dictionary = {}
	var ids: Dictionary = {}
	for lane_index in range(3):
		var lane: Dictionary = state.lanes[lane_index]
		for side in range(2):
			for unit in lane.units[side]:
				if unit == null:
					continue
				# I3: units in a lane are alive and not marked for death.
				if int(unit.health) <= 0 or bool(unit.get("condemned", false)):
					failed.append("I3 dead unit %d in lane %d" % [int(unit.uid), lane_index])
				if seen.has(int(unit.uid)):
					failed.append("I6 duplicate uid %d" % int(unit.uid))
				seen[int(unit.uid)] = true
				# I4: health never exceeds the derived maximum.
				if int(unit.health) > int(engine.max_health_of(unit)):
					failed.append("I4 health above max for %d" % int(unit.uid))
				if unit.has("hp_seen") and int(unit.hp_seen) != int(engine.max_health_of(unit)):
					failed.append("I4 hp_seen stale for %d" % int(unit.uid))
			# I5: mana is never negative and matches its base and modifier.
			if int(lane.mana[side]) < 0 or int(lane.max_mana[side]) < 0:
				failed.append("I5 negative mana in lane %d" % lane_index)
			if lane.has("max_mana_base") and int(lane.max_mana[side]) != maxi(0, int(lane.max_mana_base[side]) + int(lane.mana_bonus[side])):
				failed.append("I5 max_mana != base + bonus in lane %d" % lane_index)
			# I8: at most 16 improvements per side of a lane.
			if lane.get("improvements", [[], []])[side].size() > 16:
				failed.append("I8 improvement cap in lane %d" % lane_index)
			# I6: modifier entries and object ids.
			if lane.has("structures"):
				_check_mods(engine, lane.structures[side], "tower %d/%d" % [lane_index, side], ids, failed)
			for improvement in lane.get("improvements", [[], []])[side]:
				_check_id(ids, int(improvement.get("oid", -1)), "improvement", failed)
				_check_mods(engine, improvement, "improvement %s" % str(improvement.get("card", "")), ids, failed)
	for player in range(2):
		var owner: Dictionary = state.players[player]
		# I7: hand state runs parallel to the hand; locks are never negative.
		if owner.has("hand_state"):
			if owner.hand_state.size() != owner.hand.size():
				failed.append("I7 hand_state size for player %d" % player)
			for entry in owner.hand_state:
				if int(entry.get("lock", 0)) < 0:
					failed.append("I7 negative lock for player %d" % player)
				if entry.has("iid"):
					_check_id(ids, int(entry.iid), "hand card", failed)
		if owner.has("deck_state") and not owner.deck_state.is_empty() and owner.deck_state.size() != owner.deck.size():
			failed.append("I7 deck_state size for player %d" % player)
		for entry in owner.get("deck_state", []):
			if entry is Dictionary and entry.has("iid"):
				_check_id(ids, int(entry.iid), "deck card", failed)
		for deed in owner.get("deeds", []):
			_check_id(ids, int(deed.get("oid", -1)), "deed", failed)
			_check_mods(engine, deed, "deed %s" % str(deed.get("card", "")), ids, failed)
		# I10: every roster hero is in exactly one place; a hero in the
		# Fountain keeps no temporary (give) entry.
		for hero in owner.roster:
			var lane_index = int(hero.lane)
			if lane_index >= 0:
				var count = 0
				for unit in state.lanes[lane_index].units[player]:
					if unit != null and int(unit.uid) == int(hero.uid):
						count += 1
				if count != 1:
					failed.append("I10 hero %d is not in its lane exactly once" % int(hero.uid))
			else:
				for entry in hero.get("mods", []):
					if str(entry.get("k", "")) == "give":
						failed.append("I10 hero %d keeps a temporary entry in the Fountain" % int(hero.uid))
	for unit in all_units(engine):
		_check_mods(engine, unit, "unit %d" % int(unit.uid), ids, failed)
		var items: Dictionary = unit.get("items", {})
		var instances: Dictionary = unit.get("item_state", {})
		if not unit.has("item_state"):
			continue
		for slot in instances:
			_check_id(ids, int(instances[slot].get("oid", -1)), "item", failed)
			_check_mods(engine, instances[slot], "item %s of %d" % [slot, int(unit.uid)], ids, failed)
			if not items.has(slot):
				failed.append("I6 item instance without an item in slot %s of %d" % [slot, int(unit.uid)])
		for slot in items:
			if not instances.has(slot):
				failed.append("I6 item in slot %s of %d has no item instance" % [slot, int(unit.uid)])
	# I9: the transient rules queues are empty between commands, the op
	# budget was not spent and no rules_overflow was logged.
	if engine.get("_queue") != null and not engine._queue.is_empty():
		failed.append("I9 trigger queue not empty")
	if engine.get("_pulse_depth") != null and int(engine._pulse_depth) != 0:
		failed.append("I9 pulse depth not zero")
	if engine.get("_ops_left") != null and int(engine._ops_left) <= 0:
		failed.append("I9 op budget exhausted")
	for event in state.get("events", []):
		if event is Dictionary and str(event.get("k", "")) == "rules_overflow":
			failed.append("I9 rules_overflow logged")
			break
	return failed

## Units in lanes plus roster heroes in the Fountain, each once.
static func all_units(engine) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for lane in engine.state.lanes:
		for row in lane.units:
			for unit in row:
				if unit != null and not seen.has(int(unit.uid)):
					seen[int(unit.uid)] = true
					out.append(unit)
	for owner in engine.state.players:
		for hero in owner.get("roster", []):
			if not seen.has(int(hero.uid)):
				seen[int(hero.uid)] = true
				out.append(hero)
	return out

## Item instances, improvements, deeds, hand and deck cards and modifier
## entries share one id counter (Kernel.next_oid), so every id is unique.
static func _check_id(ids: Dictionary, id: int, what: String, failed: Array) -> void:
	if ids.has(id):
		failed.append("I6 duplicate oid %d (%s)" % [id, what])
	ids[id] = true

## I6: every entry has a known kind, duration and side, a unique id, and a
## granted ability ("card#index") that resolves.
static func _check_mods(engine, holder: Dictionary, where: String, ids: Dictionary, failed: Array) -> void:
	for entry in holder.get("mods", []):
		if not entry is Dictionary:
			failed.append("I6 malformed modifier entry on %s" % where)
			continue
		var kind = str(entry.get("k", ""))
		var duration = str(entry.get("d", ""))
		if kind not in MOD_KINDS or duration not in MOD_DURATIONS or int(entry.get("by", -1)) not in [0, 1]:
			failed.append("I6 modifier entry with unknown k/d/by on %s: %s" % [where, entry])
		elif kind == "modify" and duration != "perm":
			failed.append("I6 modify entry with a duration on %s: %s" % [where, entry])
		elif kind == "give" and duration not in Vocab.DURATIONS:
			failed.append("I6 give entry with an unknown duration on %s: %s" % [where, entry])
		var ability = str(entry.get("ab", ""))
		if not ability.is_empty() and engine.library.has_method("rules"):
			var parts = ability.split("#")
			var grants: Array = engine.library.rules(parts[0]).get("grants", []) if parts.size() == 2 else []
			if parts.size() != 2 or not parts[1].is_valid_int() or int(parts[1]) < 0 or int(parts[1]) >= grants.size():
				failed.append("I6 granted ability %s on %s does not resolve" % [ability, where])
		if entry.has("id"):
			_check_id(ids, int(entry.id), "modifier on " + where, failed)

## I11: for engine-created units, own attack, armor and max_health equal the
## printed values plus the deltas of modify entries, and own keywords equal
## the printed keywords (with the default bounty) plus modify keyword deltas.
static func write_through(engine) -> Array:
	var failed: Array = []
	for unit in all_units(engine):
		var printed: Dictionary = engine._definition_or_creep(str(unit.card))
		var want = {"attack": int(printed.get("attack", 0)), "armor": int(printed.get("armor", 0)),
			"max_health": int(printed.get("health", 0))}
		var keywords: Dictionary = {}
		for keyword in engine.library.rules(str(unit.card)).get("keywords", {}):
			keywords[keyword] = int(engine.library.rules(str(unit.card)).keywords[keyword])
		if not keywords.has("bounty"):
			keywords["bounty"] = 5 if bool(unit.get("hero", false)) else 1
		for entry in unit.get("mods", []):
			if str(entry.get("k", "")) != "modify":
				continue
			for stat in entry.get("st", {}):
				want[stat] = int(want.get(stat, 0)) + int(entry.st[stat])
			for keyword in entry.get("kw", {}):
				keywords[keyword] = int(keywords.get(keyword, 0)) + int(entry.kw[keyword])
		for stat in ["attack", "armor", "max_health"]:
			if int(unit.get(stat, 0)) != int(want[stat]):
				failed.append("I11 %s of %d (%s) is %d, printed + modify is %d" % [stat, int(unit.uid), str(unit.card),
					int(unit.get(stat, 0)), int(want[stat])])
		var have: Dictionary = {}
		for keyword in unit.get("kw", {}):
			if int(unit.kw[keyword]) != 0:
				have[keyword] = int(unit.kw[keyword])
		for keyword in keywords.keys():
			if int(keywords[keyword]) == 0:
				keywords.erase(keyword)
		if have != keywords:
			failed.append("I11 keywords of %d (%s) are %s, printed + modify is %s" % [int(unit.uid), str(unit.card), have, keywords])
	return failed

## I12, I13 and I14 together.
static func deep_violations(engine) -> Array:
	var failed: Array = privacy(engine)
	failed.append_array(purity(engine))
	failed.append_array(bounds(engine))
	return failed

## I12: no "_s" private event field, no hand or deck card id of the other
## player and no deck card id at all reaches a player's view.
static func privacy(engine) -> Array:
	var failed: Array = []
	for viewer in range(2):
		var hidden: Dictionary = {}
		for entry in engine.state.players[1 - viewer].get("hand_state", []):
			if entry.has("iid"):
				hidden[int(entry.iid)] = "opponent hand"
		for owner in engine.state.players:
			for entry in owner.get("deck_state", []):
				if entry is Dictionary and entry.has("iid"):
					hidden[int(entry.iid)] = "deck"
		var found: Array = []
		_scan(engine.player_view(viewer), hidden, found)
		if not found.is_empty():
			failed.append("I12 player %d's view leaks %s" % [viewer, found.slice(0, 3)])
	return failed

static func _scan(value, hidden: Dictionary, found: Array) -> void:
	if value is Dictionary:
		for key in value:
			if str(key) == "_s":
				found.append("a private event field")
			_scan(value[key], hidden, found)
	elif value is Array:
		for item in value:
			_scan(item, hidden, found)
	elif (value is int or value is float) and hidden.has(int(value)) and float(int(value)) == float(value):
		found.append("%s id %d" % [hidden[int(value)], int(value)])

## I13 (D3): the read-only API changes neither the state digest nor the
## random state.
static func purity(engine) -> Array:
	var digest = engine.state_digest()
	var rng_state = engine.rng.state
	for player in range(2):
		engine.legal_actions(player)
		engine.player_view(player)
		engine.player_view(player, false)
		engine.rules_of(player)
		engine.hand_public(player)
		engine.simulation_from_view(player)
		for index in range(engine.state.players[player].hand.size()):
			engine.choice_steps({"hand": index})
	for lane_index in range(3):
		engine.combat_preview(lane_index)
		engine.tower_stats(lane_index, 0)
		engine.tower_stats(lane_index, 1)
		engine.creep_positions(lane_index, 0)
		engine.creep_positions(lane_index, 1)
	for unit in all_units(engine):
		engine.attack_of(unit)
		engine.armor_of(unit)
		engine.max_health_of(unit)
		engine.keyword_of(unit, "siege")
		engine.has_flag(unit, "stun")
		engine.badges(unit)
		engine.abilities_of(int(unit.uid))
		engine.combat_targets(unit)
		engine.combat_target_of(unit)
		engine.choice_steps({"unit": int(unit.uid)})
	if engine.state_digest() != digest or engine.rng.state != rng_state:
		return ["I13 the read-only API changed the state digest or the random state"]
	return []

## I14: at most 2000 legal actions, and a view plus its legal actions (the
## guest packet) stays under 200 KB.
static func bounds(engine) -> Array:
	var failed: Array = []
	for viewer in range(2):
		var legal: Array = engine.legal_actions(viewer)
		if legal.size() > LEGAL_ACTIONS_LIMIT:
			failed.append("I14 player %d has %d legal actions" % [viewer, legal.size()])
		var size = JSON.stringify(engine.player_view(viewer)).length() + JSON.stringify(legal).length()
		if size >= PACKET_LIMIT:
			failed.append("I14 player %d's packet is %d bytes" % [viewer, size])
	return failed

## The size in bytes of the larger of the two guest packets (for reports).
static func packet_size(engine) -> int:
	var largest = 0
	for viewer in range(2):
		largest = maxi(largest, JSON.stringify(engine.player_view(viewer)).length() + JSON.stringify(engine.legal_actions(viewer)).length())
	return largest
