extends SceneTree

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	_catalog()
	_signatures_and_modifiers()
	_passives()
	_jmuy()
	_berserkers_call()
	_targeting()
	_spells()
	_equipment()
	_bot_games()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d Classic card checks and 12 complete Classic-deck bot/replay matches." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _fixture(hero_index: int = 0):
	var engine = MatchEngine.new()
	engine.start(10414)
	for lane in engine.state.lanes:
		lane.units = [[], []]
	for owner in engine.state.players:
		owner.hand = []
		for hero in owner.roster:
			hero.lane = -1
	for player in range(2):
		var hero = engine.state.players[player].roster[hero_index if player == 0 else 0]
		hero.lane = 0
		hero.arrow = 0
		engine.state.lanes[0].units[player] = [hero]
	engine.state.lanes[0].mana = [10, 10]
	engine.state.lanes[0].max_mana = [10, 10]
	engine.state.active_player = 0
	engine.state.initiative = 0
	return engine

func _play(engine, card: String, target: int = -1, destination: int = -1) -> Dictionary:
	engine.state.players[0].hand = [card]
	engine.state.active_player = 0
	var command = {"type": "play", "hand": 0}
	if target != -1:
		command.target = target
	if destination != -1:
		command.destination = destination
	return engine.apply_action(0, command)

func _catalog() -> void:
	var engine = MatchEngine.new()
	engine.start(1)
	_check(engine.library.content_pack == "artifact_classic_decks_v2", "Classic is the default content pack")
	_check(engine.library.match_deck().size() == 40, "Classic starter main deck has forty cards")
	var expected_stats = [[6, 2, 10], [3, 0, 8], [4, 0, 10], [6, 1, 11], [7, 0, 5]]
	for index in range(5):
		var hero = engine.library.heroes[index]
		_check([int(hero.attack), int(hero.armor), int(hero.health)] == expected_stats[index], "Authentic stats for " + hero.name)
		_check(engine.library.match_deck().count(hero.signature) == 3, "Three signature copies for " + hero.name)
	for card_id in engine.library.catalog.deck:
		_check(engine.library.match_deck().count(card_id) <= 3, "Maximum three main-deck copies")
	_check(engine.library.cards.bronze_legionnaire.cost == 2 and engine.library.cards.ogre_conscript.cost == 6, "Source creep mana costs")
	_check(engine.library.cards.fighting_instinct.cost == 5 and engine.library.cards.foresight.cost == 4, "Source spell mana costs")

func _signatures_and_modifiers() -> void:
	var engine = _fixture()
	var hero = engine.state.lanes[0].units[0][0]
	_check(_play(engine, "fighting_instinct", hero.uid).ok, "Fighting Instinct can modify a red hero")
	_check(engine.attack_of(hero) == 7 and engine.armor_of(hero) == 3, "Fighting Instinct permanently adds attack and armor")
	engine._begin_deployment()
	_check(engine.attack_of(hero) == 7 and engine.armor_of(hero) == 3, "Permanent modification survives round transition")
	hero.health = 0
	engine._clean_dead(0)
	engine._begin_deployment()
	engine._begin_deployment()
	engine.state.players[0].plans[str(hero.uid)] = 1
	engine._reveal_deployment()
	_check(hero.lane == 1 and engine.attack_of(hero) == 7 and engine.armor_of(hero) == 3, "Permanent modification survives death and redeployment")
	engine = _fixture()
	var blue = engine._make_unit(engine.library.heroes[1], 0, true)
	blue.lane = 0
	engine.state.lanes[0].units[0].append(blue)
	_check(not _play(engine, "fighting_instinct", blue.uid).ok, "Fighting Instinct rejects a blue hero")

