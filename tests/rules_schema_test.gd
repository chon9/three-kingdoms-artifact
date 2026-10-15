extends SceneTree
## Rules meta tests (EFFECT_SYSTEM_SPEC.md §3.14, §10.2, §13.7):
## * every card entry of both packs, and the schema-4 drafts of all 303
##   Classic cards (tests/data/classic_rules_drafts.json), compile with zero
##   errors; the validator rejects each kind of mistake with a JSON path;
## * the vocabulary is closed: every op, event, filter key, keyword, rules key
##   and shorthand in rules/vocab.gd is implemented, and nothing else is;
## * RULES_VERSION matches the rules code and data (tools/rules_hash.py);
## * the rules scripts are static-only and touch randomness only through
##   Kernel.rand_index / Kernel.chance (D1);
## * presets hold only verified, non-token cards; every RQ a card names is in
##   docs/RULES.md; Valve parity (cooldowns, charges, Pulse markers, Get
##   initiative, randomness, verb and trigger tags through tools/coverage.py)
##   against tests/data/mechanics_tags.json;
## * every verified Classic card has a spec in tests/cards/ whose text is its
##   valve_text and whose covers hold its mechanics tags, with a positive and
##   a negative or edge case per Valve clause (§13.7 items 5 to 7).

const Library = preload("res://scripts/core/card_library.gd")
const RulesDB = preload("res://scripts/core/rules/rules_db.gd")
const Vocab = preload("res://scripts/core/rules/vocab.gd")
const RulesVersion = preload("res://scripts/core/rules/rules_version.gd")
const RULES_DIR = "res://scripts/core/rules"
const HASH_EXTRA = ["scripts/core/match_engine.gd", "scripts/core/card_library.gd",
	"data/classic_cards.json", "data/training_cards.json"]
const DRAFTS = "res://tests/data/classic_rules_drafts.json"
const TAGS = "res://tests/data/mechanics_tags.json"
const RULES_DOC = "res://docs/RULES.md"
const COVERAGE = "res://tests/data/coverage.json"
const CARDS_DIR = "res://tests/cards"
const NEGATIVE_TAGS = ["negative", "edge"]
var checks = 0
var failures: Array = []

func _initialize() -> void:
	_lint_rules_scripts()
	_rules_version()
	_packs_compile()
	_drafts_compile()
	_validator_rejects()
	_validator_messages()
	_pack_links()
	_vocabulary_closed()
	_presets_and_rqs()
	_valve_parity()
	_card_specs()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d rules meta checks (schema, vocabulary, RULES_VERSION, lint, presets, RQs, Valve parity)." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _rules_files() -> Array:
	var files: Array = []
	for name in DirAccess.get_files_at(RULES_DIR):
		if name.ends_with(".gd"):
			files.append("%s/%s" % [RULES_DIR, name])
	files.sort()
	return files

func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r", "")

## Rules scripts hold no instance or static members (spec §1.2, K8) and use
## no randomness, clock, OS or hash except Kernel.rand_index / chance (D1).
func _lint_rules_scripts() -> void:
	var files = _rules_files()
	_check(files.size() >= 11, "Rules scripts exist (%d)" % files.size())
	var forbidden = RegEx.create_from_string("\\b(randf|randf_range|randi|randomize|pick_random|hash)\\s*\\(|\\bTime\\.|\\bOS\\.")
	var shuffles = RegEx.create_from_string("([A-Za-z_][A-Za-z0-9_]*)\\.shuffle\\(")
	for path in files:
		var number = 0
		var members: Array = []
		var calls: Array = []
		for line in _source(path).split("\n"):
			number += 1
			for prefix in ["var ", "static var ", "signal ", "@onready", "@export", "func "]:
				if line.begins_with(prefix):
					members.append("%d: %s" % [number, line.strip_edges()])
			var code = line.split("#")[0] if not line.strip_edges().begins_with("##") else ""
			if forbidden.search(code) != null:
				calls.append("%d: %s" % [number, line.strip_edges()])
			for found in shuffles.search_all(code):
				if found.get_string(1) != "Kernel":
					calls.append("%d: %s" % [number, line.strip_edges()])
			if code.find("randi_range(") != -1 and not (path.ends_with("kernel.gd") and (code.find("return e.rng.randi_range(0, count - 1)") != -1 or code.find("return e.rng.randi_range(0, 99) < percent") != -1)):
				calls.append("%d: %s" % [number, line.strip_edges()])
		_check(members.is_empty(), "%s declares no instance or static members: %s" % [path, members])
		_check(calls.is_empty(), "%s draws randomness only through Kernel.rand_index / chance and reads no clock, OS or hash: %s" % [path, calls])

