extends SceneTree

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	_profiles()
	_auras()
	_silence()
	_cross_lane_and_zeus()
	_growth_siege_and_removal()
	_consumables_and_shop()
	_privacy_and_validation()
	_matchup_matrix()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d expansion checks; all 18 seeded deck matchups and replay round trips tested." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _empty():
	var engine = MatchEngine.new()
	engine.start(17)
	for lane in engine.state.lanes:
		lane.units = [[], []]
		lane.mana = [20, 20]
		lane.max_mana = [20, 20]
	for owner in engine.state.players:
		owner.hand = []
		for hero in owner.roster:
			hero.lane = -1
	engine.state.active_player = 0
	return engine

func _unit(engine, card_id: String, owner: int, lane_index: int = 0):
	var definition = engine.library.definition(card_id)
	var unit = engine._make_unit(definition, owner, definition.kind == "hero")
	unit.lane = lane_index
	engine.state.lanes[lane_index].units[owner].append(unit)
	return unit

func _play(engine, card_id: String, target: int = -1) -> Dictionary:
	engine.state.active_player = 0
	engine.state.players[0].hand = [card_id]
	var command = {"type": "play", "hand": 0}
	if target != -1:
		command.target = target
	return engine.apply_action(0, command)

func _profiles() -> void:
	var engine = MatchEngine.new()
	_check(engine.library.heroes.size() == 10 and engine.library.cards.size() == 39, "Forty-nine real definitions are available")
	_check(engine.library.presets().size() == 3, "Three playable deck presets")
	for profile in engine.library.presets():
		_check(engine.library.validate_preset(profile).ok, "Preset passes card/hero/signature validation")
		_check(engine.library.match_deck(profile.id).size() == 40, "Preset main deck has forty cards")
		_check(engine.library.item_deck(profile.id).size() == 9, "Preset item deck has nine equipment cards")
		_check(engine.start(17, [profile.id, "starter"]).ok, "Preset starts a match")
		_check(engine.state.players[0].roster.map(func(hero): return hero.card) == profile.heroes, "Chosen roster and deployment order are used")
	var bad = engine.library.preset("starter").duplicate(true)
	bad.heroes[1] = "axe"
	_check(not engine.library.validate_preset(bad).ok, "Duplicate heroes rejected")
	bad = engine.library.preset("starter").duplicate(true)
	bad.cards.berserkers_call = 2
	bad.cards.ogre_conscript = 3
	_check(not engine.library.validate_preset(bad).ok, "Missing signature copy rejected even with forty cards")
	bad = engine.library.preset("starter").duplicate(true)
	bad.items.short_sword = 1
	_check(not engine.library.validate_preset(bad).ok, "Undersized item deck rejected")
	bad = engine.library.preset("starter").duplicate(true)
	bad.cards.bronze_legionnaire = 2.5
	_check(not engine.library.validate_preset(bad).ok, "Fractional copies rejected")

func _auras() -> void:
	var engine = _empty()
	var lycan = _unit(engine, "lycan", 0)
	var creep = _unit(engine, "melee_creep", 0)
	var drow = _unit(engine, "drow", 0, 2)
	_check(engine.attack_of(lycan) == 5 and engine.attack_of(creep) == 5, "Drow global aura and Lycan neighbor aura stack")
	_check(engine.attack_of(drow) == 4, "Drow does not buff herself")
	drow.silenced = true
	_check(engine.attack_of(creep) == 5, "Silence does not remove passive auras")
	drow.health = 0
	engine._clean_dead(2)
	_check(engine.attack_of(creep) == 4, "Drow aura disappears when Drow leaves the board")
	lycan.health = 0
	engine._clean_dead(0)
	_check(engine.attack_of(creep) == 2, "Neighbor aura disappears after Lycan dies")
	var pa = _unit(engine, "phantom_assassin", 0)
	var enemy_hero = _unit(engine, "axe", 1)
	_check(engine.battle_attack(pa, enemy_hero) == 10, "Phantom Assassin's bonus applies to heroes")
	_check(engine.battle_attack(pa, {}) == 6, "Phantom Assassin gets no tower bonus")
	_check(engine.battle_attack(pa, _unit(engine, "melee_creep", 1)) == 6, "Phantom Assassin gets no creep bonus")

