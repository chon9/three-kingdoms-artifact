extends RefCounted
## Card rules compiler and validator (EFFECT_SYSTEM_SPEC.md §3, §3.14).
##
## compile(card) normalizes numbers to int, expands selector shorthands,
## resolves {"param": name} to the defining card's top-level int, prepends the
## implicit choices, validates everything against rules/vocab.gd and indexes
## the abilities by event. Errors carry the card id and a JSON path; a card
## with any error is unplayable and listed in CardLibrary.errors.
##
## Compiled shapes (all values JSON-safe ints, strings, arrays, dictionaries):
##   selector  {"s", "side", "lane", "kind", "card", "color", "slot", "rel",
##              "not", "where", "zone", "player", "pick", "after"} (absent keys
##              are null); a set is a ref string, a selector or a list of sets.
##   ref       "$self", "$host", "$played", "$it", "$c.<key>", "$e.<field>",
##             "$v.<name>", optionally followed by ".<field>".
##   expr      int, ref, or a one-key dictionary from Vocab.EXPR_KEYS.
##   ops       dictionaries with "op" and their fields, recursively compiled.

const Vocab = preload("res://scripts/core/rules/vocab.gd")
const LEGACY_FIELDS = ["effect", "target", "include_tower", "piercing", "neighbors", "discard_random",
	"initiative", "ability", "rapid_deployment"]

## Compiles and validates one card entry. The pre-schema-4 effect fields
## (LEGACY_FIELDS) are errors with a hint to express them in rules.
static func compile(card: Dictionary) -> Dictionary:
	var report = {"errors": [], "warnings": []}
	var id = str(card.get("id", "?"))
	var normalized = _normalize(card, id, report)
	var kind = str(normalized.get("kind", ""))
	var out = {"id": id, "kind": kind, "errors": report.errors, "warnings": report.warnings,
		"status": str(normalized.get("status", "")), "token": bool(normalized.get("token", false)),
		"rq": normalized.get("rq", []), "params": {}, "keywords": {}, "play": {}, "enter": [],
		"abilities": [], "grants": [], "host": {}, "events": {}, "grant_events": {}, "active": -1,
		"auras": [], "static": {"draw": 0, "initiative": false, "random": false, "bias": 0.0},
		"ability_static": {}, "uses": {}}
	for key in normalized:
		var value = normalized[key]
		if value is int and not value is bool:
			out.params[key] = value
		elif key in LEGACY_FIELDS:
			_err(report, id, key, "legacy field %s is not part of schema 4; express it in rules" % key)
		elif key not in Vocab.CARD_FIELDS:
			_err(report, id, key, "unknown card field %s" % key)
	_check_metadata(normalized, id, kind, report)
	# Card keywords (printed).
	for keyword in normalized.get("keywords", {}):
		var value = _resolve_number(normalized.keywords[keyword], normalized, id, "keywords." + keyword, report)
		if keyword in Vocab.RESERVED_KEYWORDS:
			_err(report, id, "keywords." + keyword, "reserved keyword %s is not supported" % keyword)
		elif keyword not in Vocab.KEYWORDS:
			_err(report, id, "keywords." + keyword, "unknown keyword %s" % keyword)
		elif kind not in ["hero", "creep"]:
			_err(report, id, "keywords." + keyword, "only units have printed keywords")
		out.keywords[keyword] = value
	# Implicit host aura of equipment: top-level attack/armor/health.
	var equipment = kind == "item" and str(normalized.get("slot", "")) in Vocab.EQUIPMENT_SLOTS and not normalized.get("consumable", false)
	if equipment:
		for stat in ["attack", "armor"]:
			if int(normalized.get(stat, 0)) != 0:
				out.host[stat] = int(normalized[stat])
		if int(normalized.get("health", 0)) != 0:
			out.host["max_health"] = int(normalized.health)
	var holder = _holder(kind, normalized)
	# Play block (spells, consumables, creep Play Effects, deeds).
	var implicit: Array = []
	if kind == "creep":
		implicit.append({"key": "position", "from": {"s": "positions", "side": "ally", "lane": "active"}})
	elif kind == "improvement":
		implicit.append({"key": "lane", "from": {"s": "lanes", "lane": "all"}})
	elif equipment:
		implicit.append({"key": "target", "from": {"s": "units", "side": "ally", "kind": "hero", "lane": "active"}})
	var play: Dictionary = normalized.get("play", {}) if normalized.get("play", {}) is Dictionary else {}
	if normalized.has("play") and not normalized.play is Dictionary:
		_err(report, id, "play", "play must be a block")
	if kind == "hero" and normalized.has("play"):
		_err(report, id, "play", "heroes have no play block")
	if not play.is_empty() or not implicit.is_empty() or kind in ["spell", "item", "creep", "improvement"]:
		if kind != "hero":
			out.play = _compile_play(play, implicit, normalized, id, kind, report)
	if normalized.has("enter"):
		var scope = _scope(normalized, id, report, "enter", "object")
		scope.has_host = kind == "item"
		if kind not in ["item", "improvement"]:
			_err(report, id, "enter", "only items and improvements have an enter block")
		out.enter = _ops(normalized.enter, "enter", scope)
	# Abilities.
	var ability_ids: Dictionary = {}
	var abilities = normalized.get("abilities", [])
	if not abilities is Array:
		_err(report, id, "abilities", "abilities must be a list")
		abilities = []
	for index in range(abilities.size()):
		var path = "abilities[%d]" % index
		var ability = abilities[index]
		if not ability is Dictionary:
			_err(report, id, path, "an ability is an object")
			continue
		var ability_id = str(ability.get("id", ""))
		if ability_id.is_empty():
			_err(report, id, path, "an ability needs an id")
		elif ability_ids.has(ability_id):
			_err(report, id, path, "duplicate ability id %s" % ability_id)
		ability_ids[ability_id] = true
		if str(ability.get("kind", "")) == "hack":
			_err(report, id, path, "a hack is only allowed in grants")
		var compiled = _compile_ability(ability, path, normalized, id, holder, false, report)
		compiled["index"] = index
		out.abilities.append(compiled)
		match str(compiled.get("kind", "")):
			"trigger":
				if not out.events.has(compiled.on):
					out.events[compiled.on] = []
				out.events[compiled.on].append(index)
			"aura":
				out.auras.append(index)
			"active":
				if out.active != -1:
					_err(report, id, path, "a card has at most one active ability")
				else:
					out.active = index
				out.ability_static[ability_id] = _static_value(compiled.get("ops", []))
	var grants = normalized.get("grants", [])
	if not grants is Array:
		_err(report, id, "grants", "grants must be a list")
		grants = []
	for index in range(grants.size()):
		var path = "grants[%d]" % index
		if not grants[index] is Dictionary:
			_err(report, id, path, "a grant is an object")
			continue
		var compiled = _compile_ability(grants[index], path, normalized, id, "granted", true, report)
		compiled["index"] = index
		out.grants.append(compiled)
		if str(compiled.get("kind", "")) == "trigger":
			if not out.grant_events.has(compiled.on):
				out.grant_events[compiled.on] = []
			out.grant_events[compiled.on].append(index)
	# Static values for the bot (spec §9.2).
	if not out.play.is_empty():
		out.static = _static_value(out.play.get("ops", []))
		out.static["initiative"] = bool(out.play.get("initiative", false))
	out.static["random"] = _has_random(normalized)
	var ai = normalized.get("ai", {})
	if ai is Dictionary and ai.has("bias"):
		out.static["bias"] = float(ai.bias)
	_collect_uses(out, out.uses)
	if out.status == "verified":
		for op_name in out.uses:
			if op_name in Vocab.OPS_PENDING:
				_err(report, id, "status", "verified cards may not use %s yet (milestone M2); mark the card draft" % op_name)
	for op_name in out.uses:
		if op_name == "native":
			_warn(report, id, "native", "uses a native handler")
	return out

