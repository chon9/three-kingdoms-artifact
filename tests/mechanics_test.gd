extends SceneTree
## Milestone M2 acceptance (EFFECT_SYSTEM_SPEC.md §12 M2) on the rules fixture
## pack (tests/fixtures/rules_fixtures.json, CardLibrary.from_file):
## * the keyword matrix: at least three cases per keyword, flag and status,
##   tower stats included, with the interactions the spec names;
## * durations (round, next_combat, death, equip, used), Purge provenance and
##   the Fountain;
## * hand state: locks and their decay, discard, add_card, card counters,
##   hacks (resolution order and privacy);
## * zones: summon (a summoned hero joins the roster and returns from the
##   Fountain since M4, RQ-29), move, swap, control, to_fountain, with the
##   zone invariants after each;
## * objects: improvements and their cap, item instances with triggers,
##   actives and charges, deeds; the rules layer (round_draw, forbid_play,
##   secret_shop_discount, creep_lane);
## * preview_equals_combat on 2,000 random fixture boards;
## * the RQ decisions that land with these mechanics (rq_XX_* names);
## * regressions for the M2 review findings (fix_* names);
## * the engine capabilities added with the M3 cards (m3_* and rq_54_* names):
##   the `blocking` death snapshot, a Modify reaching a hero that died in the
##   same command, and granted text in mod/status events.
## Options (after --): --boards N (default 2000) for preview_equals_combat.

const EngineClass = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Combat = preload("res://scripts/core/rules/combat.gd")
const Select = preload("res://scripts/core/rules/select.gd")
const Invariants = preload("res://tests/invariants.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const FIXTURES = "res://tests/fixtures/rules_fixtures.json"
var checks = 0
var failures: Array = []
var library
var boards = 2000

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.has("--boards") and args.find("--boards") + 1 < args.size():
		boards = int(args[args.find("--boards") + 1])
	library = Library.from_file(FIXTURES, "rules_fixtures")
	for test in [_test_fixture_pack, _test_siege, _test_cleave, _test_retaliate, _test_regeneration, _test_bounty,
			_test_bonus_hero_tower, _test_pierce, _test_lethal, _test_damage_immunity, _test_death_shield, _test_stun,
			_test_silence, _test_disarm, _test_rapid_deployment, _test_soulbound, _test_tower_stats, _test_durations,
			_test_purge_and_fountain, _test_locks, _test_add_card_and_counters, _test_hacks, _test_summon_and_fountain,
			_test_move, _test_swap, _test_control, _test_zone_fuzz, _test_improvements, _test_items, _test_deeds,
			_test_rules_layer, _test_creep_lane, _test_taunt_and_end_phase, _test_hourglass_round_draw, _test_review_fixes, _test_m3_engine, _test_preview_equals_combat]:
		var started = Time.get_ticks_msec()
		test.call()
		if args.has("--timing"):
			print("%-36s %6d ms" % [test.get_method(), Time.get_ticks_msec() - started])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d M2 to M4 mechanics checks (keyword matrix, durations, Purge, Fountain, hand state, hacks, zones, summoned heroes returning (RQ-29), objects, rules layer, blocking snapshots, RQ-54, granted-text events, preview_equals_combat on %d boards)." % [
		"PASS" if failures.is_empty() else "FAIL", checks, boards])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

# --- Fixture boards -------------------------------------------------------------

## An engine on the fixture pack with an empty board, 20 mana in every lane,
## every hero in the Fountain (ready) and empty hands.
func _engine(seed_value: int = 17):
	var engine = EngineClass.new()
	engine.library = library
	engine.start(seed_value)
	for lane in engine.state.lanes:
		lane.units = [[], []]
		lane.mana = [20, 20]
		lane.max_mana = [20, 20]
		lane.max_mana_base = [20, 20]
		lane.mana_bonus = [0, 0]
	for owner in engine.state.players:
		owner.hand = []
		owner.hand_state = []
		for hero in owner.roster:
			hero.lane = -1
	engine.state.active_player = 0
	engine.state.initiative = 0
	engine.state.first_pass = -1
	engine.state.lane = 0
	engine.state.events = []
	return engine

## A fresh unit of `card_id` for `owner` in the first free (or a new right)
## position of `lane_index`.
func _unit(engine, card_id: String, owner: int, lane_index: int = 0) -> Dictionary:
	var definition = engine.library.definition(card_id)
	var unit = engine._make_unit(definition, owner, definition.get("kind", "") == "hero")
	var row = engine.state.lanes[lane_index].units[owner]
	var position = row.find(null)
	engine._place(unit, lane_index, position if position != -1 else row.size())
	return unit

## Sets lane `lane_index` to exact rows of card ids (null for an empty slot):
## [[player 0 ...], [player 1 ...]]. Returns the units in row order per side.
## Every arrow points straight ahead.
func _rows(engine, lane_index: int, rows: Array) -> Array:
	var made: Array = [[], []]
	var lane: Dictionary = engine.state.lanes[lane_index]
	var width = maxi(rows[0].size(), rows[1].size())
	lane.units = [[], []]
	for side in range(2):
		for slot in range(width):
			var card_id = rows[side][slot] if slot < rows[side].size() else null
			if card_id == null:
				lane.units[side].append(null)
				made[side].append(null)
				continue
			var unit: Dictionary
			if card_id is Dictionary:
				unit = card_id
			else:
				var definition = engine.library.definition(str(card_id))
				unit = engine._make_unit(definition, side, definition.get("kind", "") == "hero")
			unit.owner = side
			unit.lane = lane_index
			unit.arrow = 0
			unit.combat_target = -1
			lane.units[side].append(unit)
			made[side].append(unit)
	Stats.settle(engine)
	return made

## A roster hero of `colour` for `player`, placed in `lane_index`.
func _caster(engine, player: int, colour: String, lane_index: int = 0) -> Dictionary:
	for hero in engine.state.players[player].roster:
		if str(hero.color) == colour and int(hero.lane) == -1:
			var row = engine.state.lanes[lane_index].units[player]
			var position = row.find(null)
			engine._place(hero, lane_index, position if position != -1 else row.size())
			return hero
	_check(false, "Player %d has a %s hero in the Fountain" % [player, colour])
	return {}

## Plays `card_id` for `player` (puts it in hand first); returns the result.
func _play(engine, player: int, card_id: String, extra: Dictionary = {}) -> Dictionary:
	engine.state.active_player = player
	engine.state.first_pass = -1
	engine.state.players[player].hand = [card_id]
	engine.state.players[player].hand_state = [{"iid": Kernel.next_oid(engine)}]
	var command = {"type": "play", "hand": 0}
	command.merge(extra)
	return engine.apply_action(player, command)

## Both players pass: the active lane fights.
func _combat(engine) -> void:
	engine.state.active_player = int(engine.state.initiative)
	engine.state.first_pass = -1
	var first = int(engine.state.active_player)
	engine.apply_action(first, {"type": "pass"})
	engine.apply_action(1 - first, {"type": "pass"})

func _events(engine, key: String) -> Array:
	return engine.state.events.filter(func(event): return str(event.get("k", "")) == key)

func _tower(engine, lane_index: int, player: int) -> Dictionary:
	return engine.state.lanes[lane_index].structures[player]

## Gives tower (lane, player) `armor` this round.
func _tower_armor(engine, lane_index: int, player: int, armor: int) -> void:
	Kernel.give(engine, {"tower": true, "lane": lane_index, "p": player}, {"armor": armor}, {}, "", "round", {"controller": player, "card": ""})

func _improve(engine, card_id: String, owner: int, lane_index: int) -> Dictionary:
	return Zones.add_improvement(engine, card_id, owner, lane_index)

# --- The fixture pack -----------------------------------------------------------

func _test_fixture_pack() -> void:
	_check(library.errors.is_empty(), "The rules fixture pack compiles without errors: %s" % [library.errors.slice(0, 5)])
	_check(library.warnings.is_empty(), "The rules fixture pack compiles without warnings: %s" % [library.warnings.slice(0, 5)])
	_check(not Library.PACKS.has("rules_fixtures") and Library.known_pack("rules_fixtures"), "The fixture pack is a known test pack, never in PACKS")
	_check(str(library.content_pack) == "rules_fixtures" and library.cards.has("fx_cleave_3") and library.cards.has("no_accident"),
		"The fixture pack extends the Classic pack")
	_check(not Library.new().cards.has("fx_cleave_3"), "Loading the fixture pack leaves the Classic pack untouched")
	var shipped = Library.new()
	for preset in shipped.presets():
		for card_id in preset.cards.keys() + preset.items.keys() + preset.heroes:
			_check(not str(card_id).begins_with("fx_"), "Shipped preset %s holds no fixture card (%s)" % [preset.id, card_id])
	var exports = FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(exports.find("tests/*") != -1, "Exports exclude tests/ (the fixture pack)")
	_check(Library.loc("fx_cleave_3", "name", "en") == "Cleaving Brute" and Library.loc("fx_cleave_3", "name", "zh_CN") == "横扫兵",
		"Fixture cards carry their own bilingual names")
	_check(int(Library.compiled_rules("fx_cleave_3").keywords.get("cleave", 0)) == 3, "Static rule lookups find fixture cards")

# --- Keyword matrix -------------------------------------------------------------

## Siege (RQ-07): only when blocked (diagonals included) and not disarmed;
## the enemy tower takes siege minus its armor.
func _test_siege() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_siege_3"], ["fx_retaliate_2"]])
	_tower_armor(engine, 0, 1, 1)
	var before = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == before - 2, "kw_siege_1: a blocked siege unit deals siege minus tower armor (3 - 1) to the tower (%d)" % (before - int(_tower(engine, 0, 1).health)))
	engine = _engine()
	made = _rows(engine, 0, [["fx_siege_3"], [null]])
	made[0][0].attack = 0
	before = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == before, "kw_siege_2: an unblocked siege unit adds no siege (attack 0 hits the tower for 0)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_siege_3"], ["fx_retaliate_2"]])
	Kernel.give(engine, made[0][0], {}, {"disarm": 1}, "", "round", {"controller": 1, "card": "fx_disarm_spell"})
	before = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == before, "kw_siege_3: a disarmed siege unit adds no siege")
	engine = _engine()
	made = _rows(engine, 0, [["fx_siege_3", null], [null, "fx_retaliate_2"]])
	made[0][0].arrow = 1
	_tower_armor(engine, 0, 1, 1)
	before = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == before - 2, "kw_siege_4: siege counts for a diagonal blocker too (RQ-07)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_siege_3"], ["fx_retaliate_2"]])
	Kernel.give(engine, made[0][0], {}, {"pierce": 1}, "", "round", {"controller": 0, "card": ""})
	_tower_armor(engine, 0, 1, 1)
	before = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == before - 3, "kw_siege_5: siege with pierce ignores tower armor")

## Cleave (RQ-08): the target's allied neighbors take cleave minus armor.
func _test_cleave() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [[null, "fx_cleave_3", null], ["fx_retaliate_2", "melee_creep", "fx_retaliate_2"]])
	_combat(engine)
	_check(int(made[1][0].health) == 7 - 2 and int(made[1][2].health) == 7 - 2, "kw_cleave_1: cleave hits both allied neighbors of the target through their armor (3 - 1)")
	engine = _engine()
	made = _rows(engine, 0, [[null, "fx_cleave_3", null], ["fx_retaliate_2", "melee_creep", "fx_retaliate_2"]])
	Kernel.give(engine, made[0][1], {}, {"pierce": 1}, "", "round", {"controller": 0, "card": ""})
	_combat(engine)
	_check(int(made[1][0].health) == 7 - 3 and int(made[1][2].health) == 7 - 3, "kw_cleave_2: cleave with pierce ignores the neighbors' armor")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3", null], [null, "fx_retaliate_2"]])
	_combat(engine)
	_check(int(made[1][1].health) == 7, "kw_cleave_3: an unblocked cleave unit cleaves nothing")
	engine = _engine()
	made = _rows(engine, 0, [[null, "fx_cleave_3", null], ["fx_retaliate_2", "melee_creep", "fx_retaliate_2"]])
	Kernel.give(engine, made[0][1], {}, {"disarm": 1}, "", "round", {"controller": 1, "card": ""})
	_combat(engine)
	_check(int(made[1][0].health) == 7 and int(made[1][1].health) == 4, "kw_cleave_4: a disarmed cleave unit neither attacks nor cleaves")

## Retaliate (RQ-06): every attacker of the unit (or tower) takes retaliate
## minus its armor, even from a stunned defender; nothing hits an attacker
## that does not attack.
func _test_retaliate() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_cleave_3"], ["fx_retaliate_2"]])
	_combat(engine)
	_check(int(made[0][0].health) == 6 - 1 - 2, "kw_retaliate_1: the attacker takes its target's attack and retaliate 2")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], ["fx_retaliate_2"]])
	Kernel.give(engine, made[1][0], {}, {"stun": 1}, "", "round", {"controller": 0, "card": "fx_stun_spell"})
	_combat(engine)
	_check(int(made[0][0].health) == 6 - 2, "kw_retaliate_2: a stunned defender still retaliates (and does not attack)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], ["fx_retaliate_2"]])
	Kernel.give(engine, made[0][0], {}, {"disarm": 1}, "", "round", {"controller": 1, "card": "fx_disarm_spell"})
	_combat(engine)
	_check(int(made[0][0].health) == 6 - 1, "kw_retaliate_3: a disarmed attacker that does not attack takes no retaliation")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], [null]])
	_improve(engine, "fx_tower_guard", 1, 0)
	_combat(engine)
	_check(int(made[0][0].health) == 6 - 2, "kw_retaliate_4: a tower with Retaliate 2 hits its unblocked attacker")
	engine = _engine()
	made = _rows(engine, 0, [["axe"], ["fx_retaliate_2"]])
	var axe: Dictionary = made[0][0]
	_caster(engine, 0, "red")
	axe.health = 10
	axe.armor = 0
	_check(_play(engine, 0, "berserkers_call", {"target": axe.uid}).ok, "Berserker's Call plays")
	_check(int(axe.health) == 10 - 1 - 2, "kw_retaliate_5: retaliate answers in a battle outside combat (%d)" % int(axe.health))