func _passives() -> void:
	var engine = _fixture(2)
	var farvhan = engine.state.lanes[0].units[0][0]
	var prowler = engine._make_unit(engine.library.cards.prowler_vanguard, 0, false)
	var creep = engine._make_unit(engine.library.cards.melee_creep, 0, false)
	prowler.lane = 0
	creep.lane = 0
	var blocker = engine._make_unit(engine.library.cards.melee_creep, 1, false)
	blocker.lane = 0
	engine.state.lanes[0].units[0] = [farvhan, prowler, creep]
	engine.state.lanes[0].units[1] = [engine.state.lanes[0].units[1][0], blocker, null]
	_check(engine.armor_of(farvhan) == 1, "Prowler aura reaches Farvhan")
	_check(engine.armor_of(prowler) == 1, "Farvhan aura reaches adjacent Prowler")
	_check(engine.armor_of(creep) == 1, "Prowler aura reaches adjacent creep")
	prowler.health = 0
	engine._clean_dead(0)
	_check(engine.armor_of(creep) == 0 and engine.armor_of(farvhan) == 0, "Destroyed aura disappears immediately without stacking permanently")
	# With an enemy still opposite, Prowler's position stays as a gap. Once that
	# enemy also dies the empty position collapses and the creep slides next to
	# Farvhan, so it now gets his neighbor aura.
	blocker.health = 0
	engine._clean_dead(0)
	_check(engine.state.lanes[0].units[0].size() == 2 and engine.state.lanes[0].units[1].size() == 2, "Position empty on both sides collapses")
	_check(engine.armor_of(creep) == 1, "Collapsed lane makes the creep Farvhan's neighbor")
	engine = _fixture(4)
	var debbi = engine.state.lanes[0].units[0][0]
	_check(engine.battle_attack(debbi, {}) == 9, "Debbi deals nine damage to towers")
	_check(engine.battle_attack(debbi, engine.state.lanes[0].units[1][0]) == 9, "Debbi gets bonus against heroes")
	_check(engine.battle_attack(debbi, engine._make_unit(engine.library.cards.melee_creep, 1, false)) == 7, "Debbi gets no bonus against creeps")

func _jmuy() -> void:
	var engine = _fixture(1)
	var hero = engine.state.lanes[0].units[0][0]
	var old_deck = engine.state.players[0].deck.size()
	_check(engine.apply_action(0, {"type": "ability", "unit": hero.uid}).ok, "J'Muy can activate Wisdom of the Elders")
	_check(engine.state.players[0].hand.size() == 1 and engine.state.players[0].deck.size() == old_deck - 1, "J'Muy draws exactly one real deck card")
	_check(hero.cooldown == 4 and engine.state.lanes[0].mana[0] == 10, "J'Muy uses a four-round cooldown and no mana")
	engine.state.active_player = 0
	_check({"type": "ability", "unit": hero.uid} not in engine.legal_actions(0), "Cooldown prevents repeated activation")
	engine._begin_deployment()
	_check(hero.cooldown == 3, "Cooldown ticks down once per round")
	engine._begin_deployment()
	engine._begin_deployment()
	engine._begin_deployment()
	_check(hero.cooldown == 0, "Four round transitions recharge the ability")

func _berserkers_call() -> void:
	var engine = _fixture()
	var axe = engine.state.lanes[0].units[0][0]
	engine.state.lanes[0].units[0] = [null, axe, null, null]
	var opponents: Array = []
	for index in range(4):
		var creep = engine._make_unit(engine.library.cards.melee_creep, 1, false)
		creep.lane = 0
		opponents.append(creep)
	engine.state.lanes[0].units[1] = opponents.duplicate()
	_check(_play(engine, "berserkers_call", axe.uid).ok, "Berserker's Call is a legal red-hero action")
	_check(axe.health == 10, "Axe armor blocks every melee-creep battle separately")
	_check(opponents.slice(0, 3).all(func(creep): return creep.lane == -1), "Call battles all three enemy neighbors")
	_check(opponents[3].lane == 0, "Call does not hit non-neighbors")
	_check(engine.state.lanes[0].units == [[axe, null], [null, opponents[3]]], "Positions emptied on both sides collapse after the battles")
	_check(engine.state.players[0].gold == 3 and engine.state.lanes[0].mana[0] == 4, "Call pays six mana and awards creep bounties")
	engine = _fixture()
	axe = engine.state.lanes[0].units[0][0]
	axe.health = 2
	axe.armor = 0
	var opponent = engine.state.lanes[0].units[1][0]
	opponent.health = 2
	opponent.armor = 0
	_check(_play(engine, "berserkers_call", axe.uid).ok, "Mutually lethal battle resolves")
	_check(axe.lane == -1 and opponent.lane == -1 and engine.state.lanes[0].units == [[], []], "Call's opposing battle damage is simultaneous")
	_check(engine.state.players[0].gold == 5 and engine.state.players[1].gold == 5, "Both battle casualties award their enemy gold")

