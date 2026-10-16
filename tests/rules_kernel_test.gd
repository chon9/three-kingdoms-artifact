extends SceneTree
## Rules kernel tests (EFFECT_SYSTEM_SPEC.md §4, §7, §10, §13.3): the event
## bus and trigger queue (order, batches, breadth-first), look-back snapshots,
## the continuous modifier layer with provenance, settle, the Pulse guards,
## targeting equivalence, purity of the read-only API, privacy and replays.
## Synthetic fixture cards (fx_*) exercise paths the 66 migrated cards do not.

const EngineClass = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Invariants = preload("res://tests/invariants.gd")
const RulesVersion = preload("res://scripts/core/rules/rules_version.gd")
const Bridge = preload("res://scripts/network/steam_bridge.gd")
var checks = 0
var failures: Array = []

## Fixture cards: plain schema-4 entries compiled next to the Classic pack.
const FIXTURES = [
	{"id": "fx_noop", "kind": "spell", "color": "item", "cost": 0, "status": "draft", "play": {"ops": []}},
	{"id": "fx_counter", "kind": "creep", "color": "neutral", "cost": 1, "attack": 1, "health": 9, "status": "draft",
		"abilities": [{"id": "count", "kind": "trigger", "on": "card_played", "ops": [{"op": "gold", "player": "you", "add": 1}]}]},
	{"id": "fx_striker", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"abilities": [{"id": "strike", "kind": "trigger", "on": "card_played", "filter": {"player": "you"},
			"ops": [{"op": "damage", "to": "enemies", "amount": 9, "piercing": true}]}]},
	{"id": "fx_blesser", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"abilities": [{"id": "bless", "kind": "trigger", "on": "card_played", "filter": {"player": "you"},
			"ops": [{"op": "modify", "to": "enemies", "stats": {"attack": 1}}]}]},
	{"id": "fx_mourner", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"abilities": [{"id": "mourn", "kind": "trigger", "on": "unit_died", "ops": [{"op": "modify", "to": "$self", "stats": {"attack": 1}}]}]},
	{"id": "fx_martyr", "kind": "creep", "color": "neutral", "cost": 1, "attack": 1, "health": 1, "status": "draft",
		"abilities": [{"id": "martyrdom", "kind": "trigger", "on": "death",
			"ops": [{"op": "modify", "to": "allies", "stats": {"attack": 1, "max_health": 1}}, {"op": "modify", "to": "$self", "stats": {"attack": 5}}]}]},
	{"id": "fx_avenger", "kind": "creep", "color": "neutral", "cost": 1, "attack": 1, "health": 1, "status": "draft",
		"abilities": [{"id": "avenge", "kind": "trigger", "on": "unit_died", "filter": {"side": "ally", "was": "allied_neighbor"},
			"ops": [{"op": "modify", "to": "$self", "stats": {"attack": 2}}]}]},
	{"id": "fx_banner", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 3, "status": "draft",
		"abilities": [{"id": "banner", "kind": "aura", "affects": "allied_neighbors", "grant": {"max_health": 2}}]},
	{"id": "fx_buff", "kind": "spell", "color": "item", "cost": 0, "status": "draft", "amount": 1,
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "modify", "to": "$c.target", "stats": {"attack": {"param": "amount"}}}]}},
	{"id": "fx_curse", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "modify", "to": "$c.target", "stats": {"attack": -1, "armor": -1}}]}},
	{"id": "fx_temp", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "give", "to": "$c.target", "stats": {"attack": 3}, "until": "round"}]}},
	{"id": "fx_charge", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "give", "to": "$c.target", "stats": {"attack": 2}, "until": "next_combat"}]}},
	{"id": "fx_mark", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "heroes"}], "ops": [{"op": "give", "to": "$c.target", "stats": {"armor": 2}, "until": "death"},
			{"op": "give", "to": "$c.target", "keywords": {"stun": 1}, "until": "equip"}]}},
	{"id": "fx_purge", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "purge", "to": "$c.target"}]}},
	{"id": "fx_shield", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "give", "to": "$c.target", "keywords": {"death_shield": 1}, "until": "used"}]}},
	{"id": "fx_immune", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "give", "to": "$c.target", "keywords": {"damage_immunity": 1}, "until": "round"}]}},
	{"id": "fx_bolt", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "damage", "to": "$c.target", "amount": 5}]}},
	{"id": "fx_kill", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "condemn", "to": "$c.target"}]}},
	{"id": "fx_soul", "kind": "creep", "color": "neutral", "cost": 1, "attack": 1, "health": 3, "status": "draft",
		"keywords": {"soulbound": 1}},
	{"id": "fx_lethal", "kind": "creep", "color": "neutral", "cost": 1, "attack": 1, "health": 9, "status": "draft",
		"keywords": {"lethal": 1}},
	{"id": "fx_drain", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"ops": [{"op": "give", "to": "enemy_tower", "stats": {"mana": -2}, "until": "round"},
			{"op": "give", "to": "enemy_tower", "stats": {"mana": -2}, "until": "next_combat"}]}},
	{"id": "fx_dawn", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"abilities": [{"id": "dawn", "kind": "trigger", "on": "before_action", "ops": [{"op": "gold", "player": "you", "add": 3}]}]},
	{"id": "fx_herald", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"abilities": [{"id": "herald", "kind": "trigger", "on": "deployment", "ops": [{"op": "gold", "player": "you", "add": 2}]}]},
	{"id": "fx_echo", "kind": "creep", "color": "item", "cost": 1, "attack": 0, "health": 1, "status": "draft",
		"abilities": [{"id": "echo", "kind": "trigger", "on": "unit_entered", "filter": {"side": "ally"},
			"ops": [{"op": "summon", "card": "melee_creep"}]}]},
	{"id": "fx_crystal", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"abilities": [{"id": "crystal", "kind": "trigger", "on": "card_played", "lane": "any", "once_per": "lane_round",
			"filter": {"player": "you"}, "ops": [{"op": "gold", "player": "you", "add": 1}]}]},
	{"id": "fx_thorns", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"keywords": {"retaliate": 2}},
	{"id": "fx_cleaver", "kind": "creep", "color": "neutral", "cost": 1, "attack": 1, "health": 9, "status": "draft",
		"keywords": {"cleave": 3}},
	{"id": "fx_piercer", "kind": "creep", "color": "neutral", "cost": 1, "attack": 3, "health": 9, "status": "draft",
		"keywords": {"pierce": 1}},
	{"id": "fx_wall", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "armor": 2, "health": 9, "status": "draft"},
	{"id": "fx_troll", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"keywords": {"regeneration": 3}},
	{"id": "fx_watcher", "kind": "creep", "color": "neutral", "cost": 1, "attack": 0, "health": 9, "status": "draft",
		"abilities": [{"id": "watch", "kind": "trigger", "on": "battle_damage", "filter": {"role": "taker"},
			"ops": [{"op": "gold", "player": "you", "add": 1}]}]},
	{"id": "fx_roll", "kind": "spell", "color": "item", "cost": 0, "status": "draft",
		"play": {"ops": [{"op": "chance", "pct": 50, "then": [{"op": "gold", "player": "you", "add": 1}]},
			{"op": "damage", "to": {"use": "enemies", "pick": {"random": 2}}, "amount": 1}]}},
]

