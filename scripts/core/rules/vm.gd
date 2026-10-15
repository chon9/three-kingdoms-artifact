extends RefCounted
## Rules interpreter (EFFECT_SYSTEM_SPEC.md §3.3 to §3.7): runs compiled ops,
## evaluates expressions and conditions, resolves refs. Static functions over
## the engine `e`; no instance members.
##
## ctx = {src, host, controller, lane, card, choices, vars, event, played,
##        keep_initiative, end_phase, it, break}
## Ops never fail on objects that left play: they fizzle (D6). Every op
## execution spends one unit of the per-command budget (D7).

const Vocab = preload("res://scripts/core/rules/vocab.gd")
const Select = preload("res://scripts/core/rules/select.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Combat = preload("res://scripts/core/rules/combat.gd")
const Natives = preload("res://scripts/core/rules/natives.gd")
const OP_BUDGET = 2048
const MAX_LOOP = 64

static func run(e, ops: Array, ctx: Dictionary) -> void:
	for op in ops:
		if e._ops_left <= 0:
			return
		e._ops_left -= 1
		if e._ops_left <= 0:
			Kernel.overflow(e)
			return
		_op(e, op, ctx)
		if ctx.get("break", false):
			return

static func _op(e, op: Dictionary, ctx: Dictionary) -> void:
	match str(op.op):
		"damage":
			var units = _units_in_play(e, op.to, ctx)
			Kernel.damage_units(e, units, expr(e, op.amount, ctx), bool(op.get("piercing", false)), ctx)
		"damage_split":
			var units = _units_in_play(e, op.to, ctx)
			if not units.is_empty():
				# Each target takes floor(total / N); the remainder is lost (RQ-28).
				Kernel.damage_units(e, units, floor_div(expr(e, op.total, ctx), units.size()), false, ctx)
		"tower_damage":
			var amount = expr(e, op.amount, ctx)
			var hits: Array = []
			for tower in Select.resolve_set(e, op.to, ctx):
				if Select.kind_of(tower) != "tower" or not Select.in_play(e, tower):
					continue
				hits.append([int(tower.lane), int(tower.p), Kernel.tower_damage(e, int(tower.lane), int(tower.p), amount, bool(op.get("piercing", false)))])
			if not hits.is_empty():
				e._event("tower_damage", {"src": str(ctx.get("card", "")), "p": int(ctx.get("controller", 0)), "hits": hits})
		"heal":
			var units = _units_in_play(e, op.to, ctx)
			var full = str(op.amount) == "full"
			Kernel.heal_units(e, units, -1 if full else expr(e, op.amount, ctx), ctx)
		"tower_heal":
			var amount = expr(e, op.amount, ctx)
			var hits: Array = []
			for tower in Select.resolve_set(e, op.to, ctx):
				if Select.kind_of(tower) != "tower" or not Select.in_play(e, tower):
					continue
				var structure: Dictionary = e.state.lanes[int(tower.lane)].structures[int(tower.p)]
				var cap = 80 if bool(structure.ancient) else 40
				var healed = maxi(0, mini(cap, int(structure.health) + amount) - int(structure.health))
				structure.health = int(structure.health) + healed
				hits.append([int(tower.lane), int(tower.p), healed])
			if not hits.is_empty():
				e._event("heal", {"src": str(ctx.get("card", "")), "p": int(ctx.get("controller", 0)), "towers": hits, "hits": []})
		"modify", "give":
			var stats: Dictionary = {}
			for stat in op.stats:
				stats[stat] = expr(e, op.stats[stat], ctx)
			var keywords: Dictionary = {}
			for keyword in op.keywords:
				keywords[keyword] = expr(e, op.keywords[keyword], ctx)
			var grant = "" if int(op.get("grant", -1)) < 0 else "%s#%d" % [str(ctx.get("card", "")), int(op.grant)]
			for target in Select.resolve_set(e, op.to, ctx):
				if str(op.op) == "modify":
					Kernel.modify(e, target, stats, keywords, grant, ctx)
				else:
					Kernel.give(e, target, stats, keywords, grant, str(op.until), ctx)
		"purge":
			for target in Select.resolve_set(e, op.to, ctx):
				Kernel.purge(e, target, str(op.get("from", "opponent")), ctx)
		"condemn":
			for target in Select.resolve_set(e, op.to, ctx):
				Kernel.condemn(e, target, ctx)
		"summon":
			var owner = int(ctx.get("controller", 0)) if str(op.get("for", "you")) == "you" else 1 - int(ctx.get("controller", 0))
			var lane = int(ctx.get("lane", -1))
			if op.has("lane"):
				lane = _lane_value(e, op.lane, ctx)
			var summoned: Array = []
			if lane >= 0 and lane <= 2:
				for copy in range(maxi(0, expr(e, op.get("count", 1), ctx))):
					summoned.append(Zones.summon(e, str(op.card), owner, lane))
			if op.has("as"):
				ctx.vars[op["as"]] = _store(summoned)
		"retarget":
			for unit in _units_in_play(e, op.unit, ctx):
				Kernel.retarget(e, unit, _retarget_value(e, op.to, ctx))
		"taunt":
			var taunter = Select.one(e, op.unit, ctx)
			if taunter != null and Select.kind_of(taunter) == "unit" and Select.in_play(e, taunter):
				for enemy in Select.related(e, "enemy_neighbors", taunter):
					Kernel.retarget(e, enemy, taunter)
		"battle":
			var attacker = Select.one(e, op.a, ctx)
			if attacker == null or Select.kind_of(attacker) != "unit" or not Select.in_play(e, attacker):
				return
			var defenders: Array = []
			for unit in _units_in_play(e, op.b, ctx):
				if not Select.same(unit, attacker):
					defenders.append(unit)
			if not defenders.is_empty():
				Combat.battle(e, attacker, defenders, ctx)
		"to_fountain":
			for unit in _units_in_play(e, op.unit, ctx):
				if bool(unit.get("hero", false)):
					Zones.remove_from_lane(e, unit)
					Zones.enter_fountain(e, unit, int(e.state.round) + 1)
					e._event("fountain", {"uid": int(unit.uid), "card": str(unit.card), "p": int(unit.owner)})
		"draw":
			for player in _players(str(op.get("player", "you")), int(ctx.get("controller", 0))):
				var drawn = Zones.draw(e, player, expr(e, op.get("n", 1), ctx))
				if not drawn.is_empty():
					e._event("draw_cards", {"p": player, "n": drawn.size()}, {str(player): {"iids": drawn}})
		"discard":
			Zones.discard(e, Select.resolve_set(e, op.cards, ctx))
		"gold":
			var player = int(ctx.get("controller", 0)) if str(op.get("player", "you")) == "you" else 1 - int(ctx.get("controller", 0))
			var owner: Dictionary = e.state.players[player]
			var before = int(owner.gold)
			if op.has("set"):
				owner.gold = maxi(0, expr(e, op.set, ctx))
			else:
				owner.gold = maxi(0, before + expr(e, op.get("add", 0), ctx))
			if op.has("as"):
				ctx.vars[op["as"]] = maxi(0, before - int(owner.gold))
			if int(owner.gold) != before:
				e._event("gold", {"p": player, "n": int(owner.gold) - before})
		"mana":
			for tower in Select.resolve_set(e, op.to, ctx):
				if Select.kind_of(tower) != "tower":
					continue
				var lane: Dictionary = e.state.lanes[int(tower.lane)]
				var player = int(tower.p)
				var before = int(lane.mana[player])
				var restored = int(lane.max_mana[player]) if str(op.get("restore", "")) == "full" else before + expr(e, op.restore, ctx)
				lane.mana[player] = maxi(before, mini(int(lane.max_mana[player]), restored))
				if int(lane.mana[player]) != before:
					e._event("mana", {"lane": int(tower.lane), "p": player, "n": int(lane.mana[player]) - before})
		"charges":
			var target = Select.one(e, op.on, ctx)
			if target != null:
				Kernel.change_charges(e, target, op, ctx)
		"initiative":
			ctx["keep_initiative"] = true
		"end_action_phase":
			ctx["end_phase"] = true
		"let":
			ctx.vars[str(op.name)] = _evaluate_value(e, op.value, ctx)
		"if":
			run(e, op.then if cond(e, op.cond, ctx) else op["else"], ctx)
		"repeat":
			var times = expr(e, op.times, ctx)
			for index in range(maxi(0, times)):
				run(e, op.ops, ctx)
				if ctx.get("break", false):
					ctx["break"] = false
					break
				if e._ops_left <= 0:
					break
		"for_each":
			var items = Select.resolve_set(e, op["in"], ctx)
			for item in items:
				ctx.vars[str(op["as"])] = _store(item)
				run(e, op.ops, ctx)
				if ctx.get("break", false):
					ctx["break"] = false
					break
				if e._ops_left <= 0:
					break
		"chance":
			run(e, op.then if Kernel.chance(e, expr(e, op.pct, ctx)) else op["else"], ctx)
		"pulse":
			Kernel.pulse(e)
			e._event("pulse")
		"break":
			ctx["break"] = true
		"native":
			Natives.run(e, str(op.fn), ctx, op.get("args", {}))
		_:
			# Vocabulary reserved for milestone M2 (move, swap, control, lock,
			# add_card, card_counter): the validator keeps it out of verified
			# cards, so only draft fixtures reach here; they do nothing.
			pass

static func _players(word: String, controller: int) -> Array:
	match word:
		"opponent":
			return [1 - controller]
		"both":
			return [0, 1]
	return [controller]

## Units of a set that are still in a lane, in canonical order.
static func _units_in_play(e, value, ctx: Dictionary) -> Array:
	var out: Array = []
	for item in Select.resolve_set(e, value, ctx):
		if Select.kind_of(item) == "unit" and Select.in_play(e, item):
			out.append(item)
	return out

static func _retarget_value(e, value, ctx: Dictionary):
	if value is int or str(value) == "across":
		return value
	var resolved = ref(e, str(value), ctx) if value is String else Select.one(e, value, ctx)
	if resolved is Array:
		resolved = resolved[0] if resolved.size() == 1 else null
	return resolved

static func _lane_value(e, value, ctx: Dictionary) -> int:
	if value is int:
		return int(value)
	var resolved = ref(e, str(value), ctx) if value is String else Select.one(e, value, ctx)
	if resolved is Array:
		resolved = resolved[0] if resolved.size() == 1 else null
	if resolved is int:
		return int(resolved)
	return Select.lane_of(e, resolved) if resolved != null else -1

# --- Values ----------------------------------------------------------------------

## Variables hold units as uids so that reading one after a Pulse finds the
## live unit or its look-back snapshot.
static func _store(value):
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_store(item))
		return items
	var kind = Select.kind_of(value)
	if kind == "unit" or kind == "snapshot":
		return {"vref": true, "uid": int(value.uid)}
	return value

