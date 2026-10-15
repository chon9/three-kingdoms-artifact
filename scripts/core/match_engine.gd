extends RefCounted
## Authoritative, UI-independent match state. Every mutation goes through a
## validated command; RNG and command journals make a match reproducible.
##
## Card behaviour is data: the rules of every card (data/*.json, schema 4) are
## compiled by CardLibrary and run by the static rules modules in
## scripts/core/rules/ (EFFECT_SYSTEM_SPEC.md). This script is the facade:
## phases, commands, views and replays.

## Lane model: lanes[i].units[0] and lanes[i].units[1] are always the same
## length and index-aligned. Index n is one shared combat position holding the
## player-0 unit (or null) and the player-1 unit (or null). Positions that are
## empty on both sides are removed whenever units leave a lane (_compact).

const Library = preload("res://scripts/core/card_library.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Combat = preload("res://scripts/core/rules/combat.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Select = preload("res://scripts/core/rules/select.gd")
const VM = preload("res://scripts/core/rules/vm.gd")
const Targeting = preload("res://scripts/core/rules/targeting.gd")
const RulesVersion = preload("res://scripts/core/rules/rules_version.gd")
# 4: aligned combat positions, play.position for creep cards, hold command,
# structured events and visible pending lane creeps.
# 5: language-neutral state (no display names in units or players) and coded
# error results ({"ok": false, "code": ..., "args": ..., "error": English}).
# The concede command (always legal while the match runs) needs no format
# change: older replays never contain it.
# 6: a planned hero may be re-planned to another lane or taken back
# (undeploy) until its player confirms, and the reveal emits
# deployment_placed. Older builds reject such replays.
# 7: the rules engine (EFFECT_SYSTEM_SPEC.md): hand and deck state with card
# instance ids, modifier entries with provenance, item instances,
# improvements, deeds, the round log, a 400-event window and private event
# fields; replays carry RULES_VERSION and reject other rules.
const PROTOCOL_VERSION = 7
const CONCEDE = {"type": "concede"}
const HOLD_COST = 1
const EVENT_WINDOW = 400
const OID_START = 1000000
## Player fields a view never copies (spec §10.4).
const HIDDEN_PILES = ["deck", "deck_state", "item_deck"]
## RQ-19 (FX-2): the tower is a legal combat target only when the position
## directly across is empty (false: when any of the three positions across is
## empty, the rule before FX-2).
const TOWER_NEEDS_EMPTY_ACROSS = true
var library = Library.new()
var rng = RandomNumberGenerator.new()
var state: Dictionary = {}
var journal: Array = []
var match_seed: int = 1
var next_id: int = 1
var deck_ids: Array = ["starter", "starter"]
# Transient rules fields (spec §1.2): never in state, reset at the start of
# start() and apply_action(), empty again when they return.
var _queue: Array = []
var _event_index: int = 0
var _pulse_depth: int = 0
var _ops_left: int = VM.OP_BUDGET
var _lookback: Dictionary = {}
var _deploying: bool = false
var _deriving: Dictionary = {}
var _causes: Dictionary = {}
# The lane whose combat is resolving (-1 outside Combat.resolve).
var _combat_lane: int = -1
# Read-frame cache of derived stats (Stats.frame_begin / frame_end).
var _frame: Dictionary = {}
var _frame_depth: int = 0

func _reset_transient() -> void:
	_queue = []
	_event_index = 0
	_pulse_depth = 0
	_ops_left = VM.OP_BUDGET
	_lookback = {}
	_deploying = false
	_deriving = {}
	_causes = {}
	_combat_lane = -1
	_frame = {}
	_frame_depth = 0

## The transient queues are empty between commands (invariant I9).
func _settle_transient() -> void:
	if not _queue.is_empty() or _pulse_depth != 0:
		push_error("Rules queue not empty after a command")
		_queue = []
		_pulse_depth = 0
	_lookback = {}
	_causes = {}

func start(seed_value: int = 1, selected_decks: Array = ["starter", "starter"]) -> Dictionary:
	if not library.presets().is_empty():
		if selected_decks.size() != 2:
			return _fail("deck_selection", "Choose one deck for each player.")
		for preset_id in selected_decks:
			var entry = library.preset(str(preset_id))
			var validation = library.validate_preset(entry)
			if not validation.ok:
				return validation
	_reset_transient()
	deck_ids = selected_decks.duplicate()
	match_seed = seed_value
	rng.seed = seed_value
	journal.clear()
	next_id = 1
	state = {"round": 1, "lane": 0, "phase": "action", "active_player": 0,
		"initiative": 0, "first_pass": -1, "winner": -1, "revision": 0,
		"players": [], "lanes": [], "events": [], "event_seq": 0,
		"pending_creeps": [[], []], "next_oid": OID_START, "round_log": Kernel.new_round_log(),
		"combat_seq": 0, "order_seq": 0}
	for player in range(2):
		var deck = library.match_deck(str(deck_ids[player]))
		_shuffle(deck)
		var roster: Array = []
		var hero_list = library.match_heroes(str(deck_ids[player]))
		for index in range(hero_list.size()):
			var hero = _make_unit(hero_list[index], player, true)
			hero["ready_round"] = 1 if index < 3 else index - 1
			hero["cooldown"] = Kernel.HERO_ACTIVE_START_COOLDOWN
			roster.append(hero)
		var item_deck = library.item_deck(str(deck_ids[player])) if not library.presets().is_empty() else []
		_shuffle(item_deck)
		state.players.append({"hand": [], "hand_state": [], "deck": deck, "deck_state": [], "gold": 0,
			"roster": roster, "plans": {}, "finished": false, "bought": [], "deeds": [],
			"item_deck": item_deck, "shop": {}, "held_secret": "", "preset": str(deck_ids[player])})
	for lane in range(3):
		state.lanes.append({"units": [[], []], "mana": [3, 3],
			"max_mana": [3, 3], "mana_bonus": [0, 0], "max_mana_base": [3, 3], "improvements": [[], []],
			"structures": [
				{"health": 40, "ancient": false, "destroyed": false, "armor": 0, "mods": []},
				{"health": 40, "ancient": false, "destroyed": false, "armor": 0, "mods": []}]})
	# Round 1: heroes 1-3 take one random lane each and one Melee Creep joins
	# every lane per player. Both players' units are placed in one shuffled
	# order so neither side systematically claims combat positions first.
	var placements: Array = []
	for player in range(2):
		var lane_order: Array = [0, 1, 2]
		_shuffle(lane_order)
		for index in range(3):
			placements.append([state.players[player].roster[index], lane_order[index]])
		for lane in range(3):
			placements.append([_make_creep(player), lane])
		_draw(player, 5)
	_place_all(placements)
	state.initiative = Kernel.rand_index(self, 2)
	state.active_player = state.initiative
	# Round 1's placement is a deployment phase too (RQ-49, CF-7). The hooks
	# run after the initiative roll because the trigger order reads it.
	if Kernel.ROUND1_DEPLOYMENT_HOOKS:
		_deployment_hooks(placements)
	_roll_arrows()
	_event("match_start")
	Kernel.lane_open(self, 0)
	_settle_transient()
	return {"ok": true}

## unit_entered for every placed unit, then the deployment event and one
## Pulse; summons wait for the arrow roll that follows.
func _deployment_hooks(placements: Array) -> void:
	for entry in placements:
		var unit: Dictionary = entry[0]
		Kernel.emit(self, "unit_entered", {"unit": int(unit.uid), "lane": int(unit.lane), "how": "deploy"})
	Kernel.emit(self, "deployment", {})
	_deploying = true
	Kernel.pulse(self)
	_deploying = false

func legal_actions(player: int) -> Array:
	var actions: Array = []
	if player < 0 or player > 1 or state.is_empty() or state.winner != -1:
		return actions
	var owner = state.players[player]
	if state.phase == "shop":
		if owner.finished:
			return actions
		if library.presets().is_empty():
			for card_id in library.shop_cards():
				if card_id not in owner.bought and owner.gold >= Kernel.price_of(self, player, "", card_id):
					actions.append({"type": "buy", "card": card_id})
		else:
			for source in owner.shop:
				var card_id = owner.shop[source]
				if not str(card_id).is_empty() and owner.gold >= Kernel.price_of(self, player, str(source), str(card_id)):
					actions.append({"type": "buy", "card": card_id, "source": source})
			# Hold: pay 1 gold once per shop phase to keep the Secret Shop offer.
			if owner.gold >= HOLD_COST and not str(owner.shop.get("secret", "")).is_empty() and str(owner.get("held_secret", "")).is_empty():
				actions.append({"type": "hold"})
		actions.append({"type": "finish_shop"})
		return actions
	if state.phase == "deployment":
		if owner.finished:
			return actions
		var unplanned = false
		var planned: Array = []
		for hero in owner.roster:
			if hero.lane != -1 or hero.ready_round > state.round:
				continue
			if owner.plans.has(str(hero.uid)):
				planned.append(hero)
				continue
			unplanned = true
			for lane in range(3):
				actions.append({"type": "deploy", "unit": hero.uid, "lane": lane})
		if not unplanned:
			actions.append({"type": "finish_deployment"})
		# Re-planning and taking a hero back come last, so callers that take
		# legal_actions(p)[0] (scripts, tests) still reach finish_deployment.
		for hero in planned:
			var current = int(owner.plans[str(hero.uid)])
			for lane in range(3):
				if lane != current:
					actions.append({"type": "deploy", "unit": hero.uid, "lane": lane})
		for hero in planned:
			actions.append({"type": "undeploy", "unit": hero.uid})
		return actions
	if state.phase != "action" or state.active_player != player:
		return actions
	# Pass first, then abilities and hand cards in a fixed order (spec §7.1).
	actions.append({"type": "pass"})
	actions.append_array(Targeting.actions(self, player))
	return actions

## Legal `position` values for a creep card played by `player` into a lane:
## the index of an existing combat position whose own slot is empty, -1 for a
## new position at the left end, or the current position count for a new
## position at the right end. An empty lane offers only 0.
func creep_positions(lane_index: int, player: int) -> Array:
	var row = state.lanes[lane_index].units[player]
	if row.is_empty():
		return [0]
	var result: Array = [-1]
	for slot in range(row.size()):
		if row[slot] == null:
			result.append(slot)
	result.append(row.size())
	return result

func apply_action(player: int, command: Dictionary) -> Dictionary:
	# Matching the entire shape rejects unknown fields, forged targets, cross-lane
	# actions, out-of-turn plays, negative indexes and unaffordable purchases.
	# JSON decodes numbers as floats. Canonicalize exact integer command fields
	# before dictionary comparison, without accepting strings or fractions.
	command = command.duplicate(true)
	for field in ["hand", "target", "unit", "lane", "destination", "position"]:
		if command.has(field):
			var value = command[field]
			if not (value is int or value is float) or float(value) != floor(float(value)):
				return _fail("bad_index", "Command indexes must be whole numbers.")
			command[field] = int(value)
	if command == CONCEDE:
		if not can_concede(player):
			return _fail("illegal_action", "That action is not legal in the current state.")
	elif not Targeting.is_legal(self, player, command):
		return _fail("illegal_action", "That action is not legal in the current state.")
	journal.append({"player": player, "command": command.duplicate(true)})
	_reset_transient()
	Zones.sync(self)
	match command.type:
		"concede":
			_concede(player)
		"pass":
			_pass(player)
		"play":
			_play(player, command)
		"ability":
			_use_ability(player, command)
		"buy":
			var price = Kernel.price_of(self, player, str(command.get("source", "")), str(command.card))
			state.players[player].gold -= price
			state.players[player].hand.append(command.card)
			state.players[player].hand_state.append({"iid": Kernel.next_oid(self)})
			state.players[player].bought.append(command.card)
			if command.has("source"):
				if command.source == "item":
					state.players[player].item_deck.pop_back()
					state.players[player].shop.item = state.players[player].item_deck.back() if not state.players[player].item_deck.is_empty() else ""
				else:
					state.players[player].shop[command.source] = ""
					if command.source == "secret":
						state.players[player].held_secret = ""
			# Public log: cost only, never the purchased card's identity.
			_event("buy", {"p": player, "gold": price})
		"hold":
			var owner = state.players[player]
			owner.gold -= HOLD_COST
			owner.held_secret = owner.shop.secret
			_event("hold", {"p": player, "gold": HOLD_COST})
		"finish_shop":
			state.players[player].finished = true
			if state.players[0].finished and state.players[1].finished:
				_begin_deployment()
		"deploy":
			# Planning (or re-planning) is private: no event, no randomness.
			state.players[player].plans[str(command.unit)] = int(command.lane)
		"undeploy":
			state.players[player].plans.erase(str(command.unit))
		"finish_deployment":
			state.players[player].finished = true
			if state.players[0].finished and state.players[1].finished:
				_reveal_deployment()
	state.revision += 1
	_settle_transient()
	return {"ok": true}

## Either player may concede in any phase while the match is undecided. It is
## kept out of legal_actions() so turn logic (bots, "is it my turn") ignores it.
func can_concede(player: int) -> bool:
	return player >= 0 and player <= 1 and not state.is_empty() and int(state.winner) == -1

func _concede(player: int) -> void:
	_event("concede", {"p": player})
	state.winner = 1 - player
	state.phase = "finished"
	_event("win", {"p": state.winner})

func _pass(player: int) -> void:
	_event("pass", {"p": player})
	if state.first_pass == -1:
		state.first_pass = player
		state.active_player = 1 - player
	else:
		state.initiative = state.first_pass
		state.first_pass = -1
		_combat_and_advance()

## The lane fights, then the next lane opens (before-action triggers) or the
## shop begins after the right lane.
func _combat_and_advance() -> void:
	Combat.resolve(self, int(state.lane))
	if state.winner != -1:
		return
	if state.lane < 2:
		state.lane += 1
		state.active_player = state.initiative
		_event("lane_open", {"lane": state.lane, "p": state.initiative})
		Kernel.lane_open(self, int(state.lane))
	else:
		state.phase = "shop"
		for owner in state.players:
			owner.finished = false
			owner.bought.clear()
		_prepare_shop()
		_event("shop_open")

## Enough Magic! (RQ-20): the caster's opponent gets initiative and the lane
## goes straight to combat as if both players had passed.
func _end_action_phase(player: int) -> void:
	_finish_action(player, false)
	_combat_and_advance()

func _prepare_shop() -> void:
	if library.presets().is_empty():
		return
	for owner in state.players:
		var pool = library.catalog.secret_shop
		var consumables = library.catalog.consumables
		# The item deck is reshuffled at every shopping phase.
		_shuffle(owner.item_deck)
		# A held Secret Shop offer returns once, then the hold is spent.
		var secret = str(owner.get("held_secret", ""))
		if secret.is_empty():
			secret = pool[Kernel.rand_index(self, pool.size())]
		owner.held_secret = ""
		owner.shop = {"secret": secret,
			"item": owner.item_deck.back() if not owner.item_deck.is_empty() else "",
			"consumable": consumables[Kernel.rand_index(self, consumables.size())]}

## The context of a card played from hand: choices are the command's fields.
func _play_ctx(player: int, card_id: String, command: Dictionary, entry: Dictionary) -> Dictionary:
	var choices: Dictionary = {}
	for key in ["target", "destination", "lane", "position"]:
		if command.has(key):
			choices[key] = int(command[key])
	var play: Dictionary = library.rules(card_id).get("play", {})
	return {"src": null, "host": null, "controller": player, "lane": int(state.lane), "card": card_id,
		"choices": choices, "vars": {}, "played": {"card": card_id, "state": entry},
		"keep_initiative": bool(play.get("initiative", false)), "end_phase": false}

func _play(player: int, command: Dictionary) -> void:
	var taken = Zones.take_from_hand(self, player, int(command.hand))
	var card_id: String = taken.card
	var card = library.cards[card_id]
	var rules: Dictionary = library.rules(card_id)
	state.lanes[state.lane].mana[player] -= int(card.get("cost", 0))
	var target = find_unit(int(command.get("target", -1)))
	var played = {"p": player, "card": card_id}
	if not target.is_empty():
		played["target"] = target.uid
		played["target_card"] = target.card
	_event("play", played)
	var ctx = _play_ctx(player, card_id, command, taken.state)
	var ops: Array = rules.get("play", {}).get("ops", [])
	if card.kind == "creep":
		# Only the new unit gets a pathing roll; other arrows are untouched.
		var creep = _make_unit(card, player, false)
		_place(creep, state.lane, int(command.position))
		_roll_arrow(creep)
		Kernel.emit(self, "unit_entered", {"unit": int(creep.uid), "lane": int(state.lane), "how": "play"})
		ctx.src = creep
		ctx.host = creep
		VM.run(self, ops, ctx)
	elif card.kind == "item" and str(card.get("slot", "")) in ["weapon", "armor", "accessory"] and not card.get("consumable", false):
		Zones.equip(self, target, card_id)
		var item_ctx = Stats.item_ctx(self, target, str(card.slot))
		VM.run(self, rules.get("enter", []), item_ctx)
	elif card.kind == "improvement":
		var improvement = Zones.add_improvement(self, card_id, player, int(command.lane))
		VM.run(self, rules.get("enter", []), Stats.object_ctx(self, improvement))
	elif card.kind == "item" and str(card.get("slot", "")) == "deed":
		Zones.add_deed(self, card_id, player)
	else:
		VM.run(self, ops, ctx)
	# Deaths resolve before post-spell triggers; a condemned Zeus cannot trigger.
	Kernel.pulse(self)
	_run_hacks(player, card_id, taken.state)
	Kernel.emit(self, "card_played", {"player": player, "card": card_id, "kind": str(card.kind),
		"color": str(card.get("color", "")), "cost": int(card.get("cost", 0)), "lane": int(state.lane),
		"target": int(command.get("target", -1))})
	Kernel.pulse(self)
	_check_winner()
	if ctx.get("end_phase", false) and state.winner == -1:
		_end_action_phase(player)
	else:
		_finish_action(player, ctx.get("keep_initiative", false))

## Hacks on a played card (Self Sabotage) run after the card has resolved and
## pulsed, in the order they were attached, with the player who played it as
## controller; a Pulse follows each, and card_played comes after them all
## (spec §3.12, RQ-36). The hack takes its params from the granting card.
func _run_hacks(player: int, card_id: String, entry: Dictionary) -> void:
	for hack in entry.get("hacks", []):
		var ability: Dictionary = Stats.granted_ability(self, {"ab": str(hack)})
		if ability.is_empty() or _ops_left <= 0:
			continue
		var granting = str(hack).split("#")[0]
		var played = {"card": card_id, "state": entry}
		var ctx = {"src": played, "host": null, "controller": player, "lane": int(state.lane), "card": granting,
			"choices": {}, "vars": {}, "played": played, "keep_initiative": false, "end_phase": false}
		_event("trigger", {"src": "", "card": granting, "ability": "hack", "p": player})
		VM.run(self, ability.get("ops", []), ctx)
		Kernel.pulse(self)

## An active ability of a unit, item or improvement (spec §4.6).
func _use_ability(player: int, command: Dictionary) -> void:
	var source = find_object(int(command.unit))
	var card_id = str(source.get("card", ""))
	var rules: Dictionary = library.rules(card_id)
	var ability: Dictionary = rules.abilities[int(rules.active)]
	var ctx: Dictionary
	match str(source.get("kind", "")):
		"item":
			ctx = Stats.item_ctx(self, source.host, str(source.slot))
		"improvement":
			ctx = Stats.object_ctx(self, source.object)
		_:
			ctx = Stats.unit_ctx(self, source.object)
	for key in ["target", "destination", "lane", "position"]:
		if command.has(key):
			ctx.choices[key] = int(command[key])
	_event("ability", {"p": player, "uid": int(command.unit), "card": card_id, "ability": str(ability.id)})
	VM.run(self, ability.get("ops", []), ctx)
	var cooldown = int(ability.cooldown)
	if bool(ability.get("quicken", false)):
		cooldown = maxi(1, cooldown - 1)
	match str(source.get("kind", "")):
		"item":
			source.host.item_state[str(source.slot)]["cd"] = cooldown
		"improvement":
			source.object["cd"] = cooldown
		_:
			source.object["cooldown"] = cooldown
	Kernel.pulse(self)
	_check_winner()
	_finish_action(player, false)

func _finish_action(player: int, keep_initiative: bool) -> void:
	state.first_pass = -1
	state.initiative = player if keep_initiative else 1 - player
	state.active_player = state.initiative

func combat_preview(lane_index: int) -> Dictionary:
	return Combat.preview(self, lane_index)

func _combat_target(unit: Dictionary, lane_index: int, slot: int) -> Dictionary:
	return Combat.combat_target(self, unit, lane_index, slot)

## The unit (or {} for the tower) that `unit` would hit in combat right now.
func combat_target_of(unit: Dictionary) -> Dictionary:
	var slot = _slot_of(unit)
	if slot == -1:
		return {}
	return _combat_target(unit, int(unit.lane), slot)

## Legal Battlefield Control destinations: the enemy units in the three combat
## positions across from `unit`, plus the tower (0, listed first). The tower
## is legal when one of those existing positions is empty on the enemy side,
## or with TOWER_NEEDS_EMPTY_ACROSS only when the position directly across is.
func combat_targets(unit: Dictionary) -> Array:
	var result: Array = []
	var slot = _slot_of(unit)
	if slot == -1:
		return result
	var enemy_row = state.lanes[unit.lane].units[1 - int(unit.owner)]
	var tower_open = false
	for offset in [-1, 0, 1]:
		var index = slot + offset
		if index < 0 or index >= enemy_row.size():
			continue
		if enemy_row[index] == null:
			if offset == 0 or not TOWER_NEEDS_EMPTY_ACROSS:
				tower_open = true
		else:
			result.append(enemy_row[index].uid)
	if TOWER_NEEDS_EMPTY_ACROSS and slot >= enemy_row.size():
		tower_open = true
	if tower_open:
		result.push_front(0) # Tower.
	return result

func battle_attack(attacker: Dictionary, target: Dictionary) -> int:
	return Combat.battle_attack(self, attacker, target)

func _damage_unit(unit: Dictionary, amount: int, piercing: bool = false) -> void:
	Kernel.damage_units(self, [unit], amount, piercing, {"card": "", "controller": 0})

## Damage to a lane's standing structure after tower armor (none when
## piercing); a tower falls into an 80-health ancient with no overflow.
func _damage_structure(lane_index: int, defender: int, amount: int, piercing: bool = false) -> void:
	Kernel.tower_damage(self, lane_index, defender, amount, piercing)

## Test helper (an aligned Pulse): removes the dead of every lane and
## compacts `lane_index`.
func _clean_dead(lane_index: int, _cause_player: int = -1) -> void:
	_align(lane_index)
	Kernel.pulse(self)
	_compact(lane_index)
	_lookback = {}

func _enter_fountain(hero: Dictionary, ready_round: int) -> void:
	Zones.enter_fountain(self, hero, ready_round)

## Decides the match after a step. Idempotent: a decided match stays decided.
func _check_winner() -> void:
	if int(state.winner) != -1:
		return
	var winners: Array = []
	for player in range(2):
		var fallen_towers = 0
		var fallen_ancient = false
		for lane in state.lanes:
			var structure = lane.structures[1 - player]
			fallen_towers += int(structure.ancient)
			fallen_ancient = fallen_ancient or structure.destroyed
		if fallen_towers >= 2 or fallen_ancient:
			winners.append(player)
	if not winners.is_empty():
		state.winner = 2 if winners.size() == 2 else winners[0]
		state.phase = "finished"
		if state.winner == 2:
			_event("draw")
		else:
			_event("win", {"p": state.winner})

func _begin_deployment() -> void:
	Zones.sync(self)
	# Round effects end, locks and cooldowns tick, the round log clears.
	Kernel.end_of_round(self)
	state.round += 1
	state.lane = 0
	state.phase = "deployment"
	for owner in state.players:
		owner.finished = false
		owner.plans.clear()
	# Each lane's maximum mana grows by one, then mana refills (CF-5).
	for lane_index in range(3):
		var lane = state.lanes[lane_index]
		for player in range(2):
			Stats.add_mana_base(self, lane_index, player, 1)
			lane.mana[player] = lane.max_mana[player]
	for lane in state.lanes:
		for player in range(2):
			for unit in lane.units[player]:
				if unit != null:
					# A round-long redirect ends; its arrow is rerolled at reveal.
					if int(unit.combat_target) != -1:
						unit.arrow = 0
					unit.combat_target = -1
	# Lane creeps are assigned and revealed to both players before heroes are
	# chosen; they enter play together with the heroes at reveal.
	state.pending_creeps = [[], []]
	for player in range(2):
		for creep in range(2):
			state.pending_creeps[player].append(Kernel.rand_index(self, 3))
	# Kanna (RQ-22): with a creep_lane hero in a lane or ready to deploy, the
	# player's lane creeps are published as -1 ("her lane") after the random
	# draws, so randomness is unchanged and her private plan never leaks.
	for player in range(2):
		if not Stats.creep_lane_heroes(self, player).is_empty():
			for index in range(state.pending_creeps[player].size()):
				state.pending_creeps[player][index] = -1
	_event("deployment", {"round": state.round, "creeps": state.pending_creeps.duplicate(true)})

func _reveal_deployment() -> void:
	Zones.sync(self)
	var placements: Array = []
	var pending = state.get("pending_creeps", [[], []])
	for player in range(2):
		var owner = state.players[player]
		# Both choices are confirmed: draw first, then place units (CF-9).
		_draw(player, 2 + int(Stats.rules_of(self, player).round_draw))
		for hero in owner.roster:
			if owner.plans.has(str(hero.uid)):
				hero.health = max_health_of(hero)
				hero["hp_seen"] = int(hero.health)
				placements.append([hero, int(owner.plans[str(hero.uid)])])
		# A -1 lane creep goes to Kanna's planned (or current) lane (RQ-22).
		var creep_lane = _creep_lane_of(player) if pending[player].any(func(value): return int(value) < 0) else -1
		owner.plans.clear()
		owner.finished = false
		for lane_index in pending[player]:
			placements.append([_make_creep(player), int(lane_index) if int(lane_index) >= 0 else maxi(0, creep_lane)])
	state.pending_creeps = [[], []]
	# _place_all shuffles `placements` in place: read back the placement
	# order (and each unit's final combat position) for the reveal animation.
	_place_all(placements)
	_deployment_hooks(placements)
	var placed: Array = []
	for entry in placements:
		var unit: Dictionary = entry[0]
		if int(unit.lane) < 0:
			continue
		placed.append({"uid": int(unit.uid), "p": int(unit.owner), "card": str(unit.card),
			"hero": bool(unit.hero), "lane": int(unit.lane), "slot": _slot_of(unit)})
	_roll_arrows()
	state.phase = "action"
	state.active_player = state.initiative
	state.first_pass = -1
	_event("deployment_placed", {"units": placed})
	_event("deployment_revealed")
	Kernel.lane_open(self, 0)

## The lane `player`'s lane creeps follow (Kanna, RQ-22): the planned lane of
## the first creep_lane hero, else its current lane; -1 when there is none.
func _creep_lane_of(player: int) -> int:
	var plans: Dictionary = state.players[player].get("plans", {})
	for hero in Stats.creep_lane_heroes(self, player):
		if plans.has(str(hero.uid)):
			return int(plans[str(hero.uid)])
		if int(hero.lane) >= 0:
			return int(hero.lane)
	return -1

func _make_unit(definition: Dictionary, player: int, is_hero: bool) -> Dictionary:
	# Units carry ids and numbers only; display text is looked up by "card".
	var keywords: Dictionary = library.rules(str(definition.get("id", ""))).get("keywords", {}).duplicate()
	if not keywords.has("bounty"):
		keywords["bounty"] = 5 if is_hero else 1
	var health = int(definition.health)
	var result = {"uid": next_id, "card": definition.id,
		"owner": player, "hero": is_hero, "color": definition.get("color", "neutral"),
		"attack": int(definition.attack), "armor": int(definition.get("armor", 0)),
		"max_health": health, "health": health, "items": {}, "lane": -1,
		"ready_round": 1, "arrow": 0, "combat_target": -1, "cooldown": 0,
		"kw": keywords, "mods": [], "item_state": {}, "charges": 0, "used": {}, "condemned": false,
		"hp_seen": health, "roster": is_hero, "silenced": false, "stunned": false, "disarmed": false}
	next_id += 1
	return result

## Random placement used by Summon, lane creeps and deployed heroes: a random
## combat position whose own slot is empty, otherwise a new position at a
## random end of the lane.
func _spawn(unit: Dictionary, lane_index: int) -> void:
	Zones.spawn(self, unit, lane_index)

## Puts `unit` into combat position `position` (see creep_positions for the
## encoding). New positions are added to both sides so rows stay aligned;
## arrows are relative offsets, so inserting at the left end shifts every
## unit equally and no attacker changes target.
func _place(unit: Dictionary, lane_index: int, position: int) -> void:
	Zones.place(self, unit, lane_index, position)

## Places [unit, lane] pairs from both players in one shuffled order, so the
## result does not depend on which player is processed first.
func _place_all(placements: Array) -> void:
	Zones.place_all(self, placements)

## Removes a unit that leaves play without dying (e.g. Town Portal).
func _remove_from_lane(unit: Dictionary) -> void:
	Zones.remove_from_lane(self, unit)

## Removing a unit's current target from play resets that attacker's pathing
## to straight forward (including a Battlefield Control choice of that unit).
func _release_attackers(lane_index: int, unit: Dictionary, slot: int) -> void:
	Zones.release_attackers(self, lane_index, unit, slot)

## Pads the shorter row with empty slots. Engine operations keep rows aligned;
## this only repairs hand-built fixture boards before they are mutated.
func _align(lane_index: int) -> void:
	Zones.align(self, lane_index)

## Removes every combat position that is empty on both sides.
func _compact(lane_index: int) -> void:
	Zones.compact(self, lane_index)

func _slot_of(unit: Dictionary) -> int:
	return Zones.slot_of(self, unit)

func _make_creep(player: int) -> Dictionary:
	return _make_unit(_definition_or_creep("melee_creep"), player, false)

## A card definition by id; the training pack has no Melee Creep entry, so a
## plain 2/0/4 creep stands in for it.
func _definition_or_creep(card_id: String) -> Dictionary:
	var definition = library.definition(card_id)
	if definition.is_empty() and card_id == "melee_creep":
		definition = {"id": "melee_creep", "attack": 2, "health": 4, "color": "neutral"}
	return definition

func _spawn_creep(player: int, lane_index: int) -> void:
	_spawn(_make_creep(player), lane_index)

## End of deployment (and match start): every unit gets a fresh pathing roll.
func _roll_arrows() -> void:
	Zones.roll_arrows(self)

## Pathing: blocked units attack forward. Otherwise 50% forward, 25% left,
## 25% right; a rolled diagonal with no unit there means forward.
func _roll_arrow(unit: Dictionary) -> void:
	Zones.roll_arrow(self, unit)

func _draw(player: int, count: int) -> void:
	Zones.draw(self, player, count)

func _shuffle(values: Array) -> void:
	Kernel.shuffle(self, values)

func find_unit(uid: int) -> Dictionary:
	for lane in state.lanes:
		for row in lane.units:
			for unit in row:
				if unit != null and unit.uid == uid:
					return unit
	return {}

# --- Derived stats and read-only helpers (pure: spec D3) ------------------------------

func attack_of(unit: Dictionary) -> int:
	return Stats.attack_of(self, unit)

func armor_of(unit: Dictionary) -> int:
	return Stats.armor_of(self, unit)

func _max_health(unit: Dictionary) -> int:
	return Stats.max_health(self, unit)

## Public read-only helpers for display code (board preview, arrows).
func slot_of(unit: Dictionary) -> int:
	return _slot_of(unit)

func max_health_of(unit: Dictionary) -> int:
	return _max_health(unit)

## Derived keyword value: siege, cleave, retaliate, regeneration, bounty,
## bonus_hero, bonus_tower (flags and statuses read 1 or 0).
func keyword_of(unit: Dictionary, keyword: String) -> int:
	return Stats.keyword(self, unit, keyword)

## A derived flag or status: pierce, lethal, damage_immunity, death_shield,
## stun, silence, disarm, rapid_deployment, soulbound.
func has_flag(unit: Dictionary, flag: String) -> bool:
	return Stats.flag(self, unit, flag)

## Hero, not silenced and not stunned: its colour counts for casting.
func can_cast_colour(unit: Dictionary) -> bool:
	return Stats.can_cast_colour(self, unit)

## Status, flag and keyword badges of a unit for the board and inspect:
## [{"k", "v", "until", "src"}], statuses first, then flags, then numbers.
func badges(unit: Dictionary) -> Array:
	var out: Array = []
	for status in ["stun", "silence", "disarm", "death_shield"]:
		for entry in unit.get("mods", []):
			if str(entry.get("k", "")) == "give" and int(entry.get("kw", {}).get(status, 0)) > 0:
				out.append({"k": status, "v": 1, "until": str(entry.get("d", "")), "src": str(entry.get("src", ""))})
				break
	var derived = Stats.derive(self, unit)
	for flag in ["damage_immunity", "pierce", "lethal", "lethal_heroes", "lethal_creeps", "rapid_deployment", "soulbound"]:
		if int(derived.kw.get(flag, 0)) > 0:
			out.append({"k": flag, "v": 1, "until": "", "src": ""})
	for keyword in ["siege", "cleave", "retaliate", "regeneration"]:
		if int(derived.kw.get(keyword, 0)) > 0:
			out.append({"k": keyword, "v": int(derived.kw[keyword]), "until": "", "src": ""})
	var base_bounty = 5 if bool(unit.get("hero", false)) else 1
	if int(derived.kw.get("bounty", base_bounty)) != base_bounty:
		out.append({"k": "bounty", "v": int(derived.kw.bounty), "until": "", "src": ""})
	return out

## Derived tower values: {armor, retaliate, regeneration, mana_mod}.
func tower_stats(lane_index: int, player: int) -> Dictionary:
	var derived = Stats.tower(self, lane_index, player)
	return {"armor": int(derived.armor), "retaliate": int(derived.retaliate),
		"regeneration": int(derived.regeneration), "mana_mod": int(derived.mana)}

## A unit, item instance, improvement or deed by id:
## {"kind": "unit"|"item"|"improvement"|"deed", "object", "card"[, "host", "slot"]}.
func find_object(id: int) -> Dictionary:
	if id < OID_START:
		var unit = find_unit(id)
		if unit.is_empty():
			unit = Select.resolve_unit(self, id)
		return {} if unit.is_empty() else {"kind": "unit", "object": unit, "card": str(unit.card)}
	for unit in Stats.all_units(self):
		for slot in unit.get("item_state", {}):
			if int(unit.item_state[slot].get("oid", -1)) == id:
				return {"kind": "item", "object": unit.item_state[slot], "host": unit, "slot": str(slot),
					"card": str(unit.items.get(slot, ""))}
	for lane in state.lanes:
		for row in lane.get("improvements", [[], []]):
			for improvement in row:
				if int(improvement.oid) == id:
					return {"kind": "improvement", "object": improvement, "card": str(improvement.card)}
	for owner in state.players:
		for deed in owner.get("deeds", []):
			if int(deed.oid) == id:
				return {"kind": "deed", "object": deed, "card": str(deed.card)}
	return {}

## Improvement objects of `player` in a lane, in play order.
func improvements(lane_index: int, player: int) -> Array:
	return state.lanes[lane_index].get("improvements", [[], []])[player]

## The active abilities of a unit (and its items), an item or an
## improvement: [{"source", "ability", "card", "cooldown", "cd", "ready", "steps"}].
func abilities_of(id: int) -> Array:
	var out: Array = []
	var found = find_object(id)
	if found.is_empty():
		return out
	var player = int(found.get("host", found.object).get("owner", 0))
	var ready: Array = Targeting.ability_actions(self, player, -1) if str(state.get("phase", "")) == "action" \
		and int(state.get("active_player", -1)) == player else []
	var sources: Array = [[id, str(found.card), found.object]]
	if str(found.kind) == "unit":
		for slot in ["weapon", "armor", "accessory"]:
			if found.object.get("items", {}).has(slot):
				var instance: Dictionary = found.object.get("item_state", {}).get(slot, {})
				sources.append([int(instance.get("oid", 0)), str(found.object.items[slot]), instance])
	for source in sources:
		var rules: Dictionary = library.rules(str(source[1]))
		if int(rules.get("active", -1)) < 0:
			continue
		var ability: Dictionary = rules.abilities[int(rules.active)]
		var current = int(source[2].get("cooldown", source[2].get("cd", 0)))
		out.append({"source": int(source[0]), "ability": str(ability.id), "card": str(source[1]),
			"cooldown": int(ability.cooldown), "cd": current,
			"ready": ready.any(func(action): return int(action.unit) == int(source[0])),
			"steps": choice_steps({"unit": int(source[0])})})
	return out

## The choice steps of a hand card ({"hand": i}) or an ability source
## ({"unit": id}) for the UI's target stepper.
func choice_steps(source: Dictionary) -> Array:
	return Targeting.steps(self, source)

## The folded rules layer of a player (round_draw, forbid_play,
## secret_shop_discount, creep_lane).
func rules_of(player: int) -> Dictionary:
	return Stats.rules_of(self, player)

## A shop price after the rules layer (a Deed can make it negative).
func price_of(player: int, source: String, card_id: String) -> int:
	return Kernel.price_of(self, player, source, card_id)

## Public per-card hand data: [{"lock": n}] (locks show on card backs).
func hand_public(player: int) -> Array:
	var out: Array = []
	var owner: Dictionary = state.players[player]
	var states: Array = owner.get("hand_state", [])
	for index in range(owner.hand.size()):
		var entry = states[index] if index < states.size() and states[index] is Dictionary else {}
		out.append({"lock": int(entry.get("lock", 0))})
	return out

## Events are structured dictionaries ({"k": key, ...}); scripts/core/event_text.gd
## turns them into display text. event_seq counts every event ever emitted so
## views can tell which entries are new even after the window rolls.
## `private` maps a player index (string) to fields only that player sees;
## player_view merges them for that viewer and strips them for the other.
func _event(key: String, data: Dictionary = {}, private: Dictionary = {}) -> void:
	var entry = {"k": key}
	entry.merge(data)
	if not private.is_empty():
		entry["_s"] = private
	state.events.append(entry)
	state.event_seq = int(state.get("event_seq", 0)) + 1
	if state.events.size() > EVENT_WINDOW:
		state.events.pop_front()

## Opens a read frame: derived stats are cached until the matching
## frame_end(). Only for pure reads (no command may run inside a frame).
func frame_begin() -> void:
	Stats.frame_begin(self)

func frame_end() -> void:
	Stats.frame_end(self)

func player_view(player: int, with_events: bool = true) -> Dictionary:
	# Hidden piles are never copied: they are set aside during the deep copy
	# (and so is the event history when it is not wanted), then restored.
	# Only keys that exist are blanked and restored, so the call never adds
	# a key to a hand-built state (D3).
	var events: Array = state.get("events", [])
	var piles: Array = []
	for owner in state.players:
		var saved: Dictionary = {}
		for key in HIDDEN_PILES:
			if owner.has(key):
				saved[key] = owner[key]
				owner[key] = []
		piles.append(saved)
	if not with_events:
		state.events = []
	var result = state.duplicate(true)
	if not with_events:
		state.events = events
	for index in range(2):
		var original = state.players[index]
		for key in piles[index]:
			original[key] = piles[index][key]
		var owner = result.players[index]
		owner["hand_count"] = owner.hand.size()
		owner["deck_count"] = original.get("deck", []).size()
		owner["hand_public"] = hand_public(index)
		owner["item_deck_count"] = original.get("item_deck", []).size()
		if index != player:
			owner.hand = []
			owner["hand_state"] = []
			owner.plans = {}
			owner.shop = {}
			owner.held_secret = ""
			owner.bought = []
	# Private event fields reach only their viewer (spec §10.4).
	for event in result.events:
		if event.has("_s"):
			var mine = event._s.get(str(player), {})
			event.erase("_s")
			if mine is Dictionary:
				event.merge(mine)
	return result

func simulation_from_view(player: int):
	# The bot receives only the same observation a player sees. Its simulation
	# has synthetic randomness, never the live engine's future random state.
	var simulation = get_script().new()
	simulation.library = library
	# A simulation needs no event history (the bot never reads it).
	simulation.state = player_view(player, false)
	simulation.rng.seed = 1
	simulation.next_id = next_id
	simulation.deck_ids = deck_ids.duplicate()
	return simulation

func replay_data() -> Dictionary:
	return {"protocol": PROTOCOL_VERSION, "rules": RulesVersion.RULES_VERSION, "content_pack": library.content_pack,
		"seed": match_seed, "decks": deck_ids.duplicate(), "actions": journal.duplicate(true)}

func load_replay(data: Dictionary) -> Dictionary:
	if data.get("protocol") != PROTOCOL_VERSION or not Library.known_pack(str(data.get("content_pack", ""))):
		return _fail("replay_version", "Replay version or card pack does not match.")
	if str(data.get("rules", "")) != RulesVersion.RULES_VERSION:
		return _fail("replay_rules", "Replay was recorded with other card rules.",
			{"replay": str(data.get("rules", "")), "engine": RulesVersion.RULES_VERSION})
	if not data.get("seed") is float and not data.get("seed") is int:
		return _fail("replay_seed", "Replay has no valid seed.")
	if not data.get("actions") is Array or data.actions.size() > 20000:
		return _fail("replay_actions", "Invalid replay actions.")
	if not data.get("decks") is Array:
		return _fail("replay_decks", "Replay has no valid deck selection.")
	# An engine already holding the replay's pack keeps it (a test pack may
	# carry generated presets); otherwise the pack is opened by id.
	if str(library.content_pack) != str(data.content_pack):
		library = Library.open(str(data.content_pack))
	var initial = start(int(data.seed), data.get("decks", ["starter", "starter"]))
	if not initial.ok:
		return initial
	for entry in data.actions:
		if not entry is Dictionary or not entry.get("command") is Dictionary:
			return _fail("replay_entry", "Invalid replay entry.")
		var result = apply_action(int(entry.get("player", -1)), entry.command)
		if not result.ok:
			return _fail("replay_illegal", "Replay contains an illegal action at revision %d." % state.revision,
				{"revision": int(state.revision)})
	return {"ok": true}

## Failed command or load result. `code` and `args` are stable for UI
## translation (i18n key ERR_<CODE>); `error` is an English fallback only.
static func _fail(code: String, message: String, args: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "args": args, "error": message}

func state_digest() -> String:
	return (JSON.stringify(state) + str(rng.state) + str(next_id)).sha256_text()
