extends SceneTree
## Per-card specs (EFFECT_SYSTEM_SPEC.md §13.1): every tests/cards/<id>.json
## case builds a board with the board DSL, runs its steps through
## apply_action (so they are validated) and checks its expectations. The
## runner also, for every case:
## * checks the global invariants (I1 to I10) after every step;
## * runs the case twice and compares the final state digests;
## * formats every emitted event in both skins and both locales;
## * checks that every expected-illegal command is rejected without changing
##   the state digest or the random state.
## The meta tests over the specs (§13.7 items 5 to 7 and the coverage gate)
## are in tests/rules_schema_test.gd.
##
## Options (after --): --card <id> runs one spec.
##
## Board DSL ("board"): lanes {"0": {"p0": [entry, null, ...], "p1": [...]}},
## where an entry is "card#label[:hp=N][:atk=N][:arm=N][:arrow=N][+item...]";
## active_lane, active_player, initiative, round (default 2), mana (an int for
## every lane, or {"0": [p0, p1]}), gold {"p0": n}, hand {"p0": [ids]}, deck
## {"p0": [ids]}, towers {"0": {"p1": {"health": n, "ancient": bool}}},
## improvements {"0": {"p0": ["card#label"]}}, fountain {"p0":
## ["card#label[:ready=N]"]}, give {label: ["silence", ...]} (this round),
## charges {label | "label.<slot>": n}, cooldowns {label | "label.<slot>": n}
## (a slot names the hero's item instance), hand_state {"p0": [{...}]};
## "@n" reuses case n's board and {"base": "@n", ...} merges into it. An
## unknown card or a "+item" that is not equipment fails the board (the
## modifiers of an entry go before its first +item).
## Steps ("do"): {"play": card, "target": label, "destination": label |
## "tower", "lane": n, "position": n, "player": p, "as": label (names the
## unit the play puts into a lane: the creep it plays, else the first unit
## it summons)}, {"ability": label | "label.weapon", with the same target
## fields ("tower" is 0)}, {"pass": p},
## {"combat": true}, {"end_round": true, "deploy": {hero label: lane}},
## {"kill": [labels]}, {"draw": {"p1": n}}, {"give": {label: ["stun", ...]}}
## (statuses this round, mid-case); a deployment phase step by step:
## {"begin_deployment": true}, {"plan": {hero label: lane}} (real, validated
## deploy commands), {"reveal": true}.
## Expectations ("expect"): "label.<field>" (attack, armor, health,
## max_health, kw.<k>, stunned, silenced, disarmed, in_play, lane, slot,
## owner, cooldown, charges, items, ready_round, combat_target, arrow),
## "label.<slot>.<field>" (the item instance in that slot: cooldown, charges,
## card, mods), "tower.<lane>.<p>.health" (and
## .ancient), "mana.<lane>.<p>", "max_mana.<lane>.<p>", "p<i>.gold",
## "p<i>.hand" (ids, or a count), "p<i>.hand.<i>" (the card id at that
## index, "" past the end), "p<i>.hand.<card>" (copies of that card in hand),
## "p<i>.hand_state.<i>.lock" (null past the end), "p<i>.deeds" (deed ids,
## or a count), "p<i>.price.<source>.<card>" (a shop price after the rules
## layer),
## "initiative", "lane", "winner", "units.<lane>.<p>[.<card>]" (a count of
## units), "fountain.<p>[.<card>]" (a count of roster heroes out of the lanes),
## "events": {"has": [keys], "not": [keys]};
## "expect_legal" / "expect_illegal" (commands in step form), "expect_rate"
## ({key: [low, high]} over "seeds": {"from", "count"}), "expect_private"
## ({"viewer": p, "absent": [strings]}), "gd" (a script whose
## check(engine, labels) returns failure messages).