## RULES_VERSION is the first 12 hex digits of SHA-256 over the rules code
## and data, exactly as tools/rules_hash.py computes it.
func _rules_version() -> void:
	var files: Array = []
	for path in _rules_files():
		var relative = str(path).trim_prefix("res://")
		if relative != "scripts/core/rules/rules_version.gd":
			files.append(relative)
	files.append_array(HASH_EXTRA)
	files.sort()
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path in files:
		context.update((str(path) + "\n").to_utf8_buffer())
		context.update(_source("res://" + str(path)).to_utf8_buffer())
	var full = context.finish().hex_encode()
	_check(full.substr(0, 12) == RulesVersion.RULES_VERSION and full == RulesVersion.CODE_HASH,
		"RULES_VERSION %s is current (computed %s); run python tools/rules_hash.py" % [RulesVersion.RULES_VERSION, full.substr(0, 12)])
	_check(Array(RulesVersion.FILES) == files, "RULES_VERSION covers the rules code and data files")

func _packs_compile() -> void:
	for pack in Library.PACKS:
		var library = Library.new(pack)
		_check(library.errors.is_empty(), "Pack %s compiles without errors: %s" % [pack, library.errors.slice(0, 5)])
		_check(library.warnings.is_empty(), "Pack %s compiles without warnings: %s" % [pack, library.warnings.slice(0, 5)])
		var schema = int(library.catalog.get("schema_version", 0))
		_check(schema == (Vocab.SCHEMA_CLASSIC if pack == "artifact_classic_decks_v2" else Vocab.SCHEMA_TRAINING), "Pack %s is at its schema-4 version (%d)" % [pack, schema])
		for card_id in library.compiled:
			var rules: Dictionary = library.compiled[card_id]
			# Spec §12 M3-M7: verified, or a draft that names the RQ keeping it
			# one. Drafts compile and can be tested, but never enter a deck.
			var verified = str(rules.status) == "verified"
			_check(verified or (str(rules.status) == "draft" and not rules.get("rq", []).is_empty()),
				"Shipped card %s is verified, or a draft that names its RQ in rq (status %s)" % [card_id, rules.status])

## The schema-4 drafts of every counted Classic card validate (spec C.2).
func _drafts_compile() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DRAFTS))
	_check(parsed is Dictionary and parsed.get("cards") is Array, "The Classic rules drafts parse")
	if not parsed is Dictionary:
		return
	var cards: Array = parsed.cards
	_check(cards.size() == 303, "Drafts cover all 303 counted Classic cards (%d)" % cards.size())
	var bad: Array = []
	var ids: Dictionary = {}
	for card in cards:
		var rules = RulesDB.compile(card)
		ids[str(card.id)] = true
		if not rules.errors.is_empty():
			bad.append(rules.errors.slice(0, 3))
		if str(card.get("status", "")) != "draft":
			bad.append("%s is not a draft" % card.id)
	_check(bad.is_empty(), "Every Classic draft compiles without errors (%d bad): %s" % [bad.size(), bad.slice(0, 6)])
	_check(ids.size() == cards.size(), "Draft ids are unique")
	var shipped = Library.new("artifact_classic_decks_v2")
	for card_id in shipped.compiled:
		_check(ids.has(card_id), "Shipped card %s has a draft" % card_id)