## Regeneration (RQ-09): in the combat phase, after damage and before the
## death check, capped at the maximum; towers too unless they fell.
func _test_regeneration() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_regen_2"], ["fx_cleave_3"]])
	_combat(engine)
	_check(int(made[0][0].health) == 5 - 2 + 2, "kw_regeneration_1: a unit regenerates after taking combat damage")
	engine = _engine()
	made = _rows(engine, 0, [["fx_regen_2"], ["fx_cleave_3"]])
	made[0][0].health = 2
	var preview = engine.combat_preview(0)
	_check(not preview.dies.has(int(made[0][0].uid)) and int(preview.heal.get(str(made[0][0].uid), 0)) == 2, "The preview shows regeneration saving the unit")
	_combat(engine)
	_check(int(made[0][0].lane) == 0 and int(made[0][0].health) == 2, "kw_regeneration_2: regeneration saves a unit dealt exactly its health (2 - 2 + 2)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_regen_2"], [null]])
	made[0][0].health = 4
	made[0][0].attack = 0
	_combat(engine)
	_check(int(made[0][0].health) == 5, "kw_regeneration_3: an unattacked unit regenerates up to its maximum, not beyond (4 + 2 capped at 5)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], [null]])
	_improve(engine, "fx_tower_guard", 1, 0)
	_tower(engine, 0, 1).health = 30
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == 30 - 1 + 1, "kw_regeneration_4: a tower regenerates in the combat phase (30 - 1 + 1)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], [null]])
	_improve(engine, "fx_tower_guard", 1, 0)
	_tower(engine, 0, 1).health = 1
	_combat(engine)
	_check(bool(_tower(engine, 0, 1).ancient) and int(_tower(engine, 0, 1).health) == 80, "kw_regeneration_5: a tower that fell this combat does not regenerate its ancient")

## Bounty (RQ-02): the dead unit's opponent gains max(0, bounty); 5 for
## heroes and 1 for creeps unless modified or printed.
func _test_bounty() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["melee_creep", "fx_bounty_creep"], ["axe", "keefe"]])
	var gold = int(engine.state.players[1].gold)
	made[0][0].health = 0
	made[0][1].health = 0
	engine._clean_dead(0)
	_check(int(engine.state.players[1].gold) == gold + 1 + 4, "kw_bounty_1: a creep pays its default bounty 1 and a printed Bounty 4 pays 4")
	gold = int(engine.state.players[0].gold)
	made[1][0].health = 0
	engine._clean_dead(0)
	_check(int(engine.state.players[0].gold) == gold + 5, "kw_bounty_2: a hero pays bounty 5")
	engine = _engine()
	made = _rows(engine, 0, [["fx_bounty_creep"], ["axe"]])
	Kernel.modify(engine, made[0][0], {}, {"bounty": -9}, "", {"controller": 1, "card": ""})
	_check(engine.keyword_of(made[0][0], "bounty") == -5, "keyword_of reads the derived bounty")
	gold = int(engine.state.players[1].gold)
	made[0][0].health = 0
	engine._clean_dead(0)
	_check(int(engine.state.players[1].gold) == gold, "kw_bounty_3: a negative bounty pays nothing (max 0)")
	var badges = []
	engine = _engine()
	made = _rows(engine, 0, [["fx_bounty_creep"], ["melee_creep"]])
	badges = engine.badges(made[0][0])
	_check(badges.any(func(badge): return str(badge.k) == "bounty" and int(badge.v) == 4) and not engine.badges(made[1][0]).any(func(badge): return str(badge.k) == "bounty"),
		"kw_bounty_4: a bounty that differs from its base shows a badge; the default does not")

## Bonus against heroes and towers (Debbi 2/2, Phantom Assassin 4/0).
func _test_bonus_hero_tower() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["debbi", "phantom_assassin"], ["axe", "keefe"]])
	var axe_health = int(made[1][0].health)
	var keefe_health = int(made[1][1].health)
	var debbi = engine.attack_of(made[0][0])
	var assassin = engine.attack_of(made[0][1])
	_combat(engine)
	_check(int(made[1][0].health) == axe_health - (debbi + 2 - int(made[1][0].armor)), "kw_bonus_hero_1: Debbi deals +2 to a hero")
	_check(int(made[1][1].health) == keefe_health - (assassin + 4 - int(made[1][1].armor)), "kw_bonus_hero_2: Phantom Assassin deals +4 to a hero")
	engine = _engine()
	made = _rows(engine, 0, [["debbi", "phantom_assassin"], [null, null]])
	var tower = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == tower - (debbi + 2) - assassin, "kw_bonus_tower_1: Debbi deals +2 to a tower; Phantom Assassin has no tower bonus")
	engine = _engine()
	made = _rows(engine, 0, [["debbi"], ["fx_retaliate_2"]])
	_combat(engine)
	_check(int(made[1][0].health) == 7 - (debbi - 1), "kw_bonus_hero_3: no bonus against a creep")
	engine = _engine()
	made = _rows(engine, 0, [["fx_siege_3", "melee_creep"], ["fx_retaliate_2", null]])
	for unit in made[0]:
		Kernel.give(engine, unit, {}, {"bonus_tower": 2}, "", "round", {"controller": 0, "card": ""})
	tower = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == tower - 3 - (2 + 2), "kw_bonus_tower_2: a granted tower bonus adds to an unblocked attack, never to siege")
	_check(int(made[1][0].health) == 7 - (2 - 1), "kw_bonus_tower_3: no tower bonus against a unit")

## Pierce: all battle damage the unit deals ignores armor.
func _test_pierce() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_pierce_creep"], ["fx_retaliate_2"]])
	_combat(engine)
	_check(int(made[1][0].health) == 7 - 3, "kw_pierce_1: a piercing attack ignores armor (3 against armor 1)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_retaliate_2"], ["melee_creep"]])
	made[0][0].armor = 0
	made[1][0].armor = 3
	Kernel.give(engine, made[0][0], {}, {"pierce": 1}, "", "round", {"controller": 0, "card": ""})
	_combat(engine)
	_check(int(made[1][0].health) == 4 - 1 - 2, "kw_pierce_2: a piercing unit's retaliate ignores the attacker's armor (attack 1 + retaliate 2 through armor 3)")
	engine = _engine()
	made = _rows(engine, 0, [["fx_pierce_creep"], [null]])
	_improve(engine, "fx_tower_guard", 1, 0)
	var tower = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(_tower(engine, 0, 1).health) == tower - 3 + 1, "kw_pierce_3: a piercing attack on the tower ignores tower armor (regeneration 1 after)")

## Lethal (RQ-10): battle damage above 0 condemns; immunity (0 damage) and a
## Death Shield stop it; lethal_creeps and lethal_heroes filter by kind.
func _test_lethal() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_lethal_creep"], ["centaur_hunter"]])
	_combat(engine)
	_check(int(made[1][0].lane) == -1, "kw_lethal_1: battle damage above 0 from a Lethal unit condemns the victim")
	engine = _engine()
	made = _rows(engine, 0, [["fx_lethal_creep"], ["centaur_hunter"]])
	Kernel.give(engine, made[1][0], {}, {"damage_immunity": 1}, "", "round", {"controller": 1, "card": "fx_immunity_spell"})
	_combat(engine)
	_check(int(made[1][0].lane) == 0, "kw_lethal_2: Lethal against Damage Immunity deals 0 and condemns nothing")
	engine = _engine()
	made = _rows(engine, 0, [["fx_lethal_creep"], ["centaur_hunter"]])
	Kernel.give(engine, made[1][0], {}, {"death_shield": 1}, "", "used", {"controller": 1, "card": "fx_shield_spell"})
	_combat(engine)
	_check(int(made[1][0].lane) == 0 and int(made[1][0].health) == 1 and not engine.has_flag(made[1][0], "death_shield"),
		"kw_lethal_3: a Death Shield saves the Lethal victim once at 1 health")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3", "fx_cleave_3"], ["fx_retaliate_2", "keefe"]])
	Kernel.give(engine, made[0][0], {}, {"lethal_heroes": 1}, "", "round", {"controller": 0, "card": ""})
	Kernel.give(engine, made[0][1], {}, {"lethal_heroes": 1}, "", "round", {"controller": 0, "card": ""})
	var keefe: Dictionary = made[1][1]
	_combat(engine)
	_check(int(made[1][0].lane) == 0 and int(keefe.lane) == -1, "kw_lethal_4: lethal_heroes condemns a hero it damages (cleave included) and spares creeps")
	engine = _engine()
	made = _rows(engine, 0, [["keefe"], ["fx_retaliate_2"]])
	Zones.equip(engine, made[0][0], "fx_lethal_item")
	Stats.settle(engine)
	_check(engine.has_flag(made[0][0], "lethal") and engine.badges(made[0][0]).any(func(badge): return str(badge.k) == "lethal"), "An item's host aura grants Lethal")
	_combat(engine)
	_check(int(made[1][0].lane) == -1, "kw_lethal_5: an equipped Lethal item condemns the blocker")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3", "fx_cleave_3"], ["fx_retaliate_2", "keefe"]])
	for unit in made[0]:
		Kernel.give(engine, unit, {}, {"lethal_creeps": 1}, "", "round", {"controller": 0, "card": ""})
	_combat(engine)
	_check(int(made[1][0].lane) == -1 and int(made[1][1].lane) == 0, "kw_lethal_creeps_1: lethal_creeps condemns creeps and spares heroes")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], ["fx_retaliate_2"]])
	Kernel.give(engine, made[1][0], {}, {"lethal": 1}, "", "round", {"controller": 1, "card": ""})
	_combat(engine)
	_check(int(made[0][0].lane) == -1, "kw_lethal_6: Lethal applies to retaliate damage too (all battle damage)")
	engine = _engine()
	made = _rows(engine, 0, [["axe"], ["fx_retaliate_2"]])
	made[0][0].armor = 0
	Kernel.give(engine, made[1][0], {}, {"lethal_heroes": 1}, "", "round", {"controller": 1, "card": ""})
	_caster(engine, 0, "red")
	_play(engine, 0, "berserkers_call", {"target": made[0][0].uid})
	_check(int(made[0][0].lane) == -1, "kw_lethal_heroes_2: Lethal works in battles outside combat")

## Damage Immunity (RQ-10): damage becomes 0, no battle damage event, condemn still kills.
func _test_damage_immunity() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["melee_creep"], ["fx_retaliate_2"]])
	_caster(engine, 0, "black")
	Kernel.give(engine, made[1][0], {}, {"damage_immunity": 1}, "", "round", {"controller": 1, "card": "fx_immunity_spell"})
	_play(engine, 0, "no_accident", {"target": made[1][0].uid})
	_check(int(made[1][0].health) == 7, "kw_damage_immunity_1: spell damage becomes 0")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], ["fx_retaliate_2"]])
	Kernel.give(engine, made[1][0], {}, {"damage_immunity": 1}, "", "round", {"controller": 1, "card": ""})
	var seen = engine.state.events.size()
	_combat(engine)
	var strikes: Array = _events(engine, "combat").back().strikes
	_check(int(made[1][0].health) == 7 and strikes.any(func(strike): return int(strike[1]) == int(made[1][0].uid) and int(strike[2]) == 0),
		"kw_damage_immunity_2: combat damage to an immune unit is 0 (a 0 strike)")
	engine = _engine()
	made = _rows(engine, 0, [["melee_creep"], ["fx_retaliate_2"]])
	_caster(engine, 0, "black")
	Kernel.give(engine, made[1][0], {}, {"damage_immunity": 1}, "", "round", {"controller": 1, "card": ""})
	_play(engine, 0, "slay", {"target": made[1][0].uid})
	_check(int(made[1][0].lane) == -1, "kw_damage_immunity_3: condemn still kills an immune unit")

## Death Shield (RQ-11): instead of dying, lose the shield and stay at 1
## health; at most one; consumed (until used) or ended with its duration.
func _test_death_shield() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["melee_creep"], ["fx_retaliate_2"]])
	_caster(engine, 0, "green")
	_caster(engine, 1, "black")
	_check(_play(engine, 0, "fx_shield_spell", {"target": made[0][0].uid}).ok, "Death Ward plays on an ally")
	_play(engine, 1, "slay", {"target": made[0][0].uid})
	_check(int(made[0][0].lane) == 0 and int(made[0][0].health) == 1 and not engine.has_flag(made[0][0], "death_shield"),
		"kw_death_shield_1: a shield saves from condemn once, at 1 health")
	engine = _engine()
	made = _rows(engine, 0, [["melee_creep"], ["fx_cleave_3"]])
	_caster(engine, 0, "green")
	_play(engine, 0, "fx_shield_spell", {"target": made[0][0].uid})
	_play(engine, 0, "fx_shield_spell", {"target": made[0][0].uid})
	_check(made[0][0].mods.filter(func(entry): return int(entry.kw.get("death_shield", 0)) > 0).size() == 1, "kw_death_shield_2: a second shield does nothing (RQ-11)")
	made[0][0].health = 1
	_combat(engine)
	_check(int(made[0][0].lane) == 0 and int(made[0][0].health) == 1, "kw_death_shield_3: a shield saves from lethal combat damage")
	_check(not _events(engine, "shield").is_empty(), "Shield consumption is logged")
	engine = _engine()
	made = _rows(engine, 0, [["melee_creep"], ["fx_cleave_3"]])
	Kernel.give(engine, made[0][0], {}, {"death_shield": 1}, "", "round", {"controller": 0, "card": ""})
	engine._begin_deployment()
	_check(not engine.has_flag(made[0][0], "death_shield"), "kw_death_shield_4: a shield given this round ends at round end when unused")