const EngineClass = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Select = preload("res://scripts/core/rules/select.gd")
const Invariants = preload("res://tests/invariants.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const CARDS_DIR = "res://tests/cards"
var checks = 0
var failures: Array = []
var library = Library.new()
var cases_run = 0

func _initialize() -> void:
	var only = ""
	var args = OS.get_cmdline_user_args()
	if args.has("--card") and args.find("--card") + 1 < args.size():
		only = args[args.find("--card") + 1]
	var specs = _load_specs()
	for card_id in specs:
		if only.is_empty() or card_id == only:
			_run_spec(specs[card_id])
	Settings.set_locale("en", false)
	Settings.set_skin(Settings.DEFAULT_SKIN, false)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d card spec checks over %d specs and %d cases (invariants every step, double runs, event text, rejected commands)." % [
		"PASS" if failures.is_empty() else "FAIL", checks, specs.size(), cases_run])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _load_specs() -> Dictionary:
	var specs: Dictionary = {}
	var names: Array = Array(DirAccess.get_files_at(CARDS_DIR)).filter(func(name): return str(name).ends_with(".json"))
	names.sort()
	for name in names:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [CARDS_DIR, name]))
		_check(parsed is Dictionary and parsed.has("card"), "Spec %s parses" % name)
		if parsed is Dictionary and parsed.has("card"):
			_check(str(name) == str(parsed.card) + ".json", "Spec file %s is named after its card" % name)
			specs[str(parsed.card)] = _normalize(parsed)
	return specs

# --- Running specs ---------------------------------------------------------------------

func _run_spec(spec: Dictionary) -> void:
	var cases: Array = spec.get("cases", [])
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var label = "%s case %d (%s)" % [spec.card, index, entry.get("name", "")]
		if entry.has("expect_rate"):
			_run_rate(spec, index, label)
			continue
		var seed_value = int(entry.get("seed", 1))
		var first = _run_case(spec, index, seed_value, label, true)
		var second = _run_case(spec, index, seed_value, label, false)
		if not first.is_empty() and not second.is_empty():
			_check(first.digest == second.digest, "%s: a second run gives the same state digest" % label)
		cases_run += 1

## Runs case `index` once; returns {"digest", "engine", "labels"} or {} on a setup failure.
func _run_case(spec: Dictionary, index: int, seed_value: int, label: String, report: bool) -> Dictionary:
	var entry: Dictionary = spec.cases[index]
	var board = _board(spec, entry.get("board", {}))
	var setup = _setup(board, seed_value)
	if setup.has("error"):
		if report:
			_check(false, "%s: board: %s" % [label, setup.error])
		return {}
	var engine = setup.engine
	var labels: Dictionary = setup.labels
	var seen = int(engine.state.event_seq)
	var ok = true
	for step in entry.get("do", []):
		var problem = _step(engine, labels, step)
		if problem != "":
			if report:
				_check(false, "%s: step %s: %s" % [label, JSON.stringify(step), problem])
			ok = false
			break
		var broken = Invariants.violations(engine)
		if report and not broken.is_empty():
			_check(false, "%s: invariants after %s: %s" % [label, JSON.stringify(step), broken])
			ok = false
			break
	# The digest after the steps (expectations below may put cards in hand).
	var digest = engine.state_digest()
	if report and ok:
		_expectations(engine, labels, entry, label, seen)
		_extra_checks(engine, labels, entry, label)
		_illegal(engine, labels, entry, label)
		_event_text(engine, seen, label)
	return {"digest": digest, "engine": engine, "labels": labels}

## A probability over many seeds (spec §13.1 expect_rate).
func _run_rate(spec: Dictionary, index: int, label: String) -> void:
	var entry: Dictionary = spec.cases[index]
	var seeds: Dictionary = entry.get("seeds", {"from": 1, "count": 200})
	var hits: Dictionary = {}
	var runs = 0
	for offset in range(int(seeds.get("count", 200))):
		var result = _run_case(spec, index, int(seeds.get("from", 1)) + offset, label, offset == 0)
		if result.is_empty():
			return
		runs += 1
		for key in entry.expect_rate:
			if _truthy(_read(result.engine, result.labels, str(key))):
				hits[key] = int(hits.get(key, 0)) + 1
	for key in entry.expect_rate:
		var bounds: Array = entry.expect_rate[key]
		var rate = float(hits.get(key, 0)) / maxf(1.0, float(runs))
		_check(rate >= float(bounds[0]) and rate <= float(bounds[1]), "%s: %s happens at rate %.3f (expected %s over %d seeds)" % [label, key, rate, bounds, runs])
	cases_run += 1