## The validator names the card, the JSON path and the problem.
func _validator_rejects() -> void:
	var spell = {"id": "bad", "kind": "spell", "color": "blue", "cost": 1, "status": "draft"}
	var creep = {"id": "bad", "kind": "creep", "color": "blue", "cost": 1, "attack": 1, "health": 1, "status": "draft"}
	var cases = [
		[_with(spell, {"play": {"ops": [{"op": "explode"}]}}), "unknown op"],
		[_with(spell, {"play": {"ops": [{"op": "draw", "player": "you", "n": 1, "colour": 1}]}}), "unknown field"],
		[_with(spell, {"play": {"ops": [{"op": "damage", "to": "$c.target", "amount": 1}]}}), "not declared"],
		[_with(spell, {"play": {"ops": [{"op": "damage", "to": "$v.who", "amount": 1}]}}), "not bound"],
		[_with(spell, {"play": {"ops": [{"op": "damage", "to": "$self", "amount": 1}]}}), "$self is not available"],
		[_with(spell, {"play": {"ops": [{"op": "damage", "to": "allied_neighbors", "amount": 1}]}}), "$host is not available"],
		[_with(spell, {"amount": 2.5, "play": {"ops": []}}), "fraction"],
		[_with(spell, {"play": {"ops": [{"op": "draw", "player": "you", "n": {"param": "missing"}}]}}), "param missing"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "aura", "affects": {"use": "allies", "pick": {"random": 1}}, "grant": {"attack": 1}}]}), "randomness is not allowed"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "aura", "affects": "allies", "grant": {"stun": 1}}]}), "may not grant stun"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "aura", "affects": "allies", "grant": {"health": 2}}]}), "use max_health"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "aura", "affects": "allies", "grant": {"attack": {"stat": "armor", "of": "$self"}}}]}), "may not read derived stats"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "active", "cooldown": 0, "ops": []}]}), "cooldown >= 1"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "trigger", "on": "card_played", "filter": {"role": "dealer"}, "ops": []}]}), "not valid for card_played"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "trigger", "on": "after_combat", "ops": [{"op": "damage", "to": "$e.unit", "amount": 1}]}]}), "is not a field of after_combat"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "trigger", "on": "sunrise", "ops": []}]}), "unknown event"],
		[_with(creep, {"abilities": [{"id": "a", "kind": "aura", "affects": "allies", "grant": {"attack": 1}}, {"id": "a", "kind": "aura", "affects": "allies", "grant": {"armor": 1}}]}), "duplicate ability id"],
		[_with(spell, {"play": {"ops": [{"op": "give", "to": "allies", "keywords": {"silence": 1}, "until": "forever"}]}}), "until is one of"],
		[_with(spell, {"play": {"ops": [{"op": "give", "to": "allies", "keywords": {"decay": 1}, "until": "round"}]}}), "reserved keyword decay"],
		[_with(spell, {"play": {"ops": [{"op": "give", "to": "allies", "keywords": {"flying": 1}, "until": "round"}]}}), "unknown keyword flying"],
		[_with(spell, {"play": {"ops": [{"op": "condemn", "to": {"s": "units", "colour": "red"}}]}}), "unknown selector key"],
		[_with(spell, {"play": {"choices": [{"key": "lane", "from": "units"}], "ops": []}}), "does not match"],
		[_with(spell, {"play": {"ops": [{"op": "condemn", "to": {"s": "units", "where": {"in_play": "$it"}}}, {"op": "condemn", "to": "$it"}]}}), "only available inside where"],
		[_with(spell, {"play": {"ops": [{"op": "modify", "to": "allies", "grant": 3}]}}), "does not index"],
		[_with(spell, {"play": {"ops": [{"op": "battle", "a": {"use": "allies", "pick": {"random": 2}}, "b": "enemies"}]}}), "single-object field"],
		[_with(spell, {"play": {"ops": [{"op": "swap", "a": "$v.x", "b": "$v.y"}]}}), "variable $v.x is not bound"],
		[_with(spell, {"play": {"ops": [{"op": "swap", "a": {"use": "allies", "pick": {"random": 1}}}]}}), "swap needs b"],
		[_with(spell, {"play": {"ops": [{"op": "add_card", "player": "you"}]}}), "add_card names either a card or from_pool"],
		[_with(spell, {"play": {"ops": [{"op": "give", "to": "your_hand", "stats": {"attack": 1}, "until": "round"}]}}), "cards in hand only take a hack"],
		[_with(spell, {"grants": [{"kind": "hack", "ops": []}], "play": {"ops": [{"op": "modify", "to": "allies", "grant": 0}]}}), "a hack is attached to cards in hand"],
		[_with(spell, {"play": {"ops": [{"op": "move", "unit": {"use": "allies", "pick": {"random": 1}}, "lane": "sideways"}]}}), "unknown selector sideways"],
		[_with(spell, {"effect": "damage", "play": {"ops": []}}), "legacy field effect"],
		[_with(spell, {"status": "done", "play": {"ops": []}}), "status must be verified or draft"],
		[_with(spell, {"play": {"ops": [{"op": "native", "fn": "mystery"}]}}), "no native handler"],
		# Required op fields: a card that compiles never crashes at play time.
		[_with(spell, {"play": {"ops": [{"op": "damage", "amount": 3}]}}), "damage needs to"],
		[_with(spell, {"play": {"ops": [{"op": "heal", "amount": 3}]}}), "heal needs to"],
		[_with(spell, {"play": {"ops": [{"op": "damage", "to": "enemies"}]}}), "damage needs amount"],
		[_with(spell, {"play": {"ops": [{"op": "retarget", "to": 0}]}}), "retarget needs unit"],
		[_with(spell, {"play": {"ops": [{"op": "if", "then": [{"op": "draw"}]}]}}), "if needs cond"],
		[_with(spell, {"play": {"ops": [{"op": "chance", "then": [{"op": "draw"}]}]}}), "chance needs pct"],
		[_with(spell, {"play": {"ops": [{"op": "battle", "b": "enemies"}]}}), "battle needs a"],
		[_with(spell, {"play": {"ops": [{"op": "mana", "to": "your_tower"}]}}), "mana needs restore"],
		[_with(spell, {"play": {"ops": [{"op": "give", "to": "allies", "stats": {"attack": 1}}]}}), "give needs until"],
		# Randomness is never allowed in a condition, an op's included.
		[_with(spell, {"play": {"ops": [{"op": "if", "cond": {"has": {"s": "units", "pick": {"random": 1}}}}]}}), "randomness is not allowed"],
		[_with(spell, {"play": {"ops": [{"op": "if", "cond": {"cmp": [{"count": {"use": "enemies", "pick": {"random": 1}}}, ">", 0]}}]}}), "randomness is not allowed"],
		# Units need printed stats.
		[_without(creep, "attack"), "a creep needs attack"],
		[_without(creep, "health"), "a creep needs health"],
		[_with(spell, {"play": {"ops": [{"op": "damage", "to": "enemies", "amount": "3"}]}}), "expected a number, a ref or a {...} expression, got string \"3\""],
	]
	for entry in cases:
		var errors = RulesDB.compile(entry[0]).errors
		var found = errors.any(func(error): return str(error).find(entry[1]) != -1 and str(error).begins_with("bad."))
		_check(found, "The validator reports \"%s\" with a card path: %s" % [entry[1], errors])

