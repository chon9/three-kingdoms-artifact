extends RefCounted
## Derived stats, keywords, statuses and the continuous-effect layer
## (EFFECT_SYSTEM_SPEC.md §4.4). Static functions over the engine `e`; no
## instance members. Derivation is pure and uncached (K15).
##
##   attack/armor/max_health/kw = stored fields (printed + permanent Modify)
##     + legacy temp_* shim fields (hand-built fixtures only)
##     + give entries in unit.mods
##     + host auras of the unit's items (also in the Fountain)
##     + layer A: board auras granting stats (they read no derived stats)
##     + layer B: board auras granting keywords (they may read the derived
##       attack, armor and max_health computed by layer A)

const Vocab = preload("res://scripts/core/rules/vocab.gd")
const Select = preload("res://scripts/core/rules/select.gd")
const VM = preload("res://scripts/core/rules/vm.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")

## Aura liveness. FX-3 (RQ-15, false): a unit projects auras until the Pulse
## removes it, as continuous effects update at Pulses (glossary). true: only
## while it has health above 0 and is not condemned, the rule before FX-3.
const AURAS_NEED_HEALTH = false

# --- Units -------------------------------------------------------------------

## Every field a full unit derivation computes, as aura index keys.
const ALL_FIELDS = ["units:attack", "units:armor", "units:max_health", "units:kw"]
const STAT_FIELDS = ["units:attack", "units:armor", "units:max_health"]
const TOWER_FIELDS = ["towers:armor", "towers:mana", "towers:kw"]
const RULES_FIELDS = ["players:rules"]

# --- Read frames (spec §13.6) ------------------------------------------------------
# K15: no caches until a budget fails. The full bot match missed its 3 s
# budget, so the spec's first remedy applies: a derived-stats cache that
# lives only inside an explicit read frame. Frames are opened around pure
# reads only (a combat plan, the bot's evaluation of a simulation, the
# board's display models), never across a mutation, so nothing needs
# invalidating. Frames nest; the cache dies with the outermost one.

static func frame_begin(e) -> void:
	e._frame_depth += 1
	if e._frame_depth == 1:
		e._frame = {"derived": {}, "sources": {}}

static func frame_end(e) -> void:
	e._frame_depth = maxi(0, e._frame_depth - 1)
	if e._frame_depth == 0:
		e._frame = {}

## Derived {attack, armor, max_health, kw} of a unit. `fields` limits which
## board auras are scanned: a caller reads only the fields it asked for (the
## others then lack board auras). Snapshots return their recorded values.
static func derive(e, unit: Dictionary, fields: Array = ALL_FIELDS) -> Dictionary:
	if unit.has("snap"):
		return {"attack": int(unit.get("attack", 0)), "armor": int(unit.get("armor", 0)),
			"max_health": int(unit.get("max_health", 0)), "kw": unit.get("kw", {}).duplicate()}
	var uid = int(unit.get("uid", 0))
	if e._deriving.has(uid):
		# A keyword aura of this unit reads its own stats: layer A only.
		return e._deriving[uid]
	if not e._frame.is_empty():
		# In a read frame every field is derived once per unit and serves
		# every later request.
		if not e._frame.derived.has(uid):
			e._frame.derived[uid] = _derive(e, unit, ALL_FIELDS)
		return e._frame.derived[uid]
	return _derive(e, unit, fields)

