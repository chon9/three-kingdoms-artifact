extends SceneTree
## Golden gate (EFFECT_SYSTEM_SPEC.md §13.5, M1.0). Replays the recorded bot
## matches in tests/data/goldens/*.json against the current engine.
##
## For every game it runs two checks:
## 1. Journal replay: the recorded commands are applied to a fresh engine and
##    every checkpoint (revision, state_digest, projection hash, new event
##    keys) must match. A failure here means the rules engine changed. The
##    global invariants (tests/invariants.gd) are checked along the way.
## 2. Bot replay: the heuristic bot plays the match again and must choose the
##    same command at every step, with the same checkpoints and result. A
##    failure only here means the bot's choices changed.
##
## Options (after `--`):
##   --projection-only  ignore state_digest and accept extra event keys around
##                      the recorded ones (for steps that change the state
##                      shape on purpose, spec M1.2/M1.3)
##   --journal-only     skip the bot replay
##   --suite <name>     training, classic or matchups
##   --game <id>        one game, for example classic_03
## Re-record (only for an intended rules change): tools/record_goldens.gd.

const Goldens = preload("res://tests/golden/golden_games.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const Invariants = preload("res://tests/invariants.gd")
## Commands between the full read-API invariant checks (I12 to I14).
const DEEP_EVERY = 10
var checks = 0
var failures: Array = []
var projection_only = false
var journal_only = false

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	projection_only = args.has("--projection-only")
	journal_only = args.has("--journal-only")
	var suites: Array = Goldens.SUITES.duplicate()
	var only_game = _option(args, "--game")
	if _option(args, "--suite") != "":
		suites = [_option(args, "--suite")]
	var games = 0
	var commands = 0
	for suite in suites:
		var started = Time.get_ticks_msec()
		var data = Goldens.load_suite(suite)
		_check(not data.is_empty(), "Golden file %s exists and parses (record it with tools/record_goldens.gd)" % Goldens.path_of(suite))
		if data.is_empty():
			continue
		_check(int(data.get("format", 0)) == Goldens.FORMAT, "Golden file %s has format %d" % [suite, Goldens.FORMAT])
		var recorded: Dictionary = {}
		for record in data.get("games", []):
			recorded[str(record.id)] = record
		var expected_games = Goldens.games(suite)
		_check(recorded.size() == expected_games.size(), "Golden suite %s holds exactly its %d defined games" % [suite, expected_games.size()])
		for game in expected_games:
			if only_game != "" and game.id != only_game:
				continue
			if not recorded.has(game.id):
				_check(false, "Golden game %s is recorded" % game.id)
				continue
			var record: Dictionary = Goldens.normalize(recorded[game.id])
			if not _same_definition(game, record):
				continue
			games += 1
			commands += int(record.step_count)
			if _journal_replay(record) and not journal_only:
				_bot_replay(record)
		print("%s: checked in %.1f s" % [suite, (Time.get_ticks_msec() - started) / 1000.0])
	_check(games > 0, "At least one golden game was checked")
	if failures.is_empty():
		print("PASS: %d golden checks over %d games and %d commands (%s%s)." % [checks, games, commands,
			"projection only" if projection_only else "state_digest and projection",
			", journal only" if journal_only else ", journal and bot replay"])
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("%d failures in %d golden checks. If the rules change is intended, re-record with tools/record_goldens.gd and say why in the commit." % [failures.size(), checks])
		quit(1)

func _option(args: PackedStringArray, name: String) -> String:
	var index = args.find(name)
	return args[index + 1] if index != -1 and index + 1 < args.size() else ""

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _same_definition(game: Dictionary, record: Dictionary) -> bool:
	var same = str(record.pack) == game.pack and int(record.seed) == game.seed \
		and Array(record.decks) == game.decks and int(record.max_steps) == game.max_steps \
		and Array(record.steps).size() == int(record.step_count) + 1
	_check(same, "Golden game %s matches its definition (pack, seed, decks, step count)" % game.id)
	return same

## Applies the recorded commands; every checkpoint must match.
func _journal_replay(record: Dictionary) -> bool:
	var engine = Goldens.new_engine(record)
	var steps: Array = record.steps
	var problem = _compare(steps[0], Goldens.checkpoint(engine, -1, null, 0))
	if problem != "":
		problem = "step 0 (after start): " + problem
	for index in range(1, steps.size()):
		if problem != "":
			break
		var step: Dictionary = steps[index]
		var seen = int(engine.state.event_seq)
		var result = engine.apply_action(int(step.p), step.c)
		if not result.ok:
			problem = "step %d: recorded command %s by player %d is now rejected (%s)" % [index, JSON.stringify(step.c), int(step.p), result.get("code", "")]
			break
		problem = _step_problem(index, step, Goldens.checkpoint(engine, int(step.p), engine.journal.back().command, seen))
		if problem == "":
			# The global invariants (spec §13.3): I1 to I11 after every recorded
			# command, and I12 to I14 (privacy, purity, packet bounds), which
			# call the whole read API, after every DEEP_EVERY-th command.
			var broken = Invariants.violations(engine) + Invariants.write_through(engine)
			if index % DEEP_EVERY == 0:
				broken.append_array(Invariants.deep_violations(engine))
			if not broken.is_empty():
				problem = "step %d (revision %d): invariants %s" % [index, int(step.r), ", ".join(broken)]
	if problem == "":
		problem = _final_problem(record, engine)
	_check(problem == "", "Journal replay of %s: %s" % [record.id, problem])
	return problem == ""

## Lets the bot play again; it must make the recorded choice at every step.
func _bot_replay(record: Dictionary) -> void:
	var engine = Goldens.new_engine(record)
	var bot = BotClass.new()
	var steps: Array = record.steps
	var problem = ""
	for index in range(1, steps.size()):
		var step: Dictionary = steps[index]
		if engine.state.winner != -1:
			problem = "match ended after %d commands, recorded %d" % [index - 1, steps.size() - 1]
			break
		var player = Goldens.next_player(engine)
		var command = bot.choose_action(engine, player)
		if command.is_empty():
			problem = "bot stalled at step %d (recorded %s)" % [index, JSON.stringify(step.c)]
			break
		var seen = int(engine.state.event_seq)
		if not engine.apply_action(player, command).ok:
			problem = "bot command %s at step %d is illegal" % [JSON.stringify(command), index]
			break
		problem = _step_problem(index, step, Goldens.checkpoint(engine, player, engine.journal.back().command, seen))
		if problem != "":
			break
	if problem == "":
		problem = _final_problem(record, engine)
	_check(problem == "", "Bot replay of %s: %s" % [record.id, problem])

func _step_problem(index: int, expected: Dictionary, actual: Dictionary) -> String:
	var problem = _compare(expected, actual)
	return "" if problem == "" else "step %d (revision %d, recorded command %s by player %d): %s" % [
		index, int(expected.r), JSON.stringify(expected.c), int(expected.p), problem]

func _compare(expected: Dictionary, actual: Dictionary) -> String:
	if int(expected.p) != int(actual.p) or Goldens.normalize(expected.c) != Goldens.normalize(actual.c):
		return "command differs: now %s by player %d" % [JSON.stringify(actual.c), int(actual.p)]
	if int(expected.r) != int(actual.r):
		return "revision %d, now %d" % [int(expected.r), int(actual.r)]
	if not projection_only and str(expected.d) != str(actual.d):
		return "state_digest differs (%s, now %s)" % [str(expected.d).left(12), str(actual.d).left(12)]
	if str(expected.h) != str(actual.h):
		return "projection differs (%s, now %s)" % [str(expected.h).left(12), str(actual.h).left(12)]
	var keys_ok = Array(expected.e) == Array(actual.e) if not projection_only else _subsequence(Array(expected.e), Array(actual.e))
	if not keys_ok:
		return "event keys %s, now %s" % [JSON.stringify(expected.e), JSON.stringify(actual.e)]
	return ""

func _final_problem(record: Dictionary, engine) -> String:
	if int(engine.state.winner) != int(record.winner):
		return "winner %d, now %d" % [int(record.winner), int(engine.state.winner)]
	var paths: Array = []
	_diff("", Goldens.normalize(record.final_projection), Goldens.normalize(JSON.parse_string(JSON.stringify(Goldens.projection(engine)))), paths)
	return "" if paths.is_empty() else "final projection differs at " + ", ".join(paths.slice(0, 8))

func _diff(path: String, expected, actual, paths: Array) -> void:
	if paths.size() >= 8:
		return
	if expected is Dictionary and actual is Dictionary:
		for key in expected:
			_diff("%s.%s" % [path, key], expected[key], actual.get(key), paths)
		for key in actual:
			if not expected.has(key):
				paths.append("%s.%s (new)" % [path, key])
	elif expected is Array and actual is Array and expected.size() == actual.size():
		for index in range(expected.size()):
			_diff("%s[%d]" % [path, index], expected[index], actual[index], paths)
	elif typeof(expected) != typeof(actual) or expected != actual:
		paths.append("%s: %s -> %s" % [path, JSON.stringify(expected), JSON.stringify(actual)])

## True when every recorded key appears in order among the current keys.
func _subsequence(expected: Array, actual: Array) -> bool:
	var at = 0
	for key in actual:
		if at < expected.size() and key == expected[at]:
			at += 1
	return at == expected.size()