## Messages are precise and reported once.
func _validator_messages() -> void:
	var spell = {"id": "bad", "kind": "spell", "color": "blue", "cost": 1, "status": "draft"}
	var errors = RulesDB.compile(_with(spell, {"play": {"ops": [{"op": "damage", "to": "enemies", "amount": 1, "too": 2}]}})).errors
	_check(errors.size() == 1 and str(errors[0]).find("unknown field too of damage") != -1,
		"An unknown op field is reported exactly once: %s" % [errors])
	var clean = RulesDB.compile(_with(spell, {"play": {"ops": [{"op": "if", "cond": {"empty": "enemies"}, "then": [{"op": "draw"}]},
		{"op": "chance", "pct": 50, "then": [{"op": "damage", "to": {"use": "enemies", "pick": {"random": 1}}, "amount": 1}]}]}}))
	_check(clean.errors.is_empty(), "A plain condition and randomness inside chance compile: %s" % [clean.errors])

## Pack-level links (CardLibrary._check_links): summons name a unit of the
## pack, signatures exist, and an unread parameter is a warning (a typo).
func _pack_links() -> void:
	var base = {"kind": "spell", "color": "green", "cost": 1, "status": "draft", "rq": ["RQ-15"]}
	var summon_typo = _with(base, {"id": "fx_bad_summon", "play": {"ops": [{"op": "summon", "card": "melee_crep"}]}})
	var summon_spell = _with(base, {"id": "fx_summon_spell", "play": {"ops": [{"op": "summon", "card": "gust"}]}})
	var summon_ok = _with(base, {"id": "fx_summon_ok", "play": {"ops": [{"op": "summon", "card": "melee_creep"}]}})
	var hero = {"id": "fx_hero", "kind": "hero", "color": "red", "attack": 1, "health": 5, "status": "draft",
		"rq": ["RQ-15"], "signature": "no_such_card"}
	var typo = {"id": "fx_typo", "kind": "creep", "color": "red", "cost": 1, "health": 1, "atack": 2,
		"status": "draft", "rq": ["RQ-15"]}
	var used = _with(base, {"id": "fx_used", "amount": 2, "play": {"ops": [{"op": "draw", "n": {"param": "amount"}}]}})
	var library = Library.with_cards("artifact_classic_decks_v2", [summon_typo, summon_spell, summon_ok, hero, typo, used])
	_check(not library.playable("fx_bad_summon") and library.errors.any(func(error): return str(error).begins_with("fx_bad_summon.summon") and str(error).find("melee_crep") != -1),
		"Summoning an unknown card is a compile error: %s" % [library.compiled.fx_bad_summon.errors])
	_check(not library.playable("fx_summon_spell"), "Summoning a card that is not a unit is a compile error")
	_check(library.playable("fx_summon_ok"), "Summoning a pack creep compiles: %s" % [library.compiled.fx_summon_ok.errors])
	_check(not library.playable("fx_hero") and library.errors.any(func(error): return str(error).begins_with("fx_hero.signature")),
		"A hero whose signature is not in the pack is a compile error")
	_check(not library.playable("fx_typo") and library.compiled.fx_typo.warnings.any(func(error): return str(error).find("parameter atack") != -1),
		"A misspelled stat fails (no attack) and its parameter is flagged as unread: %s / %s" % [library.compiled.fx_typo.errors, library.compiled.fx_typo.warnings])
	_check(library.compiled.fx_used.warnings.is_empty(), "A parameter read with {param} raises no warning: %s" % [library.compiled.fx_used.warnings])
	_check(Library.new("artifact_classic_decks_v2").errors.is_empty(), "with_cards leaves the shared pack untouched")