static func _load(e, value):
	if value is Array:
		var items: Array = []
		for item in value:
			var loaded = _load(e, item)
			if not (loaded is Dictionary and loaded.is_empty()):
				items.append(loaded)
		return items
	if value is Dictionary and value.has("vref"):
		return Select.resolve_unit(e, int(value.uid))
	return value

static func _evaluate_value(e, value, ctx: Dictionary):
	if value is Dictionary and value.has("set"):
		return _store(Select.resolve_set(e, value.set, ctx))
	if value is String and str(value).begins_with("$"):
		return _store(ref(e, str(value), ctx))
	return expr(e, value, ctx)

static func ref(e, text: String, ctx: Dictionary):
	# Fast paths: the bare roots are by far the most common refs.
	match text:
		"$host":
			return ctx.get("host")
		"$self":
			return ctx.get("src")
		"$it":
			return ctx.get("it")
	var parts = text.split(".")
	var value = null
	var next = 1
	match parts[0]:
		"$self":
			value = ctx.get("src")
		"$host":
			value = ctx.get("host")
		"$it":
			value = ctx.get("it")
		"$played":
			var played: Dictionary = ctx.get("played", {}) if ctx.get("played") is Dictionary else {}
			if parts.size() > 1:
				return played.get(parts[1])
			return played
		"$c":
			next = 2
			value = _choice(e, ctx, parts[1] if parts.size() > 1 else "")
		"$e":
			next = 2
			value = _event_field(e, ctx, parts[1] if parts.size() > 1 else "")
		"$v":
			next = 2
			value = _load(e, ctx.get("vars", {}).get(parts[1] if parts.size() > 1 else "", null))
	for index in range(next, parts.size()):
		value = _field(e, value, parts[index])
	return value