func _initialize() -> void:
	for test in [_test_fixtures_compile, _test_trigger_order, _test_batch_semantics, _test_death_lookback,
			_test_modifier_provenance, _test_durations, _test_settle, _test_death_shield_soulbound_lethal,
			_test_lane_hooks, _test_overflow_guard, _test_once_per, _test_randomness,
			_test_combat_keywords, _test_hand_state_and_privacy, _test_bot_game_properties, _test_random_agent_fuzz,
			_test_player_view_partial_state, _test_invariants_catch, _test_replay_versions,
			_test_rq_01_each_enemy_excludes_tower, _test_rq_19_tower_needs_empty_across, _test_fx3_aura_persists_until_pulse]:
		var started = Time.get_ticks_msec()
		test.call()
		if OS.get_cmdline_user_args().has("--timing"):
			print("%-40s %6d ms" % [test.get_method(), Time.get_ticks_msec() - started])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d rules kernel checks (triggers, batches, look-back, provenance, durations, settle, guards, targeting equivalence, purity, privacy, replays, fidelity fixes)." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

# --- Fixture boards -------------------------------------------------------------

## An engine on the Classic pack plus the fixtures, with an empty board.
func _engine(seed_value: int = 17):
	var engine = EngineClass.new()
	engine.library = Library.with_cards("artifact_classic_decks_v2", FIXTURES)
	engine.start(seed_value)
	for lane in engine.state.lanes:
		lane.units = [[], []]
		lane.mana = [20, 20]
		lane.max_mana = [20, 20]
	for owner in engine.state.players:
		owner.hand = []
		for hero in owner.roster:
			hero.lane = -1
	engine.state.active_player = 0
	engine.state.initiative = 0
	engine.state.first_pass = -1
	return engine

func _unit(engine, card_id: String, owner: int, lane_index: int = 0) -> Dictionary:
	var definition = engine.library.definition(card_id)
	var unit = engine._make_unit(definition, owner, definition.get("kind", "") == "hero")
	var row = engine.state.lanes[lane_index].units[owner]
	var position = row.find(null)
	engine._place(unit, lane_index, position if position != -1 else row.size())
	return unit

func _play(engine, player: int, card_id: String, extra: Dictionary = {}) -> Dictionary:
	engine.state.active_player = player
	engine.state.players[player].hand = [card_id]
	var command = {"type": "play", "hand": 0}
	command.merge(extra)
	return engine.apply_action(player, command)

func _keys_since(engine, seen: int) -> Array:
	var events: Array = engine.state.events
	var fresh = mini(int(engine.state.event_seq) - seen, events.size())
	return events.slice(events.size() - fresh)

func _triggers(engine, seen: int) -> Array:
	return _keys_since(engine, seen).filter(func(event): return str(event.k) == "trigger").map(func(event): return str(event.src))

# --- Tests --------------------------------------------------------------------------

func _test_fixtures_compile() -> void:
	var library = Library.with_cards("artifact_classic_decks_v2", FIXTURES)
	_check(library.errors.is_empty(), "Fixture cards compile without errors: %s" % [library.errors])
	_check(library.listening.has("card_played") and library.listening.card_played.has("fx_counter"), "Fixture triggers are indexed by event")
	_check(Library.new().compiled.has("zeus") and not Library.new().compiled.has("fx_counter"), "Fixtures stay out of the shared pack cache")

## RQ-37: one total order: event, initiative side, lane, zone, slot, ability, id.
func _test_trigger_order() -> void:
	for initiative in [0, 1]:
		var engine = _engine()
		var a = _unit(engine, "fx_counter", 0)
		var b = _unit(engine, "fx_counter", 0)
		var c = _unit(engine, "fx_counter", 1)
		engine.state.initiative = initiative
		var seen = int(engine.state.event_seq)
		_check(_play(engine, initiative, "fx_noop").ok, "A fixture spell plays")
		var order = _triggers(engine, seen)
		var expected = ["u%d" % a.uid, "u%d" % b.uid, "u%d" % c.uid] if initiative == 0 else ["u%d" % c.uid, "u%d" % a.uid, "u%d" % b.uid]
		_check(order == expected, "rq_37_order: the initiative player's triggers resolve first, then by slot (initiative %d): %s" % [initiative, order])
		_check(int(engine.state.players[0].gold) == 2 and int(engine.state.players[1].gold) == 1, "Each trigger resolves once")

## RQ-37 batch mode: no Pulse between triggers of one batch; new events wait
## for the next batch (breadth-first).
func _test_batch_semantics() -> void:
	var engine = _engine()
	var striker = _unit(engine, "fx_striker", 0)
	var blesser = _unit(engine, "fx_blesser", 0)
	var mourner = _unit(engine, "fx_mourner", 0)
	var victim = _unit(engine, "melee_creep", 1)
	var seen = int(engine.state.event_seq)
	_check(_play(engine, 0, "fx_noop").ok, "Batch fixture plays")
	var events = _keys_since(engine, seen)
	var modified = events.any(func(event): return str(event.k) == "mod" and int(event.id) == int(victim.uid))
	_check(modified, "rq_37_batch_mode: a unit dealt lethal damage earlier in the batch is still a target until the Pulse")
	_check(int(victim.lane) == -1, "The batch's Pulse removes the lethally damaged unit")
	var order = _triggers(engine, seen)
	_check(order == ["u%d" % striker.uid, "u%d" % blesser.uid, "u%d" % mourner.uid],
		"Events raised while a batch resolves wait for the next batch (breadth-first): %s" % [order])
	_check(Kernel.BATCH_MODE == "per_batch", "RQ-37 default is per_batch")