## Stun: no attacks, no abilities, no casting colour; counts as silence and disarm.
func _test_stun() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_cleave_3"], ["melee_creep"]])
	_caster(engine, 1, "blue")
	_play(engine, 1, "fx_stun_spell", {"target": made[0][0].uid})
	_check(bool(made[0][0].stunned) and bool(made[0][0].silenced) and bool(made[0][0].disarmed), "Stun mirrors as stunned, silenced and disarmed")
	_combat(engine)
	_check(int(made[1][0].health) == 4, "kw_stun_1: a stunned unit does not attack")
	engine = _engine()
	var hero = _caster(engine, 0, "blue")
	_rows(engine, 0, [[hero], ["melee_creep"]])
	Kernel.give(engine, hero, {}, {"stun": 1}, "", "round", {"controller": 1, "card": ""})
	engine.state.players[0].hand = ["fx_stun_spell"]
	engine.state.players[0].hand_state = [{"iid": Kernel.next_oid(engine)}]
	_check(not engine.legal_actions(0).any(func(action): return str(action.type) == "play"), "kw_stun_2: a stunned hero gives no casting colour")
	_check(not engine.legal_actions(0).any(func(action): return str(action.type) == "ability"), "kw_stun_3: a stunned J'Muy cannot use its active ability")
	engine._begin_deployment()
	_check(not engine.has_flag(hero, "stun"), "kw_stun_4: a stun this round ends with the round")

## Silence (RQ-31): no active abilities (item actives included) and no casting colour; it still attacks.
func _test_silence() -> void:
	var engine = _engine()
	var hero = _caster(engine, 0, "blue")
	var made = _rows(engine, 0, [[hero], ["fx_retaliate_2"]])
	Kernel.give(engine, hero, {}, {"silence": 1}, "", "round", {"controller": 1, "card": "act_of_defiance"})
	_check(not engine.legal_actions(0).any(func(action): return str(action.type) == "ability"), "kw_silence_1: a silenced unit has no active ability")
	engine.state.players[0].hand = ["foresight"]
	engine.state.players[0].hand_state = [{"iid": Kernel.next_oid(engine)}]
	_check(engine.legal_actions(0).size() == 1, "kw_silence_2: a silenced hero gives no casting colour")
	var before = int(made[1][0].health)
	_combat(engine)
	_check(int(made[1][0].health) < before, "kw_silence_3: a silenced unit still attacks")
	engine = _engine()
	var keefe = _caster(engine, 0, "red")
	Zones.equip(engine, keefe, "fx_blink_item")
	var oid = int(keefe.item_state.accessory.oid)
	_check(engine.legal_actions(0).any(func(action): return str(action.type) == "ability" and int(action.unit) == oid), "An item active is usable from its host's lane")
	Kernel.give(engine, keefe, {}, {"silence": 1}, "", "round", {"controller": 1, "card": ""})
	_check(not engine.legal_actions(0).any(func(action): return str(action.type) == "ability" and int(action.unit) == oid), "kw_silence_4: a silenced host cannot use its item's active")

## Disarm: no attacks; the unit still blocks and still retaliates.
func _test_disarm() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_cleave_3"], ["fx_retaliate_2"]])
	_caster(engine, 1, "red")
	_play(engine, 1, "fx_disarm_spell", {"target": made[0][0].uid})
	_combat(engine)
	_check(int(made[1][0].health) == 7, "kw_disarm_1: a disarmed unit does not attack")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3"], ["fx_retaliate_2"]])
	Kernel.give(engine, made[1][0], {}, {"disarm": 1}, "", "round", {"controller": 0, "card": ""})
	var tower = int(_tower(engine, 0, 1).health)
	_combat(engine)
	_check(int(made[1][0].health) < 7 and int(_tower(engine, 0, 1).health) == tower, "kw_disarm_2: a disarmed unit still blocks its attacker")
	_check(int(made[0][0].health) == 6 - 2, "kw_disarm_3: a disarmed unit still retaliates")

## Rapid deployment: a hero that dies is ready the next round.
func _test_rapid_deployment() -> void:
	var engine = _engine()
	var round_now = int(engine.state.round)
	var made = _rows(engine, 0, [["axe"], ["melee_creep"]])
	var axe: Dictionary = made[0][0]
	axe.health = 0
	engine._clean_dead(0)
	_check(int(axe.ready_round) == round_now + 2, "kw_rapid_deployment_1: a normal hero is ready two rounds later")
	engine = _engine()
	made = _rows(engine, 0, [["rix"], ["melee_creep"]])
	made[0][0].health = 0
	engine._clean_dead(0)
	_check(int(made[0][0].ready_round) == round_now + 1,
		"kw_rapid_deployment_2: Rix (Rapid Deployment) is ready the next round")
	engine = _engine()
	var hero = engine.state.players[0].roster[0]
	_rows(engine, 0, [[hero], ["melee_creep"]])
	Kernel.modify(engine, hero, {}, {"rapid_deployment": 1}, "", {"controller": 0, "card": ""})
	hero.health = 0
	engine._clean_dead(0)
	_check(int(hero.ready_round) == round_now + 1 and int(hero.lane) == -1, "kw_rapid_deployment_3: a granted Rapid Deployment works generically")

## Soulbound (RQ-39): a dying Soulbound unit condemns allied units of the
## same card in every lane; shields apply after the closure.
func _test_soulbound() -> void:
	var engine = _engine()
	var one = _unit(engine, "fx_soulbound_creep", 0, 0)
	var two = _unit(engine, "fx_soulbound_creep", 0, 2)
	var theirs = _unit(engine, "fx_soulbound_creep", 1, 1)
	_unit(engine, "melee_creep", 1, 0)
	_unit(engine, "melee_creep", 0, 1)
	one.health = 0
	engine._clean_dead(0)
	_check(int(one.lane) == -1 and int(two.lane) == -1, "kw_soulbound_1: a dying Soulbound unit takes its allied twins in every lane")
	_check(int(theirs.lane) == 1, "kw_soulbound_2: enemy units of the same card are not condemned")
	engine = _engine()
	one = _unit(engine, "fx_soulbound_creep", 0, 0)
	two = _unit(engine, "fx_soulbound_creep", 0, 1)
	Kernel.give(engine, two, {}, {"death_shield": 1}, "", "used", {"controller": 0, "card": ""})
	one.condemned = true
	engine._clean_dead(0)
	_check(int(one.lane) == -1 and int(two.lane) == 1 and int(two.health) == 1, "kw_soulbound_3: rq_39_soulbound_shield: a shielded twin survives the closure")
	engine = _engine()
	one = _unit(engine, "fx_soulbound_creep", 0, 0)
	var other = _unit(engine, "fx_cleave_3", 0, 0)
	one.health = 0
	engine._clean_dead(0)
	_check(int(other.lane) == 0, "kw_soulbound_4: allies of another card are unaffected")

## Tower stats: armor (reduces non-piercing tower damage, siege included),
## mana (give/modify), retaliate and regeneration (above).
func _test_tower_stats() -> void:
	var engine = _engine()
	_caster(engine, 0, "blue")
	var guard = _improve(engine, "fx_tower_guard", 1, 0)
	var stats = engine.tower_stats(0, 1)
	_check(int(stats.armor) == 1 and int(stats.retaliate) == 2 and int(stats.regeneration) == 1, "kw_tower_1: an improvement aura gives its own tower armor, retaliate and regeneration")
	_check(int(engine.tower_stats(0, 0).armor) == 0 and int(engine.tower_stats(1, 1).armor) == 0, "kw_tower_2: the aura reaches only its side's tower in its lane")
	var before = int(_tower(engine, 0, 1).health)
	_play(engine, 0, "lightning_strike")
	_check(int(_tower(engine, 0, 1).health) == before - 5, "kw_tower_3: tower armor reduces spell tower damage (6 - 1)")
	Kernel.give(engine, {"tower": true, "lane": 1, "p": 0}, {"armor": 2}, {}, "", "round", {"controller": 0, "card": ""})
	_check(int(engine.tower_stats(1, 0).armor) == 2, "kw_tower_4: a temporary tower armor entry derives")
	engine._begin_deployment()
	_check(int(engine.tower_stats(1, 0).armor) == 0, "kw_tower_5: it ends with the round")
	engine = _engine()
	var lane: Dictionary = engine.state.lanes[0]
	Kernel.modify(engine, {"tower": true, "lane": 0, "p": 1}, {"mana": -3}, {}, "", {"controller": 0, "card": "fx_curse_spell"})
	_check(int(lane.max_mana[1]) == 17 and int(lane.mana[1]) == 17 and int(lane.max_mana_base[1]) == 17, "kw_tower_6: a permanent tower mana modify writes the base (CF-5)")
	Kernel.purge(engine, {"tower": true, "lane": 0, "p": 1}, "opponent", {"controller": 1, "card": ""})
	_check(int(lane.max_mana[1]) == 20 and int(lane.mana[1]) == 20, "kw_tower_7: Purge reverses the opponent's tower mana modify")

# --- Durations, Purge and the Fountain ---------------------------------------------

## round, next_combat (its own lane, and following a move), death, equip, used.
func _test_durations() -> void:
	var engine = _engine()
	var near = _unit(engine, "melee_creep", 0, 0)
	var far = _unit(engine, "melee_creep", 0, 1)
	_unit(engine, "melee_creep", 1, 0)
	_unit(engine, "melee_creep", 1, 1)
	for unit in [near, far]:
		Kernel.give(engine, unit, {"attack": 3}, {}, "", "next_combat", {"controller": 0, "card": "fx_next_combat_spell"})
	_combat(engine)
	_check(engine.attack_of(near) == 2 and engine.attack_of(far) == 5, "dur_next_combat_1: next_combat ends with the combat of the unit's own lane only")
	engine._begin_deployment()
	_check(engine.attack_of(far) == 5, "dur_next_combat_2: next_combat survives the end of the round")
	engine = _engine()
	var mover = _unit(engine, "melee_creep", 0, 0)
	_unit(engine, "melee_creep", 1, 0)
	_unit(engine, "melee_creep", 1, 1)
	Kernel.give(engine, mover, {"attack": 3}, {}, "", "next_combat", {"controller": 0, "card": "fx_next_combat_spell"})
	Zones.move(engine, mover, 1, null)
	_combat(engine)
	_check(int(engine.state.lane) == 1 and engine.attack_of(mover) == 5, "dur_next_combat_3: a moved unit keeps next_combat past its old lane's combat")
	_combat(engine)
	_check(engine.attack_of(mover) == 2, "dur_next_combat_4: it ends with the combat of the lane it moved to")
	engine = _engine()
	var hero = engine.state.players[0].roster[0]
	_rows(engine, 0, [[hero], ["melee_creep"]])
	_caster(engine, 0, "red")
	_check(_play(engine, 0, "fx_death_mark", {"target": hero.uid}).ok, "Fight to the Death plays")
	engine._begin_deployment()
	_check(engine.armor_of(hero) == int(hero.armor) + 2, "dur_death_1: until death outlasts the round")
	hero.health = 0
	engine._clean_dead(0)
	_check(engine.armor_of(hero) == int(hero.armor) and hero.mods.is_empty(), "dur_death_2: until death ends when the hero dies")
	engine = _engine()
	hero = engine.state.players[0].roster[0]
	_rows(engine, 0, [[hero], ["melee_creep"]])
	_caster(engine, 0, "green")
	_check(_play(engine, 0, "fx_equip_stun", {"target": hero.uid}).ok, "Caught Off Guard plays")
	engine._begin_deployment()
	engine.state.phase = "action"
	_check(engine.has_flag(hero, "stun"), "dur_equip_1: until equip outlasts the round (Caught Unprepared across rounds)")
	_hand(engine, 0, ["short_sword"])
	engine.state.active_player = 0
	var equip = {"type": "play", "hand": 0, "target": hero.uid}
	_check(equip in engine.legal_actions(0) and engine.apply_action(0, equip).ok, "rq_35_equip_while_stunned: a stunned hero may equip")
	_check(not engine.has_flag(hero, "stun"), "dur_equip_2: equipping any item ends until-equip effects")
	Kernel.give(engine, hero, {}, {"stun": 1}, "", "equip", {"controller": 1, "card": "fx_equip_stun"})
	hero.health = 0
	engine._clean_dead(0)
	_check(not engine.has_flag(hero, "stun"), "dur_equip_3: the Fountain ends until-equip effects too")
	engine = _engine()
	var unit = _unit(engine, "melee_creep", 0, 0)
	Kernel.give(engine, unit, {}, {"death_shield": 1}, "", "used", {"controller": 0, "card": "fx_shield_spell"})
	engine._begin_deployment()
	_check(engine.has_flag(unit, "death_shield"), "dur_used_1: until used outlasts the round")
	unit.condemned = true
	engine._clean_dead(0)
	_check(not engine.has_flag(unit, "death_shield") and int(unit.lane) == 0, "dur_used_2: it ends when consumed")