func _without(base: Dictionary, key: String) -> Dictionary:
	var out = base.duplicate(true)
	out.erase(key)
	return out

func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out = base.duplicate(true)
	out.merge(extra, true)
	return out

## Every word in the vocabulary is implemented, and the VM implements nothing
## outside it.
func _vocabulary_closed() -> void:
	var vm = _source(RULES_DIR + "/vm.gd")
	var arms = RegEx.create_from_string("(?m)^\\t\\t((?:\"[a-z_]+\", )*\"[a-z_]+\"):$")
	var handled: Dictionary = {}
	var in_op = false
	for line in vm.split("\n"):
		if line.begins_with("static func _op("):
			in_op = true
			continue
		if in_op and line.begins_with("static func "):
			break
		if in_op:
			var found = arms.search(line)
			if found != null:
				for name in found.get_string(1).replace("\"", "").split(", "):
					handled[name] = true
	for op_name in Vocab.OPS:
		_check(handled.has(op_name), "The VM implements op %s" % op_name)
	for op_name in handled:
		_check(Vocab.OPS.has(op_name), "VM op %s is in the vocabulary" % op_name)
	var sources = ""
	for path in _rules_files():
		sources += _source(path)
	sources += _source("res://scripts/core/match_engine.gd")
	for event in Vocab.EVENTS:
		var emitted = sources.find("emit(e, \"%s\"" % event) != -1 or sources.find("emit(self, \"%s\"" % event) != -1
		_check(emitted, "Event %s is emitted by the engine" % event)
	var kernel = _source(RULES_DIR + "/kernel.gd")
	for event in Vocab.FILTERS:
		for key in Vocab.FILTERS[event]:
			_check(kernel.find("\"%s\":" % key) != -1, "Filter key %s is evaluated" % key)
	var engine_sources = ""
	for name in ["combat.gd", "kernel.gd", "stats.gd", "zones.gd", "select.gd", "vm.gd"]:
		engine_sources += _source(RULES_DIR + "/" + name)
	engine_sources += _source("res://scripts/core/match_engine.gd")
	for keyword in Vocab.KEYWORDS:
		_check(engine_sources.find("\"%s\"" % keyword) != -1, "Keyword %s has rules behaviour" % keyword)
	var stats = _source(RULES_DIR + "/stats.gd")
	for key in Vocab.RULES_KEYS:
		_check(stats.find(key) != -1, "Rules key %s is folded by Stats.rules_of" % key)
	for shorthand in Vocab.SHORTHANDS:
		var card = {"id": "probe", "kind": "creep", "color": "red", "cost": 1, "attack": 1, "health": 1, "status": "draft",
			"abilities": [{"id": "probe", "kind": "trigger", "on": "after_combat",
				"ops": [{"op": "gold", "player": "you", "add": {"count": shorthand}}]}]}
		_check(RulesDB.compile(card).errors.is_empty(), "Shorthand %s expands to a valid selector" % shorthand)