## Death snapshots: Death Effects run with the dead unit's snapshot as $self;
## units dying in the same Pulse do not see each other (RQ-43).
func _test_death_lookback() -> void:
	var engine = _engine()
	var martyr = _unit(engine, "fx_martyr", 0)
	var friend = _unit(engine, "melee_creep", 0)
	var enemy = _unit(engine, "melee_creep", 1)
	var friend_attack = engine.attack_of(friend)
	var seen = int(engine.state.event_seq)
	_check(_play(engine, 1, "fx_kill", {"target": martyr.uid}).ok, "Condemn targets the martyr")
	_check(int(martyr.lane) == -1, "A condemned unit dies at the Pulse")
	_check(engine.attack_of(friend) == friend_attack + 1 and int(friend.health) == 5, "A Death Effect modifies the dead unit's allies in its lane (+1/+1, health follows max health)")
	var self_mods = _keys_since(engine, seen).filter(func(event): return str(event.k) == "mod" and int(event.id) == int(martyr.uid))
	_check(self_mods.is_empty() and int(martyr.attack) == 1, "Ops on the look-back $self fizzle (D6)")
	_check(int(engine.state.players[1].gold) == 1, "rq_02: the bounty goes to the dead unit's opponent")
	# RQ-43: an avenger dying in the same Pulse as its neighbor does not trigger.
	engine = _engine()
	var avenger = _unit(engine, "fx_avenger", 0)
	var neighbor = _unit(engine, "melee_creep", 0)
	var survivor = _unit(engine, "fx_avenger", 0)
	engine.state.lanes[0].units[0] = [avenger, neighbor, survivor]
	avenger.health = 0
	neighbor.health = 0
	engine._clean_dead(0)
	_check(int(survivor.attack) == 3 and int(avenger.attack) == 1, "rq_43_simultaneous_death: a living avenger sees its neighbor die; one dying in the same Pulse does not")

## Write-through Modify with provenance, coalescing, temporary give entries
## and Purge of the opponent's effects only (RQ-12).
func _test_modifier_provenance() -> void:
	var engine = _engine()
	var unit = _unit(engine, "melee_creep", 0)
	_play(engine, 0, "fx_buff", {"target": unit.uid})
	_play(engine, 0, "fx_buff", {"target": unit.uid})
	var modifies = unit.mods.filter(func(entry): return str(entry.k) == "modify")
	_check(int(unit.attack) == 4 and modifies.size() == 1 and int(modifies[0].st.attack) == 2 and int(modifies[0].by) == 0,
		"Permanent Modify writes through and coalesces entries with the same source and player")
	_play(engine, 1, "fx_curse", {"target": unit.uid})
	_play(engine, 0, "fx_temp", {"target": unit.uid})
	_check(int(unit.attack) == 3 and int(unit.armor) == -1 and engine.attack_of(unit) == 6, "Give is pulled at read time; Modify is written into the fields")
	_play(engine, 0, "fx_purge", {"target": unit.uid})
	_check(int(unit.attack) == 4 and int(unit.armor) == 0 and engine.attack_of(unit) == 7, "Purge reverses only the opponent's modifications and keeps the caster's own effects")
	_check(unit.mods.all(func(entry): return int(entry.by) == 0), "Purge removes the opponent's entries")
	_play(engine, 1, "fx_purge", {"target": unit.uid})
	_check(int(unit.attack) == 2 and engine.attack_of(unit) == 2 and unit.mods.is_empty(), "The opponent's Purge removes the owner's modify and give entries")
	var fountain = engine.state.players[0].roster[0]
	_unit_place(engine, fountain, 0)
	_play(engine, 0, "fx_buff", {"target": fountain.uid})
	_play(engine, 0, "fx_mark", {"target": fountain.uid})
	_check(engine.armor_of(fountain) == int(fountain.armor) + 2 and bool(fountain.stunned), "until death and until equip entries apply")
	fountain.health = 0
	engine._clean_dead(0)
	_check(fountain.mods.size() == 1 and str(fountain.mods[0].k) == "modify" and not bool(fountain.stunned),
		"rq_13_fountain: the Fountain keeps Modify entries and clears every temporary entry")

## Puts a roster hero of `colour` into lane 0, so `player` can cast that colour there.
func _caster(engine, player: int, colour: String) -> Dictionary:
	for hero in engine.state.players[player].roster:
		if str(hero.color) == colour:
			_unit_place(engine, hero, 0)
			return hero
	_check(false, "The starter roster has a %s hero" % colour)
	return {}

func _unit_place(engine, unit: Dictionary, lane_index: int) -> void:
	var row = engine.state.lanes[lane_index].units[int(unit.owner)]
	var position = row.find(null)
	engine._place(unit, lane_index, position if position != -1 else row.size())

## Durations: round, next_combat (its own lane, before after-combat), equip.
func _test_durations() -> void:
	var engine = _engine()
	var near = _unit(engine, "melee_creep", 0, 0)
	var far = _unit(engine, "melee_creep", 0, 1)
	_unit(engine, "melee_creep", 1, 0)
	_unit(engine, "melee_creep", 1, 1)
	_play(engine, 0, "fx_charge", {"target": near.uid})
	engine.state.lane = 1
	_play(engine, 0, "fx_charge", {"target": far.uid})
	engine.state.lane = 0
	_check(engine.attack_of(near) == 4 and engine.attack_of(far) == 4, "next_combat effects apply until then")
	engine.state.active_player = 0
	engine.state.first_pass = -1
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(engine.attack_of(near) == 2 and engine.attack_of(far) == 4, "next_combat ends with the combat of the unit's own lane only")
	engine._begin_deployment()
	_check(engine.attack_of(far) == 4, "next_combat effects survive the end of the round")
	engine = _engine()
	var hero = engine.state.players[0].roster[0]
	_unit_place(engine, hero, 0)
	_play(engine, 0, "fx_mark", {"target": hero.uid})
	_check(engine.has_flag(hero, "stun") and not engine.can_cast_colour(hero), "A stunned hero gives no casting colour")
	engine.state.players[0].hand = ["short_sword"]
	engine.state.active_player = 0
	var equip = {"type": "play", "hand": 0, "target": hero.uid}
	_check(equip in engine.legal_actions(0), "rq_35_equip_while_stunned: equipping is legal while stunned (CF-10)")
	engine.apply_action(0, equip)
	_check(not engine.has_flag(hero, "stun") and engine.armor_of(hero) == int(hero.armor) + 2, "Equipping ends until-equip effects only")
	var instance: Dictionary = hero.item_state.weapon
	_check(int(instance.oid) >= EngineClass.OID_START and hero.items.weapon == "short_sword", "Equipping creates an item instance with an oid")
	engine.state.players[0].hand = ["broadsword"]
	engine.state.active_player = 0
	engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid})
	_check(int(hero.item_state.weapon.oid) != int(instance.oid) and engine.attack_of(hero) == int(hero.attack) + 4, "Replacing an item discards the old instance")