static func _choice(e, ctx: Dictionary, key: String):
	var value = ctx.get("choices", {}).get(key)
	if value == null:
		return null
	if key in ["target", "destination"] and value is int:
		if int(value) == 0:
			return 0
		if int(value) >= 1000000:
			for lane in e.state.lanes:
				for row in lane.get("improvements", [[], []]):
					for entry in row:
						if int(entry.oid) == int(value):
							return entry
			return null
		var unit = Select.resolve_unit(e, int(value))
		return unit if not unit.is_empty() else null
	return value

static func _event_field(e, ctx: Dictionary, field: String):
	var payload = ctx.get("event")
	if not payload is Dictionary:
		return null
	var value = payload.get(field)
	match field:
		"unit", "uid":
			if value is int:
				var unit = Select.resolve_unit(e, int(value))
				return unit if not unit.is_empty() else null
		"target", "source":
			if value is int and int(value) > 0:
				var unit = Select.resolve_unit(e, int(value))
				return unit if not unit.is_empty() else null
			if value is String and str(value).begins_with("t"):
				var parts = str(value).substr(1).split("_")
				return {"tower": true, "lane": int(parts[0]), "p": int(parts[1])}
		"neighbors", "enemy_neighbors", "attackers":
			var units: Array = []
			for uid in (value if value is Array else []):
				var unit = Select.resolve_unit(e, int(uid))
				if not unit.is_empty():
					units.append(unit)
			return units
	return value

