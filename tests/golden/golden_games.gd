extends RefCounted
## Golden recordings of today's engine (EFFECT_SYSTEM_SPEC.md §13.5, M1.0).
##
## Every refactor step of the effect system is gated by these recordings: the
## same seeded bot matches must produce the same commands, the same
## state_digest() after every command and the same model-independent
## projection. tools/record_goldens.gd writes them, tests/golden_test.gd checks
## them. Re-record only in a commit that intends a rules change, and say why.
##
## File format (tests/data/goldens/<suite>.json, one step per line):
##   {"format": 1, "suite": ..., "protocol": ..., "games": [
##     {"id", "pack", "seed", "decks", "max_steps", "winner", "step_count",
##      "steps": [{"r": revision, "p": player, "c": command,
##                 "d": state_digest(), "h": projection hash, "e": [event keys]}],
##      "final_projection": {...}}]}
## Step 0 is the state right after start() (player -1, command null).

const EngineClass = preload("res://scripts/core/match_engine.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const FORMAT = 1
const GOLDEN_DIR = "res://tests/data/goldens"
const SUITES = ["training", "classic", "matchups"]
const CLASSIC_PACK = "artifact_classic_decks_v2"
const TRAINING_PACK = "original_training_fixtures"

## The 54 games named by spec M1.0: the 24 training seeds of run_tests, the 12
## Classic seeds of classic_cards_test and the 18 games of the expanded test's
## _matchup_matrix (every ordered pair of the three presets, seeds 41 and 73).
static func games(suite: String) -> Array:
	var result: Array = []
	match suite:
		"training":
			for seed_value in range(1, 25):
				result.append(_game("training_%02d" % seed_value, TRAINING_PACK, seed_value, ["starter", "starter"], 1200))
		"classic":
			for seed_value in range(1, 13):
				result.append(_game("classic_%02d" % seed_value, CLASSIC_PACK, seed_value, ["starter", "starter"], 1500))
		"matchups":
			var ids = ["starter", "green_assault", "blue_black_control"]
			for first in ids:
				for second in ids:
					for seed_value in [41, 73]:
						result.append(_game("%s_vs_%s_%d" % [first, second, seed_value], CLASSIC_PACK, seed_value, [first, second], 1500))
	return result

static func _game(id: String, pack: String, seed_value: int, decks: Array, max_steps: int) -> Dictionary:
	return {"id": id, "pack": pack, "seed": seed_value, "decks": decks, "max_steps": max_steps}

static func path_of(suite: String) -> String:
	return "%s/%s.json" % [GOLDEN_DIR, suite]

static func new_engine(game: Dictionary):
	var engine = EngineClass.new()
	engine.library = EngineClass.Library.new(str(game.pack))
	var result = engine.start(int(game.seed), Array(game.decks))
	assert(result.ok, "Golden game %s does not start" % game.id)
	return engine

## Player whose decision is next, exactly as the existing bot-match tests pick it.
static func next_player(engine) -> int:
	return int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)

## Plays one complete seeded bot match and records a checkpoint per command.
static func record_game(game: Dictionary) -> Dictionary:
	var engine = new_engine(game)
	var bot = BotClass.new()
	var steps: Array = [checkpoint(engine, -1, null, 0)]
	while engine.state.winner == -1 and steps.size() <= int(game.max_steps):
		var player = next_player(engine)
		var command = bot.choose_action(engine, player)
		if command.is_empty():
			break
		var seen = int(engine.state.event_seq)
		var result = engine.apply_action(player, command)
		assert(result.ok, "Golden bot command rejected in %s" % game.id)
		steps.append(checkpoint(engine, player, engine.journal.back().command, seen))
	var record = game.duplicate(true)
	record["winner"] = int(engine.state.winner)
	record["step_count"] = steps.size() - 1
	record["steps"] = steps
	record["final_projection"] = projection(engine)
	return record

static func checkpoint(engine, player: int, command, seen_events: int) -> Dictionary:
	return {"r": int(engine.state.revision), "p": player,
		"c": command.duplicate(true) if command is Dictionary else null,
		"d": engine.state_digest(), "h": projection_hash(engine),
		"e": new_event_keys(engine, seen_events)}

static func new_event_keys(engine, seen_events: int) -> Array:
	var events: Array = engine.state.events
	var count = mini(int(engine.state.event_seq) - seen_events, events.size())
	var keys: Array = []
	for index in range(events.size() - count, events.size()):
		keys.append(str(events[index].k))
	return keys

static func projection_hash(engine) -> String:
	return JSON.stringify(projection(engine), "", true).sha256_text()