## Presets hold verified, non-token cards only; every RQ in the data is
## documented.
func _presets_and_rqs() -> void:
	var library = Library.new()
	for preset in library.presets():
		var ids: Array = preset.heroes.duplicate()
		ids.append_array(preset.cards.keys())
		ids.append_array(preset.items.keys())
		for card_id in ids:
			var rules = library.rules(str(card_id))
			_check(str(rules.status) == "verified" and not bool(rules.get("token", false)), "Preset %s card %s is verified and not a token" % [preset.id, card_id])
		_check(library.validate_preset(preset).ok, "Preset %s validates" % preset.id)
		# A signature card comes with its hero: a preset holds one only with that hero.
		var own: Array = preset.heroes.map(func(hero_id): return str(library.definition(str(hero_id)).get("signature", "")))
		for hero in library.heroes:
			var signature = str(hero.get("signature", ""))
			_check(not preset.cards.has(signature) or signature in own, "Preset %s holds %s only with its hero" % [preset.id, signature])
	var token_deck = library.preset("starter").duplicate(true)
	token_deck.cards["melee_creep"] = 1
	_check(not library.validate_preset(token_deck).ok, "A token can never enter a deck (K13)")
	var doc = FileAccess.get_file_as_string(RULES_DOC)
	for pack in Library.PACKS:
		var pack_library = Library.new(pack)
		for card_id in pack_library.compiled:
			for rq in pack_library.compiled[card_id].get("rq", []):
				_check(doc.find(str(rq)) != -1, "%s's %s is documented in docs/RULES.md" % [card_id, rq])

## Valve parity (CF-12) for every shipped card and every draft with Valve data.
func _valve_parity() -> void:
	var tags = JSON.parse_string(FileAccess.get_file_as_string(TAGS))
	_check(tags is Dictionary and tags.get("cards") is Array, "mechanics_tags.json parses")
	if not tags is Dictionary:
		return
	var valve: Dictionary = {}
	var children: Dictionary = {}
	for entry in tags.cards:
		valve[int(entry.source_id)] = entry
		if entry.has("parent"):
			if not children.has(int(entry.parent)):
				children[int(entry.parent)] = []
			children[int(entry.parent)].append(entry)
	var shipped = Library.new("artifact_classic_decks_v2")
	var entries: Array = []
	for card_id in shipped.compiled:
		entries.append(shipped.definition(card_id))
	var drafts = JSON.parse_string(FileAccess.get_file_as_string(DRAFTS))
	if drafts is Dictionary:
		entries.append_array(drafts.cards)
	var problems: Array = []
	var coverage = _coverage()
	var parity_cards = 0
	var seen_sources: Dictionary = {}
	for card in entries:
		var source_id = int(card.get("source_id", 0))
		if not valve.has(source_id):
			continue
		seen_sources[source_id] = true
		var tag: Dictionary = valve[source_id]
		var rules = RulesDB.compile(card)
		var where = "%s (%s)" % [card.id, card.get("status", "")]
		var cooldowns: Array = []
		for ability in rules.abilities:
			if str(ability.kind) == "active":
				cooldowns.append(int(ability.cooldown))
		cooldowns.sort()
		# One cooldown per Valve active ability card, else "Active N" in the text.
		var want: Array = []
		for child in children.get(source_id, []):
			if str(child.get("type", "")) == "Ability" and not child.get("cooldowns", []).is_empty():
				want.append(int(child.cooldowns[0]))
		if want.is_empty():
			for found in RegEx.create_from_string("Active (\\d+)").search_all(str(tag.get("text", ""))):
				want.append(int(found.get_string(1)))
		want.sort()
		if cooldowns != want:
			problems.append("%s: active cooldowns %s, Valve %s" % [where, cooldowns, want])
		if tag.has("charges") and int(rules.params.get("charges", -1)) != int(tag.charges):
			problems.append("%s: charges %s, Valve %d" % [where, rules.params.get("charges", "none"), int(tag.charges)])
		var pulses = _count_ops(card, "pulse")
		if pulses != int(tag.get("pulses", 0)):
			problems.append("%s: %d pulse ops, Valve %d markers" % [where, pulses, int(tag.pulses)])
		if bool(rules.get("play", {}).get("initiative", false)) != bool(tag.get("get_initiative", false)):
			problems.append("%s: Get initiative differs from Valve" % where)
		var random = bool(rules.static.random) or JSON.stringify(card).find("creep_lane") != -1
		if bool(tag.get("random", false)) and not random:
			problems.append("%s: Valve text is random but the rules draw no randomness" % where)
		# The last bullet of item 10: every verb and trigger tag maps to an
		# op, keyword, rules key, listener or block (tools/coverage.py's tables).
		if not coverage.is_empty():
			var known = _facts(card)
			var text = JSON.stringify(card)
			for verb in tag.get("verbs", []):
				if not coverage.verbs.has(verb) or not _holds(coverage.verbs[verb], card, known, text):
					problems.append("%s: verb tag %s maps to nothing in the rules" % [where, verb])
			for trigger in tag.get("triggers", []):
				if not coverage.triggers.has(trigger) or not _holds(coverage.triggers[trigger], card, known, text):
					problems.append("%s: trigger tag %s maps to nothing in the rules" % [where, trigger])
	parity_cards = seen_sources.size()
	_check(not coverage.is_empty(), "tests/data/coverage.json (tools/coverage.py) parses")
	_check(parity_cards >= 303, "Valve parity covers every counted card (%d)" % parity_cards)
	_check(problems.is_empty(), "Valve parity (cooldowns, charges, Pulse markers, initiative, randomness, verb and trigger tags): %s" % [problems.slice(0, 8)])