# --- Metadata ----------------------------------------------------------------

static func _check_metadata(card: Dictionary, id: String, kind: String, report: Dictionary) -> void:
	if not card.has("id") or not card.id is String or str(card.id).is_empty():
		_err(report, id, "id", "a card needs a string id")
	if kind not in Vocab.KINDS:
		_err(report, id, "kind", "unknown kind %s" % kind)
	if str(card.get("status", "")) not in Vocab.STATUSES:
		_err(report, id, "status", "status must be verified or draft")
	if card.has("color") and str(card.color) not in Vocab.COLORS:
		_err(report, id, "color", "unknown color %s" % str(card.color))
	if card.has("slot") and str(card.slot) not in Vocab.SLOTS:
		_err(report, id, "slot", "unknown slot %s" % str(card.slot))
	if card.has("token") and not card.token is bool:
		_err(report, id, "token", "token is a boolean")
	if card.has("rq"):
		if not card.rq is Array:
			_err(report, id, "rq", "rq is a list of RQ ids")
		else:
			for entry in card.rq:
				if not (entry is String and str(entry).begins_with("RQ-")):
					_err(report, id, "rq", "bad rules question id %s" % str(entry))
	if card.has("valve_text") and not card.valve_text is String:
		_err(report, id, "valve_text", "valve_text is a string")
	if card.has("ai") and not card.ai is Dictionary:
		_err(report, id, "ai", "ai is an object")
	if card.has("charges") and not (card.charges is int and int(card.charges) >= 0):
		_err(report, id, "charges", "charges is a whole number")
	# Units need printed stats: the engine builds them from attack and health.
	if kind in ["hero", "creep"]:
		for stat in ["attack", "health"]:
			if not card.has(stat):
				_err(report, id, stat, "a %s needs %s" % [kind, stat])
			elif not (card[stat] is int and int(card[stat]) >= 0):
				_err(report, id, stat, "%s is a whole number" % stat)
		if card.has("armor") and not card.armor is int:
			_err(report, id, "armor", "armor is a whole number")

static func _holder(kind: String, card: Dictionary) -> String:
	match kind:
		"hero", "creep":
			return "unit"
		"item":
			return "deed" if str(card.get("slot", "")) == "deed" else "item"
		"improvement":
			return "improvement"
	return "spell"

# --- Normalization -------------------------------------------------------------

## Deep copy with whole floats turned into ints; fractions are errors.
static func _normalize(value, id: String, report: Dictionary, path: String = ""):
	if value is float:
		if value != floor(value):
			_err(report, id, path, "fraction %s; rules use whole numbers only" % str(value))
			return int(floor(value))
		return int(value)
	if value is Array:
		var items: Array = []
		for index in range(value.size()):
			items.append(_normalize(value[index], id, report, "%s[%d]" % [path, index]))
		return items
	if value is Dictionary:
		var entries: Dictionary = {}
		for key in value:
			entries[key] = _normalize(value[key], id, report, (str(key) if path.is_empty() else "%s.%s" % [path, key]))
		return entries
	return value

# --- Scopes --------------------------------------------------------------------

static func _scope(card: Dictionary, id: String, report: Dictionary, path: String, block: String) -> Dictionary:
	return {"card": card, "id": id, "report": report, "path": path, "block": block,
		"choices": [], "vars": [], "event": "", "in_where": false, "has_self": block != "spell",
		"has_host": block in ["unit", "creep", "granted", "item"], "played": block in ["spell", "creep", "hack"],
		"random": true, "aura": "", "single": false}

static func _child(scope: Dictionary) -> Dictionary:
	var copy = scope.duplicate()
	copy.choices = scope.choices.duplicate()
	copy.vars = scope.vars.duplicate()
	return copy

static func _err(report: Dictionary, id: String, path: String, message: String) -> void:
	report.errors.append("%s.%s: %s" % [id, path, message])

static func _warn(report: Dictionary, id: String, path: String, message: String) -> void:
	report.warnings.append("%s.%s: %s" % [id, path, message])

static func _e(scope: Dictionary, path: String, message: String) -> void:
	_err(scope.report, scope.id, path, message)

# --- Blocks --------------------------------------------------------------------