## Purge provenance (RQ-12) and the Fountain (RQ-13).
func _test_purge_and_fountain() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["melee_creep"], ["melee_creep"]])
	var unit: Dictionary = made[0][0]
	_caster(engine, 0, "green")
	_caster(engine, 1, "black")
	_play(engine, 0, "avernus_blessing", {"target": unit.uid})
	_play(engine, 1, "fx_curse_spell", {"target": unit.uid})
	_check(engine.attack_of(unit) == 2 + 2 - 1 and int(unit.armor) == -1, "Both players' modifications are written through")
	_play(engine, 0, "fx_purge_spell", {"target": unit.uid})
	_check(engine.attack_of(unit) == 4 and int(unit.armor) == 0 and unit.mods.all(func(entry): return int(entry.by) == 0),
		"purge_1: the caster's Purge removes only the opponent's modifications; its own stay")
	_caster(engine, 1, "green")
	_check(_play(engine, 1, "fx_purge_spell", {"target": unit.uid}).ok, "The opponent purges")
	_check(engine.attack_of(unit) == 2 and unit.mods.is_empty(), "purge_2: the opponent's Purge removes the owner's modifications")
	engine = _engine()
	var hero = engine.state.players[0].roster[0]
	_rows(engine, 0, [[hero], ["melee_creep"]])
	Zones.equip(engine, hero, "short_sword")
	Kernel.give(engine, hero, {"attack": 2}, {}, "", "round", {"controller": 1, "card": ""})
	var printed = engine.attack_of(hero)
	Kernel.purge(engine, hero, "all", {"controller": 0, "card": "fx_purge_spell"})
	_check(engine.attack_of(hero) == printed - 2 and hero.items.has("weapon"), "purge_3: Purge never removes items or base stats")
	engine = _engine()
	hero = engine.state.players[0].roster[0]
	_rows(engine, 0, [[hero], ["melee_creep"]])
	Zones.equip(engine, hero, "travelers_cloak")
	Kernel.modify(engine, hero, {"attack": 1}, {}, "", {"controller": 0, "card": "combat_training"})
	for duration in ["round", "next_combat", "death", "equip", "used"]:
		Kernel.give(engine, hero, {"armor": 1}, {}, "", duration, {"controller": 1, "card": ""})
	hero.health = 1
	hero.condemned = true
	engine._clean_dead(0)
	_check(hero.mods.size() == 1 and str(hero.mods[0].k) == "modify", "rq_13_fountain: the Fountain keeps Modify and clears every give entry")
	_check(int(hero.health) == engine.max_health_of(hero) and engine.max_health_of(hero) == int(hero.max_health) + 4,
		"fountain_2: the Fountain heals to the maximum with item auras")

# --- Hand state -----------------------------------------------------------------------

func _hand(engine, player: int, cards: Array) -> void:
	engine.state.players[player].hand = cards.duplicate()
	engine.state.players[player].hand_state = []
	for card_id in cards:
		engine.state.players[player].hand_state.append({"iid": Kernel.next_oid(engine)})

## Locks (RQ-14): they stack, decay by one per round, block plays and stay
## private except their counts.
func _test_locks() -> void:
	var engine = _engine()
	_caster(engine, 0, "blue")
	_caster(engine, 1, "blue")
	_hand(engine, 1, ["foresight", "foresight"])
	_check(_play(engine, 0, "fx_lock_spell").ok, "Seal Cards plays")
	var states: Array = engine.state.players[1].hand_state
	_check(int(states[0].get("lock", 0)) == 1 and int(states[1].get("lock", 0)) == 1, "lock_1: two random cards in the opponent's hand get a lock")
	_check(engine.hand_public(1) == [{"lock": 1}, {"lock": 1}] and engine.player_view(0).players[1].hand_public == [{"lock": 1}, {"lock": 1}],
		"lock_2: lock counts are public on card backs")
	var theirs = engine.player_view(0).events.filter(func(event): return str(event.k) == "lock").back()
	var holder = engine.player_view(1).events.filter(func(event): return str(event.k) == "lock").back()
	_check(not theirs.has("idx") and holder.get("idx", []).size() == 2 and int(theirs.n) == 2, "lock_3: only the holder learns which cards are locked")
	_play(engine, 0, "fx_lock_spell")
	_check(int(states[0].lock) == 2 and int(states[1].lock) == 2, "rq_14_lock_stacks: locks stack")
	engine.state.active_player = 1
	_check(not engine.legal_actions(1).any(func(action): return str(action.type) == "play"), "lock_4: a locked card has no legal plays")
	engine._begin_deployment()
	_check(int(states[0].lock) == 1, "lock_5: each round removes one lock")
	engine._begin_deployment()
	engine.state.phase = "action"
	engine.state.lane = 0
	engine.state.active_player = 1
	_check(int(states[0].lock) == 0 and engine.legal_actions(1).any(func(action): return str(action.type) == "play"),
		"rq_14_lock_decay: a card with no lock left is playable again")
	_check(Invariants.violations(engine).is_empty(), "Invariants hold after locks: %s" % [Invariants.violations(engine)])

## add_card (base copies, the Secret Shop pool) and card counters (CF-2).
func _test_add_card_and_counters() -> void:
	var engine = _engine()
	_caster(engine, 0, "blue")
	_hand(engine, 0, ["fx_copy_spell", "fx_counter_spell"])
	engine.state.players[0].hand_state[1]["charges"] = 3
	engine.state.players[0].hand_state[1]["hacks"] = ["fx_hack_spell#0"]
	engine.apply_action(0, {"type": "play", "hand": 0})
	var hand: Array = engine.state.players[0].hand
	var copy: Dictionary = engine.state.players[0].hand_state.back()
	_check(hand == ["fx_counter_spell", "fx_counter_spell"] and bool(copy.get("base", false)) and not copy.has("charges") and not copy.has("hacks"),
		"rq_36_base_copy: a base copy has no locks, charges or hacks")
	var gained = engine.player_view(1).events.filter(func(event): return str(event.k) == "gain_card").back()
	var own = engine.player_view(0).events.filter(func(event): return str(event.k) == "gain_card").back()
	_check(not gained.has("card") and str(own.get("card", "")) == "fx_counter_spell", "add_card_1: only the receiver learns the gained card")
	engine = _engine()
	_hand(engine, 0, ["fx_ticket"])
	var rng_before = engine.rng.state
	engine.apply_action(0, {"type": "play", "hand": 0})
	var manual = RandomNumberGenerator.new()
	manual.state = rng_before
	var pool: Array = engine.library.catalog.secret_shop
	var expected = str(pool[manual.randi_range(0, pool.size() - 1)])
	_check(engine.state.players[0].hand == [expected] and engine.rng.state == manual.state, "add_card_2: a Secret Shop pick costs one draw (%s)" % expected)
	engine = _engine()
	_rows(engine, 0, [[null], ["fx_retaliate_2"]])
	_caster(engine, 0, "blue")
	_hand(engine, 0, ["fx_counter_spell"])
	var seen = engine.state.events.size()
	engine.apply_action(0, {"type": "play", "hand": 0})
	_check(engine.state.events.slice(seen).filter(func(event): return str(event.k) == "damage").size() == 1,
		"cf2_eclipse_default: an untouched card counter reads its printed charge (one bolt)")
	engine = _engine()
	_rows(engine, 0, [[null], ["fx_retaliate_2"]])
	_caster(engine, 0, "blue")
	_hand(engine, 0, ["fx_charge_spell", "fx_counter_spell"])
	engine.state.players[0].deck = ["fx_counter_spell", "foresight", "fx_counter_spell"]
	engine.state.players[0].deck_state = []
	engine.apply_action(0, {"type": "play", "hand": 0})
	var deck_states: Array = engine.state.players[0].deck_state
	_check(deck_states.size() == 3, "card_counter_1: writing a deck card's counter materializes deck_state")
	var charged = [int(engine.state.players[0].hand_state[0].get("charges", 1)), int(deck_states[0].get("charges", 1)) if deck_states.size() == 3 else 0,
		int(deck_states[2].get("charges", 1)) if deck_states.size() == 3 else 0]
	charged.sort()
	_check(charged == [1, 2, 2], "card_counter_2: two random copies in hand or deck go from their printed 1 to 2 (%s)" % [charged])
	var view = engine.player_view(1)
	_check(view.players[0].hand_state.is_empty() and view.players[0].deck_state.is_empty() and view.events.back().get("k") == "charged",
		"card_counter_3: counters stay hidden; the log says only how many cards changed")
	_check(Invariants.privacy(engine).is_empty(), "Privacy holds after card counters: %s" % [Invariants.privacy(engine)])
	engine = _engine()
	_rows(engine, 0, [[null], ["fx_retaliate_2"]])
	engine.state.lanes[0].units[1][0].health = 30
	engine.state.lanes[0].units[1][0].max_health = 30
	engine.state.lanes[0].units[1][0].hp_seen = 30
	_caster(engine, 0, "blue")
	_hand(engine, 0, ["fx_counter_spell"])
	engine.state.players[0].hand_state[0]["charges"] = 3
	seen = engine.state.events.size()
	engine.apply_action(0, {"type": "play", "hand": 0})
	_check(engine.state.events.slice(seen).filter(func(event): return str(event.k) == "damage").size() == 3,
		"card_counter_4: a card with 3 charges repeats three times")

## Hacks (spec §3.12): attached privately to cards in hand; when that card
## is played it resolves and pulses first, then the hack runs with the player
## who played it as controller, then card_played.
func _test_hacks() -> void:
	var engine = _engine()
	_caster(engine, 0, "blue")
	_unit(engine, "zeus", 1, 0)
	_unit(engine, "melee_creep", 0, 0)
	_hand(engine, 1, ["foresight", "foresight"])
	_check(_play(engine, 0, "fx_hack_spell").ok, "Sabotage Plot plays")
	var states: Array = engine.state.players[1].hand_state
	_check(states.all(func(entry): return entry.get("hacks", []) == ["fx_hack_spell#0"]), "hack_1: two random cards in the opponent's hand carry the hack")
	var caster_view = engine.player_view(0).events.filter(func(event): return str(event.k) == "hack").back()
	var holder_view = engine.player_view(1).events.filter(func(event): return str(event.k) == "hack").back()
	_check(int(caster_view.n) == 2 and not caster_view.has("idx") and holder_view.get("idx", []).size() == 2, "hack_2: only the holder sees which cards are hacked")
	_check(engine.player_view(0).players[1].hand_state.is_empty(), "hack_3: the caster's view has no hand state of the victim")
	var towers_before = []
	for lane in engine.state.lanes:
		towers_before.append(int(lane.structures[1].health))
	engine.state.active_player = 1
	var seen = engine.state.events.size()
	_check(engine.apply_action(1, {"type": "play", "hand": 0}).ok, "The victim plays a hacked Foresight")
	var keys: Array = engine.state.events.slice(seen).map(func(event): return str(event.k))
	var hack_at = -1
	var zeus_at = -1
	var draw_at = -1
	for index in range(seen, engine.state.events.size()):
		var event = engine.state.events[index]
		if str(event.k) == "trigger" and str(event.get("ability", "")) == "hack":
			hack_at = index
		if str(event.k) == "trigger" and str(event.get("card", "")) == "zeus":
			zeus_at = index
		if str(event.k) == "draw_cards" and draw_at == -1:
			draw_at = index
	_check(draw_at != -1 and hack_at > draw_at and zeus_at > hack_at, "hack_4: the card resolves, then the hack, then card_played triggers (%s)" % [keys])
	var lost = 0
	for lane_index in range(3):
		lost += towers_before[lane_index] - int(engine.state.lanes[lane_index].structures[1].health)
	_check(lost == 3, "hack_5: the hack hits a random tower of the player who played the card")
	_check(Invariants.violations(engine).is_empty() and Invariants.privacy(engine).is_empty(), "Invariants hold after a hack")
	_check(engine.state.players[1].hand_state[0].get("hacks", []).size() == 1, "The other hacked card keeps its hack")

# --- Zones ----------------------------------------------------------------------------

func _zones_ok(engine, label: String) -> void:
	var broken = Invariants.violations(engine)
	_check(broken.is_empty(), "%s: zone invariants (rows aligned, arrows consistent, no stale forced target, roster heroes in one place): %s" % [label, broken])

## Summoned heroes (RQ-29) and to_fountain.
func _test_summon_and_fountain() -> void:
	var engine = _engine()
	_caster(engine, 0, "blue")
	_unit(engine, "melee_creep", 1, 0)
	_check(_play(engine, 0, "fx_summon_hero").ok, "Call a Champion plays")
	var summoned = engine.state.lanes[0].units[0].filter(func(unit): return unit != null and str(unit.card) == "fx_minion")
	_check(summoned.size() == 1, "summon_1: the hero is summoned into the active lane")
	if summoned.is_empty():
		return
	var minion: Dictionary = summoned[0]
	var joins = Kernel.SUMMONED_HEROES_JOIN_ROSTER
	_check(bool(minion.hero) and bool(minion.roster) == joins and engine.state.players[0].roster.has(minion) == joins
		and engine.can_cast_colour(minion), "summon_2: rq_29_summoned_hero: a summoned hero's colour counts and it %s its owner's roster" % ("joins" if joins else "stays out of"))
	_zones_ok(engine, "summon")
	_hand(engine, 0, ["short_sword"])
	engine.state.active_player = 0
	_check({"type": "play", "hand": 0, "target": minion.uid} in engine.legal_actions(0), "summon_3: a summoned hero can equip items")
	var gold = int(engine.state.players[1].gold)
	minion.health = 0
	engine._clean_dead(0)
	if joins:
		_check(int(minion.lane) == -1 and int(engine.state.players[1].gold) == gold + 5 and engine.state.players[0].roster.has(minion)
			and int(minion.ready_round) == int(engine.state.round) + 2 and int(minion.health) == int(minion.max_health),
			"summon_4: rq_29_summoned_hero: a dead summoned hero pays hero bounty and goes to the Fountain, healed, ready in two rounds")
	else:
		_check(int(minion.lane) == -1 and int(engine.state.players[1].gold) == gold + 5 and not engine.state.players[0].roster.has(minion),
			"summon_4: rq_29_summoned_hero: a dead summoned hero pays hero bounty and leaves the game")
	_zones_ok(engine, "summoned death")
	if joins:
		_test_summoned_hero_returns()
	engine = _engine()
	var hero = engine.state.players[0].roster[0]
	_rows(engine, 0, [[hero], ["melee_creep"]])
	Kernel.give(engine, hero, {"attack": 2}, {}, "", "round", {"controller": 0, "card": ""})
	gold = int(engine.state.players[1].gold)
	_hand(engine, 0, ["town_portal_scroll"])
	engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid})
	_check(int(hero.lane) == -1 and int(hero.ready_round) == int(engine.state.round) + 1 and int(engine.state.players[1].gold) == gold and hero.mods.is_empty(),
		"to_fountain_1: a voluntary return pays no bounty, is ready next round and clears temporary effects")
	_zones_ok(engine, "to_fountain")