func _targeting() -> void:
	var engine = _fixture(1)
	var jmuy = engine.state.lanes[0].units[0][0]
	var enemy = engine.state.lanes[0].units[1][0]
	_check(not _play(engine, "battlefield_control", jmuy.uid, 0).ok, "A unit blocked in all three positions across cannot be redirected to the tower")
	# An empty diagonal is not enough while a unit stands directly across (RQ-19, FX-2).
	var ally = engine._make_unit(engine.library.cards.melee_creep, 0, false)
	ally.lane = 0
	engine.state.lanes[0].units[0].append(ally)
	engine.state.lanes[0].units[1].append(null)
	_check(not _play(engine, "battlefield_control", jmuy.uid, 0).ok, "An empty diagonal does not open the tower while a unit stands directly across (RQ-19)")
	# Open the position directly across: J'Muy, attacking a diagonal enemy, may pick the tower.
	engine = _fixture(1)
	jmuy = engine.state.lanes[0].units[0][0]
	enemy = engine.state.lanes[0].units[1][0]
	engine.state.lanes[0].units[0] = [jmuy, null]
	engine.state.lanes[0].units[1] = [null, enemy]
	jmuy.arrow = 1
	_check(engine.combat_preview(0).tower_damage[0] == 0, "J'Muy attacks the diagonal enemy before the redirect")
	_check(_play(engine, "battlefield_control", jmuy.uid, 0).ok, "Battlefield Control can choose the tower when the position directly across is empty")
	_check(engine.combat_preview(0).tower_damage[0] >= 3, "Chosen tower target changes the combat forecast")
	# A far enemy beyond the three positions across is never a legal destination.
	engine = _fixture(1)
	jmuy = engine.state.lanes[0].units[0][0]
	enemy = engine.state.lanes[0].units[1][0]
	var far = engine._make_unit(engine.library.cards.melee_creep, 1, false)
	far.lane = 0
	engine.state.lanes[0].units[0].append(null)
	engine.state.lanes[0].units[1].append(null)
	engine.state.lanes[0].units[0].append(null)
	engine.state.lanes[0].units[1].append(far)
	_check(not _play(engine, "battlefield_control", jmuy.uid, far.uid).ok, "Battlefield Control cannot reach an enemy two positions away")
	_check(_play(engine, "battlefield_control", jmuy.uid, enemy.uid).ok, "Battlefield Control can choose an enemy unit")
	_check(engine.combat_preview(0).tower_damage[0] == 0, "Chosen enemy unit replaces the tower target")
	engine.state.players[0].hand = ["battlefield_control"]
	engine.state.active_player = 0
	var before = engine.state_digest()
	_check(not engine.apply_action(0, {"type": "play", "hand": 0, "target": jmuy.uid, "destination": jmuy.uid}).ok, "A unit cannot redirect onto its own side")
	_check(engine.state_digest() == before, "Rejected redirect leaves all state unchanged")
	engine = _fixture(4)
	var debbi = engine.state.lanes[0].units[0][0]
	debbi.health = 1
	_check(_play(engine, "no_accident", debbi.uid).ok, "No Accident may target an allied unit")
	_check(engine.state.players[1].gold == 5, "Classic bounty is awarded when an enemy hero dies, including friendly damage")