## Settle: max-health changes move current health (RQ-40) and tower mana
## follows its exact base under stacked modifiers (CF-5, RQ-52).
func _test_settle() -> void:
	var engine = _engine()
	var banner = _unit(engine, "fx_banner", 0)
	var guard = _unit(engine, "melee_creep", 0)
	_unit(engine, "melee_creep", 1)
	Stats.settle(engine)
	_check(engine.max_health_of(guard) == 6 and int(guard.health) == 6, "Gaining a +Health aura raises current health")
	guard.health = 2
	banner.health = 0
	engine._clean_dead(0)
	_check(int(guard.lane) == -1, "rq_40_aura_loss_kills: losing a +Health aura can kill at the next death check")
	engine = _engine()
	var lane: Dictionary = engine.state.lanes[0]
	lane.max_mana = [3, 3]
	lane.mana = [3, 3]
	Stats.settle(engine)
	_check(_play(engine, 0, "fx_drain").ok, "Mana drain plays")
	_check(int(lane.max_mana[1]) == 0 and int(lane.mana[1]) == 0 and int(lane.mana_bonus[1]) == -4 and int(lane.max_mana_base[1]) == 3,
		"Stacked -Mana effects floor the derived maximum at 0 and keep the exact base")
	_unit(engine, "melee_creep", 0)
	engine.state.active_player = 0
	engine.state.first_pass = -1
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(int(lane.max_mana[1]) == 1 and int(lane.mana[1]) == 1, "rq_52_mana_floor: losing one effect restores exactly the right maximum; current mana follows the actual change")
	_check(Invariants.violations(engine).is_empty(), "Invariants hold after the mana effects: %s" % [Invariants.violations(engine)])

## Death Shield, Soulbound closure, Lethal and Damage Immunity in the Pulse.
func _test_death_shield_soulbound_lethal() -> void:
	var engine = _engine()
	var unit = _unit(engine, "melee_creep", 0)
	_play(engine, 0, "fx_shield", {"target": unit.uid})
	_play(engine, 0, "fx_shield", {"target": unit.uid})
	_check(unit.mods.filter(func(entry): return int(entry.kw.get("death_shield", 0)) > 0).size() == 1, "rq_11: a second Death Shield does nothing")
	_play(engine, 1, "fx_kill", {"target": unit.uid})
	_check(int(unit.lane) == 0 and int(unit.health) == 1 and not engine.has_flag(unit, "death_shield"), "A Death Shield saves from condemn once, at 1 health")
	_play(engine, 1, "fx_kill", {"target": unit.uid})
	_check(int(unit.lane) == -1, "Without a shield the condemned unit dies")
	engine = _engine()
	var one = _unit(engine, "fx_soul", 0, 0)
	var two = _unit(engine, "fx_soul", 0, 1)
	var other = _unit(engine, "fx_soul", 1, 2)
	engine.state.lane = 1
	_play(engine, 0, "fx_shield", {"target": two.uid})
	engine.state.lane = 0
	_play(engine, 1, "fx_bolt", {"target": one.uid})
	_check(int(one.lane) == -1 and int(two.lane) == 1 and int(two.health) == 1 and int(other.lane) == 2,
		"rq_39_soulbound_shield: Soulbound condemns allied same-card units in every lane; a Death Shield saves a partner; enemies are unaffected")
	engine = _engine()
	var immune = _unit(engine, "melee_creep", 1)
	_play(engine, 1, "fx_immune", {"target": immune.uid})
	_play(engine, 0, "fx_bolt", {"target": immune.uid})
	_check(int(immune.health) == 4, "Damage Immunity makes damage 0")
	engine = _engine()
	var killer = _unit(engine, "fx_lethal", 0)
	var tough = _unit(engine, "centaur_hunter", 1)
	engine.state.active_player = 0
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(int(tough.lane) == -1 and int(killer.lane) == 0, "rq_10: Lethal battle damage above 0 condemns the victim")

## Lane opening runs before-action triggers; deployment hooks run at reveal.
func _test_lane_hooks() -> void:
	var engine = _engine()
	_unit(engine, "fx_dawn", 0, 1)
	_unit(engine, "melee_creep", 1, 1)
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(int(engine.state.lane) == 1 and int(engine.state.players[0].gold) == 3, "before_action triggers fire when their lane opens")
	engine = _engine()
	_unit(engine, "fx_herald", 1, 2)
	engine._begin_deployment()
	for player in range(2):
		engine.state.players[player].finished = true
	engine._reveal_deployment()
	_check(int(engine.state.players[1].gold) == 2, "deployment triggers fire at the reveal (RQ-23)")
	_check(Kernel.ROUND1_DEPLOYMENT_HOOKS, "rq_49_round1_deployment: round 1's placement runs the deployment hooks by default")

## D7: an endless trigger loop stops deterministically with rules_overflow.
func _test_overflow_guard() -> void:
	var engine = _engine()
	_unit(engine, "melee_creep", 1)
	engine.state.players[0].hand = ["fx_echo"]
	var position = engine.creep_positions(0, 0)[0]
	var seen = int(engine.state.event_seq)
	var result = engine.apply_action(0, {"type": "play", "hand": 0, "position": position})
	_check(result.ok, "A creep that summons whenever an ally enters still finishes its command")
	_check(_keys_since(engine, seen).any(func(event): return str(event.k) == "rules_overflow"), "An endless trigger loop emits rules_overflow")
	_check(engine.state.lanes[0].units[0].size() <= Kernel.MAX_PULSE_LOOPS + 2, "The Pulse loop guard (64 batches) stops it")
	_check(engine._queue.is_empty() and engine._pulse_depth == 0, "Overflow leaves the transient queues empty (I9)")

## once_per lane_round: one trigger per lane per round, any lane.
func _test_once_per() -> void:
	var engine = _engine()
	_unit(engine, "fx_crystal", 0, 2)
	for lane_index in [0, 0, 1]:
		engine.state.lane = lane_index
		_play(engine, 0, "fx_noop")
	_check(int(engine.state.players[0].gold) == 2, "once_per lane_round fires once in each lane per round")
	engine._begin_deployment()
	engine.state.phase = "action"
	engine.state.lane = 0
	_play(engine, 0, "fx_noop")
	_check(int(engine.state.players[0].gold) == 3, "once_per marks reset with the round")

## Randomness only at resolution, one draw per pick, none for empty pools.
func _test_randomness() -> void:
	var engine = _engine()
	var before = engine.rng.state
	_play(engine, 0, "fx_roll")
	var with_empty = engine.rng.state
	engine = _engine()
	_unit(engine, "melee_creep", 1)
	_unit(engine, "melee_creep", 1)
	_unit(engine, "melee_creep", 1)
	var start_state = engine.rng.state
	_play(engine, 0, "fx_roll")
	var manual = RandomNumberGenerator.new()
	manual.state = start_state
	manual.randi_range(0, 99)
	manual.randi_range(0, 2)
	manual.randi_range(0, 1)
	_check(engine.rng.state == manual.state, "A chance costs one draw and a pick of 2 from 3 costs one draw per pick")
	var check = RandomNumberGenerator.new()
	check.state = before
	check.randi_range(0, 99)
	_check(with_empty == check.state, "A random pick over an empty set draws nothing (D6)")