func _silence() -> void:
	var engine = _empty()
	_unit(engine, "drow", 0)
	var left = _unit(engine, "melee_creep", 1)
	var jmuy = _unit(engine, "jmuy", 1)
	var right = _unit(engine, "melee_creep", 1)
	var far = _unit(engine, "jmuy", 1)
	_check(_play(engine, "gust", jmuy.uid).ok, "Updated Gust targets one enemy hero")
	_check(left.silenced and jmuy.silenced and right.silenced and not far.silenced, "Gust silences only the hero and its adjacent allies")
	far.lane = -1
	engine.state.lanes[0].units[1][3] = null
	engine.state.active_player = 1
	engine.state.players[1].hand = ["foresight", "short_sword"]
	var actions = engine.legal_actions(1)
	_check(not actions.any(func(action): return action.type == "ability"), "Silenced J'Muy cannot use an active ability")
	_check(not actions.any(func(action): return action.type == "play" and action.hand == 0), "Silenced hero does not enable blue casting")
	_check(actions.any(func(action): return action.type == "play" and action.hand == 1), "Silenced hero can still receive equipment")
	engine._begin_deployment()
	_check(not jmuy.silenced and not left.silenced, "Silence expires at the end of the round")

func _cross_lane_and_zeus() -> void:
	var engine = _empty()
	_unit(engine, "phantom_assassin", 0)
	var target = _unit(engine, "jmuy", 1, 2)
	_check(_play(engine, "pick_off", target.uid).ok and target.health == 4, "Pick Off targets another lane using active-lane color and mana")
	_check(engine.state.lanes[0].mana[0] == 16 and engine.state.lanes[2].mana[0] == 20, "Cross-lane spell spends source-lane mana only")
	engine.state.players[0].hand = ["no_accident"]
	engine.state.active_player = 0
	_check(not engine.apply_action(0, {"type": "play", "hand": 0, "target": target.uid}).ok, "Ordinary spell cannot target another lane")
	engine = _empty()
	_unit(engine, "zeus", 0)
	var armored = _unit(engine, "axe", 1)
	_check(_play(engine, "lightning_strike").ok, "Blue spell triggers Zeus")
	_check(armored.health == 9, "Static Field's piercing damage ignores armor")
	_check(engine.state.lanes[0].structures[1].health == 34, "Static Field does not damage the tower")
	var distant = _unit(engine, "axe", 1, 2)
	var ally = _unit(engine, "axe", 0, 1)
	_check(_play(engine, "thundergods_wrath").ok, "Thundergod's Wrath plays")
	_check(armored.health == 4 and distant.health == 6 and ally.health == 10, "Global spell hits enemy heroes across lanes, then living Zeus triggers locally")
	engine = _empty()
	_unit(engine, "zeus", 0)
	_unit(engine, "melee_creep", 0)
	_unit(engine, "axe", 1)
	_unit(engine, "melee_creep", 1)
	_check(_play(engine, "annihilation").ok, "Annihilation plays")
	_check(engine.state.players[0].gold == 6 and engine.state.players[1].gold == 6, "Symmetric board clear pays bounties to both players")
	_check(engine.state.lanes[0].units[0].all(func(unit): return unit == null), "Zeus is removed before post-spell triggers")

func _growth_siege_and_removal() -> void:
	var engine = _empty()
	var wolf = _unit(engine, "savage_wolf", 0)
	engine.state.active_player = 0
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(wolf.attack == 4 and wolf.max_health == 5 and wolf.health == 5, "Savage Wolf grows after its lane combat")
	engine = _empty()
	var pack = _unit(engine, "thunderhide_pack", 0)
	_unit(engine, "axe", 1)
	_check(engine.combat_preview(0).tower_damage[0] == 6, "Blocked Thunderhide Pack applies siege")
	engine.state.lanes[0].units[1] = []
	_check(engine.combat_preview(0).tower_damage[0] == 14, "Unblocked pack deals attack without extra siege")
	engine = _empty()
	_unit(engine, "axe", 0)
	var pa = _unit(engine, "phantom_assassin", 0)
	_unit(engine, "melee_creep", 1)
	_check(_play(engine, "forward_charge").ok and pa.temp_siege == 2 and engine.combat_preview(0).tower_damage[0] == 8, "Black Forward Charge grants siege and resets combat direction")
	engine = _empty()
	_unit(engine, "phantom_assassin", 0)
	var creep = _unit(engine, "melee_creep", 1)
	var hero = _unit(engine, "axe", 1)
	_check(_play(engine, "slay", creep.uid).ok and creep.lane == -1, "Slay condemns a creep")
	_check(not _play(engine, "slay", hero.uid).ok, "Slay rejects heroes")
	engine.state.players[0].hand = ["coup_de_grace", "untested_grunt", "hip_fire"]
	engine.state.active_player = 0
	_check(engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid}).ok, "Coup de Grace condemns an armored hero")
	_check(engine.state.players[0].hand.size() == 1 and hero.lane == -1, "Coup consumes itself and discards exactly one remaining card")
	engine = _empty()
	var rix = _unit(engine, "rix", 0)
	rix.health = 0
	engine._clean_dead(0)
	_check(rix.ready_round == 2 and rix.health == 7, "Rix enters the Fountain healed and redeploys next round")