## tools/coverage.py's tables, checked to be current against the script.
func _coverage() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(COVERAGE))
	if not parsed is Dictionary:
		return {}
	var script = FileAccess.get_file_as_string("res://tools/coverage.py").replace("\r", "")
	var digest = script.sha256_text()
	_check(str(parsed.get("source_sha256", "")) == digest, "tests/data/coverage.json is current; run python tools/coverage.py")
	_check(int(parsed.get("summary", {}).get("passing", 0)) == int(parsed.get("summary", {}).get("cards", -1)) and int(parsed.summary.cards) == 303,
		"tools/coverage.py reports every counted card passing: %s" % [parsed.get("summary", {})])
	return parsed

## What a raw card entry uses (tools/coverage.py facts()).
func _facts(entry: Dictionary) -> Dictionary:
	var out = {"ops": {}, "keywords": {}, "rules": {}, "kinds": {}, "events": {}, "blocks": {}, "fields": {}}
	_collect_facts(entry, out)
	for block in ["play", "enter"]:
		if entry.has(block):
			out.blocks[block] = true
	for field in ["grants", "keywords"]:
		if entry.get(field) is Array and not entry[field].is_empty() or entry.get(field) is Dictionary and not entry[field].is_empty():
			out.fields[field] = true
	return out

func _collect_facts(value, out: Dictionary) -> void:
	if value is Array:
		for item in value:
			_collect_facts(item, out)
		return
	if not value is Dictionary:
		return
	if value.has("op"):
		out.ops[str(value.op)] = true
	if value.get("keywords") is Dictionary:
		for key in value.keywords:
			out.keywords[str(key)] = true
	if value.get("grant") is Dictionary:
		for key in value.grant:
			if str(key) != "rules":
				out.keywords[str(key)] = true
		if value.grant.get("rules") is Dictionary:
			for key in value.grant.rules:
				out.rules[str(key)] = true
	if str(value.get("kind", "")) in ["aura", "trigger", "active", "hack"] and (value.has("ops") or value.has("grant")):
		out.kinds[str(value.kind)] = true
	if str(value.get("kind", "")) == "trigger" and value.has("on"):
		out.events[str(value.on)] = true
	for key in value:
		_collect_facts(value[key], out)