func _truthy(value) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is Array or value is Dictionary or value is String:
		return not value.is_empty()
	return value != null

# --- Boards ------------------------------------------------------------------------------

## The board of a case: a dictionary, "@n" (case n's board) or {"base": "@n", ...}.
func _board(spec: Dictionary, value) -> Dictionary:
	if value is String and str(value).begins_with("@"):
		return _board(spec, spec.cases[int(str(value).substr(1))].get("board", {}))
	if value is Dictionary and value.has("base"):
		var merged = _board(spec, value.base).duplicate(true)
		for key in value:
			if key == "base":
				continue
			if merged.get(key) is Dictionary and value[key] is Dictionary:
				merged[key].merge(value[key], true)
			else:
				merged[key] = value[key]
		return merged
	return value if value is Dictionary else {}

func _setup(board: Dictionary, seed_value: int) -> Dictionary:
	var engine = EngineClass.new()
	engine.library = library
	engine.start(seed_value)
	var state: Dictionary = engine.state
	state.round = int(board.get("round", 2))
	state.lane = int(board.get("active_lane", 0))
	state.active_player = int(board.get("active_player", 0))
	state.initiative = int(board.get("initiative", 0))
	state.first_pass = -1
	state.events = []
	for lane in state.lanes:
		lane.units = [[], []]
	for owner in state.players:
		owner.hand = []
		owner.hand_state = []
		owner.deck = []
		owner.deck_state = []
		owner.gold = 0
		for hero in owner.roster:
			hero.lane = -1
			hero.ready_round = 1
	var mana = board.get("mana", 10)
	for lane_index in range(3):
		var values = [int(mana), int(mana)] if not mana is Dictionary else mana.get(str(lane_index), [10, 10])
		var lane: Dictionary = state.lanes[lane_index]
		lane.mana = [int(values[0]), int(values[1])]
		lane.max_mana = [int(values[0]), int(values[1])]
		lane.max_mana_base = [int(values[0]), int(values[1])]
		lane.mana_bonus = [0, 0]
	var labels: Dictionary = {}
	var used: Dictionary = {}
	for lane_key in board.get("lanes", {}):
		var lane_index = int(lane_key)
		var rows: Dictionary = board.lanes[lane_key]
		var width = maxi(rows.get("p0", []).size(), rows.get("p1", []).size())
		for side in range(2):
			var row: Array = []
			var entries: Array = rows.get("p%d" % side, [])
			for slot in range(width):
				var text = entries[slot] if slot < entries.size() else null
				if text == null:
					row.append(null)
					continue
				var unit = _unit(engine, str(text), side, labels, used)
				if unit.has("_error"):
					return {"error": unit._error}
				unit.lane = lane_index
				row.append(unit)
			state.lanes[lane_index].units[side] = row
	for side_key in board.get("fountain", {}):
		var side = int(str(side_key).substr(1))
		for text in board.fountain[side_key]:
			var unit = _unit(engine, str(text), side, labels, used)
			if unit.has("_error"):
				return {"error": unit._error}
			unit.lane = -1
	for lane_key in board.get("improvements", {}):
		for side_key in board.improvements[lane_key]:
			for text in board.improvements[lane_key][side_key]:
				var parts = str(text).split("#")
				var improvement = Zones.add_improvement(engine, parts[0], int(str(side_key).substr(1)), int(lane_key))
				if parts.size() > 1:
					labels[parts[1]] = improvement
	for side_key in board.get("hand", {}):
		var owner: Dictionary = state.players[int(str(side_key).substr(1))]
		owner.hand = board.hand[side_key].duplicate()
	for side_key in board.get("deck", {}):
		state.players[int(str(side_key).substr(1))].deck = board.deck[side_key].duplicate()
	for side_key in board.get("gold", {}):
		state.players[int(str(side_key).substr(1))].gold = int(board.gold[side_key])
	Zones.sync(engine)
	for side_key in board.get("hand_state", {}):
		var owner: Dictionary = state.players[int(str(side_key).substr(1))]
		var extra: Array = board.hand_state[side_key]
		for index in range(mini(extra.size(), owner.hand_state.size())):
			owner.hand_state[index].merge(extra[index], true)
	for lane_key in board.get("towers", {}):
		for side_key in board.towers[lane_key]:
			var structure: Dictionary = state.lanes[int(lane_key)].structures[int(str(side_key).substr(1))]
			for field in board.towers[lane_key][side_key]:
				structure[field] = board.towers[lane_key][side_key][field]
	for name in board.get("give", {}):
		if not labels.has(name):
			return {"error": "give: unknown label %s" % name}
		for status in board.give[name]:
			Kernel.give(engine, labels[name], {}, {str(status): 1}, "", "round", {"controller": 1 - int(labels[name].get("owner", 0)), "card": ""})
	# "charges" and "cooldowns" take a label, or "label.<slot>" for the item
	# instance in that slot of a hero.
	for name in board.get("charges", {}):
		var holder = _holder(labels, str(name))
		if holder.is_empty():
			return {"error": "charges: unknown label %s" % name}
		holder["charges"] = int(board.charges[name])
	for name in board.get("cooldowns", {}):
		var holder = _holder(labels, str(name))
		if holder.is_empty():
			return {"error": "cooldowns: unknown label %s" % name}
		holder["cooldown" if holder.has("uid") else "cd"] = int(board.cooldowns[name])
	Stats.settle(engine)
	for name in labels:
		var object: Dictionary = labels[name]
		if object.has("uid") and object.has("_hp"):
			object.health = int(object._hp)
			object.erase("_hp")
	Zones.normalize_arrows(engine, 0)
	for lane_index in range(3):
		Zones.compact(engine, lane_index)
		Zones.normalize_arrows(engine, lane_index)
	engine._reset_transient()
	engine._settle_transient()
	var broken = Invariants.violations(engine)
	if not broken.is_empty():
		return {"error": "the board breaks the invariants: %s" % [broken]}
	return {"engine": engine, "labels": labels}