func _spells() -> void:
	var engine = _fixture(1)
	var enemy = engine.state.lanes[0].units[1][0]
	var creep = engine._make_unit(engine.library.cards.untested_grunt, 1, false)
	creep.lane = 0
	engine.state.lanes[0].units[1].append(creep)
	_check(_play(engine, "tower_barrage").ok, "Tower Barrage plays")
	_check(enemy.health == 10, "Tower Barrage respects two armor")
	_check(creep.lane == -1 and engine.state.lanes[0].structures[1].health == 40, "Tower Barrage hits each enemy unit but not the enemy tower (RQ-01, FX-1)")
	engine = _fixture(1)
	_check(_play(engine, "dimensional_portal").ok, "Dimensional Portal plays")
	_check(engine.state.lanes[0].units[0].size() == 4, "Portal summons three real Melee Creeps")
	_check(engine.state.lanes[0].units[0].filter(func(unit): return unit != null and unit.card == "melee_creep").size() == 3, "Portal creeps fill new end positions when no own slot is empty")
	# Summons only roll pathing for the new units. An allied flanker keeps its
	# diagonal arrow; an enemy flanker is reset when a summon lands in front.
	engine = _fixture(1)
	var jmuy = engine.state.lanes[0].units[0][0]
	var enemy_hero = engine.state.lanes[0].units[1][0]
	var ally = engine._make_unit(engine.library.cards.melee_creep, 0, false)
	engine._place(ally, 0, 1)
	ally.arrow = -1
	_check(_play(engine, "dimensional_portal").ok, "Dimensional Portal plays beside an allied flanker")
	_check(ally.arrow == -1 and engine.combat_target_of(ally).uid == enemy_hero.uid, "Summon does not reroll existing arrows")
	engine = _fixture(1)
	jmuy = engine.state.lanes[0].units[0][0]
	var flanker = engine._make_unit(engine.library.cards.melee_creep, 1, false)
	engine._place(flanker, 0, 1)
	flanker.arrow = -1
	_check(engine.combat_target_of(flanker).uid == jmuy.uid, "Enemy flanker attacks J'Muy diagonally")
	_check(_play(engine, "dimensional_portal").ok, "Dimensional Portal plays beside an enemy flanker")
	var blocker = engine.state.lanes[0].units[0][engine._slot_of(flanker)]
	_check(blocker != null and blocker.card == "melee_creep", "First summon fills the only empty own position")
	_check(flanker.arrow == 0 and engine.combat_target_of(flanker).uid == blocker.uid, "A summon placed in front resets the flanker to attack it")
	engine = _fixture(1)
	_check(_play(engine, "foresight").ok and engine.state.players[0].hand.size() == 2, "Foresight draws two cards")
	engine = _fixture(2)
	_check(_play(engine, "stars_align").ok, "Stars Align plays")
	_check(engine.state.lanes[0].mana[0] == 12 and engine.state.lanes[0].max_mana[0] == 13, "Stars Align pays one and grants three temporary mana")
	engine._begin_deployment()
	_check(engine.state.lanes[0].max_mana[0] == 11 and engine.state.lanes[0].mana[0] == 11, "Temporary mana expires before normal next-round growth")
	engine = _fixture(4)
	var target = engine.state.lanes[0].units[1][0]
	_check(_play(engine, "hip_fire", target.uid).ok and engine.state.active_player == 0, "Hip Fire deals damage and grants initiative")
	_check(target.health == 8, "Hip Fire's four damage respects two armor")
	engine = _fixture(1)
	_check(_play(engine, "lightning_strike").ok and engine.state.lanes[0].structures[1].health == 34, "Lightning Strike deals six tower damage")

func _equipment() -> void:
	var engine = _fixture()
	var hero = engine.state.lanes[0].units[0][0]
	for card in ["short_sword", "leather_armor", "travelers_cloak"]:
		_check(_play(engine, card, hero.uid).ok, "Equip " + card)
	_check(engine.attack_of(hero) == 8 and engine.armor_of(hero) == 3 and hero.health == 14, "Real equipment applies the printed stats")
	_check(_play(engine, "short_sword", hero.uid).ok and engine.attack_of(hero) == 8, "Equipment replacement does not stack")

func _bot_games() -> void:
	var bot = Bot.new()
	for seed_value in range(1, 13):
		var engine = MatchEngine.new()
		engine.start(seed_value)
		var steps = 0
		while engine.state.winner == -1 and steps < 1500:
			var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
			var command = bot.choose_action(engine, player)
			if command.is_empty():
				failures.append("Classic bot stalled in seed %d" % seed_value)
				break
			_check(engine.apply_action(player, command).ok, "Classic bot command is legal")
			steps += 1
		_check(engine.state.winner != -1, "Classic match terminates in seed %d" % seed_value)
		var restored = MatchEngine.new()
		_check(restored.load_replay(JSON.parse_string(JSON.stringify(engine.replay_data()))).ok, "Classic replay loads")
		_check(restored.state_digest() == engine.state_digest(), "Classic replay reproduces every state field and RNG")