static func _field(e, value, field: String):
	if value is Array:
		value = value[0] if value.size() == 1 else null
	if value == null:
		return null
	match field:
		"lane":
			return Select.lane_of(e, value)
		"owner":
			return Select.owner_of(e, value)
		"slot":
			match Select.kind_of(value):
				"unit":
					return Zones.slot_of(e, value)
				"snapshot":
					return int(value.slot)
				"item":
					return str(value.slot)
			return -1
	if value is Dictionary:
		return value.get(field)
	return null

## Integer division rounding down (RQ-28: "half" rounds down).
static func floor_div(value: int, by: int) -> int:
	if by == 0:
		return 0
	@warning_ignore("integer_division")
	var quotient = value / by
	if (value % by != 0) and ((value < 0) != (by < 0)):
		quotient -= 1
	return quotient

static func expr(e, value, ctx: Dictionary) -> int:
	if value is int:
		return value
	if value is bool:
		return int(value)
	if value is String:
		match str(value):
			"you":
				return int(ctx.get("controller", 0))
			"opponent":
				return 1 - int(ctx.get("controller", 0))
		return _number(ref(e, str(value), ctx))
	if not value is Dictionary:
		return 0
	if value.has("count"):
		return Select.resolve_set(e, value.count, ctx).size()
	if value.has("sum"):
		var total = 0
		for item in Select.resolve_set(e, value.sum, ctx):
			total += stat_value(e, item, str(value.stat))
		return total
	if value.has("stat"):
		var item = Select.one(e, value.of, ctx)
		return stat_value(e, item, str(value.stat)) if item != null else 0
	if value.has("charges"):
		var item = Select.one(e, value.charges, ctx)
		return Kernel.charges_of(e, item) if item != null else 0
	if value.has("card_counter"):
		return Zones.card_counter(e, ref(e, str(value.card_counter), ctx))
	if value.has("gold"):
		var player = int(ctx.get("controller", 0)) if str(value.gold) == "you" else 1 - int(ctx.get("controller", 0))
		return int(e.state.players[player].gold)
	if value.has("price"):
		var item = Select.one(e, value.price, ctx)
		return Kernel.price_value(e, item)
	if value.has("half"):
		return floor_div(expr(e, value.half, ctx), 2)
	if value.has("neg"):
		return -expr(e, value.neg, ctx)
	if value.has("add"):
		var total = 0
		for entry in value.add:
			total += expr(e, entry, ctx)
		return total
	if value.has("sub"):
		return expr(e, value.sub[0], ctx) - expr(e, value.sub[1], ctx)
	if value.has("mul"):
		return expr(e, value.mul[0], ctx) * expr(e, value.mul[1], ctx)
	if value.has("min"):
		var low = expr(e, value["min"][0], ctx)
		for entry in value["min"]:
			low = mini(low, expr(e, entry, ctx))
		return low
	if value.has("max"):
		var high = expr(e, value["max"][0], ctx)
		for entry in value["max"]:
			high = maxi(high, expr(e, entry, ctx))
		return high
	return 0

static func _number(value) -> int:
	if value is int:
		return value
	if value is bool:
		return int(value)
	if value is Array and value.size() == 1 and value[0] is int:
		return value[0]
	return 0