## The object a "charges"/"cooldowns" board key names: a label, or the item
## instance of "label.<slot>" ({} when there is none).
func _holder(labels: Dictionary, name: String) -> Dictionary:
	var parts = name.split(".")
	if not labels.has(parts[0]):
		return {}
	var object: Dictionary = labels[parts[0]]
	if parts.size() == 1:
		return object
	return object.get("item_state", {}).get(parts[1], {})

## A unit from "card#label[:hp=N][:atk=N][:arm=N][:arrow=N][:ready=N][+item...]".
## Heroes of the player's roster are reused (so they stay roster heroes);
## other heroes join the roster. An unknown card, or an item that is not
## equipment ("card#x+item:arrow=-1" puts the modifier after the item),
## returns {"_error": ...}.
func _unit(engine, text: String, side: int, labels: Dictionary, used: Dictionary) -> Dictionary:
	var items = text.split("+")
	var head = items[0].split(":")
	var parts = head[0].split("#")
	var card_id = parts[0]
	var definition = engine.library.definition(card_id)
	if definition.is_empty():
		return {"_error": "unknown card in %s" % text}
	for item_id in items.slice(1):
		var item: Dictionary = engine.library.get_card(str(item_id))
		if str(item.get("kind", "")) != "item" or str(item.get("slot", "")) not in ["weapon", "armor", "accessory"]:
			return {"_error": "unknown equipment %s in %s (modifiers go before the first +item)" % [item_id, text]}
	var unit: Dictionary = {}
	var hero = str(definition.get("kind", "")) == "hero" or engine.library.heroes.any(func(entry): return str(entry.id) == card_id)
	if hero:
		for candidate in engine.state.players[side].roster:
			if str(candidate.card) == card_id and not used.has(int(candidate.uid)):
				unit = candidate
				break
		if unit.is_empty():
			unit = engine._make_unit(definition, side, true)
			engine.state.players[side].roster.append(unit)
		unit.ready_round = 1
	else:
		unit = engine._make_unit(definition, side, false)
	used[int(unit.uid)] = true
	unit.arrow = 0
	unit.combat_target = -1
	for modifier in head.slice(1):
		var pair = modifier.split("=")
		match pair[0]:
			"hp":
				unit["_hp"] = int(pair[1])
			"atk":
				unit.attack = int(pair[1])
			"arm":
				unit.armor = int(pair[1])
			"arrow":
				unit.arrow = int(pair[1])
			"ready":
				unit.ready_round = int(pair[1])
	for item_id in items.slice(1):
		Zones.equip(engine, unit, item_id)
	if parts.size() > 1:
		labels[parts[1]] = unit
	return unit

