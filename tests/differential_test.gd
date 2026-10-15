extends SceneTree
## Differential test (EFFECT_SYSTEM_SPEC.md §12, M1.2): for every migrated
## definition (49 Classic, 22 training) the rules engine must behave exactly
## like the frozen legacy engine (tests/legacy/, the hand-written effect
## switch it replaced). Cards added after the migration (M3 on) are not in the
## frozen data, so the definitions, board creeps, equipment and hand cards come
## from the legacy pack, the decks only from presets both packs define
## identically, and the shop pools (grown by M6) from the legacy pack. Each seeded fixture builds the same random board in
## both engines with the definition on the board or in hand, then plays random
## legal actions (favouring that card). After every step the legal actions,
## the model-independent projection (tests/golden/golden_games.gd), the random
## state and next_id must be equal.
##
## Options (after `--`): --fixtures N (default 200 per definition),
## --steps N (default 6), --card <id>.

const Goldens = preload("res://tests/golden/golden_games.gd")
const Legacy = preload("res://tests/legacy/legacy_engine.gd")
const EngineClass = preload("res://scripts/core/match_engine.gd")
const PACKS = ["artifact_classic_decks_v2", "original_training_fixtures"]
var checks = 0
var failures: Array = []
var fixtures_per_card = 200
var steps_per_fixture = 6

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if _option(args, "--fixtures") != "":
		fixtures_per_card = int(_option(args, "--fixtures"))
	if _option(args, "--steps") != "":
		steps_per_fixture = int(_option(args, "--steps"))
	var only = _option(args, "--card")
	var started = Time.get_ticks_msec()
	var definitions = 0
	var steps = 0
	for pack in PACKS:
		var library = Legacy.Library.new(pack)
		var ids: Array = []
		for hero in library.heroes:
			ids.append(str(hero.id))
		ids.append_array(library.cards.keys())
		for card_id in ids:
			if only != "" and card_id != only:
				continue
			definitions += 1
			var problem = ""
			for index in range(fixtures_per_card):
				var result = _fixture(pack, card_id, index)
				steps += int(result.steps)
				if result.problem != "":
					problem = result.problem
					break
			_check(problem == "", "Differential %s (%s): %s" % [card_id, pack, problem])
	print("%d definitions, %d fixtures each, %d steps in %.1f s" % [definitions, fixtures_per_card, steps,
		(Time.get_ticks_msec() - started) / 1000.0])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d differential checks (legacy effect switch vs rules engine)." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _option(args: PackedStringArray, name: String) -> String:
	var index = args.find(name)
	return args[index + 1] if index != -1 and index + 1 < args.size() else ""

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