static func _compile_play(play: Dictionary, implicit: Array, card: Dictionary, id: String, kind: String, report: Dictionary) -> Dictionary:
	var block = "creep" if kind == "creep" else ("object" if kind == "improvement" else "spell")
	var scope = _scope(card, id, report, "play", block)
	if kind == "item" and str(card.get("slot", "")) == "deed":
		scope.played = false
	for key in play:
		if key not in Vocab.PLAY_FIELDS:
			_e(scope, "play." + str(key), "unknown play field %s" % key)
	var written = play.get("choices", [])
	if not written is Array:
		_e(scope, "play.choices", "choices must be a list")
		written = []
	for choice in written:
		if choice is Dictionary:
			for entry in implicit:
				if str(choice.get("key", "")) == entry.key:
					_e(scope, "play.choices", "the %s choice is implicit for this card type and must not be written" % entry.key)
	var choices = _choices(implicit + written, "play.choices", scope, implicit.size())
	var requires = null
	if play.has("requires"):
		var condition_scope = _child(scope)
		condition_scope.random = false
		condition_scope.choices = []
		requires = _cond(play.requires, "play.requires", condition_scope)
	var initiative = play.get("initiative", false)
	if not initiative is bool:
		_e(scope, "play.initiative", "initiative is a boolean")
		initiative = false
	return {"choices": choices, "requires": requires, "ops": _ops(play.get("ops", []), "play.ops", scope),
		"initiative": initiative}

static func _choices(choices: Array, path: String, scope: Dictionary, implicit_count: int = 0) -> Array:
	var out: Array = []
	for index in range(choices.size()):
		var here = "%s[%d]" % [path, index - implicit_count] if index >= implicit_count else "%s(implicit)" % path
		var choice = choices[index]
		if not choice is Dictionary:
			_e(scope, here, "a choice is an object")
			continue
		for key in choice:
			if key not in Vocab.CHOICE_FIELDS:
				_e(scope, "%s.%s" % [here, key], "unknown choice field %s" % key)
		var key = str(choice.get("key", ""))
		if key not in Vocab.CHOICE_KEYS:
			_e(scope, here + ".key", "choice key must be one of %s" % [Vocab.CHOICE_KEYS])
		elif key in scope.choices:
			_e(scope, here + ".key", "duplicate choice key %s" % key)
		var choice_scope = _child(scope)
		choice_scope.random = false
		var compiled = {"key": key}
		if choice.has("combat_target_of"):
			compiled["combat_target_of"] = _one(choice.combat_target_of, here + ".combat_target_of", choice_scope)
			compiled["type"] = "combat_target"
			if key not in ["target", "destination"]:
				_e(scope, here, "a combat target choice fills target or destination")
		elif choice.has("from"):
			var source = _set_of(choice.from, here + ".from", choice_scope)
			compiled["from"] = source
			var selector_kind = str(source.get("s", "")) if source is Dictionary else "units"
			var expected = {"units": ["target", "destination"], "improvements": ["target", "destination"],
				"lanes": ["lane"], "positions": ["position"]}
			if not expected.has(selector_kind):
				_e(scope, here + ".from", "a choice selects units, improvements, lanes or positions")
			elif key not in expected[selector_kind]:
				_e(scope, here + ".from", "choice key %s does not match a %s selector" % [key, selector_kind])
			compiled["type"] = {"units": "unit", "improvements": "improvement", "lanes": "lane", "positions": "position"}.get(selector_kind, "unit")
		else:
			_e(scope, here, "a choice needs from or combat_target_of")
		if choice.has("after"):
			compiled["after"] = _ref(choice.after, here + ".after", choice_scope)
		scope.choices.append(key)
		out.append(compiled)
	return out