# --- Steps -------------------------------------------------------------------------------

## Runs one step; "" when it applied.
func _step(engine, labels: Dictionary, step: Dictionary) -> String:
	if step.has("play"):
		var command = _play_command(engine, labels, step, true)
		if command.has("error"):
			return command.error
		var before: Dictionary = {}
		for unit in Stats.all_units(engine):
			before[int(unit.uid)] = true
		var problem = _apply(engine, int(step.get("player", engine.state.active_player)), command)
		if problem == "" and step.has("as"):
			# "as": "<label>" names the unit the play put into a lane: the
			# creep it plays, else the first unit it summoned (canonical order).
			var placed: Array = Stats.all_units(engine).filter(func(unit): return not before.has(int(unit.uid)) and int(unit.get("lane", -1)) >= 0)
			var own: Array = placed.filter(func(unit): return str(unit.card) == str(step.play))
			if not own.is_empty():
				placed = own
			if placed.is_empty():
				return "as: the play put no unit into a lane"
			labels[str(step.as)] = placed[0]
		return problem
	if step.has("ability"):
		var command = _ability_command(labels, step)
		if command.has("error"):
			return command.error
		return _apply(engine, int(step.get("player", engine.state.active_player)), command)
	if step.has("pass"):
		return _apply(engine, int(step.pass), {"type": "pass"})
	if step.has("combat"):
		var first = int(engine.state.active_player)
		var problem = _apply(engine, first, {"type": "pass"})
		return problem if problem != "" else _apply(engine, 1 - first, {"type": "pass"})
	if step.has("end_round"):
		engine._begin_deployment()
		# "deploy": {label: lane} plans heroes (from the Fountain) for the reveal.
		for name in step.get("deploy", {}):
			if not labels.has(name) or not labels[name].has("uid"):
				return "deploy: unknown hero label %s" % name
			var hero: Dictionary = labels[name]
			engine.state.players[int(hero.owner)].plans[str(hero.uid)] = int(step.deploy[name])
		for owner in engine.state.players:
			owner.finished = true
		engine._reveal_deployment()
		engine._settle_transient()
		return ""
	if step.has("begin_deployment"):
		# The round ends and the deployment phase begins (lane creeps
		# published); "plan" then deploys heroes with real commands and
		# "reveal" ends the phase, so a case can look in between.
		engine._reset_transient()
		engine._begin_deployment()
		engine._settle_transient()
		return ""
	if step.has("plan"):
		if str(engine.state.phase) != "deployment":
			return "plan: not in a deployment phase"
		for name in step.plan:
			if not labels.has(name) or not labels[name].has("uid"):
				return "plan: unknown hero label %s" % name
			var hero: Dictionary = labels[name]
			var problem = _apply(engine, int(hero.owner), {"type": "deploy", "unit": int(hero.uid), "lane": int(step.plan[name])})
			if problem != "":
				return problem
		return ""
	if step.has("reveal"):
		if str(engine.state.phase) != "deployment":
			return "reveal: not in a deployment phase"
		for owner in engine.state.players:
			owner.finished = true
		engine._reset_transient()
		engine._reveal_deployment()
		engine._settle_transient()
		return ""
	if step.has("give"):
		# "give": {label: [statuses]} gives statuses this round mid-case, as the
		# board's "give" does at setup: a stunned or silenced unit in a lane
		# whose action phase has not begun yet (a granted before-action trigger).
		engine._reset_transient()
		for name in step.give:
			if not labels.has(name) or not labels[name].has("uid"):
				return "give: unknown unit label %s" % name
			for status in step.give[name]:
				Kernel.give(engine, labels[name], {}, {str(status): 1}, "", "round", {"controller": 1 - int(labels[name].get("owner", 0)), "card": ""})
		Kernel.pulse(engine)
		engine._settle_transient()
		return ""
	if step.has("kill"):
		for name in step.kill:
			if labels.has(name):
				labels[name].health = 0
		engine._reset_transient()
		Kernel.pulse(engine)
		engine._settle_transient()
		return ""
	if step.has("draw"):
		engine._reset_transient()
		for side_key in step.draw:
			Zones.draw(engine, int(str(side_key).substr(1)), int(step.draw[side_key]))
		Kernel.pulse(engine)
		engine._settle_transient()
		return ""
	return "unknown step"