## Combat keywords in the combat plan: retaliate, cleave, pierce, regeneration
## and battle-damage triggers (RQ-06, RQ-08, RQ-09, RQ-32, RQ-45).
func _test_combat_keywords() -> void:
	var engine = _engine()
	var cleaver = _unit(engine, "fx_cleaver", 0)
	var piercer = _unit(engine, "fx_piercer", 0)
	var idle = _unit(engine, "fx_dawn", 0)
	var thorns = _unit(engine, "fx_thorns", 1)
	var wall = _unit(engine, "fx_wall", 1)
	var watcher = _unit(engine, "fx_watcher", 1)
	engine.state.lanes[0].units = [[cleaver, piercer, idle], [thorns, wall, watcher]]
	for unit in [cleaver, piercer, idle, thorns, wall, watcher]:
		unit.arrow = 0
		unit.combat_target = -1
	var gold = int(engine.state.players[1].gold)
	var seen = int(engine.state.event_seq)
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(int(thorns.health) == 8 and int(cleaver.health) == 7, "Retaliate answers its attacker, reduced by the attacker's armor (RQ-06)")
	_check(int(wall.health) == 5, "Cleave hits the target's allied neighbors through their armor, and pierce ignores armor (RQ-08): %d" % int(wall.health))
	_check(int(watcher.health) == 9 and int(engine.state.players[1].gold) == gold, "A 0-damage attack is no battle damage and fires no trigger (RQ-32)")
	var parts: Dictionary = {}
	for event in _keys_since(engine, seen):
		if str(event.k) == "combat":
			for strike in event.strikes:
				if int(strike[2]) > 0:
					parts[str(strike[3])] = true
	_check(parts.has("attack") and parts.has("cleave") and parts.has("retaliate"), "Combat strikes name their battle-damage part (RQ-45): %s" % [parts.keys()])
	engine = _engine()
	var troll = _unit(engine, "fx_troll", 0)
	var watching = _unit(engine, "fx_watcher", 0)
	var first = _unit(engine, "fx_piercer", 1)
	var second = _unit(engine, "fx_piercer", 1)
	engine.state.lanes[0].units = [[troll, watching], [first, second]]
	for unit in [troll, watching, first, second]:
		unit.arrow = 0
		unit.combat_target = -1
	troll.health = 2
	gold = int(engine.state.players[0].gold)
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(int(troll.lane) == 0 and int(troll.health) == 2, "Regeneration heals in the combat phase before the death check (RQ-09)")
	_check(int(watching.health) == 6 and int(engine.state.players[0].gold) == gold + 1, "A battle-damage trigger fires once for its own unit as the taker")

## Hand state: iids, parallel arrays, private event fields, redaction.
func _test_hand_state_and_privacy() -> void:
	var engine = EngineClass.new()
	engine.start(11, ["starter", "blue_black_control"])
	var iids: Dictionary = {}
	for player in range(2):
		var owner = engine.state.players[player]
		_check(owner.hand_state.size() == owner.hand.size(), "hand_state runs parallel to the hand")
		for entry in owner.hand_state:
			iids[int(entry.iid)] = true
	_check(iids.size() == 10, "Opening cards get unique iids")
	var view = engine.player_view(0)
	_check(view.players[1].hand_state.is_empty() and view.players[0].hand_state.size() == 5 and view.players[1].deck_state.is_empty(),
		"Views redact the opponent's hand state and every deck state")
	_check(view.players[1].hand_public.size() == 5 and view.players[1].hand_public[0].has("lock"), "Lock counts are public per hand slot")
	engine._event("draw_cards", {"p": 1, "n": 1}, {"1": {"iids": [999]}})
	var mine = engine.player_view(1).events.back()
	var theirs = engine.player_view(0).events.back()
	_check(mine.get("iids") == [999] and not mine.has("_s"), "Private event fields reach their viewer")
	_check(not theirs.has("iids") and not theirs.has("_s"), "Private event fields are stripped for the other viewer")

## Over real bot games: invariants, targeting equivalence (10,000 commands),
## purity of the read-only API, privacy taint and the hidden swap.
func _test_bot_game_properties() -> void:
	var bot = BotClass.new()
	var commands = 0
	var equivalent = true
	var pure = true
	var taint_free = true
	var swap_ok = true
	var invariants_ok = true
	var rng = RandomNumberGenerator.new()
	rng.seed = 404
	var games = 0
	for decks in [["starter", "green_assault"], ["blue_black_control", "starter"], ["green_assault", "blue_black_control"], ["starter", "starter"]]:
		for seed_value in [5, 9]:
			games += 1
			var engine = EngineClass.new()
			engine.start(seed_value, decks)
			var steps = 0
			while engine.state.winner == -1 and steps < 400:
				var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
				if steps % 3 == 0:
					pure = _pure(engine) and pure
					taint_free = _taint_free(engine) and taint_free
				if steps % 25 == 0:
					swap_ok = _hidden_swap(engine, bot) and swap_ok
				for p in range(2):
					var legal = engine.legal_actions(p)
					for command in _mutations(engine, legal, rng):
						commands += 1
						var expected = command in legal
						var actual = EngineClass.Targeting.is_legal(engine, p, command) if command.get("type", "") != "concede" else expected
						if expected != actual:
							equivalent = false
							failures.append("targeting_equivalence: %s for player %d: legal %s, is_legal %s" % [JSON.stringify(command), p, expected, actual])
				var action = bot.choose_action(engine, player)
				if action.is_empty() or not engine.apply_action(player, action).ok:
					break
				var broken = Invariants.violations(engine) + Invariants.write_through(engine)
				if steps % 5 == 0:
					broken.append_array(Invariants.deep_violations(engine))
				if not broken.is_empty():
					invariants_ok = false
					failures.append("Invariants after a bot action (%s seed %d step %d): %s" % [decks, seed_value, steps, broken])
				steps += 1
	_check(commands >= 10000, "targeting_equivalence covers at least 10,000 commands (%d)" % commands)
	_check(equivalent, "targeting_equivalence: is_legal accepts exactly the commands in legal_actions")
	_check(pure, "D3: legal_actions, previews, views, choice steps and the *_of helpers leave digest and rng untouched")
	_check(taint_free, "Privacy taint: no hidden iid of the other player and no private field reaches a view")
	_check(swap_ok, "Hidden swap: the other player's hidden hand, card ids, deck, plans, shop, held secret and item deck change no view, legal action, simulation or bot choice, for both viewers in every phase")
	_check(invariants_ok and games == 8, "Global invariants (I1 to I14) hold after every action of %d bot games" % games)

