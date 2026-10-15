extends RefCounted
## Selectors, relations, canonical order, random picks and look-back
## (EFFECT_SYSTEM_SPEC.md §3.4, D2, D6). Static functions over the engine `e`;
## no instance members.
##
## Runtime objects:
##   unit         the live unit dictionary (in a lane, or a roster hero in the Fountain)
##   snapshot     {"snap": true, "uid", ...} of a unit that died this command (read-only)
##   tower        {"tower": true, "lane": l, "p": p}
##   item         {"item": true, "uid": host uid, "slot": s, "oid": n, "card": id}
##   improvement  the live dictionary in lanes[l].improvements[p] (has oid and lane)
##   deed         the live dictionary in players[p].deeds (has oid, no lane)
##   card         {"cardref": true, "p": p, "zone": "hand"|"deck", "index": i, "card": id, "iid": n}
##   player       {"player": p}
##   lane, position, number: int

const VM = preload("res://scripts/core/rules/vm.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Combat = preload("res://scripts/core/rules/combat.gd")
const SLOT_RANK = {"weapon": 0, "armor": 1, "accessory": 2}

# --- Object identity and order ---------------------------------------------------

static func kind_of(value) -> String:
	if value is int:
		return "int"
	if value is Dictionary:
		if value.has("snap"):
			return "snapshot"
		if value.has("uid") and not value.has("item"):
			return "unit"
		if value.has("tower"):
			return "tower"
		if value.has("item"):
			return "item"
		if value.has("cardref"):
			return "card"
		if value.has("player"):
			return "player"
		if value.has("oid"):
			return "improvement" if value.has("lane") else "deed"
	return ""

## Stable identity key: a unit and its look-back snapshot share one.
static func key(value) -> String:
	match kind_of(value):
		"unit", "snapshot":
			return "u%d" % int(value.uid)
		"tower":
			return "t%d_%d" % [int(value.lane), int(value.p)]
		"item":
			return "o%d" % int(value.oid)
		"improvement", "deed":
			return "o%d" % int(value.oid)
		"card":
			return "c%d_%s_%d" % [int(value.p), str(value.zone), int(value.index)]
		"player":
			return "p%d" % int(value.player)
		"int":
			return "n%d" % int(value)
	return "?"

static func same(a, b) -> bool:
	# Fast path: two units (or a unit and its snapshot) compare by uid.
	if a is Dictionary and b is Dictionary and a.has("uid") and b.has("uid") and not a.has("item") and not b.has("item"):
		return int(a.uid) == int(b.uid)
	var id = key(a)
	return id == key(b) and id != "?"

## Canonical order (D2): player 0 then 1, lane ascending, slot ascending; the
## last element is always a unique id, so sorting is total.
static func order(e, value) -> Array:
	match kind_of(value):
		"unit":
			var lane = int(value.get("lane", -1))
			var slot = Zones.slot_of(e, value) if lane >= 0 else -1
			if slot == -1:
				return [0, int(value.owner), 9, 0, int(value.uid)]
			return [0, int(value.owner), lane, slot, int(value.uid)]
		"snapshot":
			return [0, int(value.owner), int(value.lane), int(value.slot), int(value.uid)]
		"tower":
			return [1, int(value.p), int(value.lane), 0, 0]
		"item":
			var host = resolve_unit(e, int(value.uid))
			var host_order = order(e, host) if not host.is_empty() else [0, 0, 9, 0, 0]
			return [2, host_order[1], host_order[2], host_order[3] * 3 + int(SLOT_RANK.get(str(value.slot), 0)), int(value.oid)]
		"improvement":
			return [3, int(value.owner), int(value.lane), int(value.get("order", 0)), int(value.oid)]
		"deed":
			return [4, int(value.get("owner", 0)), 0, 0, int(value.oid)]
		"card":
			return [5, int(value.p), 0 if str(value.zone) == "hand" else 1, int(value.index), 0]
		"player":
			return [6, int(value.player), 0, 0, 0]
		"int":
			return [7, int(value), 0, 0, 0]
	return [8, 0, 0, 0, 0]

static func before(a: Array, b: Array) -> bool:
	for index in range(mini(a.size(), b.size())):
		if a[index] != b[index]:
			return a[index] < b[index]
	return a.size() < b.size()

## Sorts objects into canonical order and drops duplicates.
static func canonical(e, values: Array) -> Array:
	var keyed: Array = []
	var seen: Dictionary = {}
	for value in values:
		var id = key(value)
		if seen.has(id):
			continue
		seen[id] = true
		keyed.append([order(e, value), value])
	keyed.sort_custom(func(a, b): return before(a[0], b[0]))
	var out: Array = []
	for entry in keyed:
		out.append(entry[1])
	return out

# --- Resolution ---------------------------------------------------------------

## A unit by uid: in a lane, else its look-back snapshot (it left play during
## this command), else a roster hero in the Fountain, else {}.
static func resolve_unit(e, uid: int) -> Dictionary:
	if uid <= 0:
		return {}
	var live = e.find_unit(uid)
	if not live.is_empty():
		return live
	if e._lookback.has(uid):
		return e._lookback[uid]
	for owner in e.state.players:
		for hero in owner.roster:
			if int(hero.uid) == uid:
				return hero
	return {}

## True while the object is in its live zone (ops on anything else fizzle).
static func in_play(e, value) -> bool:
	match kind_of(value):
		"unit":
			return int(value.get("lane", -1)) >= 0 and Zones.slot_of(e, value) != -1
		"tower":
			return not bool(e.state.lanes[int(value.lane)].structures[int(value.p)].get("destroyed", false))
		"item":
			var host = e.find_unit(int(value.uid))
			if host.is_empty():
				host = resolve_unit(e, int(value.uid))
			return not host.is_empty() and not host.has("snap") and int(host.get("item_state", {}).get(str(value.slot), {}).get("oid", -1)) == int(value.oid)
		"improvement":
			for entry in e.state.lanes[int(value.lane)].get("improvements", [[], []])[int(value.owner)]:
				if int(entry.oid) == int(value.oid):
					return true
			return false
		"deed":
			return true
		"card":
			return true
	return false

## The lane an object stands in (-1 when it has none).
static func lane_of(e, value) -> int:
	match kind_of(value):
		"unit", "snapshot", "tower", "improvement":
			return int(value.get("lane", -1))
		"item":
			var host = resolve_unit(e, int(value.uid))
			return int(host.get("lane", -1)) if not host.is_empty() else -1
		"int":
			return int(value)
	return -1

static func owner_of(e, value) -> int:
	match kind_of(value):
		"unit", "snapshot", "improvement", "deed":
			return int(value.get("owner", -1))
		"tower", "card":
			return int(value.p)
		"item":
			var host = resolve_unit(e, int(value.uid))
			return int(host.get("owner", -1)) if not host.is_empty() else -1
		"player":
			return int(value.player)
	return -1

## Any set (ref, selector, list) as an array of objects in canonical order.
static func resolve_set(e, value, ctx: Dictionary) -> Array:
	if value == null:
		return []
	if value is String:
		return as_list(VM.ref(e, value, ctx))
	if value is Array:
		var items: Array = []
		for entry in value:
			items.append_array(resolve_set(e, entry, ctx))
		return canonical(e, items)
	if value is Dictionary:
		return enumerate(e, value, ctx)
	if value is int:
		return [value]
	return []

static func as_list(value) -> Array:
	if value == null:
		return []
	if value is Array:
		return value
	if value is Dictionary and value.is_empty():
		return []
	return [value]

## Exactly one object from a set (CF-3): the only element, or null.
static func one(e, value, ctx: Dictionary):
	var items = resolve_set(e, value, ctx)
	return items[0] if items.size() == 1 else null

# --- Enumeration ----------------------------------------------------------------

static func enumerate(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var found: Array = []
	match str(sel.get("s", "")):
		"units":
			found = _units(e, sel, ctx)
		"towers":
			found = _towers(e, sel, ctx)
		"lanes":
			found = _lane_values(e, sel, ctx)
		"positions":
			found = _positions(e, sel, ctx)
		"players":
			found = _players(e, sel, ctx)
		"cards":
			found = _cards(e, sel, ctx)
		"items":
			found = _items(e, sel, ctx)
		"improvements":
			found = _improvements(e, sel, ctx)
	return _finish(e, sel, ctx, found)

static func _finish(e, sel: Dictionary, ctx: Dictionary, found: Array) -> Array:
	var out = found
	if sel.get("not") != null:
		var excluded: Dictionary = {}
		for value in resolve_set(e, sel["not"], ctx):
			excluded[key(value)] = true
		out = out.filter(func(value): return not excluded.has(key(value)))
	if sel.get("where") != null:
		var kept: Array = []
		for value in out:
			var inner = ctx.duplicate()
			inner["it"] = value
			if VM.cond(e, sel.where, inner):
				kept.append(value)
		out = kept
	if sel.get("after") != null:
		var pivot = VM.ref(e, sel.after, ctx)
		if pivot is Array:
			pivot = pivot[0] if pivot.size() == 1 else null
		if pivot != null:
			var pivot_order = order(e, pivot)
			out = out.filter(func(value): return before(pivot_order, order(e, value)))
	if sel.get("pick") != null:
		out = pick(e, out, VM.expr(e, sel.pick, ctx))
	return out

## A random distinct subset of `count` candidates (fewer if there are not
## enough), one rand_index per pick in candidate order (partial Fisher-Yates),
## returned in canonical order. An empty pool consumes no randomness.
static func pick(e, candidates: Array, count: int) -> Array:
	if count <= 0 or candidates.is_empty():
		return []
	var pool = candidates.duplicate()
	var taken = mini(count, pool.size())
	for index in range(taken):
		var other = index + Kernel.rand_index(e, pool.size() - index)
		var held = pool[index]
		pool[index] = pool[other]
		pool[other] = held
	return canonical(e, pool.slice(0, taken))

static func _players_of(side: String, controller: int) -> Array:
	match side:
		"ally":
			return [controller]
		"enemy":
			return [1 - controller]
	return [0, 1]

## The lanes a selector's `lane` value names, ascending.
static func lanes_for(e, lane, ctx: Dictionary, default_all: bool = false) -> Array:
	if lane == null:
		if default_all:
			return [0, 1, 2]
		var current = int(ctx.get("lane", -1))
		return [current] if current >= 0 else []
	if lane is int:
		return [int(lane)] if int(lane) >= 0 and int(lane) <= 2 else []
	match str(lane):
		"active":
			return [int(e.state.lane)]
		"self":
			var own = source_lane(e, ctx)
			return [own] if own >= 0 else []
		"all":
			return [0, 1, 2]
		"other":
			var current = int(ctx.get("lane", -1))
			return [0, 1, 2].filter(func(index): return index != current)
		"fountain":
			return []
	# A ref: a lane number, or an object standing in a lane.
	var lanes: Array = []
	for value in as_list(VM.ref(e, str(lane), ctx)):
		var index = int(value) if value is int else lane_of(e, value)
		if index >= 0 and index <= 2 and index not in lanes:
			lanes.append(index)
	lanes.sort()
	return lanes

static func source_lane(e, ctx: Dictionary) -> int:
	var source = ctx.get("src")
	if source != null and not (source is Dictionary and source.is_empty()):
		var lane = lane_of(e, source)
		if lane >= 0:
			return lane
	return int(ctx.get("lane", -1))

static func _unit_matches(e, unit: Dictionary, sel: Dictionary, ctx: Dictionary) -> bool:
	if sel.get("kind") != null and (str(sel.kind) == "hero") != bool(unit.get("hero", false)):
		return false
	if sel.get("card") != null and str(unit.get("card", "")) not in sel.card:
		return false
	if sel.get("color") != null and str(unit.get("color", "")) != str(sel.color):
		return false
	var side = str(sel.get("side", "any"))
	if side != "any" and int(unit.owner) not in _players_of(side, int(ctx.get("controller", 0))):
		return false
	return true

static func _units(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var found: Array = []
	if sel.get("rel") != null:
		for relation in sel.rel:
			for unit in relation_units(e, relation, sel.rel[relation], ctx):
				if not _unit_matches(e, unit, sel, ctx):
					continue
				if sel.get("lane") != null and int(unit.lane) not in lanes_for(e, sel.lane, ctx):
					continue
				found.append(unit)
		return found
	var players = _players_of(str(sel.get("side", "any")), int(ctx.get("controller", 0)))
	if str(sel.get("lane", "")) == "fountain":
		for player in players:
			for hero in e.state.players[player].roster:
				if int(hero.lane) == -1 and _unit_matches(e, hero, sel, ctx):
					found.append(hero)
		return found
	var lanes = lanes_for(e, sel.get("lane"), ctx)
	for player in players:
		for lane in lanes:
			for unit in e.state.lanes[lane].units[player]:
				if unit != null and _unit_matches(e, unit, sel, ctx):
					found.append(unit)
	return found

## Units related to every object of `argument` (a ref or a selector), united
## in canonical order. A look-back snapshot reads its recorded lists and keeps
## only units still in play (RQ-16).
static func relation_units(e, relation: String, argument, ctx: Dictionary) -> Array:
	var found: Array = []
	for subject in resolve_set(e, argument, ctx):
		found.append_array(related(e, relation, subject))
	return canonical(e, found) if found.size() > 1 else found

static func related(e, relation: String, subject) -> Array:
	var kind = kind_of(subject)
	if kind == "snapshot":
		var uids: Array = []
		match relation:
			"allied_neighbors":
				uids = subject.get("neighbors", [])
			"enemy_neighbors":
				uids = subject.get("enemy_neighbors", [])
			"across":
				uids = [subject.get("across", 0)]
			"blocker":
				uids = [subject.get("target", 0)]
			"attackers":
				uids = subject.get("attackers", [])
		var live: Array = []
		for uid in uids:
			var unit = e.find_unit(int(uid))
			if not unit.is_empty():
				live.append(unit)
		return live
	if kind != "unit" or int(subject.get("lane", -1)) < 0:
		return []
	var lane = int(subject.lane)
	var slot = Zones.slot_of(e, subject)
	if slot == -1:
		return []
	var rows = e.state.lanes[lane].units
	var own = rows[int(subject.owner)]
	var enemy = rows[1 - int(subject.owner)]
	var out: Array = []
	match relation:
		"allied_neighbors":
			for index in [slot - 1, slot + 1]:
				if index >= 0 and index < own.size() and own[index] != null:
					out.append(own[index])
		"enemy_neighbors":
			for index in [slot - 1, slot, slot + 1]:
				if index >= 0 and index < enemy.size() and enemy[index] != null:
					out.append(enemy[index])
		"across":
			if slot < enemy.size() and enemy[slot] != null:
				out.append(enemy[slot])
		"blocker":
			var target = Combat.combat_target(e, subject, lane, slot)
			if not target.is_empty():
				out.append(target)
		"attackers":
			for index in range(enemy.size()):
				var attacker = enemy[index]
				if attacker == null or Stats.status(e, attacker, "disarm"):
					continue
				var target = Combat.combat_target(e, attacker, lane, index)
				if not target.is_empty() and int(target.uid) == int(subject.uid):
					out.append(attacker)
	return out

static func _towers(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var found: Array = []
	for player in _players_of(str(sel.get("side", "any")), int(ctx.get("controller", 0))):
		for lane in lanes_for(e, sel.get("lane"), ctx):
			if not bool(e.state.lanes[lane].structures[player].get("destroyed", false)):
				found.append({"tower": true, "lane": lane, "p": player})
	return found

static func _lane_values(e, sel: Dictionary, ctx: Dictionary) -> Array:
	return lanes_for(e, sel.get("lane"), ctx, true)

static func _positions(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var side = str(sel.get("side", "ally"))
	var player = int(ctx.get("controller", 0)) if side != "enemy" else 1 - int(ctx.get("controller", 0))
	var lanes = lanes_for(e, sel.get("lane"), ctx)
	if lanes.size() != 1:
		return []
	return e.creep_positions(lanes[0], player)

static func _players(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var controller = int(ctx.get("controller", 0))
	match str(sel.get("player", "")):
		"you":
			return [{"player": controller}]
		"opponent":
			return [{"player": 1 - controller}]
	return [{"player": 0}, {"player": 1}]

static func _cards(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var controller = int(ctx.get("controller", 0))
	var players = [controller] if str(sel.get("player", "you")) != "opponent" else [1 - controller]
	var found: Array = []
	for player in players:
		var owner: Dictionary = e.state.players[player]
		for zone in sel.get("zone", ["hand"]):
			var ids: Array = owner.get(str(zone), [])
			var states: Array = owner.get("hand_state" if str(zone) == "hand" else "deck_state", [])
			for index in range(ids.size()):
				var card_id = str(ids[index])
				if sel.get("card") != null and card_id not in sel.card:
					continue
				var definition = e.library.get_card(card_id)
				if sel.get("kind") != null and str(definition.get("kind", "")) != str(sel.kind):
					continue
				if sel.get("color") != null and str(definition.get("color", "")) != str(sel.color):
					continue
				var entry = states[index] if index < states.size() and states[index] is Dictionary else {}
				found.append({"cardref": true, "p": player, "zone": str(zone), "index": index, "card": card_id,
					"iid": int(entry.get("iid", 0))})
	return found

static func _items(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var hosts: Array = []
	if sel.get("rel") != null and sel.rel.has("equipped_on"):
		hosts = resolve_set(e, sel.rel.equipped_on, ctx)
	else:
		var host_sel = {"s": "units", "side": sel.get("side", "any"), "lane": sel.get("lane")}
		hosts = _units(e, host_sel, ctx)
	var found: Array = []
	for host in hosts:
		if kind_of(host) != "unit":
			continue
		for slot in ["weapon", "armor", "accessory"]:
			if not host.get("items", {}).has(slot):
				continue
			if sel.get("slot") != null and str(sel.slot) != slot:
				continue
			var card_id = str(host.items[slot])
			if sel.get("card") != null and card_id not in sel.card:
				continue
			found.append(item_handle(host, slot))
	return found

static func item_handle(host: Dictionary, slot: String) -> Dictionary:
	var instance = host.get("item_state", {}).get(slot, {})
	return {"item": true, "uid": int(host.uid), "slot": slot, "oid": int(instance.get("oid", 0)),
		"card": str(host.get("items", {}).get(slot, ""))}

static func _improvements(e, sel: Dictionary, ctx: Dictionary) -> Array:
	var found: Array = []
	for player in _players_of(str(sel.get("side", "any")), int(ctx.get("controller", 0))):
		for lane in lanes_for(e, sel.get("lane"), ctx):
			for entry in e.state.lanes[lane].get("improvements", [[], []])[player]:
				if sel.get("card") != null and str(entry.card) not in sel.card:
					continue
				found.append(entry)
	return found

# --- Membership without enumeration (auras) -----------------------------------------

## True when `value` is in the set `sel` evaluated in `ctx`. Used for aura
## membership so a stat read costs one check per aura source.
static func includes(e, sel, ctx: Dictionary, value) -> bool:
	if sel is String:
		for item in as_list(VM.ref(e, sel, ctx)):
			if same(item, value):
				return true
		return false
	if sel is Array:
		for entry in sel:
			if includes(e, entry, ctx, value):
				return true
		return false
	if not sel is Dictionary:
		return false
	var kind = kind_of(value)
	match str(sel.get("s", "")):
		"units":
			if kind != "unit":
				return false
			if not _unit_matches(e, value, sel, ctx):
				return false
			var lane = int(value.get("lane", -1))
			if str(sel.get("lane", "")) == "fountain":
				if lane != -1:
					return false
			elif lane < 0:
				return false
			if sel.get("rel") != null:
				var related = false
				for relation in sel.rel:
					for subject in resolve_set(e, sel.rel[relation], ctx):
						if _is_related(e, relation, subject, value):
							related = true
							break
				if not related:
					return false
				if sel.get("lane") != null and lane not in lanes_for(e, sel.lane, ctx):
					return false
			elif str(sel.get("lane", "")) != "fountain" and lane not in lanes_for(e, sel.get("lane"), ctx):
				return false
		"towers":
			if kind != "tower":
				return false
			if int(value.p) not in _players_of(str(sel.get("side", "any")), int(ctx.get("controller", 0))):
				return false
			if int(value.lane) not in lanes_for(e, sel.get("lane"), ctx):
				return false
		"players":
			if kind != "player":
				return false
			var controller = int(ctx.get("controller", 0))
			match str(sel.get("player", "")):
				"you":
					if int(value.player) != controller:
						return false
				"opponent":
					if int(value.player) != 1 - controller:
						return false
		_:
			for item in enumerate(e, sel, ctx):
				if same(item, value):
					return true
			return false
	if sel.get("not") != null:
		for excluded in resolve_set(e, sel["not"], ctx):
			if same(excluded, value):
				return false
	if sel.get("where") != null:
		var inner = ctx.duplicate()
		inner["it"] = value
		if not VM.cond(e, sel.where, inner):
			return false
	return true

static func _is_related(e, relation: String, subject, value: Dictionary) -> bool:
	if kind_of(subject) == "unit" and relation in ["allied_neighbors", "enemy_neighbors", "across"]:
		if int(subject.get("lane", -1)) < 0 or int(subject.lane) != int(value.lane):
			return false
		var subject_slot = Zones.slot_of(e, subject)
		var value_slot = Zones.slot_of(e, value)
		if subject_slot == -1 or value_slot == -1:
			return false
		match relation:
			"allied_neighbors":
				return int(value.owner) == int(subject.owner) and absi(value_slot - subject_slot) == 1
			"enemy_neighbors":
				return int(value.owner) != int(subject.owner) and absi(value_slot - subject_slot) <= 1
			"across":
				return int(value.owner) != int(subject.owner) and value_slot == subject_slot
	for unit in related(e, relation, subject):
		if same(unit, value):
			return true
	return false