func _apply(engine, player: int, command: Dictionary) -> String:
	var result = engine.apply_action(player, command)
	return "" if result.ok else "%s rejected (%s)" % [JSON.stringify(command), result.get("code", "")]

## {"type": "play", ...} for a play step; the card goes into the player's
## hand first when it is not there.
func _play_command(engine, labels: Dictionary, step: Dictionary, add: bool) -> Dictionary:
	var player = int(step.get("player", engine.state.active_player))
	var owner: Dictionary = engine.state.players[player]
	var index = owner.hand.find(str(step.play))
	if index == -1:
		if not add:
			return {"type": "play", "hand": owner.hand.size()}
		owner.hand.append(str(step.play))
		owner.hand_state.append({"iid": Kernel.next_oid(engine)})
		index = owner.hand.size() - 1
	var command = {"type": "play", "hand": index}
	for key in ["target", "destination", "lane", "position"]:
		if not step.has(key):
			continue
		var value = step[key]
		if value is String:
			if str(value) == "tower":
				command[key] = 0
			elif labels.has(value):
				command[key] = _id_of(labels[value])
			else:
				return {"error": "unknown label %s" % value}
		else:
			command[key] = int(value)
	return command

func _ability_command(labels: Dictionary, step: Dictionary) -> Dictionary:
	var parts = str(step.ability).split(".")
	if not labels.has(parts[0]):
		return {"error": "unknown label %s" % parts[0]}
	var source: Dictionary = labels[parts[0]]
	var id = _id_of(source)
	if parts.size() > 1:
		id = int(source.get("item_state", {}).get(parts[1], {}).get("oid", -1))
	var command = {"type": "ability", "unit": id}
	for key in ["target", "destination", "lane", "position"]:
		if not step.has(key):
			continue
		var value = step[key]
		if value is String:
			if str(value) == "tower":
				command[key] = 0
			elif labels.has(value):
				command[key] = _id_of(labels[value])
			else:
				return {"error": "unknown label %s" % value}
		else:
			command[key] = int(value)
	return command

func _id_of(object: Dictionary) -> int:
	return int(object.get("uid", object.get("oid", -1)))

# --- Expectations -------------------------------------------------------------------------

func _expectations(engine, labels: Dictionary, entry: Dictionary, label: String, seen: int) -> void:
	for key in entry.get("expect", {}):
		var want = entry.expect[key]
		if key == "events":
			var keys: Array = _new_events(engine, seen).map(func(event): return str(event.k))
			for event_key in want.get("has", []):
				_check(keys.has(event_key), "%s: event %s was emitted (%s)" % [label, event_key, keys])
			for event_key in want.get("not", []):
				_check(not keys.has(event_key), "%s: event %s was not emitted (%s)" % [label, event_key, keys])
			continue
		var have = _read(engine, labels, str(key))
		_check(_same(have, want), "%s: %s is %s, expected %s" % [label, key, JSON.stringify(have), JSON.stringify(want)])
	for command in entry.get("expect_legal", []):
		var built = _command(engine, labels, command)
		var player = int(command.get("player", engine.state.active_player))
		_check(not built.has("error") and built in engine.legal_actions(player), "%s: %s is legal" % [label, JSON.stringify(command)])
	var private: Dictionary = entry.get("expect_private", {})
	if not private.is_empty():
		var text = JSON.stringify(engine.player_view(int(private.get("viewer", 1))))
		for value in private.get("absent", []):
			_check(text.find(str(value)) == -1, "%s: %s stays out of player %d's view" % [label, value, int(private.get("viewer", 1))])