## Legal commands plus forged variants (wrong ids, extra or missing fields).
func _mutations(engine, legal: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = legal.duplicate()
	var uids: Array = [0, -1, 1, 999999, 1000000]
	for lane in engine.state.lanes:
		for row in lane.units:
			for unit in row:
				if unit != null:
					uids.append(int(unit.uid))
	for command in legal:
		var forged = command.duplicate()
		match rng.randi_range(0, 5):
			0:
				forged["target"] = uids[rng.randi_range(0, uids.size() - 1)]
			1:
				forged["injected"] = true
			2:
				if forged.has("hand"):
					forged.hand = int(forged.hand) + rng.randi_range(-1, 1)
			3:
				if forged.has("position"):
					forged.position = int(forged.position) + rng.randi_range(-2, 2)
				else:
					forged["position"] = 0
			4:
				if forged.has("destination"):
					forged.destination = uids[rng.randi_range(0, uids.size() - 1)]
				elif forged.has("unit"):
					forged.unit = uids[rng.randi_range(0, uids.size() - 1)]
			5:
				for key in ["target", "destination", "position", "unit"]:
					forged.erase(key)
		out.append(forged)
	return out

func _pure(engine) -> bool:
	var digest = engine.state_digest()
	var rng_state = engine.rng.state
	for p in range(2):
		engine.legal_actions(p)
		engine.player_view(p)
		engine.rules_of(p)
		engine.hand_public(p)
		engine.simulation_from_view(p)
		for index in range(engine.state.players[p].hand.size()):
			engine.choice_steps({"hand": index})
	for lane_index in range(3):
		engine.combat_preview(lane_index)
		engine.tower_stats(lane_index, 0)
		engine.creep_positions(lane_index, 1)
		for row in engine.state.lanes[lane_index].units:
			for unit in row:
				if unit == null:
					continue
				engine.attack_of(unit)
				engine.armor_of(unit)
				engine.max_health_of(unit)
				engine.keyword_of(unit, "siege")
				engine.has_flag(unit, "stun")
				engine.badges(unit)
				engine.abilities_of(int(unit.uid))
				engine.combat_targets(unit)
				engine.choice_steps({"unit": int(unit.uid)})
	return engine.state_digest() == digest and engine.rng.state == rng_state

func _taint_free(engine) -> bool:
	for viewer in range(2):
		var text = JSON.stringify(engine.player_view(viewer))
		if text.find("\"_s\"") != -1:
			return false
		for entry in engine.state.players[1 - viewer].get("hand_state", []):
			var pattern = RegEx.create_from_string("\\b%d\\b" % int(entry.iid))
			if pattern.search(text) != null:
				return false
	return true

## Swaps everything the other player keeps hidden (hand cards, their ids and
## counters, deck order and cards, deployment plans, shop, held secret,
## purchases and item deck) and requires each viewer's view, legal actions,
## simulation and (when it is their turn) bot choice to stay the same.
func _hidden_swap(engine, bot) -> bool:
	var ok = true
	for viewer in range(2):
		var swapped = _swapped(engine, 1 - viewer)
		var view = JSON.stringify(engine.player_view(viewer))
		var same_view = view == JSON.stringify(swapped.player_view(viewer))
		var same_actions = engine.legal_actions(viewer) == swapped.legal_actions(viewer)
		var same_simulation = JSON.stringify(engine.simulation_from_view(viewer).state) == JSON.stringify(swapped.simulation_from_view(viewer).state)
		var same_choice = true
		if engine.state.winner == -1 and _next_player(engine) == viewer:
			same_choice = bot.choose_action(engine, viewer) == bot.choose_action(swapped, viewer)
		if not (same_view and same_actions and same_simulation and same_choice):
			ok = false
			failures.append("Hidden swap for viewer %d in phase %s: view %s, actions %s, simulation %s, bot %s" % [viewer,
				engine.state.phase, same_view, same_actions, same_simulation, same_choice])
	return ok

func _swapped(engine, hidden_owner: int):
	var swapped = EngineClass.new()
	swapped.library = engine.library
	swapped.state = engine.state.duplicate(true)
	swapped.rng.state = engine.rng.state
	swapped.next_id = engine.next_id
	swapped.match_seed = engine.match_seed
	swapped.deck_ids = engine.deck_ids.duplicate()
	var owner: Dictionary = swapped.state.players[hidden_owner]
	var ids: Array = engine.library.cards.keys()
	ids.sort()
	for index in range(owner.hand.size()):
		owner.hand[index] = ids[0] if str(owner.hand[index]) != str(ids[0]) else ids[1]
	for index in range(owner.get("hand_state", []).size()):
		owner.hand_state[index]["iid"] = 7777000 + index
		owner.hand_state[index]["charges"] = 9
	owner.deck.reverse()
	if not owner.deck.is_empty():
		owner.deck[0] = ids[2]
	for key in owner.get("plans", {}).keys():
		owner.plans[key] = (int(owner.plans[key]) + 1) % 3
	for key in owner.get("shop", {}).keys():
		owner.shop[key] = ids[3]
	if not str(owner.get("held_secret", "")).is_empty():
		owner.held_secret = ids[3]
	owner["bought"] = []
	owner.get("item_deck", []).reverse()
	return swapped

func _next_player(engine) -> int:
	return int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)