func _consumables_and_shop() -> void:
	var engine = _empty()
	var hero = _unit(engine, "axe", 0)
	hero.health = 2
	_check(_play(engine, "healing_salve", hero.uid).ok and hero.health == 8, "Healing Salve heals six without mana")
	_check(engine.state.lanes[0].mana[0] == 20, "Consumables cost no mana to play")
	hero.silenced = true
	hero.temp_attack = 5
	_check(_play(engine, "town_portal_scroll", hero.uid).ok, "Town Portal Scroll returns an allied hero")
	_check(hero.lane == -1 and hero.ready_round == 2 and hero.health == 10 and not hero.silenced and hero.temp_attack == 0, "Portal heals, clears temporary effects and prepares next deployment")
	_check(engine.state.players[1].gold == 0, "Returning a living hero gives no death bounty")
	_check(_play(engine, "potion_of_knowledge").ok and engine.state.players[0].hand.size() == 1, "Potion draws one card even without a matching-color hero")
	engine = _empty()
	engine.state.phase = "shop"
	engine._prepare_shop()
	engine.state.players[0].gold = 100
	var first_item = engine.state.players[0].shop.item
	_check(engine.apply_action(0, {"type": "buy", "card": first_item, "source": "item"}).ok, "Item-deck offer can be purchased")
	_check(engine.state.players[0].item_deck.size() == 8 and engine.state.players[0].shop.item == engine.state.players[0].item_deck.back(), "Buying item reveals next item-deck offer")
	var secret = engine.state.players[0].shop.secret
	_check(engine.apply_action(0, {"type": "buy", "card": secret, "source": "secret"}).ok, "Secret offer can be purchased")
	_check(engine.state.players[0].shop.secret == "", "Secret slot sells at most one item per shop")
	var before = engine.state_digest()
	_check(not engine.apply_action(0, {"type": "buy", "card": "claymore", "source": "consumable"}).ok, "Cannot forge an item in another shop source")
	_check(engine.state_digest() == before, "Rejected shop command is inert")

func _privacy_and_validation() -> void:
	var engine = MatchEngine.new()
	engine.start(4, ["green_assault", "blue_black_control"])
	engine._prepare_shop()
	var view = engine.player_view(0)
	_check(view.players[0].item_deck.is_empty() and view.players[1].item_deck.is_empty(), "Observations hide both item-deck orders")
	_check(view.players[1].shop.is_empty() and not view.players[0].shop.is_empty(), "Opponent's unrevealed shop offers stay private")
	engine.state.phase = "shop"
	engine.state.players[1].gold = 100
	var purchase = engine.state.players[1].shop.secret
	engine.apply_action(1, {"type": "buy", "card": purchase, "source": "secret"})
	view = engine.player_view(0)
	_check(view.players[1].bought.is_empty(), "Opponent's purchase history cannot reveal its new hand cards")
	_check(engine.library.cards[purchase].name not in str(view.events.back()), "Public purchase log reveals cost without item identity")
	var before = engine.state_digest()
	_check(not engine.start(4, ["missing", "starter"]).ok and engine.state_digest() == before, "Invalid deck selection cannot overwrite a live match")
	var replay = engine.replay_data()
	replay.decks = "forged"
	_check(not MatchEngine.new().load_replay(replay).ok, "Replay deck envelope must be an array")

func _matchup_matrix() -> void:
	var bot = Bot.new()
	var ids = ["starter", "green_assault", "blue_black_control"]
	for first in ids:
		for second in ids:
			for seed_value in [41, 73]:
				var engine = MatchEngine.new()
				engine.start(seed_value, [first, second])
				var steps = 0
				while engine.state.winner == -1 and steps < 1500:
					var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
					var command = bot.choose_action(engine, player)
					if command.is_empty():
						failures.append("Bot stalled: %s vs %s" % [first, second])
						break
					_check(engine.apply_action(player, command).ok, "Expansion bot action is legal")
					steps += 1
				_check(engine.state.winner != -1, "Matchup terminates: %s vs %s" % [first, second])
				var restored = MatchEngine.new()
				_check(restored.load_replay(JSON.parse_string(JSON.stringify(engine.replay_data()))).ok, "Expanded replay loads with deck IDs")
				_check(restored.state_digest() == engine.state_digest(), "Expanded replay preserves every field and RNG")