## The "gd" escape (spec §13.1): a RefCounted script whose
## `func check(engine, labels: Dictionary) -> Array` returns failure messages
## for assertions the DSL cannot express (an empty list when they hold).
func _extra_checks(engine, labels: Dictionary, entry: Dictionary, label: String) -> void:
	if not entry.has("gd"):
		return
	var script = load(str(entry.gd))
	var checker = script.new() if script is Script else null
	_check(checker != null and checker.has_method("check"), "%s: gd script %s has check(engine, labels)" % [label, entry.gd])
	if checker == null or not checker.has_method("check"):
		return
	for message in checker.check(engine, labels):
		_check(false, "%s: %s" % [label, message])

## Expected-illegal commands are rejected and change neither the digest nor
## the random state (also the runner's rejected-command check).
func _illegal(engine, labels: Dictionary, entry: Dictionary, label: String) -> void:
	for command in entry.get("expect_illegal", []):
		var built = _command(engine, labels, command)
		if built.has("error"):
			_check(false, "%s: %s: %s" % [label, JSON.stringify(command), built.error])
			continue
		var player = int(command.get("player", engine.state.active_player))
		_check(not built in engine.legal_actions(player), "%s: %s is not legal" % [label, JSON.stringify(command)])
		var digest = engine.state_digest()
		var rng_state = engine.rng.state
		var result = engine.apply_action(player, built)
		_check(not result.ok and engine.state_digest() == digest and engine.rng.state == rng_state,
			"%s: the rejected %s changes nothing" % [label, JSON.stringify(command)])

func _command(engine, labels: Dictionary, command: Dictionary) -> Dictionary:
	if command.has("play"):
		var player = int(command.get("player", engine.state.active_player))
		var owner: Dictionary = engine.state.players[player]
		if owner.hand.find(str(command.play)) == -1:
			owner.hand.append(str(command.play))
			owner.hand_state.append({"iid": Kernel.next_oid(engine)})
		return _play_command(engine, labels, command, false)
	if command.has("ability"):
		return _ability_command(labels, command)
	return {"error": "unknown command"}

func _new_events(engine, seen: int) -> Array:
	var events: Array = engine.state.events
	var count = mini(int(engine.state.event_seq) - seen, events.size())
	return events.slice(events.size() - count)

## Every event of the case formats in both skins and both locales.
func _event_text(engine, seen: int, label: String) -> void:
	var events = _new_events(engine, seen)
	for skin in ["classic", "three_kingdoms"]:
		Settings.set_skin(skin, false)
		for locale in ["en", "zh_CN"]:
			Settings.set_locale(locale, false)
			for event in events:
				var text = EventText.format(event)
				if text.is_empty() or text == "?" or text.find("{") != -1:
					_check(false, "%s: event %s formats in %s/%s (%s)" % [label, JSON.stringify(event), skin, locale, text])
	Settings.set_locale("en", false)
	Settings.set_skin(Settings.DEFAULT_SKIN, false)