## RQ-29 (M4): a summoned hero that died sits in the Fountain like any roster
## hero, keeps its items and permanent modifications, becomes ready two rounds
## later, is offered for deployment, and enters the planned lane at the reveal.
func _test_summoned_hero_returns() -> void:
	var engine = _engine()
	_caster(engine, 0, "blue")
	_check(_play(engine, 0, "fx_summon_hero").ok, "rq_29_returns: Call a Champion plays")
	var found = engine.state.lanes[0].units[0].filter(func(unit): return unit != null and str(unit.card) == "fx_minion")
	if found.is_empty():
		_check(false, "rq_29_returns: the hero was summoned")
		return
	var minion: Dictionary = found[0]
	Zones.equip(engine, minion, "short_sword")
	Kernel.modify(engine, minion, {"attack": 1}, {}, "", {"controller": 0, "card": ""})
	var died_in = int(engine.state.round)
	engine._reset_transient()
	minion.health = 0
	Kernel.pulse(engine)
	engine._settle_transient()
	_check(int(minion.lane) == -1 and minion.items.has("weapon") and int(minion.attack) == 4,
		"rq_29_returns_1: in the Fountain the summoned hero keeps its item and its Modify")
	var view = engine.player_view(1)
	_check(view.players[0].roster.any(func(hero): return int(hero.uid) == int(minion.uid)),
		"rq_29_returns_2: the opponent sees the summoned hero in the Fountain (the roster is public)")
	for round_step in range(2):
		engine._begin_deployment()
		var offered = engine.legal_actions(0).any(func(action): return str(action.type) == "deploy" and int(action.unit) == int(minion.uid))
		var ready = int(engine.state.round) >= died_in + 2
		_check(offered == ready, "rq_29_returns_3: round %d: the summoned hero is %s for deployment" % [int(engine.state.round), "offered" if ready else "not yet offered"])
		if ready:
			engine.apply_action(0, {"type": "deploy", "unit": int(minion.uid), "lane": 2})
		for owner in engine.state.players:
			owner.finished = true
		engine._reset_transient()
		engine._reveal_deployment()
		engine._settle_transient()
	_check(int(minion.lane) == 2 and int(minion.health) == engine.max_health_of(minion), "rq_29_returns_4: the summoned hero is redeployed into its planned lane at full health")
	_zones_ok(engine, "summoned hero redeployed")

## Moves (spec §3.7, CF-1, RQ-17, RQ-42).
func _test_move() -> void:
	var engine = _engine()
	var mover = _unit(engine, "fx_cleave_3", 0, 0)
	_unit(engine, "melee_creep", 1, 0)
	_unit(engine, "melee_creep", 1, 1)
	_unit(engine, "melee_creep", 0, 1)
	_caster(engine, 0, "black")
	_improve(engine, "fx_glyph", 1, 1)
	_hand(engine, 0, ["fx_move_any"])
	var plays = engine.legal_actions(0).filter(func(action): return str(action.type) == "play" and int(action.get("target", -1)) == int(mover.uid) and int(action.get("lane", -1)) == 1)
	var positions = plays.map(func(action): return int(action.position))
	_check(positions == engine.creep_positions(1, 0), "rq_42_empty_position: move positions are the creep_positions set (%s)" % [positions])
	_check(engine.choice_steps({"hand": 0}) == [{"key": "target", "type": "unit"}, {"key": "lane", "type": "lane"}, {"key": "position", "type": "position", "lane_key": "lane"}],
		"Redeploy's steps: a unit, a lane, then a position in that lane")
	var command = plays.filter(func(action): return int(action.position) == -1)
	_check(not command.is_empty() and engine.apply_action(0, command[0]).ok, "Redeploy plays")
	_check(int(mover.lane) == 1 and engine.slot_of(mover) == 0, "move_1: a cross-lane move enters the chosen position (a new left end)")
	_check(not _events(engine, "move").is_empty() and engine.has_flag(mover, "stun"), "rq_21_move_enters: a unit moved into a lane enters it (the enemy trap stuns it)")
	_zones_ok(engine, "cross-lane move")
	# Same-lane moves: to the right end with the old position compacting away,
	# to an inner empty slot, and without a position (nothing).
	engine = _engine()
	var made = _rows(engine, 0, [["fx_cleave_3", "melee_creep"], [null, "melee_creep"]])
	var unit: Dictionary = made[0][0]
	_check(Zones.move(engine, unit, 0, 2) and engine.state.lanes[0].units[0].size() == 2 and engine.slot_of(unit) == 1,
		"cf1_same_lane_end: a same-lane move to the right end compacts its old position away")
	_zones_ok(engine, "same-lane move")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3", "melee_creep", null], ["melee_creep", "melee_creep", "melee_creep"]])
	unit = made[0][0]
	_check(Zones.move(engine, unit, 0, 2) and engine.slot_of(unit) == 2 and engine.state.lanes[0].units[0][0] == null,
		"cf1_same_lane_inner: a same-lane move into an inner empty slot leaves its old slot empty")
	_check(not Zones.move(engine, unit, 0, null) and engine.slot_of(unit) == 2, "cf1_same_lane_no_position: a same-lane move without a position does nothing")
	_check(not Zones.move(engine, unit, 0, 1), "move_stale: a position that is no longer free fizzles the move")
	_zones_ok(engine, "inner move")
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3", "melee_creep"], ["melee_creep", "melee_creep"]])
	unit = made[0][0]
	_check(Zones.move(engine, unit, 0, -1) and engine.slot_of(unit) == 0 and engine.state.lanes[0].units[0].size() == 3,
		"cf1_same_lane_left: a same-lane move to the left end opens a new position")
	_zones_ok(engine, "left-end move")
	# Forced targets: an enemy's forced target at the mover ends when out of range.
	engine = _engine()
	made = _rows(engine, 0, [["fx_cleave_3", "melee_creep", null], ["melee_creep", "melee_creep", "melee_creep"]])
	unit = made[0][0]
	unit.combat_target = int(made[1][0].uid)
	made[1][0].combat_target = int(unit.uid)
	Zones.move(engine, unit, 0, 2)
	_check(int(made[1][0].combat_target) == -1 and int(unit.combat_target) == -1, "move_forced: forced targets out of range end after a move")
	_zones_ok(engine, "forced targets after a move")
	# random_other: one lane roll per unit (CF-1).
	var split = false
	var together = false
	for seed_value in range(1, 41):
		engine = _engine(seed_value)
		var a = _unit(engine, "melee_creep", 1, 0)
		var b = _unit(engine, "melee_creep", 1, 0)
		_unit(engine, "melee_creep", 0, 0)
		_unit(engine, "melee_creep", 0, 0)
		_caster(engine, 0, "red")
		_hand(engine, 0, ["fx_bounce_spell"])
		engine.apply_action(0, {"type": "play", "hand": 0, "target": a.uid})
		_hand(engine, 0, ["fx_bounce_spell"])
		engine.state.active_player = 0
		engine.apply_action(0, {"type": "play", "hand": 0, "target": b.uid})
		if int(a.lane) != int(b.lane):
			split = true
		else:
			together = true
		if int(a.lane) == 0 or int(b.lane) == 0:
			split = false
			together = false
			break
	_check(split and together, "cf1_random_other: each moved unit rolls its own other lane")
	engine = _engine(3)
	var units: Array = []
	for count in range(3):
		units.append(_unit(engine, "melee_creep", 1, 0))
	_unit(engine, "melee_creep", 0, 0)
	var ctx = {"controller": 0, "lane": 0, "card": "fx_bounce_spell", "choices": {}, "vars": {}, "src": null, "host": null}
	EngineClass.VM.run(engine, [{"op": "move", "unit": {"s": "units", "side": "enemy", "lane": null, "kind": null, "card": null, "color": null,
		"slot": null, "rel": null, "not": null, "where": null, "zone": null, "player": null, "pick": null, "after": null}, "lane": "random_other"}], ctx)
	_check(units.all(func(moved): return int(moved.lane) in [1, 2]) and _events(engine, "move").size() == 3, "cf1_random_other_set: a set moves one unit at a time, each to another lane")
	_zones_ok(engine, "set move")

## Swaps (RQ-30): arrows stay with positions, forced targets included;
## swapping is not entering (RQ-21).
func _test_swap() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["melee_creep", "fx_cleave_3"], [null, "fx_retaliate_2"]])
	var a: Dictionary = made[0][0]
	var b: Dictionary = made[0][1]
	a.arrow = 1
	_improve(engine, "fx_glyph", 1, 0)
	_caster(engine, 0, "green")
	_hand(engine, 0, ["fx_swap"])
	var command = {"type": "play", "hand": 0, "target": a.uid, "destination": b.uid}
	_check(command in engine.legal_actions(0), "Switch Places targets an ally and its allied neighbor")
	engine.apply_action(0, command)
	_check(engine.slot_of(a) == 1 and engine.slot_of(b) == 0, "swap_1: the two allies exchange positions")
	_check(int(b.arrow) == 1 and int(a.arrow) == 0, "rq_30_swap_arrows: arrows stay with the positions")
	_check(not engine.has_flag(a, "stun") and not engine.has_flag(b, "stun"), "rq_21_swap_not_entering: a swap does not enter the lane")
	_zones_ok(engine, "swap")
	engine = _engine()
	made = _rows(engine, 0, [["melee_creep", null, "fx_cleave_3"], ["melee_creep", "melee_creep", "melee_creep"]])
	made[0][0].combat_target = int(made[1][0].uid)
	made[1][1].combat_target = int(made[0][0].uid)
	made[1][1].arrow = -1
	_check(Zones.swap(engine, made[0][0], made[0][2]) and int(made[0][0].combat_target) == -1 and int(made[0][2].combat_target) == int(made[1][0].uid),
		"rq_30_swap_forced: a forced target stays with its position; the unit swapped in attacks it")
	_check(int(made[1][1].arrow) == -1 and int(made[1][1].combat_target) == int(made[0][2].uid),
		"rq_30_swap_forced_enemy: an enemy forced at a swapped unit keeps its arrow and attacks the unit now in that position")
	_zones_ok(engine, "swap with forced targets")
	_check(not Zones.swap(engine, made[0][0], made[1][1]), "swap_3: units of different rows never swap")

## Control (RQ-17): the stolen unit enters the new owner's row at a random
## position, keeps its modifications with their provenance and pays its
## bounty to the new owner's opponent; roster heroes never change sides.
func _test_control() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_cleave_3", null], ["melee_creep", "fx_retaliate_2"]])
	var victim: Dictionary = made[1][1]
	_improve(engine, "fx_glyph", 1, 0)
	_caster(engine, 1, "green")
	_play(engine, 1, "avernus_blessing", {"target": victim.uid})
	made[0][0].combat_target = int(victim.uid)
	_caster(engine, 0, "green")
	_check(_play(engine, 0, "fx_control", {"target": victim.uid}).ok, "Turn Coat plays")
	_check(int(victim.owner) == 0 and engine.state.lanes[0].units[0].has(victim), "control_1: the creep joins the new owner's row")
	_check(int(made[0][0].combat_target) == -1, "control_2: its attackers are released")
	_check(engine.has_flag(victim, "stun"), "rq_21_control_enters: a stolen unit enters (the trap of its old owner stuns it)")
	_check(victim.mods.any(func(entry): return int(entry.by) == 1), "control_3: modifications keep their original player")
	_play(engine, 0, "fx_purge_spell", {"target": victim.uid})
	_check(engine.attack_of(victim) == 1, "control_4: the new owner's Purge removes the old owner's modification")
	var gold = int(engine.state.players[1].gold)
	victim.health = 0
	engine._clean_dead(0)
	_check(int(engine.state.players[1].gold) == gold + 1, "control_5: its bounty goes to the new owner's opponent")
	_zones_ok(engine, "control")
	var hero = engine.state.players[1].roster[0]
	_rows(engine, 1, [["melee_creep"], [hero]])
	_check(not Zones.control(engine, hero, 0) and int(hero.owner) == 1, "control_6: a roster hero never changes sides")

## Random zone operations on random boards; the zone invariants hold after each.
func _test_zone_fuzz() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 2024
	var cards = ["melee_creep", "fx_cleave_3", "fx_retaliate_2", "fx_regen_2", "fx_soulbound_creep", "fx_bounty_creep"]
	var problems: Array = []
	var operations = 0
	for round_index in range(60):
		var engine = _engine(round_index + 1)
		for lane_index in range(3):
			var rows: Array = [[], []]
			var width = rng.randi_range(1, 5)
			for slot in range(width):
				for side in range(2):
					rows[side].append(cards[rng.randi_range(0, cards.size() - 1)] if rng.randi_range(0, 3) > 0 else null)
				if rows[0][slot] == null and rows[1][slot] == null:
					rows[0][slot] = "melee_creep"
			_rows(engine, lane_index, rows)
		engine._roll_arrows()
		for lane_index in range(3):
			for side in range(2):
				for unit in engine.state.lanes[lane_index].units[side]:
					if unit != null and rng.randi_range(0, 4) == 0:
						var enemies = engine.combat_targets(unit)
						if not enemies.is_empty():
							Kernel.retarget(engine, unit, Select_one(engine, enemies[rng.randi_range(0, enemies.size() - 1)]))
		for step in range(10):
			var units = Stats.all_units(engine).filter(func(unit): return int(unit.lane) >= 0)
			if units.is_empty():
				break
			var unit = units[rng.randi_range(0, units.size() - 1)]
			var choice = rng.randi_range(0, 4)
			match choice:
				0:
					var lane_index = rng.randi_range(0, 2)
					var positions = engine.creep_positions(lane_index, int(unit.owner))
					Zones.move(engine, unit, lane_index, positions[rng.randi_range(0, positions.size() - 1)] if rng.randi_range(0, 1) == 0 else null)
				1:
					var row: Array = engine.state.lanes[int(unit.lane)].units[int(unit.owner)]
					var others = row.filter(func(other): return other != null and int(other.uid) != int(unit.uid))
					if not others.is_empty():
						Zones.swap(engine, unit, others[rng.randi_range(0, others.size() - 1)])
				2:
					Zones.control(engine, unit, 1 - int(unit.owner))
				3:
					Zones.summon(engine, "melee_creep", rng.randi_range(0, 1), rng.randi_range(0, 2))
				4:
					var lane_index = int(unit.lane)
					unit.health = 0
					engine._clean_dead(lane_index)
			engine._settle_transient()
			operations += 1
			var broken = Invariants.violations(engine)
			if not broken.is_empty() and problems.size() < 5:
				problems.append("board %d step %d op %d: %s" % [round_index, step, choice, broken])
	_check(problems.is_empty() and operations > 400, "Zone fuzz: invariants after %d summons, moves, swaps, control changes and deaths: %s" % [operations, problems])