static func _compile_ability(ability: Dictionary, path: String, card: Dictionary, id: String, holder: String,
		granted: bool, report: Dictionary) -> Dictionary:
	var kind = str(ability.get("kind", ""))
	var block = "granted" if granted else holder
	if kind == "hack":
		block = "hack"
	var scope = _scope(card, id, report, path, block)
	scope.has_self = true
	scope.has_host = block in ["unit", "item", "granted"]
	scope.played = block == "hack"
	if not Vocab.ABILITY_KINDS.has(kind):
		_e(scope, path + ".kind", "unknown ability kind %s" % kind)
		return {"kind": kind, "ops": []}
	for key in ability:
		if key not in Vocab.ABILITY_KINDS[kind]:
			_e(scope, "%s.%s" % [path, key], "unknown %s field %s" % [kind, key])
	var out = {"kind": kind, "id": str(ability.get("id", "")), "card": id}
	if ability.has("valve"):
		out["valve"] = int(ability.valve) if ability.valve is int else 0
	match kind:
		"aura":
			var aura_scope = _child(scope)
			aura_scope.random = false
			if not ability.has("affects"):
				_e(scope, path + ".affects", "an aura needs affects")
			# Membership reads no derived stats, so derivation cannot recurse.
			var affects_scope = _child(aura_scope)
			affects_scope.aura = "if"
			out["affects"] = _set_of(ability.get("affects", "$self"), path + ".affects", affects_scope)
			if ability.has("if"):
				var condition_scope = _child(aura_scope)
				condition_scope.aura = "if"
				out["if"] = _cond(ability["if"], path + ".if", condition_scope)
			var grant = ability.get("grant", {})
			out["stats"] = {}
			out["keywords"] = {}
			out["rules"] = {}
			if not grant is Dictionary or grant.is_empty():
				_e(scope, path + ".grant", "an aura needs a non-empty grant")
				grant = {}
			for key in grant:
				var here = "%s.grant.%s" % [path, key]
				if key == "rules":
					out.rules = _rules_grant(grant.rules, here, aura_scope)
				elif key == "health":
					_e(scope, here, "a grant has no health; use max_health")
				elif key in Vocab.STATS:
					var stat_scope = _child(aura_scope)
					stat_scope.aura = "stat"
					out.stats[key] = _expr(grant[key], here, stat_scope)
				elif key in Vocab.KEYWORDS:
					if key in Vocab.AURA_FORBIDDEN:
						_e(scope, here, "an aura may not grant %s" % key)
					var keyword_scope = _child(aura_scope)
					keyword_scope.aura = "keyword"
					out.keywords[key] = _expr(grant[key], here, keyword_scope)
				elif key in Vocab.RESERVED_KEYWORDS:
					_e(scope, here, "reserved keyword %s is not supported" % key)
				else:
					_e(scope, here, "unknown grant %s" % key)
			# What this aura changes, as "<target>:<field>" (units, towers or
			# players; a stat, "kw" or "rules"), for demand-driven derivation.
			var changed: Array = out.stats.keys()
			if not out.keywords.is_empty():
				changed.append("kw")
			if not out.rules.is_empty():
				changed.append("rules")
			var fields: Array = []
			for target in _affect_kinds(out.affects):
				for field in changed:
					fields.append("%s:%s" % [target, field])
			out["fields"] = fields
		"trigger":
			var event = str(ability.get("on", ""))
			if not Vocab.EVENTS.has(event):
				_e(scope, path + ".on", "unknown event %s" % event)
				event = ""
			out["on"] = event
			scope.event = event
			var lane = str(ability.get("lane", "self"))
			if lane not in ["self", "any"]:
				_e(scope, path + ".lane", "trigger lane is self or any")
			out["lane"] = lane
			if ability.has("once_per"):
				if str(ability.once_per) not in ["round", "lane_round"]:
					_e(scope, path + ".once_per", "once_per is round or lane_round")
				out["once_per"] = str(ability.once_per)
			out["filter"] = _filter(ability.get("filter", {}), event, path + ".filter", scope)
			if ability.has("where"):
				var where_scope = _child(scope)
				where_scope.random = false
				out["where"] = _cond(ability.where, path + ".where", where_scope)
			out["ops"] = _ops(ability.get("ops", []), path + ".ops", scope)
		"active":
			var cooldown = _resolve_number(ability.get("cooldown", 0), card, id, path + ".cooldown", report)
			if cooldown < 1:
				_e(scope, path + ".cooldown", "an active ability needs cooldown >= 1")
			out["cooldown"] = cooldown
			out["quicken"] = bool(ability.get("quicken", false))
			out["choices"] = _choices(ability.get("choices", []), path + ".choices", scope)
			if ability.has("requires"):
				var condition_scope = _child(scope)
				condition_scope.random = false
				condition_scope.choices = []
				out["requires"] = _cond(ability.requires, path + ".requires", condition_scope)
			out["ops"] = _ops(ability.get("ops", []), path + ".ops", scope)
			if granted:
				_e(scope, path, "granted actives are not supported")
		"hack":
			out["ops"] = _ops(ability.get("ops", []), path + ".ops", scope)
	return out

## The kinds of object an aura's affects set can hold: refs are units.
static func _affect_kinds(affects) -> Array:
	if affects is Dictionary:
		return [str(affects.get("s", "units"))]
	if affects is Array:
		var kinds: Array = []
		for entry in affects:
			for kind in _affect_kinds(entry):
				if kind not in kinds:
					kinds.append(kind)
		return kinds
	return ["units"]