func _read(engine, labels: Dictionary, key: String):
	var parts = key.split(".")
	match parts[0]:
		"tower":
			var structure: Dictionary = engine.state.lanes[int(parts[1])].structures[int(parts[2])]
			return structure.get(parts[3])
		"mana":
			return int(engine.state.lanes[int(parts[1])].mana[int(parts[2])])
		"max_mana":
			return int(engine.state.lanes[int(parts[1])].max_mana[int(parts[2])])
		"initiative":
			return int(engine.state.initiative)
		"lane":
			return int(engine.state.lane)
		"winner":
			return int(engine.state.winner)
		"units":
			# "units.<lane>.<p>" counts a side's units in a lane; ".<card>" only that card.
			var count = 0
			for unit in engine.state.lanes[int(parts[1])].units[int(parts[2])]:
				if unit != null and (parts.size() < 4 or str(unit.card) == parts[3]):
					count += 1
			return count
		"fountain":
			# "fountain.<p>[.<card>]" counts a side's roster heroes out of the lanes.
			var count = 0
			for hero in engine.state.players[int(parts[1])].roster:
				if int(hero.get("lane", -1)) < 0 and (parts.size() < 3 or str(hero.card) == parts[2]):
					count += 1
			return count
	if parts[0].begins_with("p") and parts[0].substr(1).is_valid_int() and parts.size() > 1:
		var owner: Dictionary = engine.state.players[int(parts[0].substr(1))]
		match parts[1]:
			"gold":
				return int(owner.gold)
			"hand":
				if parts.size() > 2 and parts[2].is_valid_int():
					# "p<i>.hand.<index>": the card id there ("" past the end).
					var at = int(parts[2])
					return str(owner.hand[at]) if at >= 0 and at < owner.hand.size() else ""
				if parts.size() > 2:
					# "p<i>.hand.<card>": how many copies of that card are in hand.
					return owner.hand.count(parts[2])
				return owner.hand.duplicate()
			"hand_state":
				var index = int(parts[2]) if parts.size() > 2 else -1
				var states: Array = owner.get("hand_state", [])
				if index < 0 or index >= states.size() or parts.size() < 4:
					return null
				return states[index].get(parts[3], 0)
			"deck":
				return owner.deck.size()
			"deeds":
				# "p<i>.deeds": the card ids in the player's public deeds zone.
				return owner.get("deeds", []).map(func(deed): return str(deed.card))
			"price":
				# "p<i>.price.<source>.<card>": the shop price after the rules layer.
				if parts.size() < 4:
					return "price needs a source and a card"
				return int(engine.price_of(int(parts[0].substr(1)), parts[2], parts[3]))
	if not labels.has(parts[0]):
		return "unknown label %s" % parts[0]
	var object: Dictionary = labels[parts[0]]
	var field = parts[1] if parts.size() > 1 else ""
	var live = Select.in_play(engine, object) if object.has("uid") else not object.get("condemned", false)
	if field in ["weapon", "armor", "accessory"] and parts.size() > 2:
		# "<label>.<slot>.<field>" before the stat names: "a.armor.cooldown"
		# is the armor item's cooldown, never the hero's Armor stat.
		return _item_field(object, field, parts[2], key)
	match field:
		"attack":
			return engine.attack_of(object)
		"armor":
			return engine.armor_of(object)
		"max_health":
			return engine.max_health_of(object)
		"health":
			return int(object.health)
		"kw":
			return engine.keyword_of(object, parts[2])
		"stunned":
			return engine.has_flag(object, "stun")
		"silenced":
			return engine.has_flag(object, "silence")
		"disarmed":
			return engine.has_flag(object, "disarm")
		"in_play":
			if object.has("oid"):
				return Select.in_play(engine, object)
			return live
		"lane":
			return int(object.get("lane", -1))
		"slot":
			return engine.slot_of(object)
		"owner":
			return int(object.get("owner", -1))
		"cooldown":
			return int(object.get("cooldown", object.get("cd", 0)))
		"charges":
			return int(object.get("charges", 0))
		"items":
			return object.get("items", {}).duplicate()
		"weapon", "accessory":
			return "unknown item field %s" % key
		"ready_round":
			return int(object.get("ready_round", 0))
		"combat_target":
			return int(object.get("combat_target", -1))
		"arrow":
			return int(object.get("arrow", 0))
	return "unknown field %s" % field

## "<label>.<slot>.<field>": the item instance in that slot: its cooldown,
## charges, card, or mods (how many entries it holds, such as granted text
## from a Modify).
func _item_field(object: Dictionary, slot: String, name: String, key: String):
	var instance: Dictionary = object.get("item_state", {}).get(slot, {})
	match name:
		"cooldown":
			return int(instance.get("cd", 0))
		"charges":
			return int(instance.get("charges", 0))
		"card":
			return str(object.get("items", {}).get(slot, ""))
		"mods":
			return instance.get("mods", []).size()
	return "unknown item field %s" % key

func _same(have, want) -> bool:
	if have == null or want == null:
		return have == null and want == null
	if want is Array and have is int:
		return false
	if want is Array and have is Array:
		return JSON.stringify(_normalize(have)) == JSON.stringify(_normalize(want))
	if (want is int or want is float) and have is Array:
		return have.size() == int(want)
	if want is Dictionary and have is Dictionary:
		return JSON.stringify(_normalize(have)) == JSON.stringify(_normalize(want))
	if want is bool or have is bool:
		return bool(have) == bool(want)
	if want is float or want is int:
		return (have is int or have is float) and float(have) == float(want)
	return str(have) == str(want)

## JSON numbers load as floats: whole numbers become ints.
func _normalize(value):
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		return value.map(func(item): return _normalize(item))
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = _normalize(value[key])
		return out
	return value