## A unit by uid, or the tower marker 0.
func Select_one(engine, value):
	return 0 if int(value) == 0 else engine.find_unit(int(value))

# --- Objects --------------------------------------------------------------------------

## Improvements: lane choice, actives in their lane, triggers with charges,
## the improvement choice, the 16 cap (RQ-47) and the enter event.
func _test_improvements() -> void:
	var engine = _engine()
	_caster(engine, 0, "black")
	_unit(engine, "melee_creep", 1, 2)
	_hand(engine, 0, ["fx_improvement_ping"])
	var plays = engine.legal_actions(0).filter(func(action): return str(action.type) == "play")
	_check(plays.map(func(action): return int(action.lane)) == [0, 1, 2], "improvement_1: an improvement offers every lane")
	_check(engine.choice_steps({"hand": 0}) == [{"key": "lane", "type": "lane"}], "The improvement's step is a lane step")
	var mana = int(engine.state.lanes[0].mana[0])
	engine.apply_action(0, {"type": "play", "hand": 0, "lane": 2})
	var improvement: Dictionary = engine.improvements(2, 0)[0]
	_check(int(engine.state.lanes[0].mana[0]) == mana - 2 and str(improvement.card) == "fx_improvement_ping" and int(improvement.oid) >= EngineClass.OID_START,
		"improvement_2: it enters the chosen lane as an object with an oid and pays the active lane's mana")
	engine.state.active_player = 0
	_check(not engine.legal_actions(0).any(func(action): return str(action.type) == "ability"), "improvement_3: its active is not usable from another lane")
	engine.state.lane = 2
	var ability = {"type": "ability", "unit": int(improvement.oid)}
	_check(ability in engine.legal_actions(0), "improvement_4: its active is usable while its lane is active")
	_check(engine.abilities_of(int(improvement.oid)).size() == 1 and bool(engine.abilities_of(int(improvement.oid))[0].ready), "abilities_of lists an improvement's active as ready")
	engine.apply_action(0, ability)
	_check(int(improvement.cd) == 1 and not ability in engine.legal_actions(0), "improvement_5: using it sets its cooldown")
	engine._begin_deployment()
	_check(int(improvement.cd) == 0, "improvement_6: its cooldown ticks at round end")
	# Charges and triggers: the countdown blasts at zero charges and condemns itself.
	engine = _engine()
	_rows(engine, 0, [["melee_creep"], ["melee_creep"]])
	var keg = _improve(engine, "fx_countdown", 0, 0)
	_check(int(keg.charges) == 2, "improvement_7: an improvement starts with its printed charges")
	_combat(engine)
	_check(int(keg.charges) == 1, "improvement_8: an after-combat trigger removes a charge")
	keg.charges = 0
	var tower = int(_tower(engine, 0, 1).health)
	Kernel.lane_open(engine, 0)
	engine._settle_transient()
	_check(int(_tower(engine, 0, 1).health) == tower - 4 and engine.improvements(0, 0).is_empty() and not _events(engine, "improvement_gone").is_empty(),
		"improvement_9: at zero charges it damages the enemy tower before the action phase and condemns itself")
	# The improvement choice (Raze).
	engine = _engine()
	_caster(engine, 0, "red")
	var target = _improve(engine, "fx_library", 1, 0)
	_hand(engine, 0, ["fx_raze"])
	_check(engine.choice_steps({"hand": 0}) == [{"key": "target", "type": "improvement"}], "Raze has an improvement step")
	_check({"type": "play", "hand": 0, "target": int(target.oid)} in engine.legal_actions(0), "improvement_10: an improvement choice offers improvement oids")
	engine.apply_action(0, {"type": "play", "hand": 0, "target": int(target.oid)})
	_check(engine.improvements(0, 1).is_empty(), "improvement_11: a condemned improvement leaves at the Pulse")
	# The cap: a 17th condemns a random one of that side's (one draw).
	engine = _engine()
	for count in range(16):
		_improve(engine, "fx_library", 0, 1)
	var rng_before = engine.rng.state
	_improve(engine, "fx_oath", 0, 1)
	var manual = RandomNumberGenerator.new()
	manual.state = rng_before
	manual.randi_range(0, 15)
	_check(engine.improvements(1, 0).size() == 16 and str(engine.improvements(1, 0).back().card) == "fx_oath" and engine.rng.state == manual.state,
		"rq_47_improvement_cap: a 17th improvement on one side of a lane replaces a random one")
	_check(Invariants.violations(engine).is_empty(), "Invariants hold at the improvement cap")
	# unit_entered in the trap's lane: summons stun enemies.
	engine = _engine()
	_improve(engine, "fx_glyph", 1, 0)
	_caster(engine, 0, "blue")
	_play(engine, 0, "dimensional_portal")
	var summoned = engine.state.lanes[0].units[0].filter(func(unit): return unit != null and str(unit.card) == "melee_creep")
	_check(not summoned.is_empty() and summoned.all(func(unit): return engine.has_flag(unit, "stun")), "rq_21_summon_enters: summoned units enter the lane")

## Item instances: a trigger with charges, an active, cooldowns, the Fountain (RQ-38).
func _test_items() -> void:
	var engine = _engine()
	var hero = _caster(engine, 0, "red")
	var friend = _unit(engine, "melee_creep", 0, 0)
	var other = _unit(engine, "melee_creep", 0, 1)
	_unit(engine, "melee_creep", 1, 0)
	_unit(engine, "melee_creep", 1, 1)
	_hand(engine, 0, ["fx_charge_item"])
	engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid})
	var instance: Dictionary = hero.item_state.weapon
	friend.health = 0
	other.health = 0
	engine._clean_dead(0)
	engine._clean_dead(1)
	_check(int(instance.charges) == 1, "item_1: an item trigger counts an allied creep death in its host's lane only")
	var oid = int(instance.oid)
	engine.state.active_player = 0
	_check(engine.choice_steps({"unit": oid}).is_empty() and engine.abilities_of(int(hero.uid)).any(func(entry): return int(entry.source) == oid and bool(entry.ready)),
		"abilities_of lists the hero's item active as ready")
	engine.state.active_player = 0
	var count = engine.state.lanes[0].units[0].filter(func(unit): return unit != null).size()
	engine.apply_action(0, {"type": "ability", "unit": oid})
	_check(engine.state.lanes[0].units[0].filter(func(unit): return unit != null).size() == count + 1 and int(instance.charges) == 0 and int(instance.cd) == 2,
		"item_2: the item's active summons one creep per charge, resets its charges and sets its own cooldown")
	engine._begin_deployment()
	_check(int(instance.cd) == 1, "item_3: item cooldowns tick at round end")
	# RQ-38: no item triggers while the host is in the Fountain; stat auras still apply.
	engine = _engine()
	hero = engine.state.players[0].roster[0]
	Zones.equip(engine, hero, "fx_charge_item")
	Zones.equip(engine, hero, "fx_hourglass")
	Stats.settle(engine)
	var creep = _unit(engine, "melee_creep", 0, 0)
	_unit(engine, "melee_creep", 1, 0)
	creep.health = 0
	engine._clean_dead(0)
	_check(int(hero.item_state.weapon.charges) == 0, "rq_38_item_in_fountain: an item trigger does not work while its host is in the Fountain")
	_check(engine.max_health_of(hero) == int(hero.max_health) + 2, "rq_38_item_in_fountain: host stat auras still apply in the Fountain")
	var old_oid = int(hero.item_state.weapon.oid)
	Zones.equip(engine, hero, "fx_lethal_item")
	_check(int(hero.item_state.weapon.oid) != old_oid and int(hero.item_state.weapon.charges) == 0, "item_4: replacing an item creates a new instance")
	# An item active with a lane choice moves its host.
	engine = _engine()
	hero = _caster(engine, 0, "red")
	Zones.equip(engine, hero, "fx_blink_item")
	oid = int(hero.item_state.accessory.oid)
	_check(engine.choice_steps({"unit": oid}) == [{"key": "lane", "type": "lane"}], "An item active with a lane choice has a lane step")
	engine.apply_action(0, {"type": "ability", "unit": oid, "lane": 2})
	_check(int(hero.lane) == 2, "item_5: Swift Boots move their host to the chosen lane")
	_zones_ok(engine, "item move")
	# Quicken (RQ-25) on a unit's active.
	engine = _engine()
	var runner = _unit(engine, "fx_quick_creep", 0, 0)
	_unit(engine, "melee_creep", 1, 0)
	engine.apply_action(0, {"type": "ability", "unit": runner.uid})
	_check(int(runner.cooldown) == 2, "rq_25_quicken: a quickened Active 3 is ready again after 2 rounds")

## Deeds (RQ-41) and the Secret Shop discount (RQ-26).
func _test_deeds() -> void:
	var engine = _engine()
	_hand(engine, 0, ["fx_deed", "fx_deed"])
	var mana = int(engine.state.lanes[0].mana[0])
	_check({"type": "play", "hand": 0} in engine.legal_actions(0), "rq_41_deed_zone: a deed is played with no hero in the lane")
	engine.apply_action(0, {"type": "play", "hand": 0})
	_check(engine.state.players[0].deeds.size() == 1 and int(engine.state.lanes[0].mana[0]) == mana, "rq_41_deed_zone: it enters the public deeds zone for free")
	_check(engine.player_view(1).players[0].deeds.size() == 1, "Deeds are public")
	_check(engine.price_of(0, "secret", "claymore") == 0 and engine.price_of(1, "secret", "claymore") > 0 and engine.price_of(0, "item", "claymore") > 0,
		"rq_26_deed_discount: one deed makes the owner's Secret Shop free")
	engine.state.active_player = 0
	engine.apply_action(0, {"type": "play", "hand": 0})
	var base = int(engine.library.get_card("claymore").price)
	_check(engine.price_of(0, "secret", "claymore") == -base, "rq_26_negative_price: two deeds make the price negative")
	engine.state.phase = "shop"
	engine.state.players[0].shop = {"secret": "claymore", "item": "", "consumable": ""}
	engine.state.players[0].finished = false
	var gold = int(engine.state.players[0].gold)
	_check(engine.apply_action(0, {"type": "buy", "card": "claymore", "source": "secret"}).ok and int(engine.state.players[0].gold) == gold + base,
		"rq_26_negative_price: buying at a negative price pays gold")

## round_draw and forbid_play (spec §3.11).
func _test_rules_layer() -> void:
	var engine = _engine()
	_improve(engine, "fx_library", 0, 1)
	_check(int(engine.rules_of(0).round_draw) == 1 and int(engine.rules_of(1).round_draw) == 0, "rules_round_draw_1: the aura adds a round draw for its owner")
	engine.state.players[0].deck = ["foresight", "foresight", "foresight", "foresight"]
	engine.state.players[1].deck = ["foresight", "foresight", "foresight", "foresight"]
	engine.state.players[0].deck_state = []
	engine.state.players[1].deck_state = []
	engine._begin_deployment()
	for player in range(2):
		for hero in engine.state.players[player].roster:
			if int(hero.ready_round) <= int(engine.state.round):
				engine.state.players[player].plans[str(hero.uid)] = 0
		engine.state.players[player].finished = true
	engine._reveal_deployment()
	_check(engine.state.players[0].hand.size() == 3 and engine.state.players[1].hand.size() == 2, "rules_round_draw_2: its owner draws 3 at the reveal, the opponent 2")
	engine = _engine()
	_caster(engine, 0, "red")
	_improve(engine, "fx_oath", 0, 0)
	_hand(engine, 0, ["bronze_legionnaire", "fx_disarm_spell"])
	_unit(engine, "melee_creep", 1, 0)
	var plays = engine.legal_actions(0).filter(func(action): return str(action.type) == "play")
	_check(not plays.any(func(action): return int(action.hand) == 0) and plays.any(func(action): return int(action.hand) == 1),
		"rules_forbid_1: the ban forbids creeps in its lane, not spells")
	engine.state.lane = 1
	_caster(engine, 0, "red", 1)
	_check(engine.legal_actions(0).any(func(action): return str(action.type) == "play" and int(action.hand) == 0), "rules_forbid_2: creeps are allowed in other lanes")