## A derived stat of a unit, snapshot or tower (0 for anything else).
static func stat_value(e, item, stat: String) -> int:
	match Select.kind_of(item):
		"unit", "snapshot":
			match stat:
				"health":
					return int(item.get("health", 0))
				"attack", "armor", "max_health":
					return int(Stats.derive(e, item)[stat])
			return Stats.keyword(e, item, stat)
		"tower":
			var lane: Dictionary = e.state.lanes[int(item.lane)]
			match stat:
				"health":
					return int(lane.structures[int(item.p)].health)
				"mana":
					return int(lane.mana[int(item.p)])
				"max_mana":
					return int(lane.max_mana[int(item.p)])
			return int(Stats.tower(e, int(item.lane), int(item.p)).get(stat, 0))
	return 0

# --- Conditions -------------------------------------------------------------------

static func cond(e, condition, ctx: Dictionary) -> bool:
	if condition == null or not condition is Dictionary or condition.is_empty():
		return true
	if condition.has("all"):
		for entry in condition.all:
			if not cond(e, entry, ctx):
				return false
		return true
	if condition.has("any"):
		for entry in condition.any:
			if cond(e, entry, ctx):
				return true
		return false
	if condition.has("not"):
		return not cond(e, condition["not"], ctx)
	if condition.has("cmp"):
		return _compare(e, condition.cmp, ctx)
	if condition.has("is"):
		var item = Select.one(e, condition["is"], ctx)
		if item == null:
			return false
		var pool = condition["in"]
		var members = Select.as_list(ref(e, pool, ctx)) if pool is String else Select.resolve_set(e, pool, ctx)
		for member in members:
			if Select.same(member, item):
				return true
		return false
	if condition.has("has"):
		return not Select.resolve_set(e, condition.has, ctx).is_empty()
	if condition.has("empty"):
		return Select.resolve_set(e, condition.empty, ctx).is_empty()
	if condition.has("in_play"):
		var item = Select.one(e, condition.in_play, ctx)
		return item != null and Select.in_play(e, item)
	if condition.has("unblocked"):
		var unit = Select.one(e, condition.unblocked, ctx)
		return unit != null and Select.kind_of(unit) == "unit" and Select.in_play(e, unit) and e.combat_target_of(unit).is_empty()
	if condition.has("damaged"):
		var unit = Select.one(e, condition.damaged, ctx)
		return unit != null and Select.kind_of(unit) == "unit" and Stats.damaged(e, unit)
	if condition.has("flag"):
		var unit = Select.one(e, condition.flag[0], ctx)
		return unit != null and Select.kind_of(unit) == "unit" and Stats.flag(e, unit, str(condition.flag[1]))
	if condition.has("log"):
		var log: Dictionary = e.state.get("round_log", {})
		if str(condition.log) == "tower_hit":
			for tower in Select.resolve_set(e, condition.tower, ctx):
				if Select.kind_of(tower) == "tower" and bool(log.get("tower_hit", [[false, false, false], [false, false, false]])[int(tower.p)][int(tower.lane)]):
					return true
			return false
		var by = Select.one(e, condition.by, ctx)
		if by == null:
			return false
		for hit in log.get("hits", []):
			if int(hit[0]) == int(by.get("uid", -1)) and str(hit[1]) == str(condition.kind):
				return true
		return false
	if condition.has("active_lane"):
		return int(e.state.lane) == int(ctx.get("lane", -1))
	return true

static func _compare(e, parts: Array, ctx: Dictionary) -> bool:
	var a = _cmp_value(e, parts[0], ctx)
	var b = _cmp_value(e, parts[2], ctx)
	var op = str(parts[1])
	if a is int and b is int:
		match op:
			"==":
				return a == b
			"!=":
				return a != b
			"<":
				return a < b
			"<=":
				return a <= b
			">":
				return a > b
			">=":
				return a >= b
	var same = str(a) == str(b)
	return same if op == "==" else (not same if op == "!=" else false)

## Numbers compare as numbers; refs to objects compare by identity.
static func _cmp_value(e, value, ctx: Dictionary):
	if value is String and str(value).begins_with("$"):
		var resolved = ref(e, str(value), ctx)
		if resolved is Array:
			resolved = resolved[0] if resolved.size() == 1 else null
		if resolved is int or resolved is bool:
			return int(resolved)
		if resolved is String:
			return resolved
		return Select.key(resolved) if resolved != null else "?"
	return expr(e, value, ctx)