static func _derive(e, unit: Dictionary, fields: Array) -> Dictionary:
	var uid = int(unit.get("uid", 0))
	var attack = int(unit.get("attack", 0))
	var armor = int(unit.get("armor", 0))
	var max_health = int(unit.get("max_health", unit.get("health", 0)))
	# Keywords are only assembled when asked for (settle reads max health only).
	var want_kw = "units:kw" in fields
	var kw: Dictionary = {}
	if want_kw:
		for keyword in unit.get("kw", {}):
			kw[keyword] = int(unit.kw[keyword])
		if not kw.has("bounty"):
			kw["bounty"] = 5 if unit.get("hero", false) else 1
	for entry in unit.get("mods", []):
		if str(entry.get("k", "")) != "give":
			continue
		var stats: Dictionary = entry.get("st", {})
		attack += int(stats.get("attack", 0))
		armor += int(stats.get("armor", 0))
		max_health += int(stats.get("max_health", 0))
		if want_kw:
			for keyword in entry.get("kw", {}):
				kw[keyword] = int(kw.get(keyword, 0)) + int(entry.kw[keyword])
	# Host auras of the unit's items apply wherever the hero is.
	var keyword_auras: Array = []
	for slot in unit.get("items", {}):
		var card_id = str(unit.items[slot])
		var rules: Dictionary = e.library.rules(card_id)
		var host: Dictionary = rules.get("host", {})
		attack += int(host.get("attack", 0))
		armor += int(host.get("armor", 0))
		max_health += int(host.get("max_health", 0))
		for index in rules.get("auras", []):
			var aura: Dictionary = rules.abilities[index]
			if not _is_host_aura(aura) or not _wants(aura, fields):
				continue
			var ctx = item_ctx(e, unit, str(slot))
			if aura.get("if") != null and not VM.cond(e, aura["if"], ctx):
				continue
			attack += _grant(e, aura.stats, "attack", ctx)
			armor += _grant(e, aura.stats, "armor", ctx)
			max_health += _grant(e, aura.stats, "max_health", ctx)
			if not aura.keywords.is_empty():
				keyword_auras.append([aura, ctx])
	# Board auras: only units in a lane receive them.
	if int(unit.get("lane", -1)) >= 0:
		for source in aura_sources(e, fields):
			var aura: Dictionary = source[0]
			var ctx: Dictionary = source[1]
			if aura.get("if") != null and not VM.cond(e, aura["if"], ctx):
				continue
			if not Select.includes(e, aura.affects, ctx, unit):
				continue
			attack += _grant(e, aura.stats, "attack", ctx)
			armor += _grant(e, aura.stats, "armor", ctx)
			max_health += _grant(e, aura.stats, "max_health", ctx)
			if not aura.keywords.is_empty():
				keyword_auras.append([aura, ctx])
	var result = {"attack": maxi(0, attack), "armor": armor, "max_health": max_health, "kw": kw}
	if not keyword_auras.is_empty() and "units:kw" in fields:
		# Layer B may read this unit's derived attack, armor and max_health
		# (layer A), never its keywords: no cycles.
		var layer_a = result if fields.size() == ALL_FIELDS.size() else derive(e, unit, STAT_FIELDS)
		e._deriving[uid] = layer_a
		for entry in keyword_auras:
			var aura: Dictionary = entry[0]
			for keyword in aura.keywords:
				kw[keyword] = int(kw.get(keyword, 0)) + int(VM.expr(e, aura.keywords[keyword], entry[1]))
		e._deriving.erase(uid)
	return result

static func _grant(e, grants: Dictionary, stat: String, ctx: Dictionary) -> int:
	if not grants.has(stat):
		return 0
	return int(VM.expr(e, grants[stat], ctx))

static func _is_host_aura(aura: Dictionary) -> bool:
	return aura.get("affects") is String and str(aura.affects) == "$host"

## True when the aura changes one of `fields` (all of them when empty).
static func _wants(aura: Dictionary, fields: Array) -> bool:
	if fields.is_empty():
		return true
	for field in aura.get("fields", []):
		if field in fields:
			return true
	return false

static func attack_of(e, unit: Dictionary) -> int:
	return int(derive(e, unit, ["units:attack"]).attack)

static func armor_of(e, unit: Dictionary) -> int:
	return int(derive(e, unit, ["units:armor"]).armor)

static func max_health(e, unit: Dictionary) -> int:
	return int(derive(e, unit, ["units:max_health"]).max_health)

static func keyword(e, unit: Dictionary, name: String) -> int:
	if name in Vocab.STATUS_KEYWORDS:
		return 1 if status(e, unit, name) else 0
	return int(derive(e, unit, ["units:kw"]).kw.get(name, 0))