## Kanna (RQ-22): -1 lane creeps, resolved at the reveal, randomness unchanged.
func _test_creep_lane() -> void:
	var states: Array = []
	var pendings: Array = []
	for with_kanna in [false, true]:
		var engine = _engine(5)
		if with_kanna:
			var kanna = engine._make_unit(engine.library.definition("fx_kanna"), 0, true)
			engine.state.players[0].roster.append(kanna)
			engine._place(kanna, 2, 0)
		engine._begin_deployment()
		states.append(engine.rng.state)
		pendings.append(engine.state.pending_creeps.duplicate(true))
		if with_kanna:
			_check(engine.player_view(1).pending_creeps[0] == [-1, -1], "rq_22_kanna_lane: the opponent sees -1 lane creeps")
			var before = engine.state.lanes[2].units[0].filter(func(unit): return unit != null and str(unit.card) == "melee_creep").size()
			for player in range(2):
				for hero in engine.state.players[player].roster:
					if int(hero.lane) == -1 and int(hero.ready_round) <= int(engine.state.round):
						engine.state.players[player].plans[str(hero.uid)] = 0
				engine.state.players[player].finished = true
			engine._reveal_deployment()
			var after = engine.state.lanes[2].units[0].filter(func(unit): return unit != null and str(unit.card) == "melee_creep").size()
			_check(after == before + 2, "rq_22_kanna_lane: both lane creeps deploy into Kanna's current lane")
			_check(Invariants.violations(engine).is_empty(), "Invariants hold after Kanna's deployment")
	_check(states[0] == states[1] and pendings[1][0] == [-1, -1] and pendings[1][1] == pendings[0][1], "rq_22_kanna_lane: the lanes are still drawn, so randomness is unchanged")
	# A ready Kanna in the Fountain counts, and her planned lane wins.
	var engine = _engine(6)
	var kanna = engine._make_unit(engine.library.definition("fx_kanna"), 0, true)
	kanna.ready_round = 1
	engine.state.players[0].roster.append(kanna)
	engine._begin_deployment()
	_check(engine.state.pending_creeps[0] == [-1, -1], "rq_22_kanna_ready: a ready Kanna in the Fountain redirects the creeps")
	for player in range(2):
		for hero in engine.state.players[player].roster:
			if int(hero.lane) == -1 and int(hero.ready_round) <= int(engine.state.round):
				engine.state.players[player].plans[str(hero.uid)] = 1 if str(hero.card) == "fx_kanna" else 0
		engine.state.players[player].finished = true
	_check(engine.player_view(1).players[0].plans.is_empty(), "Kanna's plan stays private")
	engine._reveal_deployment()
	_check(engine.state.lanes[1].units[0].filter(func(unit): return unit != null and str(unit.card) == "melee_creep").size() == 2 and int(kanna.lane) == 1,
		"rq_22_kanna_planned: the creeps follow Kanna's planned lane")
	engine = _engine(7)
	kanna = engine._make_unit(engine.library.definition("fx_kanna"), 0, true)
	kanna.ready_round = 9
	engine.state.players[0].roster.append(kanna)
	engine._begin_deployment()
	_check(not engine.state.pending_creeps[0].has(-1), "rq_22_kanna_not_ready: a Kanna who cannot deploy redirects nothing")

## Taunt (RQ-18), Enough Magic! (RQ-20), granted triggers (RQ-44), the
## attackers relation (RQ-05), "half" (RQ-28), ancients (RQ-46) and allies
## including the source (RQ-50).
func _test_taunt_and_end_phase() -> void:
	var engine = _engine()
	var made = _rows(engine, 0, [[null, "melee_creep", "axe"], ["melee_creep", "melee_creep", "melee_creep"]])
	_hand(engine, 0, ["fx_taunt_creep"])
	var play = engine.legal_actions(0).filter(func(action): return str(action.type) == "play" and int(action.position) == 0)
	_check(not play.is_empty(), "Taunting Guard can take the empty position")
	if not play.is_empty():
		engine.apply_action(0, play[0])
	var taunter = engine.state.lanes[0].units[0][0]
	_check(taunter != null and str(taunter.card) == "fx_taunt_creep" and int(made[1][0].combat_target) == int(taunter.uid) and int(made[1][1].combat_target) == int(taunter.uid),
		"rq_18_taunt: the taunter's enemy neighbors target it")
	_zones_ok(engine, "taunt")
	engine = _engine()
	_rows(engine, 0, [["melee_creep"], ["melee_creep"]])
	_caster(engine, 0, "red")
	_play(engine, 0, "fx_end_phase")
	_check(int(engine.state.lane) == 1 and int(engine.state.initiative) == 1 and not _events(engine, "combat").is_empty(),
		"rq_20_end_action_phase: the lane goes straight to combat and the opponent gets initiative")
	engine = _engine()
	var hero = _caster(engine, 0, "red")
	_unit(engine, "melee_creep", 1, 0)
	var health = engine.max_health_of(hero)
	_check(_play(engine, 0, "fx_grant_spell", {"target": hero.uid}).ok, "Steadfast Vow plays")
	_check(engine.max_health_of(hero) == health + 1 and hero.mods.any(func(entry): return str(entry.get("ab", "")) == "fx_grant_spell#0"),
		"rq_44_granted_sees_granting: a granted after-you-play trigger sees the card that granted it")
	engine = _engine()
	made = _rows(engine, 0, [["fx_retaliate_2", null], ["fx_cleave_3", "fx_cleave_3"]])
	made[1][1].arrow = -1
	Kernel.give(engine, made[1][0], {}, {"disarm": 1}, "", "round", {"controller": 0, "card": ""})
	var attackers = EngineClass.Select.related(engine, "attackers", made[0][0])
	_check(attackers.size() == 1 and int(attackers[0].uid) == int(made[1][1].uid), "rq_05_attackers: a unit's attackers are the enemies aiming at it that are not disarmed")
	var ctx = {"controller": 0, "lane": 0, "card": "", "choices": {}, "vars": {}}
	_check(EngineClass.VM.expr(engine, {"half": 7}, ctx) == 3 and EngineClass.VM.expr(engine, {"half": -3}, ctx) == -2, "rq_28_half: half rounds down")
	engine = _engine()
	made = _rows(engine, 0, [["melee_creep", "melee_creep"], ["fx_retaliate_2", "fx_retaliate_2"]])
	EngineClass.VM.run(engine, [{"op": "damage_split", "to": {"s": "units", "side": "enemy", "lane": null, "kind": null, "card": null, "color": null,
		"slot": null, "rel": null, "not": null, "where": null, "zone": null, "player": null, "pick": null, "after": null}, "total": 9}], ctx)
	_check(int(made[1][0].health) == 7 - (4 - 1) and int(made[1][1].health) == 7 - (4 - 1), "rq_28_damage_split: each of N targets takes floor(total / N), the remainder is lost")
	engine = _engine()
	_tower(engine, 0, 1).ancient = true
	_tower(engine, 0, 1).health = 80
	var selector = {"s": "towers", "side": "enemy", "lane": "all", "kind": null, "card": null, "color": null,
		"slot": null, "rel": null, "not": null, "where": null, "zone": null, "player": null, "pick": null, "after": null}
	var towers = EngineClass.Select.resolve_set(engine, selector, ctx)
	_check(towers.size() == 3 and towers.any(func(tower): return int(tower.lane) == 0), "rq_46_ancient_is_tower: a lane's ancient is its tower")
	var lane_zero = selector.duplicate()
	lane_zero.lane = 0
	EngineClass.VM.run(engine, [{"op": "tower_damage", "to": lane_zero, "amount": 5, "piercing": false}], ctx)
	_check(int(_tower(engine, 0, 1).health) == 75, "rq_46_ancient_is_tower: tower damage hits the ancient")
	engine = _engine()
	var unit = _unit(engine, "melee_creep", 0, 0)
	_unit(engine, "melee_creep", 0, 0)
	var own_ctx = Stats.unit_ctx(engine, unit)
	_check(EngineClass.VM.expr(engine, {"count": {"s": "units", "side": "ally", "lane": null, "kind": null, "card": null, "color": null, "slot": null,
		"rel": null, "not": null, "where": null, "zone": null, "player": null, "pick": null, "after": null}}, own_ctx) == 2,
		"rq_50_allies_include_self: allies counts the source itself")

## RQ-51: the round draw happens before placement; an Hourglass on a host
## already in a lane locks both drawn cards, a host deployed this phase does not.
func _test_hourglass_round_draw() -> void:
	for in_lane in [true, false]:
		var engine = _engine(11)
		var hero = engine.state.players[0].roster[0]
		Zones.equip(engine, hero, "fx_hourglass")
		if in_lane:
			_rows(engine, 0, [[hero], ["melee_creep"]])
		engine.state.players[1].deck = ["foresight", "foresight", "foresight"]
		engine.state.players[1].deck_state = []
		engine._begin_deployment()
		for player in range(2):
			for other in engine.state.players[player].roster:
				if int(other.lane) == -1 and int(other.ready_round) <= int(engine.state.round):
					engine.state.players[player].plans[str(other.uid)] = 1
			engine.state.players[player].finished = true
		engine._reveal_deployment()
		var locks = engine.state.players[1].hand_state.map(func(entry): return int(entry.get("lock", 0)))
		if in_lane:
			_check(locks == [1, 1], "rq_51_hourglass_round_draw: a host already in a lane locks both round-draw cards (%s)" % [locks])
		else:
			_check(locks == [0, 0], "rq_51_hourglass_round_draw: a host deployed this phase locks neither (%s)" % [locks])

# --- preview_equals_combat ----------------------------------------------------------

# --- M2 review regressions ------------------------------------------------------

## A hand card handle as the VM selects it.
func _handle(engine, player: int, index: int) -> Dictionary:
	var owner: Dictionary = engine.state.players[player]
	return {"cardref": true, "p": player, "zone": "hand", "index": index, "card": str(owner.hand[index]),
		"iid": int(owner.hand_state[index].iid)}

func _test_review_fixes() -> void:
	# next_combat given during the lane's own combat (a death trigger in its
	# Pulse) lasts until that lane's next combat.
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_rally_creep", "melee_creep"], ["melee_creep", "fx_pierce_creep"]])
	var rally: Dictionary = made[0][0]
	var base = engine.attack_of(rally)
	made[0][1].health = 1
	_combat(engine)
	_check(int(made[0][1].lane) == -1 and engine.attack_of(rally) == base + 3,
		"fix_next_combat_1: +3 until next combat granted in this combat's Pulse survives the combat (attack %d)" % engine.attack_of(rally))
	Combat.resolve(engine, 0)
	_check(engine.attack_of(rally) == base, "fix_next_combat_2: it ends with the lane's next combat")
	engine = _engine()
	made = _rows(engine, 0, [["fx_rally_creep", "melee_creep"], ["melee_creep", "fx_pierce_creep"]])
	rally = made[0][0]
	made[0][1].health = 1
	_combat(engine)
	Zones.move(engine, rally, 1, null)
	_unit(engine, "melee_creep", 1, 1)
	_check(engine.attack_of(rally) == base + 3, "fix_next_combat_3: the entry follows a move")
	_combat(engine)
	_check(int(rally.lane) == 1 and engine.attack_of(rally) == base, "fix_next_combat_4: after a move it ends with the next combat of its new lane")
	_check(Invariants.violations(engine).is_empty(), "Invariants hold after next_combat stamps: %s" % [Invariants.violations(engine)])
	# The attackers relation and death snapshots skip stunned and disarmed attackers (RQ-05).
	for status in ["stun", "disarm"]:
		engine = _engine()
		made = _rows(engine, 0, [["melee_creep"], ["melee_creep"]])
		var mine: Dictionary = made[0][0]
		var enemy: Dictionary = made[1][0]
		_check(Select.related(engine, "attackers", mine).size() == 1 and Kernel._snapshot(engine, [mine])[0].attackers == [int(enemy.uid)],
			"fix_attackers_1: an enemy aimed at a unit is its attacker")
		Kernel.give(engine, enemy, {}, {status: 1}, "", "round", {"controller": 0, "card": ""})
		_check(Select.related(engine, "attackers", mine).is_empty(), "fix_attackers_2: a %s enemy is not an attacker" % status)
		_check(Kernel._snapshot(engine, [mine])[0].attackers.is_empty(), "fix_attackers_3: a death snapshot leaves out a %s attacker" % status)
	# A Soulbound unit its own Death Shield saves does not die, so its twins stay.
	engine = _engine()
	var one = _unit(engine, "fx_soulbound_creep", 0, 0)
	var two = _unit(engine, "fx_soulbound_creep", 0, 2)
	Kernel.give(engine, one, {}, {"death_shield": 1}, "", "used", {"controller": 0, "card": ""})
	one.condemned = true
	engine._clean_dead(0)
	_check(int(one.lane) == 0 and int(one.health) == 1 and int(two.lane) == 2, "fix_soulbound_shield_1: a shielded Soulbound unit survives and its twin stays")
	engine = _engine()
	made = _rows(engine, 0, [["fx_soulbound_creep", "fx_soulbound_creep"], ["fx_pierce_creep", null]])
	Kernel.give(engine, made[0][0], {}, {"death_shield": 1}, "", "used", {"controller": 0, "card": ""})
	var preview = engine.combat_preview(0)
	_check(preview.dies.is_empty(), "fix_soulbound_shield_2: the preview keeps both twins (%s)" % [preview.dies])
	_combat(engine)
	_check(int(made[0][0].lane) == 0 and int(made[0][0].health) == 1 and int(made[0][1].lane) == 0, "fix_soulbound_shield_3: so does the combat")
	engine = _engine()
	made = _rows(engine, 0, [["fx_soulbound_creep", "fx_soulbound_creep"], ["fx_pierce_creep", null]])
	preview = engine.combat_preview(0)
	_combat(engine)
	_check(preview.dies.size() == 2 and int(made[0][0].lane) == -1 and int(made[0][1].lane) == -1, "fix_soulbound_shield_4: without a shield both twins still die")
	engine = _engine()
	made = _rows(engine, 0, [["fx_soulbound_creep", "fx_soulbound_creep"], ["fx_pierce_creep", "fx_pierce_creep"]])
	Kernel.give(engine, made[0][0], {}, {"death_shield": 1}, "", "used", {"controller": 0, "card": ""})
	preview = engine.combat_preview(0)
	_combat(engine)
	_check(preview.dies.size() == 2 and int(made[0][0].lane) == -1 and int(made[0][1].lane) == -1,
		"fix_soulbound_shield_5: a shield that saved its unit is used; its unshielded twin's death then takes it")
	# Using a Death Shield removes only the shield from its entry.
	engine = _engine()
	var unit = _unit(engine, "melee_creep", 0, 0)
	base = engine.attack_of(unit)
	Kernel.give(engine, unit, {"attack": 5}, {"death_shield": 1}, "", "round", {"controller": 0, "card": ""})
	unit.condemned = true
	engine._clean_dead(0)
	_check(int(unit.lane) == 0 and engine.attack_of(unit) == base + 5 and not engine.has_flag(unit, "death_shield") and unit.mods.size() == 1,
		"fix_shield_entry_1: the rest of the entry (+5 Attack) stays after the shield is used")
	engine._begin_deployment()
	_check(engine.attack_of(unit) == base and unit.mods.is_empty(), "fix_shield_entry_2: and still ends with the round")
	# A shield in the unit's own keywords (printed, or written by a Modify) is used up too.
	engine = _engine()
	unit = _unit(engine, "melee_creep", 0, 0)
	if not unit.has("kw"):
		unit["kw"] = {}
	unit.kw["death_shield"] = 1
	unit.condemned = true
	engine._clean_dead(0)
	_check(int(unit.lane) == 0 and int(unit.health) == 1 and not engine.has_flag(unit, "death_shield"), "fix_shield_printed_1: a printed shield saves once")
	unit.condemned = true
	engine._clean_dead(0)
	_check(int(unit.lane) == -1, "fix_shield_printed_2: then the unit dies")
	engine = _engine()
	unit = _unit(engine, "melee_creep", 0, 0)
	Kernel.modify(engine, unit, {}, {"death_shield": 1}, "", {"controller": 1, "card": "fx_curse_spell"})
	unit.condemned = true
	engine._clean_dead(0)
	_check(int(unit.lane) == 0 and not engine.has_flag(unit, "death_shield"), "fix_shield_modify_1: a modified shield saves once")
	Kernel.purge(engine, unit, "all", {"controller": 0, "card": ""})
	_check(int(unit.kw.get("death_shield", 0)) == 0, "fix_shield_modify_2: Purge after it was used leaves no negative shield")
	_check(Invariants.violations(engine).is_empty(), "Invariants hold after shields: %s" % [Invariants.violations(engine)])
	# Discard and card counters find hand handles by iid, not by a stale index.
	engine = _engine()
	_hand(engine, 0, ["fx_raze", "fx_swap", "fx_control"])
	var handles = [_handle(engine, 0, 0), _handle(engine, 0, 1), _handle(engine, 0, 2)]
	Zones.discard(engine, [handles[0]])
	Zones.lock(engine, [handles[1]], 1)
	_check(engine.state.players[0].hand == ["fx_swap", "fx_control"] and int(engine.state.players[0].hand_state[0].get("lock", 0)) == 1,
		"fix_discard_1: lock after a discard hits the same card")
	Zones.discard(engine, [handles[1]])
	_check(engine.state.players[0].hand == ["fx_control"], "fix_discard_2: a later discard removes its own card (%s)" % [engine.state.players[0].hand])
	var events = _events(engine, "discard").size()
	Zones.discard(engine, [handles[0], handles[1]])
	_check(engine.state.players[0].hand == ["fx_control"] and _events(engine, "discard").size() == events, "fix_discard_3: handles of cards already gone fizzle")
	Zones.discard(engine, [handles[2], handles[2]])
	_check(engine.state.players[0].hand.is_empty() and int(_events(engine, "discard").back().n) == 1, "fix_discard_4: a card listed twice is discarded once")
	engine = _engine()
	_hand(engine, 0, ["fx_counter_spell", "fx_counter_spell"])
	engine.state.players[0].hand_state[1]["charges"] = 3
	var second = _handle(engine, 0, 1)
	Zones.discard(engine, [_handle(engine, 0, 0)])
	_check(Zones.card_counter(engine, second) == 3, "fix_card_counter_1: a hand counter is read by iid after a discard")
	_check(Invariants.violations(engine).is_empty(), "Invariants hold after discards: %s" % [Invariants.violations(engine)])


