extends RefCounted
## Choice specs to legal commands (EFFECT_SYSTEM_SPEC.md §7). Static functions
## over the engine `e`; no instance members. Every function here is pure: it
## reads state and never touches the random stream (D3, K6).

const Select = preload("res://scripts/core/rules/select.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const VM = preload("res://scripts/core/rules/vm.gd")

## Action-phase commands of `player` after pass, in the documented order:
## unit abilities, item abilities, improvement abilities, then hand cards.
static func actions(e, player: int) -> Array:
	var out = ability_actions(e, player, -1)
	var hand: Array = e.state.players[player].hand
	for index in range(hand.size()):
		out.append_array(hand_actions(e, player, index))
	return out

## The base context of a card played from hand by `player`.
static func hand_ctx(e, player: int, card_id: String, index: int) -> Dictionary:
	var states: Array = e.state.players[player].get("hand_state", [])
	var entry = states[index] if index >= 0 and index < states.size() and states[index] is Dictionary else {}
	return {"src": null, "host": null, "controller": player, "lane": int(e.state.lane), "card": card_id,
		"choices": {}, "vars": {}, "played": {"card": card_id, "state": entry}}

## Every legal play of hand card `index` (gates of spec §7.2).
static func hand_actions(e, player: int, index: int) -> Array:
	var owner: Dictionary = e.state.players[player]
	if index < 0 or index >= owner.hand.size():
		return []
	var card_id = str(owner.hand[index])
	var card: Dictionary = e.library.get_card(card_id)
	if card.is_empty() or not e.library.playable(card_id):
		return []
	var states: Array = owner.get("hand_state", [])
	if index < states.size() and states[index] is Dictionary and int(states[index].get("lock", 0)) > 0:
		return []
	var lane: Dictionary = e.state.lanes[int(e.state.lane)]
	if int(card.get("cost", 0)) > int(lane.mana[player]):
		return []
	var color = str(card.get("color", ""))
	if color != "item" and not colour_available(e, player, color):
		return []
	if forbidden(e, player, card):
		return []
	var rules: Dictionary = e.library.rules(card_id)
	var play: Dictionary = rules.get("play", {})
	var ctx = hand_ctx(e, player, card_id, index)
	if play.get("requires") != null and not VM.cond(e, play.requires, ctx):
		return []
	var out: Array = []
	for combo in combos(e, play.get("choices", []), ctx):
		var command = {"type": "play", "hand": index}
		command.merge(combo)
		out.append(command)
	return out

## An allied hero of `color` in the active lane whose colour counts (silence
## and stun both block it).
static func colour_available(e, player: int, color: String) -> bool:
	for unit in e.state.lanes[int(e.state.lane)].units[player]:
		if unit != null and str(unit.get("color", "")) == color and Stats.can_cast_colour(e, unit):
			return true
	return false

## The rules layer forbids this card kind while the active lane is the
## restricting source's lane (The Oath).
static func forbidden(e, player: int, card: Dictionary) -> bool:
	for entry in Stats.rules_of(e, player).forbid_play:
		if str(card.get("kind", "")) in entry.kinds and int(entry.lane) == int(e.state.lane):
			return true
	return false

## Ability commands of `player` in the active lane, optionally for one source
## id only: units by row slot, then their items, then improvements by order.
static func ability_actions(e, player: int, only: int) -> Array:
	var out: Array = []
	var lane_index = int(e.state.lane)
	var row: Array = e.state.lanes[lane_index].units[player]
	for unit in row:
		if unit == null or (only >= 0 and int(unit.uid) != only):
			continue
		var rules: Dictionary = e.library.rules(str(unit.card))
		if int(rules.get("active", -1)) < 0 or not e.library.playable(str(unit.card)):
			continue
		if int(unit.get("cooldown", 0)) != 0 or Stats.flag(e, unit, "silence"):
			continue
		var ability: Dictionary = rules.abilities[int(rules.active)]
		out.append_array(_ability_commands(e, int(unit.uid), ability, Stats.unit_ctx(e, unit)))
	for unit in row:
		if unit == null or Stats.flag(e, unit, "silence"):
			continue
		for slot in ["weapon", "armor", "accessory"]:
			if not unit.get("items", {}).has(slot):
				continue
			var instance: Dictionary = unit.get("item_state", {}).get(slot, {})
			if only >= 0 and int(instance.get("oid", -1)) != only:
				continue
			var rules: Dictionary = e.library.rules(str(unit.items[slot]))
			if int(rules.get("active", -1)) < 0 or int(instance.get("cd", 0)) != 0:
				continue
			var ability: Dictionary = rules.abilities[int(rules.active)]
			out.append_array(_ability_commands(e, int(instance.get("oid", 0)), ability, Stats.item_ctx(e, unit, slot)))
	for improvement in e.state.lanes[lane_index].get("improvements", [[], []])[player]:
		if only >= 0 and int(improvement.oid) != only:
			continue
		var rules: Dictionary = e.library.rules(str(improvement.card))
		if int(rules.get("active", -1)) < 0 or int(improvement.get("cd", 0)) != 0:
			continue
		var ability: Dictionary = rules.abilities[int(rules.active)]
		out.append_array(_ability_commands(e, int(improvement.oid), ability, Stats.object_ctx(e, improvement)))
	return out

static func _ability_commands(e, id: int, ability: Dictionary, ctx: Dictionary) -> Array:
	if ability.get("requires") != null and not VM.cond(e, ability.requires, ctx):
		return []
	var out: Array = []
	for combo in combos(e, ability.get("choices", []), ctx):
		var command = {"type": "ability", "unit": id}
		command.merge(combo)
		out.append(command)
	return out

## Choice combinations depth-first in spec order; candidates in canonical
## order with earlier picks bound as $c.<key> (spec §7.3).
static func combos(e, spec: Array, ctx: Dictionary, index: int = 0, acc: Dictionary = {}) -> Array:
	if index == spec.size():
		return [acc.duplicate()]
	var out: Array = []
	var choice: Dictionary = spec[index]
	for value in choice_values(e, choice, ctx, acc):
		acc[choice.key] = value
		out.append_array(combos(e, spec, ctx, index + 1, acc))
	acc.erase(choice.key)
	return out

## Command values of one choice: unit uids, improvement oids, lane indexes,
## position encodings, or combat targets (0 = the tower first).
static func choice_values(e, choice: Dictionary, ctx: Dictionary, acc: Dictionary) -> Array:
	var inner = ctx.duplicate()
	inner["choices"] = acc.duplicate()
	var values: Array = []
	if choice.has("combat_target_of"):
		var unit = Select.one(e, choice.combat_target_of, inner)
		if unit != null and Select.kind_of(unit) == "unit":
			values = e.combat_targets(unit)
	else:
		var candidates = Select.resolve_set(e, choice.get("from"), inner)
		if choice.has("after"):
			var pivot = VM.ref(e, str(choice.after), inner)
			if pivot is Array:
				pivot = pivot[0] if pivot.size() == 1 else null
			if pivot != null:
				var pivot_order = Select.order(e, pivot)
				candidates = candidates.filter(func(item): return Select.before(pivot_order, Select.order(e, item)))
		for item in candidates:
			match Select.kind_of(item):
				"unit":
					values.append(int(item.uid))
				"improvement":
					values.append(int(item.oid))
				"int":
					values.append(int(item))
	return values

## True exactly when `command` is in legal_actions(player), building only the
## referenced source's actions (spec §7.5).
static func is_legal(e, player: int, command: Dictionary) -> bool:
	match str(command.get("type", "")):
		"play":
			if not _action_turn(e, player) or not command.get("hand") is int:
				return false
			return command in hand_actions(e, player, int(command.hand))
		"ability":
			if not _action_turn(e, player) or not command.get("unit") is int:
				return false
			return command in ability_actions(e, player, int(command.unit))
	return command in e.legal_actions(player)

static func _action_turn(e, player: int) -> bool:
	return player >= 0 and player <= 1 and not e.state.is_empty() and int(e.state.winner) == -1 \
		and str(e.state.phase) == "action" and int(e.state.active_player) == player

## The UI steps of a hand card ({"hand": i}) or an ability source ({"unit":
## id}): [{"key", "type"[, "lane_key" | "lane"]}] in command order.
static func steps(e, source: Dictionary) -> Array:
	var spec: Array = []
	if source.has("hand"):
		var viewer = int(e.state.get("active_player", 0))
		var hand: Array = e.state.players[viewer].get("hand", [])
		var index = int(source.hand)
		if index >= 0 and index < hand.size():
			spec = e.library.rules(str(hand[index])).get("play", {}).get("choices", [])
	elif source.has("unit"):
		var card_id = _source_card(e, int(source.unit))
		var rules: Dictionary = e.library.rules(card_id)
		if int(rules.get("active", -1)) >= 0:
			spec = rules.abilities[int(rules.active)].get("choices", [])
	var out: Array = []
	for choice in spec:
		var step = {"key": str(choice.key), "type": str(choice.get("type", "unit"))}
		if step.type == "position":
			var lane = choice.get("from", {}).get("lane") if choice.get("from") is Dictionary else null
			if lane is String and str(lane).begins_with("$c."):
				step["lane_key"] = str(lane).substr(3)
			elif lane is int:
				step["lane"] = int(lane)
			else:
				step["lane"] = int(e.state.get("lane", 0))
		out.append(step)
	return out

## The card id of an ability source: a unit uid, an item oid or an improvement oid.
static func _source_card(e, id: int) -> String:
	if id < 1000000:
		var unit = Select.resolve_unit(e, id)
		return str(unit.get("card", ""))
	for unit in Stats.all_units(e):
		for slot in unit.get("item_state", {}):
			if int(unit.item_state[slot].get("oid", -1)) == id:
				return str(unit.items.get(slot, ""))
	for lane in e.state.lanes:
		for row in lane.get("improvements", [[], []]):
			for improvement in row:
				if int(improvement.oid) == id:
					return str(improvement.card)
	return ""