## Flags and statuses are on when their sum is above 0. Stun counts as both
## silence and disarm.
static func flag(e, unit: Dictionary, name: String) -> bool:
	match name:
		"silence", "disarm":
			return status(e, unit, name) or status(e, unit, "stun")
		"stun", "death_shield":
			return status(e, unit, name)
	return int(derive(e, unit, ["units:kw"]).kw.get(name, 0)) > 0

## Statuses come only from the unit's own entries (auras may not grant them),
## so reading one never derives auras: no cycles (spec §3.14 rule 6).
static func status(e, unit: Dictionary, name: String) -> bool:
	var total = int(unit.get("kw", {}).get(name, 0))
	for entry in unit.get("mods", []):
		total += int(entry.get("kw", {}).get(name, 0)) if str(entry.get("k", "")) == "give" else 0
	return total > 0

## Writes the stunned/silenced/disarmed mirrors (UI and tests read them;
## rules never do) from the unit's own entries in one pass.
static func mirror_statuses(unit: Dictionary) -> void:
	var base: Dictionary = unit.get("kw", {})
	var stun = int(base.get("stun", 0))
	var silence = int(base.get("silence", 0))
	var disarm = int(base.get("disarm", 0))
	for entry in unit.get("mods", []):
		if str(entry.get("k", "")) != "give":
			continue
		var granted: Dictionary = entry.get("kw", {})
		if granted.is_empty():
			continue
		stun += int(granted.get("stun", 0))
		silence += int(granted.get("silence", 0))
		disarm += int(granted.get("disarm", 0))
	unit["stunned"] = stun > 0
	unit["silenced"] = stun > 0 or silence > 0
	unit["disarmed"] = stun > 0 or disarm > 0

## Hero, not silenced and not stunned: its colour counts for casting.
static func can_cast_colour(e, unit: Dictionary) -> bool:
	return bool(unit.get("hero", false)) and not flag(e, unit, "silence")

static func damaged(e, unit: Dictionary) -> bool:
	return int(unit.get("health", 0)) < max_health(e, unit)

# --- Aura sources ---------------------------------------------------------------

## [aura, ctx] for every live board aura source in canonical source order:
## units in lanes (printed, then granted), items on heroes in lanes (their
## non-host auras), improvements, deeds. With `fields`, only auras changing
## one of them (the library indexes which cards have such auras).
static func aura_sources(e, fields: Array = []) -> Array:
	if not e._frame.is_empty():
		var fields_key = "any" if fields.is_empty() else ",".join(fields)
		if not e._frame.sources.has(fields_key):
			e._frame.sources[fields_key] = _aura_sources(e, fields)
		return e._frame.sources[fields_key]
	return _aura_sources(e, fields)

static func _aura_sources(e, fields: Array) -> Array:
	var library = e.library
	var wanted: Array = []
	var granted = false
	if fields.is_empty():
		wanted.append(library.aura_cards)
		granted = not library.granted_aura_fields.is_empty()
	else:
		for field in fields:
			if library.aura_fields.has(field):
				wanted.append(library.aura_fields[field])
			if library.granted_aura_fields.has(field):
				granted = true
	if wanted.is_empty() and not granted:
		return []
	var out: Array = []
	for player in range(2):
		for lane_index in range(3):
			for unit in e.state.lanes[lane_index].units[player]:
				if unit == null or not _source_live(unit):
					continue
				var card_id = str(unit.get("card", ""))
				if _listed(wanted, card_id):
					var rules: Dictionary = library.rules(card_id)
					var ctx = unit_ctx(e, unit)
					for index in rules.auras:
						if _wants(rules.abilities[index], fields):
							out.append([rules.abilities[index], ctx])
				if granted:
					for entry in unit.get("mods", []):
						var ability = granted_ability(e, entry)
						if not ability.is_empty() and str(ability.kind) == "aura" and _wants(ability, fields):
							out.append([ability, unit_ctx(e, unit)])
				for slot in unit.get("items", {}):
					var item_card = str(unit.items[slot])
					if not _listed(wanted, item_card):
						continue
					var item_rules: Dictionary = library.rules(item_card)
					for index in item_rules.auras:
						var aura: Dictionary = item_rules.abilities[index]
						if not _is_host_aura(aura) and _wants(aura, fields):
							out.append([aura, item_ctx(e, unit, str(slot))])
	for player in range(2):
		for lane_index in range(3):
			for improvement in e.state.lanes[lane_index].get("improvements", [[], []])[player]:
				if bool(improvement.get("condemned", false)) and AURAS_NEED_HEALTH:
					continue
				if not _listed(wanted, str(improvement.card)):
					continue
				var rules: Dictionary = library.rules(str(improvement.card))
				for index in rules.auras:
					if _wants(rules.abilities[index], fields):
						out.append([rules.abilities[index], object_ctx(e, improvement)])
	for player in range(2):
		for deed in e.state.players[player].get("deeds", []):
			if not _listed(wanted, str(deed.card)):
				continue
			var rules: Dictionary = library.rules(str(deed.card))
			for index in rules.auras:
				if _wants(rules.abilities[index], fields):
					out.append([rules.abilities[index], object_ctx(e, deed)])
	return out