static func _rules_grant(rules, path: String, scope: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not rules is Dictionary:
		_e(scope, path, "rules is an object")
		return out
	for key in rules:
		var here = "%s.%s" % [path, key]
		match key:
			"round_draw", "secret_shop_discount":
				out[key] = _expr(rules[key], here, scope)
			"forbid_play":
				var value = rules[key]
				if not value is Dictionary or not value.get("kinds") is Array:
					_e(scope, here, "forbid_play needs kinds")
					continue
				for kind in value.kinds:
					if str(kind) not in Vocab.KINDS:
						_e(scope, here, "unknown card kind %s" % str(kind))
				out[key] = {"kinds": value.kinds, "lane": str(value.get("lane", "self"))}
			"creep_lane":
				if str(rules[key]) != "self":
					_e(scope, here, "creep_lane is self")
				out[key] = "self"
			_:
				_e(scope, here, "unknown rules key %s" % key)
	return out

static func _filter(filter, event: String, path: String, scope: Dictionary) -> Dictionary:
	if not filter is Dictionary:
		_e(scope, path, "filter is an object")
		return {}
	var allowed = Vocab.FILTERS.get(event, [])
	var out: Dictionary = {}
	for key in filter:
		var value = filter[key]
		var here = "%s.%s" % [path, key]
		if key not in allowed:
			_e(scope, here, "filter key %s is not valid for %s" % [key, event])
			continue
		match key:
			"player", "side":
				var words = ["you", "opponent"] if key == "player" else ["ally", "enemy"]
				if str(value) not in words:
					_e(scope, here, "%s is one of %s" % [key, words])
			"kind", "not_kind":
				for entry in (value if value is Array else [value]):
					if str(entry) not in Vocab.KINDS + ["creep", "hero"]:
						_e(scope, here, "unknown kind %s" % str(entry))
			"color":
				for entry in (value if value is Array else [value]):
					if str(entry) not in Vocab.COLORS:
						_e(scope, here, "unknown color %s" % str(entry))
			"cost_max":
				if not value is int:
					_e(scope, here, "cost_max is a whole number")
			"card":
				pass
			"was":
				if str(value) not in ["allied_neighbor", "enemy_neighbor", "blocker"]:
					_e(scope, here, "was is allied_neighbor, enemy_neighbor or blocker")
			"role":
				if str(value) not in ["dealer", "taker"]:
					_e(scope, here, "role is dealer or taker")
			"target_kind":
				if str(value) not in ["unit", "hero", "creep", "tower"]:
					_e(scope, here, "target_kind is unit, hero, creep or tower")
			"source_kind":
				if str(value) not in ["unit", "tower"]:
					_e(scope, here, "source_kind is unit or tower")
			"in_combat":
				if not value is bool:
					_e(scope, here, "in_combat is a boolean")
			"how":
				if str(value) not in ["deploy", "play", "summon", "move", "control"]:
					_e(scope, here, "unknown entry kind %s" % str(value))
		out[key] = value
	return out

# --- Ops -----------------------------------------------------------------------

static func _ops(ops, path: String, scope: Dictionary) -> Array:
	var out: Array = []
	if not ops is Array:
		_e(scope, path, "ops must be a list")
		return out
	for index in range(ops.size()):
		var op = ops[index]
		var here = "%s[%d]" % [path, index]
		if not op is Dictionary or not op.has("op"):
			_e(scope, here, "an op is an object with an op name")
			continue
		var compiled = _op(op, "%s:%s" % [here, str(op.op)], scope)
		if not compiled.is_empty():
			out.append(compiled)
	return out

static func _op(op: Dictionary, path: String, scope: Dictionary) -> Dictionary:
	var name = str(op.op)
	if not Vocab.OPS.has(name):
		_e(scope, path, "unknown op %s" % name)
		return {}
	for key in op:
		if key != "op" and key not in Vocab.OPS[name]:
			_e(scope, "%s.%s" % [path, key], "unknown field %s of %s" % [key, name])
	for key in Vocab.OP_REQUIRED.get(name, []):
		if not op.has(key):
			_e(scope, path, "%s needs %s" % [name, key])
	var out = {"op": name}
	var nested: Array = []
	for key in op:
		if key == "op" or key not in Vocab.OPS[name]:
			continue
		if key in ["ops", "then", "else"]:
			nested.append(key)
			continue
		var value = op[key]
		var here = "%s.%s" % [path, key]
		if key in Vocab.SET_FIELDS.get(name, []):
			out[key] = _set_of(value, here, scope)
		elif key in Vocab.ONE_FIELDS.get(name, []):
			out[key] = _one(value, here, scope)
		elif key in Vocab.EXPR_FIELDS.get(name, []):
			if ((name == "heal" and key == "amount") or (name == "mana" and key == "restore")) and str(value) == "full":
				out[key] = "full"
			else:
				out[key] = _expr(value, here, scope)
		else:
			out[key] = _op_field(name, key, value, here, scope)
	# Nested op lists see the variables bound so far; for_each binds `as`.
	for key in nested:
		var inner = _child(scope)
		if name == "for_each" and out.has("as"):
			inner.vars.append(out["as"])
		out[key] = _ops(op[key], "%s.%s" % [path, key], inner)
	_op_defaults(name, out, path, scope)
	return out

static func _op_field(name: String, key: String, value, path: String, scope: Dictionary):
	match key:
		"piercing", "base":
			if not value is bool:
				_e(scope, path, "%s is a boolean" % key)
			return bool(value)
		"stats":
			var out: Dictionary = {}
			if not value is Dictionary:
				_e(scope, path, "stats is an object")
				return out
			for stat in value:
				if stat == "health":
					_e(scope, "%s.%s" % [path, stat], "use max_health, not health")
				elif stat not in Vocab.STATS:
					_e(scope, "%s.%s" % [path, stat], "unknown stat %s" % stat)
				out[stat] = _expr(value[stat], "%s.%s" % [path, stat], scope)
			return out
		"keywords":
			var out: Dictionary = {}
			if not value is Dictionary:
				_e(scope, path, "keywords is an object")
				return out
			for keyword in value:
				if keyword in Vocab.RESERVED_KEYWORDS:
					_e(scope, "%s.%s" % [path, keyword], "reserved keyword %s is not supported" % keyword)
				elif keyword not in Vocab.KEYWORDS:
					_e(scope, "%s.%s" % [path, keyword], "unknown keyword %s" % keyword)
				out[keyword] = _expr(value[keyword], "%s.%s" % [path, keyword], scope)
			return out
		"grant":
			var grants = scope.card.get("grants", [])
			if not value is int or int(value) < 0 or int(value) >= (grants.size() if grants is Array else 0):
				_e(scope, path, "grant %s does not index this card's grants" % str(value))
				return -1
			var granted = grants[int(value)]
			if granted is Dictionary and str(granted.get("kind", "")) == "hack" and name != "modify":
				_e(scope, path, "a hack is attached with modify")
			return int(value)
		"until":
			if str(value) not in Vocab.DURATIONS:
				_e(scope, path, "until is one of %s" % [Vocab.DURATIONS])
			return str(value)
		"from":
			if str(value) not in ["opponent", "all"]:
				_e(scope, path, "purge from is opponent or all")
			return str(value)
		"card":
			if name == "summon":
				if not value is String or str(value).begins_with("$"):
					_e(scope, path, "summon names a card id")
				return str(value)
			# add_card: an id, "$e.card" or {"card_of": Sel}.
			if value is Dictionary and value.has("card_of"):
				return {"card_of": _set_of(value.card_of, path + ".card_of", scope)}
			if value is String and str(value).begins_with("$"):
				return _ref(value, path, scope)
			return str(value)
		"from_pool":
			if str(value) != "secret_shop":
				_e(scope, path, "from_pool is secret_shop")
			return str(value)
		"for", "player":
			var words = Vocab.PLAYER_WORDS if name == "draw" else ["you", "opponent"]
			if str(value) not in words:
				_e(scope, path, "%s is one of %s" % [key, words])
			return str(value)
		"to":
			match name:
				"control":
					if str(value) != "you":
						_e(scope, path, "control to is you")
					return "you"
				"retarget":
					if value is int and int(value) == 0:
						return 0
					if str(value) == "across":
						return "across"
					return _one(value, path, scope)
			return _set_of(value, path, scope)
		"lane":
			if name == "move" and str(value) == "random_other":
				return "random_other"
			if value is int:
				return int(value)
			return _one(value, path, scope)
		"position":
			if value is int:
				return int(value)
			return _one(value, path, scope)
		"counter":
			if str(value) != "charges":
				_e(scope, path, "the only card counter is charges")
			return "charges"
		"min":
			if not value is int:
				_e(scope, path, "min is a whole number")
			return int(value) if value is int else 0
		"name", "as":
			if not value is String or str(value).is_empty():
				_e(scope, path, "%s is a variable name" % key)
			return str(value)
		"value":
			return _value(value, path, scope)
		"cond":
			# Randomness is never allowed in conditions (spec §3.5): use chance.
			var condition_scope = _child(scope)
			condition_scope.random = false
			return _cond(value, path, condition_scope)
		"fn":
			if not value is String:
				_e(scope, path, "fn names a native handler")
			return str(value)
		"args":
			return value if value is Dictionary else {}
	_e(scope, path, "unhandled field %s" % key)
	return value

## Defaults, variable bindings and per-op checks after the fields compile.
static func _op_defaults(name: String, out: Dictionary, path: String, scope: Dictionary) -> void:
	match name:
		"damage", "tower_damage":
			out["piercing"] = bool(out.get("piercing", false))
		"modify", "give":
			if not out.has("stats") and not out.has("keywords") and not out.has("grant"):
				_e(scope, path, "%s changes nothing" % name)
			out["stats"] = out.get("stats", {})
			out["keywords"] = out.get("keywords", {})
			out["grant"] = out.get("grant", -1)
			if name == "modify":
				for keyword in out.keywords:
					if keyword in Vocab.STATUS_KEYWORDS:
						_e(scope, path, "statuses are given, not modified")
		"purge":
			out["from"] = out.get("from", "opponent")
		"summon":
			out["count"] = out.get("count", 1)
			out["for"] = out.get("for", "you")
			if out.has("as"):
				scope.vars.append(out["as"])
		"draw":
			out["player"] = out.get("player", "you")
			out["n"] = out.get("n", 1)
		"gold":
			out["player"] = out.get("player", "you")
			if out.has("as"):
				scope.vars.append(out["as"])
		"let":
			if out.has("name"):
				scope.vars.append(out.name)
		"repeat":
			out["ops"] = out.get("ops", [])
		"chance":
			if not scope.random:
				_e(scope, path, "randomness is not allowed here")
			out["then"] = out.get("then", [])
			out["else"] = out.get("else", [])
		"if":
			out["then"] = out.get("then", [])
			out["else"] = out.get("else", [])
		"for_each":
			out["ops"] = out.get("ops", [])
		"native":
			_e(scope, path, "no native handler %s is registered" % str(out.get("fn", "")))

# --- Sets, refs, expressions and conditions ---------------------------------------

static func _set_of(value, path: String, scope: Dictionary):
	if value is String:
		var text = str(value)
		if text.begins_with("$"):
			return _ref(text, path, scope)
		if Vocab.SHORTHANDS.has(text):
			return _sel(Vocab.SHORTHANDS[text].duplicate(true), path, scope, text)
		_e(scope, path, "unknown selector %s" % text)
		return {}
	if value is Array:
		var items: Array = []
		for index in range(value.size()):
			items.append(_set_of(value[index], "%s[%d]" % [path, index], scope))
		return items
	if value is Dictionary:
		return _sel(value, path, scope, "")
	_e(scope, path, "a set is a ref, a selector or a list")
	return {}

## One object: a ref, or a selector whose size is not fixed above 1 (CF-3).
static func _one(value, path: String, scope: Dictionary):
	var compiled = _set_of(value, path, scope)
	if compiled is Dictionary and compiled.get("pick") is int and int(compiled.pick) > 1:
		_e(scope, path, "a single-object field cannot take %d random objects" % int(compiled.pick))
	return compiled

static func _sel(value: Dictionary, path: String, scope: Dictionary, shorthand: String) -> Dictionary:
	var source = value
	if value.has("use"):
		var base = str(value.use)
		if not Vocab.SHORTHANDS.has(base):
			_e(scope, path + ".use", "unknown shorthand %s" % base)
			source = {}
		else:
			source = Vocab.SHORTHANDS[base].duplicate(true)
			shorthand = base
		for key in value:
			if key != "use":
				source[key] = value[key]
	for key in source:
		if key not in Vocab.SELECTOR_KEYS:
			_e(scope, "%s.%s" % [path, key], "unknown selector key %s" % key)
	var kind = str(source.get("s", ""))
	if kind not in Vocab.SELECTOR_KINDS:
		_e(scope, path + ".s", "unknown selector kind %s" % kind)
	var out = {"s": kind, "side": str(source.get("side", "any")), "lane": null, "kind": null, "card": null,
		"color": null, "slot": null, "rel": null, "not": null, "where": null, "zone": null, "player": null,
		"pick": null, "after": null}
	if out.side not in Vocab.SIDES:
		_e(scope, path + ".side", "side is ally, enemy or any")
	if source.has("lane"):
		var lane = source.lane
		if lane is int:
			out.lane = int(lane)
		elif lane is String and not str(lane).begins_with("$"):
			if str(lane) not in Vocab.LANE_WORDS:
				_e(scope, path + ".lane", "lane is one of %s or a ref" % [Vocab.LANE_WORDS])
			if str(lane) == "fountain" and kind != "units":
				_e(scope, path + ".lane", "only units are in the Fountain")
			out.lane = str(lane)
		else:
			out.lane = _ref(lane, path + ".lane", scope)
	if source.has("kind"):
		var allowed = ["hero", "creep"] if kind == "units" else Vocab.KINDS
		if str(source.kind) not in allowed:
			_e(scope, path + ".kind", "kind %s is not valid for %s" % [str(source.kind), kind])
		out.kind = str(source.kind)
	if source.has("card"):
		out.card = source.card if source.card is Array else [source.card]
	if source.has("color"):
		if str(source.color) not in Vocab.COLORS:
			_e(scope, path + ".color", "unknown color %s" % str(source.color))
		out.color = str(source.color)
	if source.has("slot"):
		if str(source.slot) not in Vocab.EQUIPMENT_SLOTS:
			_e(scope, path + ".slot", "slot is weapon, armor or accessory")
		out.slot = str(source.slot)
	if source.has("rel"):
		var relations: Dictionary = {}
		if not source.rel is Dictionary or source.rel.size() != 1:
			_e(scope, path + ".rel", "rel names exactly one relation")
		else:
			for relation in source.rel:
				if relation not in Vocab.RELATIONS:
					_e(scope, "%s.rel.%s" % [path, relation], "unknown relation %s" % relation)
				relations[relation] = _set_of(source.rel[relation], "%s.rel.%s" % [path, relation], scope)
		out.rel = relations
	if source.has("not"):
		out["not"] = _set_of(source["not"], path + ".not", scope)
	if source.has("where"):
		var where_scope = _child(scope)
		where_scope.in_where = true
		where_scope.random = false
		out.where = _cond(source.where, path + ".where", where_scope)
	if source.has("zone"):
		var zones = source.zone if source.zone is Array else [source.zone]
		for zone in zones:
			if str(zone) not in Vocab.ZONES:
				_e(scope, path + ".zone", "zone is hand or deck")
		if kind != "cards":
			_e(scope, path + ".zone", "zone is only for cards")
		out.zone = zones
	if source.has("player"):
		if str(source.player) not in ["you", "opponent"]:
			_e(scope, path + ".player", "player is you or opponent")
		out.player = str(source.player)
	if source.has("pick"):
		if not scope.random:
			_e(scope, path + ".pick", "randomness is not allowed here")
		if not source.pick is Dictionary or not source.pick.has("random"):
			_e(scope, path + ".pick", "pick is {\"random\": n}")
		else:
			out.pick = _expr(source.pick.random, path + ".pick.random", scope)
	if source.has("after"):
		out.after = _ref(source.after, path + ".after", scope)
	if kind == "cards" and out.zone == null:
		out.zone = ["hand"]
	return out

## A let value: an expression, a selector (captured as a list) or a ref.
static func _value(value, path: String, scope: Dictionary):
	if value is String and Vocab.SHORTHANDS.has(str(value)):
		return {"set": _set_of(value, path, scope)}
	if value is Dictionary and (value.has("s") or value.has("use")):
		return {"set": _set_of(value, path, scope)}
	if value is Array:
		return {"set": _set_of(value, path, scope)}
	return _expr(value, path, scope)

static func _ref(value, path: String, scope: Dictionary) -> String:
	if not value is String or not str(value).begins_with("$"):
		_e(scope, path, "expected a ref, got %s" % str(value))
		return ""
	var text = str(value)
	var parts = text.split(".")
	var root = parts[0]
	var field_at = 1
	match root:
		"$self":
			if not scope.has_self:
				_e(scope, path, "$self is not available in a spell's play block")
		"$host":
			if not scope.has_host:
				_e(scope, path, "$host is not available here")
		"$played":
			if not scope.played:
				_e(scope, path, "$played is only available in a play block")
			if parts.size() > 1 and parts[1] not in ["card", "state"]:
				_e(scope, path, "$played has card and state")
			return text
		"$it":
			if not scope.in_where:
				_e(scope, path, "$it is only available inside where")
		"$c":
			field_at = 2
			if parts.size() < 2 or parts[1] not in scope.choices:
				_e(scope, path, "choice %s is not declared earlier" % text)
		"$e":
			field_at = 2
			if scope.event.is_empty():
				_e(scope, path, "event ref %s outside a trigger" % text)
			elif parts.size() < 2 or parts[1] not in Vocab.EVENTS.get(scope.event, []):
				_e(scope, path, "%s is not a field of %s" % [text, scope.event])
		"$v":
			field_at = 2
			if parts.size() < 2 or parts[1] not in scope.vars:
				_e(scope, path, "variable %s is not bound" % text)
		_:
			_e(scope, path, "unknown ref %s" % text)
	for index in range(field_at, parts.size()):
		if parts[index] not in Vocab.REF_FIELDS:
			_e(scope, path, "unknown ref field %s" % parts[index])
	return text

static func _expr(value, path: String, scope: Dictionary):
	if value is bool:
		_e(scope, path, "expected a number, got a boolean")
		return 0
	if value is int:
		return value
	if value is String:
		if str(value) in ["you", "opponent"]:
			return str(value)
		if not str(value).begins_with("$"):
			_e(scope, path, "expected a number, a ref or a {...} expression, got string \"%s\"" % str(value))
			return 0
		return _ref(value, path, scope)
	if not value is Dictionary or value.is_empty():
		_e(scope, path, "expected a number, a ref or a {...} expression, got %s" % JSON.stringify(value))
		return 0
	for key in value:
		if key not in Vocab.EXPR_KEYS:
			_e(scope, "%s.%s" % [path, key], "unknown expression key %s" % key)
			return 0
	if value.has("param"):
		return _resolve_number(value, scope.card, scope.id, path, scope.report)
	if value.has("count"):
		return {"count": _set_of(value.count, path + ".count", scope)}
	if value.has("sum"):
		_stat_read(str(value.get("stat", "")), path, scope, true)
		return {"sum": _set_of(value.sum, path + ".sum", scope), "stat": str(value.get("stat", ""))}
	if value.has("stat"):
		_stat_read(str(value.stat), path, scope, false)
		return {"stat": str(value.stat), "of": _one(value.get("of", "$self"), path + ".of", scope)}
	if value.has("charges"):
		return {"charges": _one(value.charges, path + ".charges", scope)}
	if value.has("card_counter"):
		if str(value.get("counter", "charges")) != "charges":
			_e(scope, path, "the only card counter is charges")
		return {"card_counter": _ref(value.card_counter, path + ".card_counter", scope), "counter": "charges"}
	if value.has("gold"):
		if str(value.gold) not in ["you", "opponent"]:
			_e(scope, path, "gold reads you or opponent")
		return {"gold": str(value.gold)}
	if value.has("price"):
		return {"price": _one(value.price, path + ".price", scope)}
	if value.has("half"):
		return {"half": _expr(value.half, path + ".half", scope)}
	if value.has("neg"):
		return {"neg": _expr(value.neg, path + ".neg", scope)}
	for key in ["add", "sub", "mul", "min", "max"]:
		if value.has(key):
			var items = value[key]
			if not items is Array or items.size() < (2 if key in ["sub", "mul"] else 1):
				_e(scope, path + "." + key, "%s takes a list" % key)
				return 0
			if key in ["sub", "mul"] and items.size() != 2:
				_e(scope, path + "." + key, "%s takes two values" % key)
			var compiled: Array = []
			for index in range(items.size()):
				compiled.append(_expr(items[index], "%s.%s[%d]" % [path, key, index], scope))
			return {key: compiled}
	_e(scope, path, "unsupported expression")
	return 0

## Aura layering (rule 6): stat grants may not read derived stats; keyword
## grants may read attack, armor and max_health but no keyword; an aura `if`
## reads no stats at all.
static func _stat_read(stat: String, path: String, scope: Dictionary, is_sum: bool) -> void:
	if stat not in Vocab.UNIT_READS and stat not in Vocab.TOWER_READS:
		_e(scope, path, "unknown stat %s" % stat)
	match str(scope.get("aura", "")):
		"stat":
			_e(scope, path, "a stat aura may not read derived stats")
		"keyword":
			if stat not in ["attack", "armor", "max_health"]:
				_e(scope, path, "a keyword aura may read only attack, armor and max_health")
		"if":
			_e(scope, path, "an aura condition may not read stats")

static func _resolve_number(value, card: Dictionary, id: String, path: String, report: Dictionary) -> int:
	if value is int:
		return value
	if value is Dictionary and value.has("param"):
		var name = str(value.param)
		var resolved = card.get(name)
		if resolved is float and resolved == floor(resolved):
			resolved = int(resolved)
		if not resolved is int or resolved is bool:
			_err(report, id, path, "param %s is not a top-level whole number of %s" % [name, id])
			return 0
		return resolved
	_err(report, id, path, "expected a whole number or a param")
	return 0

static func _cond(value, path: String, scope: Dictionary) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		_e(scope, path, "a condition is an object")
		return {}
	for key in value:
		if key not in Vocab.COND_KEYS:
			_e(scope, "%s.%s" % [path, key], "unknown condition key %s" % key)
			return {}
	if value.has("all") or value.has("any"):
		var key = "all" if value.has("all") else "any"
		var items: Array = []
		if not value[key] is Array:
			_e(scope, path, "%s takes a list" % key)
			return {}
		for index in range(value[key].size()):
			items.append(_cond(value[key][index], "%s.%s[%d]" % [path, key, index], scope))
		return {key: items}
	if value.has("not"):
		return {"not": _cond(value["not"], path + ".not", scope)}
	if value.has("cmp"):
		var parts = value.cmp
		if not parts is Array or parts.size() != 3 or str(parts[1]) not in Vocab.CMP_OPS:
			_e(scope, path + ".cmp", "cmp is [a, op, b] with op in %s" % [Vocab.CMP_OPS])
			return {}
		return {"cmp": [_expr(parts[0], path + ".cmp[0]", scope), str(parts[1]), _expr(parts[2], path + ".cmp[2]", scope)]}
	if value.has("is"):
		if not value.has("in"):
			_e(scope, path, "is needs in")
		var target = value.get("in", [])
		var compiled_in = _ref(target, path + ".in", scope) if target is String and str(target).begins_with("$e.") else _set_of(target, path + ".in", scope)
		return {"is": _one(value["is"], path + ".is", scope), "in": compiled_in}
	if value.has("has"):
		return {"has": _set_of(value.has, path + ".has", scope)}
	if value.has("empty"):
		return {"empty": _set_of(value.empty, path + ".empty", scope)}
	if value.has("in_play"):
		return {"in_play": _one(value.in_play, path + ".in_play", scope)}
	if value.has("unblocked"):
		return {"unblocked": _one(value.unblocked, path + ".unblocked", scope)}
	if value.has("damaged"):
		if str(scope.get("aura", "")) == "if":
			_e(scope, path, "an aura condition may not use damaged")
		return {"damaged": _one(value.damaged, path + ".damaged", scope)}
	if value.has("flag"):
		var parts = value.flag
		if not parts is Array or parts.size() != 2 or str(parts[1]) not in Vocab.KEYWORDS:
			_e(scope, path + ".flag", "flag is [ref, keyword]")
			return {}
		return {"flag": [_one(parts[0], path + ".flag[0]", scope), str(parts[1])]}
	if value.has("log"):
		match str(value.log):
			"tower_hit":
				return {"log": "tower_hit", "tower": _set_of(value.get("tower", "both_towers"), path + ".tower", scope)}
			"hit":
				var kind = str(value.get("kind", "creep"))
				if kind not in ["creep", "hero", "tower"]:
					_e(scope, path + ".kind", "hit kind is creep, hero or tower")
				return {"log": "hit", "by": _one(value.get("by", "$self"), path + ".by", scope), "kind": kind}
		_e(scope, path + ".log", "log is tower_hit or hit")
		return {}
	if value.has("active_lane"):
		if str(value.active_lane) != "self":
			_e(scope, path, "active_lane is self")
		return {"active_lane": "self"}
	_e(scope, path, "unsupported condition")
	return {}

# --- Static analysis ------------------------------------------------------------

## The bot's static values of an op list: constant draws for "you" (spec §9.2).
static func _static_value(ops: Array) -> Dictionary:
	var draw = 0
	for op in ops:
		if str(op.get("op", "")) == "draw" and str(op.get("player", "you")) == "you" and op.get("n") is int:
			draw += int(op.n)
	return {"draw": draw, "initiative": false, "random": false, "bias": 0.0}

static func _has_random(value) -> bool:
	if value is Dictionary:
		if value.has("pick") or str(value.get("op", "")) == "chance" or value.has("from_pool") \
				or str(value.get("lane", "")) == "random_other":
			return true
		for key in value:
			if _has_random(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _has_random(item):
				return true
	return false

## Every op name used anywhere in the compiled card.
static func _collect_uses(value, uses: Dictionary) -> void:
	if value is Dictionary:
		if value.has("op") and value.op is String:
			uses[value.op] = true
		for key in value:
			if key != "uses":
				_collect_uses(value[key], uses)
	elif value is Array:
		for item in value:
			_collect_uses(item, uses)
