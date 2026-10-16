extends SceneTree

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const EventFormatter = preload("res://scripts/core/event_text.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const Invariants = preload("res://tests/invariants.gd")
const Legacy = preload("res://tests/legacy/legacy_library.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	Settings.set_locale("en", false)
	Settings.set_skin("classic", false)
	_profiles()
	_auras()
	_silence()
	_cross_lane_and_zeus()
	_growth_siege_and_removal()
	_consumables_and_shop()
	_hold_and_shuffle()
	_privacy_and_validation()
	_matchup_matrix()
	_m3_presets()
	_m4_presets()
	_m5_presets()
	_m6_presets()
	_m7_presets()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d expansion checks; all 18 seeded deck matchups, the M3, M4, M5, M6 and M7 presets' bot matches (6 seeds each) and replay round trips tested." % ["PASS" if failures.is_empty() else "FAIL", checks])
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
	# Deterministic fixture placement: first empty own position, else a new
	# position at the right end, keeping both rows aligned.
	var position = engine.state.lanes[lane_index].units[owner].find(null)
	engine._place(unit, lane_index, position if position != -1 else engine.state.lanes[lane_index].units[owner].size())
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
	# M1 migrated 49 definitions (10 heroes, 39 cards); M3 adds the 92 red and
	# green cards plus three heroes' signature improvements; M4 the 44 blue
	# cards plus two heroes' signature improvements, Barracks and Ignite; M5
	# the 39 black cards plus two heroes' signature improvements, Assault
	# Ladders and March of the Machines; M6 the 40 items; M7 the 32 remaining
	# improvements (EFFECT_SYSTEM_SPEC.md §12): all 303 counted Classic cards.
	_check(engine.library.heroes.size() == 48 and engine.library.cards.size() == 255,
		"303 real definitions are available (%d heroes, %d cards)" % [engine.library.heroes.size(), engine.library.cards.size()])
	_check(engine.library.presets().size() == 22, "Twenty-two playable deck presets (%d)" % engine.library.presets().size())
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
	# The item deck holds only Weapon, Armor and Accessory cards (wiki Item
	# Shop): consumables and Deeds are bought from the shops.
	for item_id in ["golden_ticket", "obliterating_orb", "fountain_flask", "shop_deed"]:
		bad = engine.library.preset("starter").duplicate(true)
		bad.items[item_id] = 1
		var result = engine.library.validate_preset(bad)
		_check(not result.ok and str(result.get("code", "")) == "deck_item_card", "%s cannot enter an item deck (%s)" % [item_id, result])

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
	engine._remove_from_lane(far)
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
	engine.state.lanes[0].units[1] = [null]
	_check(engine.combat_preview(0).tower_damage[0] == 14, "Unblocked pack deals attack without extra siege")
	engine = _empty()
	_unit(engine, "axe", 0)
	var pa = _unit(engine, "phantom_assassin", 0)
	_unit(engine, "melee_creep", 1)
	_check(_play(engine, "forward_charge").ok and engine.keyword_of(pa, "siege") == 2 and engine.combat_preview(0).tower_damage[0] == 8, "Black Forward Charge grants siege and resets combat direction")
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
	# Real temporary effects: +5 attack and a silence until the end of the
	# round, and a permanent +1 armor that the Fountain keeps (spec §4.7).
	var context = {"controller": 1, "card": ""}
	MatchEngine.Kernel.give(engine, hero, {"attack": 5}, {"silence": 1}, "", "round", context)
	MatchEngine.Kernel.modify(engine, hero, {"armor": 1}, {}, "", context)
	MatchEngine.Stats.settle(engine)
	var printed_attack = int(engine.library.definition("axe").attack)
	_check(engine.attack_of(hero) == printed_attack + 5 and engine.has_flag(hero, "silence") and hero.silenced,
		"The hero has +5 attack and is silenced this round before the Portal")
	var silenced_cast = _play(engine, "town_portal_scroll", hero.uid)
	_check(silenced_cast.ok, "Town Portal Scroll returns an allied hero")
	_check(hero.lane == -1 and hero.ready_round == 2 and hero.health == 10, "Portal heals and prepares next deployment")
	_check(engine.attack_of(hero) == printed_attack and not engine.has_flag(hero, "silence") and not hero.silenced
		and hero.mods.all(func(entry): return str(entry.k) != "give"), "Portal clears temporary effects (give entries end in the Fountain)")
	_check(engine.armor_of(hero) == int(engine.library.definition("axe").get("armor", 0)) + 1, "The Fountain keeps a permanent modification")
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

func _hold_and_shuffle() -> void:
	var engine = _empty()
	engine.state.phase = "shop"
	engine._prepare_shop()
	var owner = engine.state.players[0]
	owner.gold = 3
	var secret = owner.shop.secret
	_check({"type": "hold"} in engine.legal_actions(0), "Hold is offered with at least one gold")
	_check(engine.apply_action(0, {"type": "hold"}).ok, "Hold is a legal shop command")
	_check(owner.gold == 2 and owner.held_secret == secret, "Hold costs one gold and records the Secret Shop item")
	_check(owner.shop.secret == secret, "Holding does not buy or remove the offer")
	_check({"type": "hold"} not in engine.legal_actions(0), "Hold can be used only once per shop phase")
	_check(not engine.apply_action(0, {"type": "hold"}).ok, "Second hold in the same phase is rejected")
	_check(engine.player_view(1).players[0].held_secret == "", "Opponent cannot see which item was held")
	_check(EventFormatter.format(engine.state.events.back(), engine.library) == "Player 1 pays 1 gold to hold the Secret Shop item.", "Hold is logged without the item identity")
	_check(engine.library.cards[secret].name not in str(engine.state.events.back()), "Hold event does not reveal the item")
	engine._prepare_shop()
	_check(owner.shop.secret == secret and owner.held_secret == "", "Held item returns in the next shop phase, then the hold is spent")
	var poor = _empty()
	poor.state.phase = "shop"
	poor._prepare_shop()
	poor.state.players[0].gold = 0
	_check({"type": "hold"} not in poor.legal_actions(0) and not poor.apply_action(0, {"type": "hold"}).ok, "Hold needs one gold")
	poor.state.players[0].gold = 100
	poor.apply_action(0, {"type": "buy", "card": poor.state.players[0].shop.secret, "source": "secret"})
	_check({"type": "hold"} not in poor.legal_actions(0), "A sold-out Secret Shop slot cannot be held")
	# The item deck is reshuffled at every shopping phase, keeping its contents.
	var shuffled = _empty()
	var deck = shuffled.state.players[0].item_deck
	var original = deck.duplicate()
	var changed = false
	for phase in range(4):
		var before = deck.duplicate()
		shuffled._prepare_shop()
		changed = changed or deck != before
	var sorted_now = deck.duplicate()
	sorted_now.sort()
	original.sort()
	_check(changed, "Item deck order changes across shopping phases")
	_check(sorted_now == original, "Shuffling keeps the same item-deck cards")
	_check(shuffled.state.players[0].shop.item == deck.back(), "Item Shop offers the top card of the reshuffled deck")

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
				var invariant = Invariants.aligned(engine)
				var formatted = true
				while engine.state.winner == -1 and steps < 1500:
					var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
					var command = bot.choose_action(engine, player)
					if command.is_empty():
						failures.append("Bot stalled: %s vs %s" % [first, second])
						break
					var seen = int(engine.state.event_seq)
					_check(engine.apply_action(player, command).ok, "Expansion bot action is legal")
					invariant = invariant and Invariants.aligned(engine)
					var events = engine.state.events
					for event in events.slice(events.size() - mini(int(engine.state.event_seq) - seen, events.size())):
						var text = EventFormatter.format(event, engine.library)
						formatted = formatted and not text.is_empty() and text != "?"
					steps += 1
				_check(engine.state.winner != -1, "Matchup terminates: %s vs %s" % [first, second])
				_check(invariant, "Lanes stay aligned and compacted: %s vs %s" % [first, second])
				_check(formatted, "Every matchup event formats: %s vs %s" % [first, second])
				var restored = MatchEngine.new()
				_check(restored.load_replay(JSON.parse_string(JSON.stringify(engine.replay_data()))).ok, "Expanded replay loads with deck IDs")
				_check(restored.state_digest() == engine.state_digest(), "Expanded replay preserves every field and RNG")

const ORIGINAL_PRESETS = ["starter", "green_assault", "blue_black_control"]
const M3_PRESETS = ["sun_liu_alliance", "northern_expedition", "gathering_of_champions", "ruxu_standoff", "little_conqueror"]
const M4_PRESETS = ["bronze_sparrow_terrace", "siege_of_xiapi", "longxi_struggle"]
const M5_PRESETS = ["fengyi_pavilion", "hulao_pass", "yellow_turban_rebellion"]
const M6_PRESETS = ["five_tigers", "emperor_of_wu", "battle_of_guandu", "warlords_rise"]
const M7_PRESETS = ["siege_of_ye", "jing_province", "dong_zhuo_tyranny", "xiaoyao_ford"]
## The 32 improvements M7 adds (EFFECT_SYSTEM_SPEC.md Appendix A; the other
## seven shipped earlier as heroes' signatures).
const M7_IMPROVEMENTS = ["assured_destruction", "escape_route", "iron_fog_goldmine", "keenfolk_turret", "steam_cannon",
	"the_tyler_estate", "trebuchets", "bitter_enemies", "path_of_the_cunning", "revtel_investments", "unsupervised_artillery",
	"the_oath", "aghanims_sanctum", "conflagration", "messenger_rookery", "fractured_timeline", "howling_mind",
	"path_of_the_wise", "watchtower", "glyph_of_confusion", "altar_of_the_mad_moon", "mist_of_avernus",
	"path_of_the_dreamer", "selemenes_favor", "cheating_death", "homefield_advantage", "unearthed_secrets",
	"temple_of_war", "burning_oil", "the_omexe_arena", "grand_melee", "path_of_the_bold"]
## The four basic consumables the Consumables Shop sells (wiki Item Shop).
const BASIC_CONSUMABLES = ["healing_salve", "potion_of_knowledge", "town_portal_scroll", "fountain_flask"]

## M3 acceptance 5 (EFFECT_SYSTEM_SPEC.md §12): every preset added with the
## red and green cards validates, and bot-vs-bot matches with it terminate
## within 1,500 steps for 6 seeds (against each preset of that milestone in
## turn), with lanes aligned, every event formatted and a replay round trip.
## The 18 golden matchups above stay the three original presets.
func _m3_presets() -> void:
	var library = MatchEngine.Library.new()
	var legacy = Legacy.new()
	var pairs: Dictionary = {}
	for index in range(M3_PRESETS.size()):
		var preset_id = str(M3_PRESETS[index])
		var preset = library.preset(preset_id)
		_check(not preset.is_empty() and library.validate_preset(preset).ok, "Preset %s validates" % preset_id)
		if preset.is_empty():
			continue
		pairs[_colour_pair(library, preset)] = true
		var m3_cards = preset.cards.keys().filter(func(card_id): return not legacy.cards.has(str(card_id)))
		_check(m3_cards.size() >= 10, "Preset %s is built from new red and green cards (%d of them)" % [preset_id, m3_cards.size()])
		_preset_matches(preset_id, index, ORIGINAL_PRESETS + M3_PRESETS, "M3")
	for pair in ["green/red", "blue/red", "black/red", "blue/green", "black/green"]:
		_check(pairs.has(pair), "A new preset covers the %s colour pair" % pair)

## M4 acceptance 5: the presets added with the blue cards (mono-blue,
## blue/black, blue/red) validate, are built from new blue cards and heroes,
## and their bot matches terminate within 1,500 steps for 6 seeds against
## every preset of M1 to M4 in turn (their pool when they landed), aligned,
## formatted and replayable.
func _m4_presets() -> void:
	var library = MatchEngine.Library.new()
	var legacy = Legacy.new()
	var all_ids: Array = ORIGINAL_PRESETS + M3_PRESETS + M4_PRESETS
	var pairs: Dictionary = {}
	for index in range(M4_PRESETS.size()):
		var preset_id = str(M4_PRESETS[index])
		var preset = library.preset(preset_id)
		_check(not preset.is_empty() and library.validate_preset(preset).ok, "Preset %s validates" % preset_id)
		if preset.is_empty():
			continue
		pairs[_colour_pair(library, preset)] = true
		var blue_cards = preset.cards.keys().filter(func(card_id): return not legacy.cards.has(str(card_id)) and str(library.get_card(str(card_id)).get("color", "")) == "blue")
		# New blue heroes (J'Muy and Zeus are M1's).
		var blue_heroes: Array = []
		for hero_id in preset.heroes:
			if str(library.definition(str(hero_id)).get("color", "")) == "blue" and str(hero_id) not in ["jmuy", "zeus"]:
				blue_heroes.append(hero_id)
		_check(blue_cards.size() >= 10 and blue_heroes.size() >= 3,
			"Preset %s is built from new blue cards (%d) and heroes (%d)" % [preset_id, blue_cards.size(), blue_heroes.size()])
		_preset_matches(preset_id, index, all_ids, "M4")
	for pair in ["blue", "black/blue", "blue/red"]:
		_check(pairs.has(pair), "An M4 preset covers %s" % pair)

## M5 acceptance 5: the presets added with the black cards (mono-black,
## black/red, black/blue) validate, are built from new black cards and
## heroes, and their bot matches terminate within 1,500 steps for 6 seeds
## against every preset of M1 to M5 in turn (their pool when they landed),
## aligned, formatted and replayable. Between them they play every deckable
## M5 card (Chain Frost is a draft, RQ-16, so Lich cannot fill a deck); the
## black improvements M7 adds are left to the M7 presets.
func _m5_presets() -> void:
	var library = MatchEngine.Library.new()
	var legacy = Legacy.new()
	var all_ids: Array = ORIGINAL_PRESETS + M3_PRESETS + M4_PRESETS + M5_PRESETS
	var pairs: Dictionary = {}
	var played: Dictionary = {}
	for index in range(M5_PRESETS.size()):
		var preset_id = str(M5_PRESETS[index])
		var preset = library.preset(preset_id)
		_check(not preset.is_empty() and library.validate_preset(preset).ok, "Preset %s validates" % preset_id)
		if preset.is_empty():
			continue
		pairs[_colour_pair(library, preset)] = true
		var black_cards = preset.cards.keys().filter(func(card_id): return not legacy.cards.has(str(card_id)) and str(library.get_card(str(card_id)).get("color", "")) == "black")
		for card_id in black_cards:
			played[str(card_id)] = true
		# New black heroes (Debbi and Phantom Assassin are M1's).
		var black_heroes: Array = []
		for hero_id in preset.heroes:
			if str(library.definition(str(hero_id)).get("color", "")) == "black" and str(hero_id) not in ["debbi", "phantom_assassin"]:
				black_heroes.append(hero_id)
		_check(black_cards.size() >= 10 and black_heroes.size() >= 2,
			"Preset %s is built from new black cards (%d) and heroes (%d)" % [preset_id, black_cards.size(), black_heroes.size()])
		_preset_matches(preset_id, index, all_ids, "M5")
	for pair in ["black", "black/red", "black/blue"]:
		_check(pairs.has(pair), "An M5 preset covers %s" % pair)
	var missing: Array = []
	for card_id in library.cards:
		var card: Dictionary = library.cards[card_id]
		if str(card.get("color", "")) == "black" and not legacy.cards.has(str(card_id)) and library._deckable(str(card_id)) \
				and not played.has(str(card_id)) and str(card_id) not in M7_IMPROVEMENTS:
			missing.append(card_id)
	_check(missing.is_empty(), "The M5 presets play every deckable new black card (missing %s)" % [missing])

## M6 acceptance 5: the presets added with the items (mono-red, mono-green,
## mono-blue and mono-black) validate; each item deck holds nine different
## M6 equipment cards, and between them they hold every deckable M6
## equipment card once. Their bot matches terminate within 1,500 steps for 6
## seeds against every preset in turn, aligned, formatted and replayable.
## The shop pools follow the wiki Item Shop page: the Secret Shop sells any
## item that is not a basic consumable (M6's consumables and its Deed
## included), the Consumables Shop one of the four basic consumables, and
## item decks hold equipment only.
func _m6_presets() -> void:
	var library = MatchEngine.Library.new()
	var legacy = Legacy.new()
	var all_ids: Array = ORIGINAL_PRESETS + M3_PRESETS + M4_PRESETS + M5_PRESETS + M6_PRESETS
	var held: Dictionary = {}
	for index in range(M6_PRESETS.size()):
		var preset_id = str(M6_PRESETS[index])
		var preset = library.preset(preset_id)
		_check(not preset.is_empty() and library.validate_preset(preset).ok, "Preset %s validates" % preset_id)
		if preset.is_empty():
			continue
		var new_items = preset.items.keys().filter(func(card_id): return not legacy.cards.has(str(card_id)))
		_check(new_items.size() == 9 and preset.items.values().all(func(count): return int(count) == 1),
			"Preset %s's item deck is nine different M6 items (%s)" % [preset_id, preset.items])
		for item_id in new_items:
			_check(not held.has(item_id), "%s is in one M6 item deck only" % item_id)
			held[str(item_id)] = true
		_preset_matches(preset_id, index, all_ids, "M6")
	var missing: Array = []
	var items: Array = []
	for card_id in library.cards:
		var card: Dictionary = library.cards[card_id]
		if str(card.get("kind", "")) != "item":
			continue
		items.append(str(card_id))
		if not legacy.cards.has(str(card_id)) and str(card.get("slot", "")) in MatchEngine.Library.EQUIPMENT_SLOTS \
				and library._deckable(str(card_id)) and not held.has(str(card_id)):
			missing.append(card_id)
	_check(missing.is_empty(), "The M6 presets hold every deckable new equipment card (missing %s)" % [missing])
	_check(items.size() == 48, "The pack has all 48 Classic items (%d)" % items.size())
	var consumables: Array = library.catalog.consumables
	_check(consumables == BASIC_CONSUMABLES, "The Consumables Shop sells the four basic consumables (%s)" % [consumables])
	var secret: Array = library.catalog.secret_shop.duplicate()
	var expected: Array = items.filter(func(card_id): return card_id not in BASIC_CONSUMABLES)
	secret.sort()
	expected.sort()
	_check(secret == expected, "The Secret Shop sells every item but the basic consumables (%d of %d)" % [secret.size(), expected.size()])
	_check(library.catalog.secret_shop.has("golden_ticket") and library.catalog.secret_shop.has("shop_deed") and library.catalog.secret_shop.has("obliterating_orb"),
		"Golden Ticket, Obliterating Orb and Shop Deed come from the Secret Shop")

## M7 acceptance 5: the presets added with the improvements (two black/blue,
## red/green and blue/green) validate and are each built on at least five
## different new improvements; between them they play every M7 improvement.
## Their bot matches terminate within 1,500 steps for 6 seeds against every
## preset in turn, aligned, formatted and replayable. With M7 every counted
## Classic card is in the pack, the 39 improvements among them.
func _m7_presets() -> void:
	var library = MatchEngine.Library.new()
	var all_ids: Array = library.presets().map(func(entry): return str(entry.id))
	_check(all_ids == ORIGINAL_PRESETS + M3_PRESETS + M4_PRESETS + M5_PRESETS + M6_PRESETS + M7_PRESETS,
		"The presets are the original three, the M3 five, the M4 three, the M5 three, the M6 four and the M7 four, in order (%s)" % [all_ids])
	var played: Dictionary = {}
	for index in range(M7_PRESETS.size()):
		var preset_id = str(M7_PRESETS[index])
		var preset = library.preset(preset_id)
		_check(not preset.is_empty() and library.validate_preset(preset).ok, "Preset %s validates" % preset_id)
		if preset.is_empty():
			continue
		var improvements = preset.cards.keys().filter(func(card_id): return str(card_id) in M7_IMPROVEMENTS)
		for card_id in improvements:
			played[str(card_id)] = true
		_check(improvements.size() >= 5, "Preset %s is built on new improvements (%d of them)" % [preset_id, improvements.size()])
		_preset_matches(preset_id, index, all_ids, "M7")
	var missing: Array = M7_IMPROVEMENTS.filter(func(card_id): return not played.has(card_id))
	_check(missing.is_empty(), "The M7 presets play every new improvement (missing %s)" % [missing])
	var in_pack: Array = library.cards.keys().filter(func(card_id): return str(library.cards[card_id].get("kind", "")) == "improvement")
	_check(in_pack.size() == 39, "The pack has all 39 Classic improvements (%d)" % in_pack.size())
	_check(M7_IMPROVEMENTS.all(func(card_id): return library._deckable(str(card_id))), "Every M7 improvement is verified and deckable")

## The sorted hero colours of a preset, "a/b" (or one colour).
func _colour_pair(library, preset: Dictionary) -> String:
	var colors: Array = []
	for hero_id in preset.heroes:
		var color = str(library.definition(hero_id).color)
		if color not in colors:
			colors.append(color)
	colors.sort()
	return "/".join(colors)

## Six seeded bot-vs-bot matches of `preset_id` (the `index`-th of its
## milestone), against `pool` presets in turn and on alternating sides: each
## ends within 1,500 steps with legal actions, aligned lanes, formatted events
## and an identical replay.
func _preset_matches(preset_id: String, index: int, pool: Array, milestone: String) -> void:
	var bot = Bot.new()
	for seed_index in range(6):
		var seed_value = 101 + seed_index * 17 + index * 7
		var opponent = str(pool[(index + seed_index * 3) % pool.size()])
		var decks = [preset_id, opponent] if seed_index % 2 == 0 else [opponent, preset_id]
		var engine = MatchEngine.new()
		_check(engine.start(seed_value, decks).ok, "Preset %s starts a match (%s)" % [preset_id, decks])
		var steps = 0
		var invariant = Invariants.aligned(engine)
		var formatted = true
		while engine.state.winner == -1 and steps < 1500:
			var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
			var command = bot.choose_action(engine, player)
			if command.is_empty():
				failures.append("Bot stalled: %s vs %s" % decks)
				break
			var seen = int(engine.state.event_seq)
			_check(engine.apply_action(player, command).ok, "%s preset bot action is legal" % milestone)
			invariant = invariant and Invariants.aligned(engine)
			var events = engine.state.events
			for event in events.slice(events.size() - mini(int(engine.state.event_seq) - seen, events.size())):
				var text = EventFormatter.format(event, engine.library)
				formatted = formatted and not text.is_empty() and text != "?" and text.find("{") == -1
			steps += 1
		_check(engine.state.winner != -1, "%s matchup terminates within 1,500 steps: %s vs %s, seed %d (%d steps)" % [milestone, decks[0], decks[1], seed_value, steps])
		_check(invariant, "Lanes stay aligned and compacted: %s vs %s" % decks)
		_check(formatted, "Every event formats: %s vs %s" % decks)
		var restored = MatchEngine.new()
		_check(restored.load_replay(JSON.parse_string(JSON.stringify(engine.replay_data()))).ok, "%s replay loads: %s vs %s" % [milestone, decks[0], decks[1]])
		_check(restored.state_digest() == engine.state_digest(), "%s replay preserves every field and RNG: %s vs %s" % [milestone, decks[0], decks[1]])
