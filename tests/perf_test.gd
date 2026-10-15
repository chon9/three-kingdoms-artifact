extends SceneTree
## Performance budgets (EFFECT_SYSTEM_SPEC.md §13.6) on a dense fixture: 3
## lanes of 8 positions, 16 improvements per side, items on every hero, 10-card
## hands. Times are normalized by the frozen legacy engine's speed on the same
## machine (a full bot match of each), so CI and desktops compare: a measure
## warns above 2x its stored baseline (tests/data/perf_baseline.json) and fails
## above 3x. Every normalized measure must also meet its §13.6 budget; the full
## bot match must cost at most 1.5x the legacy engine (the legacy engine alone
## needs about 2.7 s of the original 3 s budget, see §13.6).
##
## Record a new baseline: godot --headless --path . -s tests/perf_test.gd -- --record

const EngineClass = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Legacy = preload("res://tests/legacy/legacy_engine.gd")
const LegacyBot = preload("res://tests/legacy/legacy_bot.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const BASELINE = "res://tests/data/perf_baseline.json"
## Spec §13.6 desktop budgets in milliseconds (normalized times).
const BUDGETS = {"legal_actions": 5.0, "apply_action_median": 5.0, "pulse_no_deaths": 1.0, "combat_preview": 2.0,
	"bot_decision": 250.0}
## Spec §13.6: a full headless bot match costs at most this multiple of the
## legacy engine's match on the same machine.
const MATCH_RATIO_BUDGET = 1.5
const FIXTURE_IMPROVEMENT = {"id": "fx_post", "kind": "improvement", "color": "black", "cost": 1, "status": "draft",
	"play": {"ops": []}}
var checks = 0
var failures: Array = []

func _initialize() -> void:
	var record = OS.get_cmdline_user_args().has("--record")
	# Full matches are timed twice each, interleaved, and the faster run counts,
	# so one load spike on a shared machine does not fail the ratio check.
	var legacy_ms = _legacy_match_ms()
	var match_ms = _match_ms()
	legacy_ms = minf(legacy_ms, _legacy_match_ms())
	match_ms = minf(match_ms, _match_ms())
	var measures = _measure()
	measures["bot_match"] = match_ms
	var baseline: Dictionary = {}
	if FileAccess.file_exists(BASELINE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		baseline = parsed if parsed is Dictionary else {}
	var factor = maxf(0.25, legacy_ms / float(baseline.get("legacy_bot_match", legacy_ms)))
	print("machine factor %.2f (legacy full bot match %.0f ms)" % [factor, legacy_ms])
	for name in measures:
		var normalized = float(measures[name]) / factor
		var stored = float(baseline.get(name, normalized))
		var budget = "%.1f ms" % float(BUDGETS[name]) if BUDGETS.has(name) else "%.1fx legacy" % MATCH_RATIO_BUDGET
		print("%-22s %9.3f ms  normalized %9.3f  baseline %9.3f  budget %s" % [name, measures[name], normalized, stored, budget])
		if normalized > stored * 2.0 and not record:
			push_warning("%s is above twice its baseline" % name)
		_check(record or normalized <= stored * 3.0, "%s stays within 3x its baseline (%.3f ms normalized, baseline %.3f)" % [name, normalized, stored])
		if BUDGETS.has(name):
			_check(normalized <= float(BUDGETS[name]), "%s meets its %.1f ms budget (%.3f ms normalized)" % [name, float(BUDGETS[name]), normalized])
	var ratio = float(measures.bot_match) / legacy_ms
	print("full bot match: %.2fx the legacy engine (budget %.1fx)" % [ratio, MATCH_RATIO_BUDGET])
	_check(ratio <= MATCH_RATIO_BUDGET, "A full bot match costs at most %.1fx the legacy engine (%.2fx)" % [MATCH_RATIO_BUDGET, ratio])
	if record:
		var out = {"legacy_bot_match": legacy_ms}
		for name in measures:
			out[name] = snappedf(float(measures[name]), 0.001)
		var file = FileAccess.open(BASELINE, FileAccess.WRITE)
		file.store_string(JSON.stringify(out, "  ", true) + "\n")
		file.close()
		print("RECORDED " + BASELINE)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d performance checks." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _legacy_match_ms() -> float:
	var started = Time.get_ticks_usec()
	var engine = Legacy.new()
	engine.start(3, ["starter", "starter"])
	var bot = LegacyBot.new()
	var steps = 0
	while engine.state.winner == -1 and steps < 1500:
		var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
		engine.apply_action(player, bot.choose_action(engine, player))
		steps += 1
	return (Time.get_ticks_usec() - started) / 1000.0

## The dense fixture: every lane full on both sides, improvements, items.
func _dense():
	var engine = EngineClass.new()
	engine.library = Library.with_cards("artifact_classic_decks_v2", [FIXTURE_IMPROVEMENT])
	engine.start(21, ["green_assault", "blue_black_control"])
	var creeps = ["savage_wolf", "prowler_vanguard", "bronze_legionnaire", "ogre_conscript", "untested_grunt", "centaur_hunter"]
	for lane_index in range(3):
		engine.state.lanes[lane_index].units = [[], []]
		engine.state.lanes[lane_index].mana = [20, 20]
		engine.state.lanes[lane_index].max_mana = [20, 20]
	for owner in engine.state.players:
		for hero in owner.roster:
			hero.lane = -1
	for side in range(2):
		var roster: Array = engine.state.players[side].roster
		for lane_index in range(3):
			for slot in range(8):
				var unit: Dictionary
				if slot < 2 and lane_index * 2 + slot < roster.size():
					unit = roster[lane_index * 2 + slot]
					for item in ["broadsword", "leather_armor", "travelers_cloak"]:
						Zones.equip(engine, unit, item)
				else:
					unit = engine._make_unit(engine.library.definition(creeps[(slot + lane_index + side) % creeps.size()]), side, false)
				engine._place(unit, lane_index, slot)
			for count in range(16):
				Zones.add_improvement(engine, "fx_post", side, lane_index)
		engine.state.players[side].hand = ["gust", "foresight", "hip_fire", "no_accident", "battlefield_control",
			"thundergods_wrath", "slay", "pick_off", "savage_wolf", "arm_the_rebellion"]
	engine._roll_arrows()
	engine.state.lane = 0
	engine.state.active_player = 0
	engine.state.first_pass = -1
	EngineClass.Stats.settle(engine)
	return engine

func _measure() -> Dictionary:
	var engine = _dense()
	var out: Dictionary = {}
	out["legal_actions"] = _time(func(): engine.legal_actions(0), 30)
	out["combat_preview"] = _time(func(): engine.combat_preview(0), 30)
	out["pulse_no_deaths"] = _time(func():
		engine._reset_transient()
		Kernel.pulse(engine), 30)
	var samples: Array = []
	for index in range(15):
		var copy = _dense()
		var actions = copy.legal_actions(0).filter(func(action): return str(action.type) == "play")
		var action = actions[index % actions.size()]
		var started = Time.get_ticks_usec()
		copy.apply_action(0, action)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	out["apply_action_median"] = samples[samples.size() / 2]
	var bot = BotClass.new()
	out["bot_decision"] = _time(func(): bot.choose_action(engine, 0), 3)
	return out

## One full headless bot match (seed 3, starter decks) in milliseconds.
func _match_ms() -> float:
	var bot = BotClass.new()
	var started = Time.get_ticks_usec()
	var match_engine = EngineClass.new()
	match_engine.start(3, ["starter", "starter"])
	var steps = 0
	while match_engine.state.winner == -1 and steps < 1500:
		var player = int(match_engine.state.active_player) if match_engine.state.phase == "action" else (1 if match_engine.state.players[0].finished else 0)
		match_engine.apply_action(player, bot.choose_action(match_engine, player))
		steps += 1
	return (Time.get_ticks_usec() - started) / 1000.0

func _time(call: Callable, count: int) -> float:
	var started = Time.get_ticks_usec()
	for index in range(count):
		call.call()
	return (Time.get_ticks_usec() - started) / 1000.0 / count