## A seeded random-legal agent against the bot (and against itself) on both
## packs: every invariant (I1 to I14) after every step, forged commands
## rejected without a change, the hidden swap, and replay round trips (plain
## JSON and the network number normalization) with an equal digest.
func _test_random_agent_fuzz() -> void:
	var bot = BotClass.new()
	var steps_total = 0
	var largest_packet = 0
	var most_actions = 0
	var problems: Array = []
	for seed_value in [31, 32, 33, 34, 35, 36]:
		var pack = "original_training_fixtures" if seed_value % 3 == 0 else "artifact_classic_decks_v2"
		var engine = EngineClass.new()
		engine.library = Library.new(pack)
		var presets: Array = engine.library.presets().map(func(entry): return str(entry.id))
		var decks = ["starter", "starter"] if presets.is_empty() else [presets[seed_value % presets.size()], presets[(seed_value / 2) % presets.size()]]
		engine.start(seed_value, decks)
		var agent = RandomNumberGenerator.new()
		agent.seed = seed_value * 7919
		var bot_side = seed_value % 3
		var steps = 0
		while engine.state.winner == -1 and steps < 300 and problems.size() < 5:
			var player = _next_player(engine)
			var legal: Array = engine.legal_actions(player)
			if legal.is_empty():
				problems.append("seed %d step %d: no legal action in phase %s" % [seed_value, steps, engine.state.phase])
				break
			most_actions = maxi(most_actions, legal.size())
			if steps % 4 == 0:
				largest_packet = maxi(largest_packet, Invariants.packet_size(engine))
				var digest = engine.state_digest()
				var rng_state = engine.rng.state
				for forged in _mutations(engine, legal, agent).slice(legal.size()):
					if forged in legal:
						continue
					if engine.apply_action(player, forged).ok:
						problems.append("seed %d step %d: forged command %s was accepted" % [seed_value, steps, JSON.stringify(forged)])
					if engine.state_digest() != digest or engine.rng.state != rng_state:
						problems.append("seed %d step %d: a rejected command changed the state" % [seed_value, steps])
						break
			if steps % 20 == 0 and not _hidden_swap(engine, bot):
				problems.append("seed %d step %d: hidden swap" % [seed_value, steps])
			var command: Dictionary = bot.choose_action(engine, player) if player == bot_side else legal[agent.randi_range(0, legal.size() - 1)]
			var raw = JSON.parse_string(JSON.stringify(command))
			if not engine.apply_action(player, raw).ok:
				problems.append("seed %d step %d: legal command %s rejected after a JSON round trip" % [seed_value, steps, JSON.stringify(command)])
				break
			var broken = Invariants.violations(engine) + Invariants.write_through(engine)
			if steps % 2 == 0:
				broken.append_array(Invariants.deep_violations(engine))
			if not broken.is_empty():
				problems.append("seed %d step %d after %s: %s" % [seed_value, steps, JSON.stringify(command), broken])
			steps += 1
		steps_total += steps
		var text = JSON.stringify(engine.replay_data())
		for normalize in [false, true]:
			var data = JSON.parse_string(text)
			var restored = EngineClass.new()
			var loaded = restored.load_replay(Bridge.normalize_numbers(data) if normalize else data)
			if not loaded.ok or restored.state_digest() != engine.state_digest():
				problems.append("seed %d: replay round trip (normalized %s) %s" % [seed_value, normalize, loaded])
	_check(problems.is_empty(), "Random-agent fuzz: invariants, forged commands, hidden swap and replays: %s" % [problems.slice(0, 5)])
	_check(steps_total >= 600, "Random-agent fuzz ran at least 600 steps (%d)" % steps_total)
	_check(largest_packet < Invariants.PACKET_LIMIT and most_actions <= Invariants.LEGAL_ACTIONS_LIMIT,
		"I14: the largest guest packet is %d bytes (< %d) and the most legal actions %d (<= %d)" % [largest_packet,
			Invariants.PACKET_LIMIT, most_actions, Invariants.LEGAL_ACTIONS_LIMIT])

## D3 on hand-built states: a view never adds the hidden pile keys.
func _test_player_view_partial_state() -> void:
	var engine = EngineClass.new()
	engine.start(3)
	for owner in engine.state.players:
		owner.erase("deck_state")
		owner.erase("item_deck")
	var digest = engine.state_digest()
	var view = engine.player_view(0)
	_check(engine.state_digest() == digest and not engine.state.players[0].has("deck_state") and not engine.state.players[1].has("item_deck"),
		"player_view adds no deck_state or item_deck key to a state that lacks them")
	_check(int(view.players[1].deck_count) == engine.state.players[1].deck.size() and view.players[1].deck.is_empty(),
		"The view still counts the deck and hides its cards")

## The invariants catch what they claim to (each broken on purpose).
func _test_invariants_catch() -> void:
	var engine = _engine()
	# The fixture writes mana and empties hands directly; make them consistent.
	for lane in engine.state.lanes:
		lane.max_mana_base = [20, 20]
		lane.mana_bonus = [0, 0]
	for owner in engine.state.players:
		owner.hand_state = []
	var hero = _caster(engine, 0, "red")
	var enemy = _unit(engine, "fx_dawn", 1)
	_check(Invariants.violations(engine).is_empty() and Invariants.write_through(engine).is_empty(),
		"A fixture board satisfies the invariants: %s" % [Invariants.violations(engine) + Invariants.write_through(engine)])
	Kernel.give(engine, enemy, {"attack": 1}, {}, "", "round", {"controller": 0, "card": "gust"})
	enemy.mods.back()["d"] = "forever"
	_check(Invariants.violations(engine).any(func(text): return str(text).begins_with("I6")), "I6 flags a modifier entry with an unknown duration")
	enemy.mods.back()["d"] = "round"
	enemy.mods.back()["ab"] = "gust#4"
	_check(Invariants.violations(engine).any(func(text): return str(text).find("does not resolve") != -1), "I6 flags a granted ability that does not resolve")
	enemy.mods.clear()
	enemy.attack = int(enemy.attack) + 2
	_check(Invariants.write_through(engine).any(func(text): return str(text).begins_with("I11 attack")), "I11 flags an own stat that is not printed + modify")
	enemy.attack = int(enemy.attack) - 2
	engine._event("rules_overflow")
	_check(Invariants.violations(engine).has("I9 rules_overflow logged"), "I9 flags a rules_overflow")
	engine = _engine()
	hero = _caster(engine, 0, "red")
	engine.state.players[1]["hand_state"] = [{"iid": 4242424}]
	engine.state.players[1].hand = ["gust"]
	engine.state.events.append({"k": "probe", "n": 4242424})
	_check(Invariants.privacy(engine).any(func(text): return str(text).begins_with("I12 player 0")), "I12 flags an opponent hand id in a view")
	_unit(engine, "fx_dawn", 1)
	hero.combat_target = 0
	_check(not Invariants.board(engine), "I2 flags a forced tower target with a unit directly across")

## Replays carry the protocol and RULES_VERSION and reject other rules.
func _test_replay_versions() -> void:
	var engine = EngineClass.new()
	engine.start(3)
	engine.apply_action(int(engine.state.active_player), {"type": "pass"})
	var replay = engine.replay_data()
	_check(int(replay.protocol) == 8 and str(replay.rules) == RulesVersion.RULES_VERSION, "Replays record protocol 8 and RULES_VERSION")
	var restored = EngineClass.new()
	_check(restored.load_replay(JSON.parse_string(JSON.stringify(replay))).ok and restored.state_digest() == engine.state_digest(), "A replay round trip reproduces the digest")
	replay.rules = "000000000000"
	var stale = EngineClass.new().load_replay(replay)
	_check(stale.get("code") == "replay_rules" and str(stale.args.engine) == RulesVersion.RULES_VERSION, "A replay of other rules fails with replay_rules and names both versions")

# --- Fidelity fixes (M1.5) ----------------------------------------------------------

## RQ-01 (FX-1): "each enemy unit" hits units only; the tower is not a unit.
func _test_rq_01_each_enemy_excludes_tower() -> void:
	for card_id in ["tower_barrage", "thunderstorm"]:
		var engine = _engine()
		var caster = _caster(engine, 0, "blue")
		var ally = _unit(engine, "fx_dawn", 0)
		var enemy = _unit(engine, "fx_dawn", 1)
		var tower: Dictionary = engine.state.lanes[0].structures[1]
		var tower_health = int(tower.health)
		var amount = int(engine.library.rules(card_id).params.amount)
		var result = _play(engine, 0, card_id)
		_check(result.ok, "%s plays: %s" % [card_id, result])
		_check(int(enemy.health) == 9 - amount and int(ally.health) == 9 and int(caster.health) == int(caster.max_health),
			"%s deals %d damage to each enemy unit and none to allies" % [card_id, amount])
		_check(int(tower.health) == tower_health, "rq_01_each_enemy_excludes_tower: %s leaves the enemy tower at %d (got %d)" % [card_id, tower_health, int(tower.health)])
		var ops: Array = engine.library.rules(card_id).play.ops
		_check(ops.all(func(op): return str(op.op) != "tower_damage"), "%s has no tower_damage op" % card_id)