## Builds one seeded fixture in both engines and plays it. Returns
## {"problem": "" or a description, "steps": n}.
func _fixture(pack: String, card_id: String, index: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = card_id.hash() * 131 + index * 7919 + 17
	var legacy = Legacy.new()
	legacy.library = Legacy.Library.new(pack)
	var modern = EngineClass.new()
	modern.library = EngineClass.Library.new(pack)
	var decks = ["starter", "starter"]
	if pack == "artifact_classic_decks_v2":
		# The shop pools grew with the M6 items (wiki Item Shop) after the
		# migration and the frozen pack keeps its M1 pools: the modern engine
		# sells from those pools here, so only the migration is compared.
		modern.library.catalog = modern.library.catalog.duplicate()
		for pool in ["secret_shop", "consumables"]:
			modern.library.catalog[pool] = legacy.library.catalog[pool].duplicate()
		var presets: Array = []
		for preset in legacy.library.presets():
			if JSON.stringify(preset) == JSON.stringify(modern.library.preset(str(preset.id))):
				presets.append(str(preset.id))
		decks = [presets[rng.randi_range(0, presets.size() - 1)], presets[rng.randi_range(0, presets.size() - 1)]]
	var game_seed = rng.randi_range(1, 1000000)
	legacy.start(game_seed, decks)
	modern.start(game_seed, decks)
	for engine in [legacy, modern]:
		for lane in engine.state.lanes:
			lane.units = [[], []]
		for owner in engine.state.players:
			owner.hand = []
			for hero in owner.roster:
				hero.lane = -1
	var definition = modern.library.definition(card_id)
	var kind = str(definition.get("kind", "hero"))
	var active_lane = rng.randi_range(0, 2)
	# Random units in every lane: roster heroes and pack creeps.
	var creeps: Array = []
	for id in legacy.library.cards:
		if str(legacy.library.cards[id].get("kind", "")) == "creep":
			creeps.append(str(id))
	var used_heroes = [{}, {}]
	for lane_index in range(3):
		for side in range(2):
			for slot in range(rng.randi_range(0, 3)):
				var roll = rng.randi_range(0, 2)
				var roster: Array = modern.state.players[side].roster
				var hero_index = rng.randi_range(0, roster.size() - 1)
				if roll == 0 and not used_heroes[side].has(hero_index):
					used_heroes[side][hero_index] = true
					_place_both(legacy, modern, legacy.state.players[side].roster[hero_index], roster[hero_index], lane_index, rng)
				else:
					var creep_id = creeps[rng.randi_range(0, creeps.size() - 1)]
					_place_both(legacy, modern, legacy._make_unit(legacy.library.definition(creep_id), side, false),
						modern._make_unit(modern.library.definition(creep_id), side, false), lane_index, rng)
	# The definition under test: on the board in the active lane, or in hand.
	var side_of_card = rng.randi_range(0, 1)
	if kind in ["hero", "creep"]:
		var old_unit = legacy._make_unit(legacy.library.definition(card_id), side_of_card, kind == "hero")
		var new_unit = modern._make_unit(definition, side_of_card, kind == "hero")
		if kind == "hero":
			# A hero under test joins its player's roster, as every hero in a
			# real match does (cooldowns tick and the Fountain applies).
			legacy.state.players[side_of_card].roster.append(old_unit)
			modern.state.players[side_of_card].roster.append(new_unit)
			used_heroes[side_of_card][modern.state.players[side_of_card].roster.size() - 1] = true
		_place_both(legacy, modern, old_unit, new_unit, active_lane, rng)
	# A hero of each colour in the active lane keeps colour gates passable.
	for side in range(2):
		var roster: Array = modern.state.players[side].roster
		var hero_index = rng.randi_range(0, roster.size() - 1)
		if not used_heroes[side].has(hero_index):
			used_heroes[side][hero_index] = true
			_place_both(legacy, modern, legacy.state.players[side].roster[hero_index], roster[hero_index], active_lane, rng)
	# Equipment on some heroes, then random damage.
	var equipment: Array = []
	for id in legacy.library.cards:
		var card = legacy.library.cards[id]
		if str(card.get("kind", "")) == "item" and card.has("slot") and not card.get("consumable", false):
			equipment.append(str(id))
	for lane_index in range(3):
		for side in range(2):
			for slot in range(legacy.state.lanes[lane_index].units[side].size()):
				var old = legacy.state.lanes[lane_index].units[side][slot]
				var new = modern.state.lanes[lane_index].units[side][slot]
				if old == null:
					continue
				if bool(old.hero) and rng.randi_range(0, 2) == 0 and not equipment.is_empty():
					var item_id = equipment[rng.randi_range(0, equipment.size() - 1)]
					var slot_name = str(legacy.library.cards[item_id].slot)
					old.items[slot_name] = item_id
					EngineClass.Zones.equip(modern, new, item_id)
	EngineClass.Stats.settle(modern)
	for lane_index in range(3):
		for side in range(2):
			for slot in range(legacy.state.lanes[lane_index].units[side].size()):
				var old = legacy.state.lanes[lane_index].units[side][slot]
				var new = modern.state.lanes[lane_index].units[side][slot]
				if old == null:
					continue
				var cap = legacy.max_health_of(old)
				var health = cap if rng.randi_range(0, 1) == 0 else rng.randi_range(1, cap)
				old.health = health
				new.health = health
				new["hp_seen"] = modern.max_health_of(new)
	# Hands: the card under test (spells and items) plus a few pack cards.
	var playable: Array = legacy.library.cards.keys().filter(func(id): return str(id) != "melee_creep")
	for side in range(2):
		var hand: Array = []
		if side == 0 and kind not in ["hero", "creep"]:
			hand.append(card_id)
		for extra in range(rng.randi_range(1, 3)):
			hand.append(str(playable[rng.randi_range(0, playable.size() - 1)]))
		if side == 0 and kind == "creep":
			hand.append(card_id)
		legacy.state.players[side].hand = hand.duplicate()
		modern.state.players[side].hand = hand.duplicate()
	var lane_mana: Array = []
	for lane_index in range(3):
		lane_mana.append([rng.randi_range(2, 12), rng.randi_range(2, 12)])
	for engine in [legacy, modern]:
		engine.state.lane = active_lane
		for lane_index in range(3):
			engine.state.lanes[lane_index].mana = lane_mana[lane_index].duplicate()
			engine.state.lanes[lane_index].max_mana = lane_mana[lane_index].duplicate()
		engine.state.active_player = 0
		engine.state.initiative = 0
		engine.state.first_pass = -1
		engine._roll_arrows()
	var problem = _compare(legacy, modern, "setup")
	var steps = 0
	while problem == "" and steps < steps_per_fixture and int(legacy.state.winner) == -1:
		var player = int(legacy.state.active_player) if legacy.state.phase == "action" else (1 if legacy.state.players[0].finished else 0)
		var legal_old = legacy.legal_actions(player)
		var legal_new = modern.legal_actions(player)
		if JSON.stringify(legal_old) != JSON.stringify(legal_new):
			problem = "step %d legal actions differ for player %d: legacy %s, new %s" % [steps, player, JSON.stringify(legal_old), JSON.stringify(legal_new)]
			break
		if legal_old.is_empty():
			break
		var command = _pick(legal_old, legacy, player, card_id, rng)
		var a = legacy.apply_action(player, command)
		var b = modern.apply_action(player, command)
		steps += 1
		if a.ok != b.ok:
			problem = "step %d %s: legacy ok %s, new ok %s" % [steps, JSON.stringify(command), a.ok, b.ok]
			break
		problem = _compare(legacy, modern, "step %d %s" % [steps, JSON.stringify(command)])
	return {"problem": "" if problem == "" else "fixture %d (seed %d, lane %d): %s" % [index, game_seed, active_lane, problem], "steps": steps}

func _place_both(legacy, modern, old: Dictionary, new: Dictionary, lane_index: int, rng: RandomNumberGenerator) -> void:
	var row: Array = legacy.state.lanes[lane_index].units[int(old.owner)]
	var open: Array = []
	for slot in range(row.size()):
		if row[slot] == null:
			open.append(slot)
	var position = open[rng.randi_range(0, open.size() - 1)] if not open.is_empty() and rng.randi_range(0, 1) == 0 else (row.size() if rng.randi_range(0, 1) == 0 else -1)
	if row.is_empty():
		position = 0
	legacy._place(old, lane_index, position)
	modern._place(new, lane_index, position)

## A random legal command, favouring plays and abilities of the card under test.
func _pick(legal: Array, engine, player: int, card_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var preferred: Array = []
	for command in legal:
		if str(command.get("type", "")) == "play" and str(engine.state.players[player].hand[int(command.hand)]) == card_id:
			preferred.append(command)
		elif str(command.get("type", "")) == "ability":
			preferred.append(command)
	if not preferred.is_empty() and rng.randi_range(0, 9) < 7:
		return preferred[rng.randi_range(0, preferred.size() - 1)]
	return legal[rng.randi_range(0, legal.size() - 1)]

func _compare(legacy, modern, where: String) -> String:
	if legacy.rng.state != modern.rng.state:
		return "%s: random state differs" % where
	if int(legacy.next_id) != int(modern.next_id):
		return "%s: next_id %d, now %d" % [where, legacy.next_id, modern.next_id]
	modern.frame_begin()
	var expected = Goldens.projection(legacy)
	var actual = Goldens.projection(modern)
	modern.frame_end()
	var paths: Array = []
	_diff("", expected, actual, paths)
	return "" if paths.is_empty() else "%s: projection differs at %s" % [where, ", ".join(paths.slice(0, 4))]

func _diff(path: String, expected, actual, paths: Array) -> void:
	if paths.size() >= 4:
		return
	if expected is Dictionary and actual is Dictionary:
		for key in expected:
			_diff("%s.%s" % [path, key], expected[key], actual.get(key), paths)
	elif expected is Array and actual is Array and expected.size() == actual.size():
		for index in range(expected.size()):
			_diff("%s[%d]" % [path, index], expected[index], actual[index], paths)
	elif typeof(expected) != typeof(actual) or expected != actual:
		paths.append("%s: %s -> %s" % [path, JSON.stringify(expected), JSON.stringify(actual)])