## Model-independent projection (spec §13.5). It must stay identical while the
## effect system changes the state shape; state_digest() need not.
static func projection(engine) -> Dictionary:
	var state: Dictionary = engine.state
	var on_board: Dictionary = {}
	var lanes: Array = []
	for lane_index in range(state.lanes.size()):
		var lane: Dictionary = state.lanes[lane_index]
		var rows: Array = []
		for side in range(2):
			var row: Array = []
			for slot in range(lane.units[side].size()):
				var unit = lane.units[side][slot]
				if unit == null:
					row.append(null)
					continue
				on_board[int(unit.uid)] = true
				row.append(_unit(engine, unit, lane_index, slot))
			rows.append(row)
		var structures: Array = []
		for structure in lane.structures:
			structures.append({"health": int(structure.health), "ancient": bool(structure.ancient),
				"destroyed": bool(structure.destroyed)})
		lanes.append({"units": rows, "structures": structures, "mana": _ints(lane.mana),
			"max_mana": _ints(lane.max_mana), "mana_bonus": _ints(lane.mana_bonus)})
	var players: Array = []
	for owner in state.players:
		var off_board: Array = []
		for hero in owner.roster:
			if not on_board.has(int(hero.uid)):
				off_board.append(_unit(engine, hero, -1, -1))
		players.append({"gold": int(owner.gold), "hand": owner.hand.duplicate(),
			"deck_count": owner.deck.size(), "item_deck_count": owner.get("item_deck", []).size(),
			"shop": owner.get("shop", {}).duplicate(true), "held_secret": str(owner.get("held_secret", "")),
			"bought": owner.get("bought", []).duplicate(), "plans": owner.get("plans", {}).duplicate(true),
			"finished": bool(owner.finished), "off_board": off_board})
	return {"round": int(state.round), "lane": int(state.lane), "phase": str(state.phase),
		"active_player": int(state.active_player), "initiative": int(state.initiative),
		"first_pass": int(state.first_pass), "winner": int(state.winner),
		"pending_creeps": state.get("pending_creeps", []).duplicate(true),
		"rng_state": str(engine.rng.state), "next_id": int(engine.next_id),
		"lanes": lanes, "players": players}

static func _unit(engine, unit: Dictionary, lane_index: int, slot: int) -> Dictionary:
	var items: Dictionary = {}
	for key in unit.get("items", {}):
		items[str(key)] = str(unit.items[key])
	return {"uid": int(unit.uid), "card": str(unit.card), "owner": int(unit.owner),
		"lane": lane_index, "slot": slot, "attack": int(engine.attack_of(unit)),
		"armor": int(engine.armor_of(unit)), "max_health": int(engine.max_health_of(unit)),
		"health": int(unit.health), "arrow": int(unit.arrow), "combat_target": int(unit.combat_target),
		"cooldown": int(unit.cooldown), "ready_round": int(unit.ready_round), "items": items}

static func _ints(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(int(value))
	return result

## JSON numbers load as floats; restore whole numbers to ints so recorded
## commands compare equal to (and apply exactly like) live bot commands.
static func normalize(value):
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(normalize(item))
		return items
	if value is Dictionary:
		var entries: Dictionary = {}
		for key in value:
			entries[key] = normalize(value[key])
		return entries
	return value

## Serializes a suite with one JSON object per line so diffs point at the
## first diverging command. The output is valid JSON and byte-stable.
static func serialize(suite: String, records: Array) -> String:
	var lines: Array = ["{\"format\": %d, \"suite\": %s, \"protocol\": %d," % [FORMAT, JSON.stringify(suite), EngineClass.PROTOCOL_VERSION],
		"\"note\": \"Golden bot matches of the current engine. Re-record with tools/record_goldens.gd only for an intended rules change.\",",
		"\"games\": ["]
	for game_index in range(records.size()):
		var record: Dictionary = records[game_index]
		lines.append("{\"id\": %s, \"pack\": %s, \"seed\": %d, \"decks\": %s, \"max_steps\": %d, \"winner\": %d, \"step_count\": %d," % [
			JSON.stringify(record.id), JSON.stringify(record.pack), int(record.seed),
			JSON.stringify(record.decks), int(record.max_steps), int(record.winner), int(record.step_count)])
		lines.append("\"final_projection\": %s," % JSON.stringify(record.final_projection, "", true))
		lines.append("\"steps\": [")
		var steps: Array = record.steps
		for step_index in range(steps.size()):
			lines.append(JSON.stringify(steps[step_index], "", false) + ("," if step_index < steps.size() - 1 else ""))
		lines.append("]}" + ("," if game_index < records.size() - 1 else ""))
	lines.append("]}")
	return "\n".join(lines) + "\n"

static func load_suite(suite: String) -> Dictionary:
	if not FileAccess.file_exists(path_of(suite)):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_of(suite)))
	return parsed if parsed is Dictionary else {}