func _holds(rule: Dictionary, entry: Dictionary, known: Dictionary, text: String) -> bool:
	if rule.is_empty():
		return true
	if bool(rule.get("initiative", false)) and entry.get("play", {}) is Dictionary and bool(entry.get("play", {}).get("initiative", false)):
		return true
	for key in ["ops", "keywords", "rules", "kinds", "events", "blocks", "fields"]:
		for value in rule.get(key, []):
			if known[key].has(str(value)):
				return true
	for fragment in rule.get("text", []):
		if text.find(str(fragment).replace(": ", ":")) != -1:
			return true
	return false

## §13.7 items 5 to 7 and the coverage gate (K14) over tests/cards/<id>.json:
## every verified Classic card has a spec, its text equals the card's
## valve_text, its covers contain every mechanics tag of the card (and every
## covered tag is exercised by a case), and every Valve clause has a positive
## case and a negative or edge case. tests/card_specs_test.gd runs the cases.

func _card_specs() -> void:
	var specs: Dictionary = {}
	var names: Array = Array(DirAccess.get_files_at(CARDS_DIR)).filter(func(name): return str(name).ends_with(".json"))
	for name in names:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [CARDS_DIR, name]))
		_check(parsed is Dictionary and str(parsed.get("card", "")) + ".json" == str(name), "Spec %s parses and is named after its card" % name)
		if parsed is Dictionary:
			specs[str(parsed.get("card", ""))] = parsed
	var library = Library.new()
	var tags = JSON.parse_string(FileAccess.get_file_as_string(TAGS))
	var by_source: Dictionary = {}
	for entry in tags.cards:
		by_source[int(entry.source_id)] = entry
	var verified = 0
	for card_id in library.compiled:
		var rules: Dictionary = library.compiled[card_id]
		if str(rules.status) != "verified":
			continue
		verified += 1
		var definition = library.definition(card_id)
		_check(specs.has(card_id), "meta_5: verified card %s has a spec (tests/cards/%s.json)" % [card_id, card_id])
		if not specs.has(card_id):
			continue
		var spec: Dictionary = specs[card_id]
		_check(int(spec.get("source_id", -1)) == int(definition.get("source_id", -2)), "Spec %s names the card's source_id" % card_id)
		_check(str(spec.get("text", "")) == str(definition.get("valve_text", "")), "meta_6: spec %s text equals valve_text" % card_id)
		var tag: Dictionary = by_source.get(int(definition.get("source_id", 0)), {})
		_check(not tag.is_empty(), "%s has mechanics tags" % card_id)
		var wanted: Array = []
		for key in ["triggers", "verbs", "targets", "durations"]:
			for value in tag.get(key, []):
				if value not in wanted:
					wanted.append(value)
		var covers: Array = spec.get("covers", [])
		var missing = wanted.filter(func(value): return value not in covers)
		_check(missing.is_empty(), "meta_7: spec %s covers every mechanics tag (missing %s)" % [card_id, missing])
		var case_tags: Array = []
		for entry in spec.get("cases", []):
			case_tags.append_array(entry.get("tags", []))
		var untested = covers.filter(func(value): return value not in case_tags)
		_check(untested.is_empty(), "Every tag spec %s covers is exercised by a case (missing %s)" % [card_id, untested])
		# The coverage gate: a positive and a negative or edge case per clause.
		for clause in range(tag.get("clauses", []).size()):
			var positive = spec.cases.any(func(entry): return int(entry.get("clause", -1)) == clause and not _is_negative(entry))
			var negative = spec.cases.any(func(entry): return int(entry.get("clause", -1)) == clause and _is_negative(entry))
			_check(positive and negative, "Spec %s has a positive and a negative or edge case for clause %d" % [card_id, clause])
		if tag.get("clauses", []).is_empty():
			_check(not spec.get("cases", []).is_empty(), "Spec %s (no Valve clause) still checks the card on the board" % card_id)
	_check(verified >= 49 and specs.size() >= verified, "Every verified Classic card has a spec (%d cards, %d specs)" % [verified, specs.size()])

func _is_negative(entry: Dictionary) -> bool:
	for value in entry.get("tags", []):
		if str(value) in NEGATIVE_TAGS:
			return true
	return false

func _count_ops(value, name: String) -> int:
	var total = 0
	if value is Dictionary:
		if str(value.get("op", "")) == name:
			total += 1
		for key in value:
			total += _count_ops(value[key], name)
	elif value is Array:
		for item in value:
			total += _count_ops(item, name)
	return total