static func _listed(wanted: Array, card_id: String) -> bool:
	for cards in wanted:
		if cards.has(card_id):
			return true
	return false

static func _source_live(unit: Dictionary) -> bool:
	if AURAS_NEED_HEALTH:
		return int(unit.get("health", 0)) > 0 and not bool(unit.get("condemned", false))
	return true

## The compiled ability a modifier entry grants ({} when it grants none).
static func granted_ability(e, entry: Dictionary) -> Dictionary:
	var ability = str(entry.get("ab", ""))
	if ability.is_empty():
		return {}
	var parts = ability.split("#")
	if parts.size() != 2:
		return {}
	var grants: Array = e.library.rules(parts[0]).get("grants", [])
	var index = int(parts[1])
	return grants[index] if index >= 0 and index < grants.size() else {}

static func unit_ctx(e, unit: Dictionary) -> Dictionary:
	return {"src": unit, "host": unit, "controller": int(unit.get("owner", 0)),
		"lane": int(unit.get("lane", -1)), "card": str(unit.get("card", "")), "choices": {}, "vars": {}}

static func item_ctx(e, host: Dictionary, slot: String) -> Dictionary:
	return {"src": Select.item_handle(host, slot), "host": host, "controller": int(host.get("owner", 0)),
		"lane": int(host.get("lane", -1)), "card": str(host.get("items", {}).get(slot, "")), "choices": {}, "vars": {}}

static func object_ctx(e, object: Dictionary) -> Dictionary:
	return {"src": object, "host": null, "controller": int(object.get("owner", 0)),
		"lane": int(object.get("lane", -1)), "card": str(object.get("card", "")), "choices": {}, "vars": {}}

# --- Towers and the rules layer ------------------------------------------------------

## Derived tower values: armor, retaliate, regeneration and the mana modifier
## (give entries and auras; permanent Modify is already in the base fields).
static func tower(e, lane_index: int, player: int) -> Dictionary:
	var structure: Dictionary = e.state.lanes[lane_index].structures[player]
	var out = {"armor": int(structure.get("armor", 0)), "retaliate": int(structure.get("kw", {}).get("retaliate", 0)),
		"regeneration": int(structure.get("kw", {}).get("regeneration", 0)), "mana": 0}
	for entry in structure.get("mods", []):
		if str(entry.get("k", "")) != "give":
			continue
		out.armor += int(entry.get("st", {}).get("armor", 0))
		out.mana += int(entry.get("st", {}).get("mana", 0))
		for keyword in ["retaliate", "regeneration"]:
			out[keyword] += int(entry.get("kw", {}).get(keyword, 0))
	var handle = {"tower": true, "lane": lane_index, "p": player}
	for source in aura_sources(e, TOWER_FIELDS):
		var aura: Dictionary = source[0]
		var ctx: Dictionary = source[1]
		if aura.get("if") != null and not VM.cond(e, aura["if"], ctx):
			continue
		if not Select.includes(e, aura.affects, ctx, handle):
			continue
		out.armor += _grant(e, aura.stats, "armor", ctx)
		out.mana += _grant(e, aura.stats, "mana", ctx)
		for keyword in ["retaliate", "regeneration"]:
			out[keyword] += _grant(e, aura.keywords, keyword, ctx)
	return out