## RQ-19 (FX-2): the tower is a legal combat target only when the position
## directly across is empty; an empty diagonal is not enough.
func _test_rq_19_tower_needs_empty_across() -> void:
	_check(EngineClass.TOWER_NEEDS_EMPTY_ACROSS, "RQ-19 is on (FX-2)")
	var engine = _engine()
	var caster = _caster(engine, 0, "blue")
	var attacker = _unit(engine, "fx_dawn", 0)
	var ally = _unit(engine, "fx_dawn", 0)
	var left = _unit(engine, "fx_dawn", 1)
	var across = _unit(engine, "fx_dawn", 1)
	var lane: Dictionary = engine.state.lanes[0]
	lane.units = [[caster, attacker, ally], [left, across, null]]
	var redirect = {"type": "play", "hand": 0, "target": attacker.uid, "destination": 0}
	var targets: Array = engine.combat_targets(attacker)
	_check(not targets.has(0) and targets.has(left.uid) and targets.has(across.uid),
		"rq_19_tower_needs_empty_across: an empty diagonal does not open the tower while a unit stands directly across: %s" % [targets])
	engine.state.players[0].hand = ["battlefield_control"]
	_check(not redirect in engine.legal_actions(0) and not engine.apply_action(0, redirect).ok,
		"Battlefield Control cannot send a unit with an enemy directly across to the tower")
	lane.units[1] = [left, null, across]
	targets = engine.combat_targets(attacker)
	_check(targets.has(0) and targets.has(left.uid) and targets.has(across.uid),
		"rq_19_tower_needs_empty_across: the tower opens once the position directly across is empty: %s" % [targets])
	engine.state.players[0].hand = ["battlefield_control"]
	_check(redirect in engine.legal_actions(0) and engine.apply_action(0, redirect).ok and int(attacker.combat_target) == 0,
		"Battlefield Control then sends the unit to the tower")
	Kernel.modify(engine, attacker, {"attack": 3}, {}, "", {"controller": 0, "card": ""})
	_check(engine.combat_target_of(attacker).is_empty() and int(engine.combat_preview(0).tower_damage[0]) == 3 and Invariants.board(engine),
		"The redirected unit aims at the tower")
	# An enemy creep then enters the position directly across: it blocks the
	# unit, so the forced tower target ends (a unit directly across blocks).
	var red = _caster(engine, 1, "red")
	lane.units = [[caster, attacker, ally, null], [left, null, across, red]]
	engine.state.active_player = 1
	engine.state.players[1].hand = ["bronze_legionnaire"]
	var positions: Array = engine.creep_positions(0, 1)
	var play = {"type": "play", "hand": 0, "position": 1}
	_check(positions.has(1) and play in engine.legal_actions(1) and engine.apply_action(1, play).ok, "The opponent plays a creep directly across: %s" % [positions])
	var blocker = engine.state.lanes[0].units[1][1]
	_check(blocker != null and str(blocker.card) == "bronze_legionnaire", "The creep stands directly across")
	_check(int(attacker.combat_target) == -1 and int(attacker.arrow) == 0 and blocker != null and engine.combat_target_of(attacker).get("uid") == blocker.uid,
		"rq_19_tower_needs_empty_across: a unit sent to the tower is blocked by a unit that enters across (target %s)" % [engine.combat_target_of(attacker).get("card", "tower")])
	var preview: Dictionary = engine.combat_preview(0)
	_check(int(preview.tower_damage[0]) == 0 and blocker != null and int(preview.unit_damage.get(str(blocker.uid), 0)) > 0 and Invariants.board(engine),
		"The blocked unit damages the blocker and not the tower: %s %s" % [preview.tower_damage, preview.unit_damage])

## FX-3 (RQ-15): group damage is computed from one derived state, and a unit
## projects its auras until the Pulse removes it.
func _test_fx3_aura_persists_until_pulse() -> void:
	_check(Kernel.SIMULTANEOUS_DAMAGE and not Stats.AURAS_NEED_HEALTH, "FX-3 is on")
	# Tower Barrage kills a Prowler Vanguard; its neighbor still has the +1 armor
	# aura for the same damage (sequential damage without the aura dealt 2).
	var engine = _engine()
	_caster(engine, 0, "blue")
	var prowler = _unit(engine, "prowler_vanguard", 1)
	var neighbor = _unit(engine, "fx_dawn", 1)
	prowler.health = 2
	var seen = int(engine.state.event_seq)
	_check(_play(engine, 0, "tower_barrage").ok, "Tower Barrage plays")
	var hits: Array = []
	for event in _keys_since(engine, seen):
		if str(event.k) == "damage":
			hits = event.hits
	_check(int(prowler.lane) == -1 and int(neighbor.health) == 8 and hits.has([int(neighbor.uid), 1]),
		"fx3_aura_persists_until_pulse: a lethally damaged Prowler's armor aura still reduces the same group damage (%s)" % [hits])
	_check(engine.armor_of(neighbor) == 0, "The aura ends when the Pulse removes its source")
	# A +Health aura lasts until the Pulse: its neighbor survives the damage,
	# sees the source die, then dies to the aura's loss in the same Pulse (RQ-40).
	engine = _engine()
	_caster(engine, 0, "blue")
	var banner = _unit(engine, "fx_banner", 1)
	var avenger = _unit(engine, "fx_avenger", 1)
	Stats.settle(engine)
	banner.health = 2
	_check(int(avenger.health) == 3, "The banner raises its neighbor to 3 health")
	seen = int(engine.state.event_seq)
	_check(_play(engine, 0, "tower_barrage").ok, "Tower Barrage plays")
	_check(_triggers(engine, seen).has("u%d" % avenger.uid),
		"fx3_aura_persists_until_pulse: a unit kept alive by a dying unit's aura until the Pulse sees that death")
	_check(int(banner.lane) == -1 and int(avenger.lane) == -1, "Losing the aura at removal kills the neighbor in the same Pulse")
	var on_board = engine.state.lanes[0].units[1].filter(func(unit): return unit != null and int(unit.health) <= 0)
	_check(on_board.is_empty() and Invariants.violations(engine).is_empty(), "No unit with 0 health is left on the board: %s" % [Invariants.violations(engine)])