## Engine capabilities added with the M3 cards (EFFECT_SYSTEM_SPEC.md §12, M3
## as built): the `blocking` death snapshot behind the "was": "blocker"
## filter, a Modify that reaches a hero killed in the same command (RQ-54),
## and granted text in mod/status events.
func _test_m3_engine() -> void:
	# "A unit blocking it" is the unit's combat target: a stunned or disarmed
	# unit is still blocked, so its trigger fires (Bristleback, Stonehall Elite).
	for status in ["stun", "disarm"]:
		var engine = _engine()
		var made = _rows(engine, 0, [["fx_grudge_creep"], ["melee_creep"]])
		var grudge: Dictionary = made[0][0]
		var blocker: Dictionary = made[1][0]
		Kernel.give(engine, grudge, {}, {status: 1}, "", "round", {"controller": 1, "card": ""})
		var snapshot: Dictionary = Kernel._snapshot(engine, [blocker])[0]
		_check(snapshot.blocking == [int(grudge.uid)] and snapshot.attackers.is_empty(),
			"m3_blocking_1: a %s unit aimed at the dying unit is in blocking, not in attackers (RQ-05)" % status)
		engine._reset_transient()
		blocker.health = 0
		Kernel.pulse(engine)
		engine._settle_transient()
		_check(engine.attack_of(grudge) == 3, "m3_blocking_2: a %s unit grows after the unit blocking it dies (attack %d)" % [status, engine.attack_of(grudge)])
	var engine = _engine()
	var made = _rows(engine, 0, [["fx_grudge_creep", null], [null, "melee_creep"]])
	made[0][0].arrow = 1
	Stats.settle(engine)
	engine._reset_transient()
	made[1][1].health = 0
	Kernel.pulse(engine)
	engine._settle_transient()
	_check(engine.attack_of(made[0][0]) == 3, "m3_blocking_3: a diagonal combat target counts as blocking")
	engine = _engine()
	made = _rows(engine, 0, [["fx_grudge_creep", "melee_creep"], ["melee_creep", "melee_creep"]])
	engine._reset_transient()
	made[1][1].health = 0
	Kernel.pulse(engine)
	engine._settle_transient()
	_check(engine.attack_of(made[0][0]) == 1, "m3_blocking_4: the death of a unit blocking another unit does not count")
	# RQ-54: a hero that dies in the combat where it hit Acid Shell keeps the
	# -1 Attack in the Fountain (heroes keep modifications through death).
	engine = _engine()
	var hero: Dictionary = engine.state.players[0].roster[0]
	var printed = int(hero.attack)
	made = _rows(engine, 0, [[hero], ["fx_corrode_creep"]])
	hero.health = 2
	_combat(engine)
	_check(int(hero.lane) == -1 and int(hero.attack) == printed - 1 and engine.attack_of(hero) == printed - 1,
		"rq_54_dead_hero_keeps_modify: the hero is in the Fountain with %d Attack (printed %d)" % [engine.attack_of(hero), printed])
	_check(_events(engine, "mod").any(func(event): return int(event.get("id", 0)) == int(hero.uid)), "rq_54_dead_hero_keeps_modify: a mod event names the hero")
	_check(Invariants.violations(engine).is_empty(), "rq_54: invariants hold: %s" % [Invariants.violations(engine)])
	engine = _engine()
	made = _rows(engine, 0, [["melee_creep"], ["fx_corrode_creep"]])
	var creep: Dictionary = made[0][0]
	_combat(engine)
	_check(int(creep.lane) == -1 and not _events(engine, "mod").any(func(event): return int(event.get("id", 0)) == int(creep.uid)),
		"rq_54_dead_creep_fizzles: a creep that died is gone; the Modify fizzles")
	engine = _engine()
	hero = engine.state.players[0].roster[0]
	made = _rows(engine, 0, [[hero], ["fx_corrode_creep"]])
	_combat(engine)
	_check(int(hero.lane) == 0 and engine.attack_of(hero) == printed - 1, "rq_54_live_hero: a surviving attacker loses 1 Attack")
	# Granted text travels in the mod event ("ab") and reaches the log.
	engine = _engine()
	var caster = _caster(engine, 0, "red")
	_check(_play(engine, 0, "fx_grant_spell", {"target": caster.uid}).ok, "m3_grant_event_1: Steadfast Vow plays")
	# The grant's own mod event names it; the trigger it grants then fires on
	# this very play (cost 2, RQ-44) with a plain +1 Health mod event.
	var mods = _events(engine, "mod").filter(func(event): return event.has("ab"))
	_check(mods.size() == 1 and str(mods[0].ab) == "fx_grant_spell#0", "m3_grant_event_2: the mod event names the granted text (%s)" % [mods])
	if not mods.is_empty():
		Settings.set_locale("en", false)
		var text = EventText.format(mods[0])
		_check(text.find("After you play a card costing 2 or less") != -1 and text.find("none") == -1,
			"m3_grant_event_3: the log shows the granted text: %s" % text)

## On random fixture boards (keywords, statuses, items, improvements), the
## combat preview's damage, healing, deaths and tower damage equal what the
## combat then does.
func _test_preview_equals_combat() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 7151
	var creeps = ["melee_creep", "fx_cleave_3", "fx_retaliate_2", "fx_regen_2", "fx_siege_3", "fx_pierce_creep", "fx_lethal_creep",
		"fx_soulbound_creep", "fx_bounty_creep", "centaur_hunter", "bronze_legionnaire", "prowler_vanguard", "untested_grunt"]
	var heroes = ["axe", "keefe", "debbi", "phantom_assassin", "farvhan", "lycan", "drow", "zeus", "jmuy", "rix"]
	var items = ["short_sword", "broadsword", "leather_armor", "travelers_cloak", "fx_lethal_item", "fx_regen_armor", "claymore"]
	var statuses = [{"stun": 1}, {"disarm": 1}, {"silence": 1}, {"damage_immunity": 1}, {"death_shield": 1}, {"pierce": 1},
		{"lethal_creeps": 1}, {"cleave": 2}, {"retaliate": 1}, {"regeneration": 3}, {"siege": 2}]
	var base = _engine(99)
	var base_state = base.state.duplicate(true)
	var mismatches: Array = []
	var dies_total = 0
	var heal_total = 0
	var shields_total = 0
	for board in range(boards):
		var engine = EngineClass.new()
		engine.library = library
		engine.state = base_state.duplicate(true)
		engine.rng.seed = board + 1
		engine.next_id = 500
		var width = rng.randi_range(1, 6)
		var rows: Array = [[], []]
		for slot in range(width):
			for side in range(2):
				var card_id = null
				var roll = rng.randi_range(0, 9)
				if roll < 6:
					card_id = creeps[rng.randi_range(0, creeps.size() - 1)]
				elif roll < 8:
					card_id = heroes[rng.randi_range(0, heroes.size() - 1)]
				rows[side].append(card_id)
			if rows[0][slot] == null and rows[1][slot] == null:
				rows[rng.randi_range(0, 1)][slot] = creeps[0]
		var made = _rows(engine, 0, rows)
		for side in range(2):
			for unit in made[side]:
				if unit == null:
					continue
				if bool(unit.hero) and rng.randi_range(0, 2) == 0:
					Zones.equip(engine, unit, items[rng.randi_range(0, items.size() - 1)])
				if rng.randi_range(0, 3) == 0:
					Kernel.give(engine, unit, {}, statuses[rng.randi_range(0, statuses.size() - 1)], "", "round", {"controller": 1 - side, "card": ""})
				if rng.randi_range(0, 4) == 0:
					Kernel.give(engine, unit, {"attack": rng.randi_range(-2, 3), "armor": rng.randi_range(-1, 2)}, {}, "", "round", {"controller": side, "card": ""})
		engine._roll_arrows()
		for side in range(2):
			for unit in made[side]:
				if unit == null or rng.randi_range(0, 5) != 0:
					continue
				var enemies = engine.combat_targets(unit)
				if not enemies.is_empty():
					Kernel.retarget(engine, unit, Select_one(engine, enemies[rng.randi_range(0, enemies.size() - 1)]))
		for side in range(2):
			if rng.randi_range(0, 2) == 0:
				_improve(engine, "fx_tower_guard", side, 0)
			_tower(engine, 0, side).health = rng.randi_range(1, 40)
		Stats.settle(engine)
		for side in range(2):
			for unit in engine.state.lanes[0].units[side]:
				if unit != null:
					unit.health = rng.randi_range(1, engine.max_health_of(unit))
		engine.state.events = []
		var preview = engine.combat_preview(0)
		var expected: Dictionary = {}
		var shielded: Dictionary = {}
		var units_before: Dictionary = {}
		for side in range(2):
			for unit in engine.state.lanes[0].units[side]:
				if unit == null:
					continue
				var key = str(unit.uid)
				expected[int(unit.uid)] = mini(engine.max_health_of(unit), int(unit.health) - int(preview.unit_damage.get(key, 0)) + int(preview.heal.get(key, 0)))
				shielded[int(unit.uid)] = engine.has_flag(unit, "death_shield")
				units_before[int(unit.uid)] = unit
		engine._reset_transient()
		Combat.resolve(engine, 0)
		engine._settle_transient()
		var combat = _events(engine, "combat").back()
		var problem = ""
		if Array(combat.damage) != Array(preview.tower_damage):
			problem = "tower damage %s vs %s" % [preview.tower_damage, combat.damage]
		for uid in units_before:
			var unit: Dictionary = units_before[uid]
			var died = int(unit.get("lane", -1)) != 0
			var predicted = preview.dies.has(uid)
			if died != predicted:
				problem = "unit %s died %s, preview %s" % [unit.card, died, predicted]
				break
			if died:
				continue
			var want = int(expected[uid])
			if bool(shielded[uid]) and want <= 0:
				want = 1
				shields_total += 1
			if bool(shielded[uid]) and not engine.has_flag(unit, "death_shield"):
				want = 1
			if int(unit.health) != want:
				problem = "unit %s health %d, preview %d" % [unit.card, int(unit.health), want]
				break
		dies_total += preview.dies.size()
		heal_total += preview.heal.size()
		if problem != "" and mismatches.size() < 5:
			mismatches.append("board %d: %s" % [board, problem])
	_check(mismatches.is_empty(), "preview_equals_combat on %d random fixture boards: %s" % [boards, mismatches])
	_check(dies_total > boards / 4 and heal_total > boards / 20, "The random boards exercise deaths (%d), regeneration (%d) and shields (%d)" % [dies_total, heal_total, shields_total])