## The folded rules layer of player `player` (spec §3.11).
static func rules_of(e, player: int) -> Dictionary:
	var out = {"round_draw": 0, "forbid_play": [], "secret_shop_discount": 0, "creep_lane": []}
	var handle = {"player": player}
	for source in aura_sources(e, RULES_FIELDS):
		var aura: Dictionary = source[0]
		var ctx: Dictionary = source[1]
		if aura.get("rules", {}).is_empty():
			continue
		if aura.get("if") != null and not VM.cond(e, aura["if"], ctx):
			continue
		if not Select.includes(e, aura.affects, ctx, handle):
			continue
		var rules: Dictionary = aura.rules
		if rules.has("round_draw"):
			out.round_draw += int(VM.expr(e, rules.round_draw, ctx))
		if rules.has("secret_shop_discount"):
			out.secret_shop_discount += int(VM.expr(e, rules.secret_shop_discount, ctx))
		if rules.has("forbid_play"):
			out.forbid_play.append({"kinds": rules.forbid_play.kinds, "lane": Select.source_lane(e, ctx)})
		if rules.has("creep_lane"):
			out.creep_lane.append(ctx.src)
	return out

# --- Settle ------------------------------------------------------------------------

## Every unit in a lane plus every roster hero (Fountain included).
static func all_units(e) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for lane in e.state.lanes:
		for row in lane.units:
			for unit in row:
				if unit != null:
					out.append(unit)
					seen[int(unit.uid)] = true
	for owner in e.state.players:
		for hero in owner.roster:
			if not seen.has(int(hero.uid)):
				out.append(hero)
	return out

## Changes a tower's mana base by `delta` (permanent Modify, Purge, the
## round's growth) and re-derives max_mana at once, moving current mana by
## the change actually made (CF-5). Keeping max_mana == max(0, base + bonus)
## after every engine write lets settle adopt only external (fixture) writes.
static func add_mana_base(e, lane_index: int, player: int, delta: int) -> void:
	var lane: Dictionary = e.state.lanes[lane_index]
	lane.max_mana_base[player] = int(lane.max_mana_base[player]) + delta
	var new_max = maxi(0, int(lane.max_mana_base[player]) + int(lane.mana_bonus[player]))
	var change = new_max - int(lane.max_mana[player])
	if change != 0:
		lane.max_mana[player] = new_max
		lane.mana[player] = maxi(0, int(lane.mana[player]) + change)

## Applies max-health and mana deltas and refreshes the status mirrors
## (spec §4.4, CF-5). Runs in every Pulse loop and after deaths.
static func settle(e) -> void:
	for unit in all_units(e):
		var cap = max_health(e, unit)
		var seen = int(unit.get("hp_seen", cap))
		if cap != seen:
			# Gaining or losing maximum health moves current health (RQ-40).
			unit.health = int(unit.health) + cap - seen
		unit["hp_seen"] = cap
		mirror_statuses(unit)
	for lane_index in range(3):
		var lane: Dictionary = e.state.lanes[lane_index]
		if not lane.has("max_mana_base"):
			lane["max_mana_base"] = [int(lane.max_mana[0]) - int(lane.get("mana_bonus", [0, 0])[0]),
				int(lane.max_mana[1]) - int(lane.get("mana_bonus", [0, 0])[1])]
		for player in range(2):
			# A fixture that wrote max_mana directly sets a new base.
			if int(lane.max_mana[player]) != maxi(0, int(lane.max_mana_base[player]) + int(lane.mana_bonus[player])):
				lane.max_mana_base[player] = int(lane.max_mana[player]) - int(lane.mana_bonus[player])
			var total = int(tower(e, lane_index, player).mana)
			var new_max = maxi(0, int(lane.max_mana_base[player]) + total)
			var delta = new_max - int(lane.max_mana[player])
			if delta != 0:
				lane.max_mana[player] = new_max
				lane.mana[player] = maxi(0, int(lane.mana[player]) + delta)
			lane.mana_bonus[player] = total
