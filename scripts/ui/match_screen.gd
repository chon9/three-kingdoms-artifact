extends Control
## The match: board, hand, HUD, coin, overlays and the play-input state
## machine. Controller states are applied through the AnimationQueue: new
## structured events are animated (card casts, combat lunges and damage,
## deaths, tower hits, lane slides, shop and deployment transitions) before
## the views settle and input is accepted again.
##
## Playing a card: drag it out of the hand. Untargeted cards drop anywhere on
## the board; targeted cards draw a target arrow and drop on a highlighted
## unit; creeps drop into a highlighted combat position; Battlefield Control
## picks a unit, then that unit's new combat target. A plain click on a card
## holds it the same way (click the target next). Right-click or Esc cancels.

signal menu_requested
signal game_over_action(action: String)
## The deployment reveal starts settling lane `lane` (capture timing, tests).
signal reveal_lane_started(lane: int)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const BoardView = preload("res://scripts/ui/board_view.gd")
const HandView = preload("res://scripts/ui/hand_view.gd")
const LaneHud = preload("res://scripts/ui/lane_hud.gd")
const PlayerPanel = preload("res://scripts/ui/player_panel.gd")
const InitiativeCoin = preload("res://scripts/ui/initiative_coin.gd")
const CardPile = preload("res://scripts/ui/card_pile.gd")
const TargetArrow = preload("res://scripts/ui/target_arrow.gd")
const FxLayer = preload("res://scripts/ui/fx_layer.gd")
const ShopOverlay = preload("res://scripts/ui/shop_overlay.gd")
const DeploymentOverlay = preload("res://scripts/ui/deployment_overlay.gd")
const InspectOverlay = preload("res://scripts/ui/inspect_overlay.gd")
const GameOverOverlay = preload("res://scripts/ui/game_over_overlay.gd")
const ReconnectOverlay = preload("res://scripts/ui/reconnect_overlay.gd")
const PassDeviceScreen = preload("res://scripts/ui/pass_device_screen.gd")
const LogPanel = preload("res://scripts/ui/log_panel.gd")
const UnitCard = preload("res://scripts/ui/unit_card.gd")
const HAND_ZONE = 176.0
const DRAG_THRESHOLD = 10.0
const LONG_PRESS = 0.55
const EDGE = 74.0

var controller: Node
var queue: Node
var sfx: Node
var board: Control
var hand: Control
var hud: Control
var enemy_panel: Control
var own_panel: Control
var coin: Control
var own_deck: Control
var enemy_deck: Control
var enemy_hand: Control
var arrow: Control
var fx: Control
var shop: Control
var deployment: Control
var inspect: Control
var game_over: Control
var reconnect: Control
var pass_screen: Control
var log_panel: Control
var hint_label: Label

var shown_view: Dictionary = {}
var shown_viewer: int = -1
var shown_seq: int = 0
var actions: Array = []
## The card being played: index, plays, kind (untargeted, target, creep,
## redirect), mode (pending, drag, click), press point, source, candidate.
var hold: Dictionary = {}
var _mouse: Vector2 = Vector2.ZERO
var _hint_time: float = 0.0
var _edge_time: float = 0.0
## Edge lane switching re-arms only after the pointer leaves the edge.
var _edge_armed: bool = true
var _press_time: float = 0.0
## Press-and-hold on a board unit inspects it: {"uid", "point", "time"}.
var _unit_press: Dictionary = {}
var _game_over_shown: bool = false
var _pending_origin: Vector2 = Vector2(-1, -1)
var _hand_origin: Vector2 = Vector2(-1, -1)
## True while something above the match (a modal dialog) owns the input.
var input_blocked: Callable = func() -> bool: return false
var _deploy_band: Vector2 = Vector2(126, 548)
var _shop_band: Vector2 = Vector2(126, 588)
var _view_band: Vector2 = Vector2(126, 588)
## Deployment reveal: playing, skip requested, its tweens, and whether the
## state being applied played one (the camera then moves on sooner).
var reveal_catcher: Control
var _revealing: bool = false
var _reveal_skip: bool = false
var _reveal_tweens: Array = []
var _revealed_this_state: bool = false
## The player skipped this state's reveal: the camera then hurries too.
var _reveal_skipped: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = UiKit.theme()
	queue = AnimationQueue.new()
	queue.name = "AnimationQueue"
	add_child(queue)
	board = _add(BoardView.new(), "Board")
	own_deck = _add(CardPile.new(), "OwnDeck")
	own_deck.mode = CardPile.DECK
	enemy_deck = _add(CardPile.new(), "EnemyDeck")
	enemy_deck.mode = CardPile.DECK
	enemy_hand = _add(CardPile.new(), "EnemyHand")
	enemy_hand.mode = CardPile.HAND
	hud = _add(LaneHud.new(), "LaneHud")
	enemy_panel = _add(PlayerPanel.new(), "EnemyPanel")
	enemy_panel.own = false
	enemy_panel.show_menu = true
	own_panel = _add(PlayerPanel.new(), "OwnPanel")
	deployment = _add(DeploymentOverlay.new(), "Deployment")
	deployment.board = board
	shop = _add(ShopOverlay.new(), "Shop")
	hand = _add(HandView.new(), "Hand")
	move_child(own_panel, -1)
	coin = _add(InitiativeCoin.new(), "Coin")
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 17)
	hint_label.add_theme_color_override("font_color", UiKit.PAPER)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("outline_size", 5)
	hint_label.add_theme_stylebox_override("normal", UiKit.box(Color(0.02, 0.02, 0.03, 0.72), Color(UiKit.GOLD_DARK, 0.6), 14, 1, 7.0))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	add_child(hint_label)
	arrow = _add(TargetArrow.new(), "TargetArrow")
	fx = _add(FxLayer.new(), "Fx")
	reveal_catcher = _add(RevealCatcher.new(), "RevealCatcher")
	reveal_catcher.skipped.connect(func(): _reveal_skip = true)
	log_panel = _add(LogPanel.new(), "Log")
	game_over = _add(GameOverOverlay.new(), "GameOver")
	reconnect = _add(ReconnectOverlay.new(), "Reconnect")
	inspect = _add(InspectOverlay.new(), "Inspect")
	pass_screen = _add(PassDeviceScreen.new(), "PassDevice")
	log_panel.names_source = func() -> Array:
		# Third-person names that read in every template ("Your army passes").
		if shown_viewer < 0 or controller == null or controller.mode == controller.MODE_LOCAL:
			return []
		var other = UiKit.t("PLAYER_AI") if controller.mode == controller.MODE_AI else UiKit.t("PLAYER_OPPONENT")
		var names = [UiKit.t("LOG_PLAYER_YOU"), other]
		return names if shown_viewer == 0 else [names[1], names[0]]
	game_over.text_source = func() -> Array:
		return [_towers_text(shown_view, shown_viewer), _matchup_text(shown_view, shown_viewer)]
	board.board_pressed.connect(_on_board_pressed)
	board.lane_selected.connect(func(_index): _refresh_controls())
	hand.card_pressed.connect(_on_hand_pressed)
	hud.lane_pressed.connect(func(index): view_lane(index))
	enemy_panel.menu_pressed.connect(func(): menu_requested.emit())
	coin.pressed.connect(press_coin)
	shop.buy_requested.connect(buy)
	shop.hold_requested.connect(hold_secret)
	deployment.deploy_requested.connect(deploy_hero)
	deployment.undeploy_requested.connect(undeploy_hero)
	deployment.inspect_requested.connect(inspect_card)
	game_over.action_requested.connect(_on_game_over_action)
	for source in shop.slots:
		shop.slots[source].card.gui_input.connect(_on_shop_card_input.bind(source))

func _add(node: Control, node_name: String) -> Control:
	node.name = node_name
	add_child(node)
	return node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and board != null:
		_layout()

func _layout() -> void:
	var full = Rect2(Vector2.ZERO, size)
	for node in [board, deployment, shop, hand, arrow, fx, reveal_catcher, game_over, reconnect, inspect, pass_screen]:
		node.position = full.position
		node.size = full.size
	hud.position = Vector2.ZERO
	enemy_panel.position = Vector2(size.x - enemy_panel.size.x, 0)
	own_panel.position = Vector2(size.x - own_panel.size.x, size.y - own_panel.size.y)
	# The coin's two-line hint ends a few pixels above the player panel.
	coin.position = Vector2(size.x - coin.size.x - 22, size.y - own_panel.size.y - InitiativeCoin.CAPTION_BOTTOM - 8.0)
	coin.queue_redraw()
	own_deck.size = Vector2(88, 125)
	own_deck.position = Vector2(30, size.y - 300)
	# Under the opponent's panel, clear of the overview lanes below it.
	enemy_deck.size = Vector2(50, 71)
	enemy_deck.position = Vector2(size.x - 84, 50)
	# The opponent's hand fits between the lane HUD and the opponent's panel.
	var gap_left = hud.size.x + 12.0
	var gap_right = enemy_panel.position.x - 12.0
	enemy_hand.size = Vector2(minf(560.0, gap_right - gap_left), 64)
	enemy_hand.position = Vector2(maxf(gap_left, (size.x - enemy_hand.size.x) * 0.5), 0)
	deployment.set_strip_center(enemy_hand.position.x + enemy_hand.size.x * 0.5)
	# The fan spreads from the left edge to just short of the player panel.
	hand.fan_left = 24.0
	hand.fan_right = own_panel.position.x - 12.0
	hand.layout(false)
	log_panel.size = Vector2(LogPanel.WIDTH, size.y - 150)
	log_panel.position = Vector2(size.x - LogPanel.WIDTH - 12, 56)
	_place_hint()
	# The overview stops above the deck pile and the coin (bottom corners).
	var bottom = minf(own_deck.position.y, coin.position.y) - 12.0
	_view_band = Vector2(126, bottom)
	_shop_band = Vector2(126, bottom)
	var band = _view_band
	match str(shown_view.get("phase", "")):
		"shop":
			band = _shop_band
		"deployment":
			band = _deploy_band
	board.overview_top = band.x
	board.overview_bottom = band.y
	board.apply_camera()

func _place_hint() -> void:
	# Centred on the river of the lane view, clear of both unit rows.
	hint_label.size = hint_label.get_minimum_size()
	hint_label.position = Vector2((size.x - hint_label.size.x) * 0.5, size.y * 0.456 - hint_label.size.y * 0.5)

func bind(match_controller: Node) -> void:
	controller = match_controller
	controller.state_changed.connect(_on_state_changed)
	controller.notice_changed.connect(func(text): show_hint(text, 4.0))
	controller.ui_busy = func() -> bool: return queue.busy or pass_screen.visible
	queue.idle.connect(_refresh_controls)
	reconnect.controller = controller
	reconnect.action_requested.connect(_on_reconnect_action)
	controller.online_paused.connect(func(paused): reconnect.set_waiting(paused))
	controller.connection_changed.connect(func(_info): _refresh_controls())

## Forgets the shown match so the next state is drawn from scratch.
func reset() -> void:
	queue.clear()
	_reveal_skip = true
	_cancel_hold()
	shown_view = {}
	shown_viewer = -1
	shown_seq = 0
	actions = []
	_game_over_shown = false
	game_over.visible = false
	reconnect.set_waiting(controller != null and controller.waiting_for_opponent)
	inspect.close()
	shop.close()
	deployment.close()
	fx.clear_cast()
	log_panel.toggle(false)

func refresh_text() -> void:
	hand.refresh_text()
	for lane in board.lanes:
		lane.queue_redraw()
		for uid in lane.cards:
			lane.cards[uid].refresh()
		for card in lane.staged_cards():
			card.refresh()
	shop.refresh_text()
	deployment.refresh_text()
	inspect.refresh_text()
	game_over.refresh_text()
	reconnect.refresh_text()
	pass_screen.refresh_text()
	log_panel.refresh_text()
	hint_label.visible = false
	if not shown_view.is_empty():
		# Strings built from the state (hand reasons, shop tooltips, the
		# opponent's spending at deployment) are rebuilt in the new language.
		var states = _card_states(shown_view, shown_viewer, actions)
		for index in range(mini(hand.cards.size(), states.size())):
			hand.cards[index].tooltip_text = states[index].get("reason", "")
		if not queue.busy:
			_ensure_phase_ui(shown_view, shown_viewer, actions)
	_refresh_controls()

# --- Applying states ---------------------------------------------------------

func _on_state_changed(view: Dictionary, new_actions: Array) -> void:
	var viewer = controller.viewer()
	queue.push(_apply_state.bind(view.duplicate(true), new_actions.duplicate(true), viewer))

func _apply_state(view: Dictionary, new_actions: Array, viewer: int) -> void:
	_cancel_hold()
	_revealed_this_state = false
	_reveal_skipped = false
	board.display_engine.library = controller.engine.library
	var seq = int(view.get("event_seq", 0))
	var events = _new_events(view, seq)
	if shown_view.is_empty() or seq < shown_seq or events.size() > 40:
		_hard_sync(view, new_actions, viewer)
		return
	if viewer != shown_viewer:
		# Hot-seat hand-over: hide everything until the next player confirms,
		# then replay the latest events from that player's side. Staged heroes
		# show the previous player's secret plans, so they go first.
		if deployment.visible:
			deployment.close()
		if controller.mode == controller.MODE_LOCAL:
			pass_screen.show_for(viewer)
			_refresh_controls()
			await pass_screen.confirmed
		shown_viewer = viewer
		_free_removed(board.sync(shown_view, viewer, []))
		hand.sync(view.players[viewer].get("hand", []), [], own_deck.origin(), false)
	var context = {"dead": {}, "combat_lanes": {}, "lane": int(shown_view.get("lane", 0))}
	for event in events:
		if str(event.get("k", "")) == "death":
			context.dead[int(event.get("uid", -1))] = true
	for event in events:
		match str(event.get("k", "")):
			"play":
				await _anim_play(event, viewer)
			"ability":
				await _anim_ability(event, viewer)
			"combat":
				context.combat_lanes[int(event.lane)] = true
				context.lane = int(event.lane)
				await _anim_combat(event, viewer)
			"pass":
				_anim_pass(event, viewer)
			"deployment_placed":
				# Before the sync below: the staged cards fly into place.
				await _anim_deployment_reveal(event, view, viewer)
	await _sync_all(view, new_actions, viewer, context, true)
	for event in events:
		match str(event.get("k", "")):
			"tower_fall", "ancient_fall":
				await _anim_structure_fall(event, viewer, int(context.lane))
			"lane_open":
				await _anim_lane_open(event)
			"shop_open":
				await _enter_shop(view, viewer, new_actions)
			"deployment":
				await _enter_deployment(view, viewer, new_actions)
			"deployment_revealed":
				await _exit_deployment(view)
			"win", "draw":
				await _show_game_over(view, viewer)
	_pending_origin = Vector2(-1, -1)
	_hand_origin = Vector2(-1, -1)
	_ensure_phase_ui(view, viewer, new_actions)
	_refresh_controls()

func _new_events(view: Dictionary, seq: int) -> Array:
	var count = seq - shown_seq
	var events: Array = view.get("events", [])
	if count <= 0:
		return []
	return events.slice(maxi(0, events.size() - count))

## Draws `view` without animation (new match, replay, perspective jump).
func _hard_sync(view: Dictionary, new_actions: Array, viewer: int) -> void:
	var first_viewer = shown_viewer
	shown_view = view
	shown_viewer = viewer
	shown_seq = int(view.get("event_seq", 0))
	actions = new_actions
	_free_removed(board.sync(view, viewer, new_actions))
	for lane in board.lanes:
		for uid in lane.cards:
			lane.cards[uid].modulate = Color.WHITE
	hand.sync(view.players[viewer].get("hand", []), _card_states(view, viewer, new_actions), own_deck.origin(), false)
	var phase = str(view.phase)
	if phase in ["shop", "deployment"]:
		_set_band(_shop_band if phase == "shop" else _deploy_band)
		board.set_overview(true, 0.0)
	else:
		board.set_overview(false, 0.0)
		board.slide_to(int(view.lane), 0.0)
	_ensure_phase_ui(view, viewer, new_actions)
	if int(view.get("winner", -1)) != -1 and not _game_over_shown:
		_game_over_shown = true
		_show_result(view, viewer)
	elif int(view.get("winner", -1)) == -1 and _game_over_shown:
		# An undecided state after a result (a new match) clears the result.
		_game_over_shown = false
		game_over.visible = false
	log_panel.set_events(view.get("events", []))
	_refresh_controls()
	if controller.mode == controller.MODE_LOCAL and viewer != first_viewer and int(view.get("winner", -1)) == -1:
		pass_screen.show_for(viewer)

func _free_removed(changes: Array) -> void:
	for change in changes:
		for card in change.removed:
			UiKit.discard(card)

## Syncs every view to `view`, animating unit arrivals, departures, moves,
## health changes and the hand.
func _sync_all(view: Dictionary, new_actions: Array, viewer: int, context: Dictionary, animate: bool) -> void:
	var old_health: Dictionary = {}
	for models in board.lane_models:
		for uid in models:
			if uid is int:
				old_health[uid] = int(models[uid].health)
	var old_towers: Array = []
	for lane_index in range(3):
		var lane = shown_view.lanes[lane_index]
		old_towers.append([lane.structures[1 - viewer].duplicate(), lane.structures[viewer].duplicate()])
	if str(view.phase) != "deployment" and deployment.visible:
		deployment.close()
	var changes = board.sync(view, viewer, new_actions)
	var animated = false
	var stagger = 0
	for lane_index in range(3):
		var change: Dictionary = changes[lane_index]
		var lane = board.lanes[lane_index]
		for card in change.added:
			_animate_enter(card, lane, stagger)
			stagger += 1
			animated = true
		for card in change.removed:
			_animate_exit(card, context.dead.has(card.uid))
			animated = true
		for card in change.moved:
			_animate_move(card, change.moved[card])
		if context.combat_lanes.has(lane_index):
			continue
		var models: Dictionary = board.lane_models[lane_index]
		for uid in models:
			if not uid is int or not old_health.has(uid):
				continue
			var delta = int(models[uid].health) - int(old_health[uid])
			var card = lane.cards.get(uid)
			if delta != 0 and card != null:
				fx.float_text(card.get_global_rect().get_center(), ("%+d" % delta), UiKit.DAMAGE if delta < 0 else UiKit.HEAL, 30)
				_flash(card)
				animated = true
		for side in range(2):
			var before: Dictionary = old_towers[lane_index][side]
			var after: Dictionary = view.lanes[lane_index].structures[viewer if side == 1 else 1 - viewer]
			var delta = int(after.health) - int(before.health)
			if delta < 0 and bool(after.ancient) == bool(before.ancient):
				var tower: Control = lane.towers[side]
				var beside = tower.get_global_rect()
				fx.float_text(Vector2(beside.end.x + 50.0 * tower.scale.x, beside.get_center().y), "%d" % delta, UiKit.DAMAGE, 52, 80)
				fx.shake(tower, 9.0)
				animated = true
	var origin = _hand_origin if _hand_origin.x >= 0.0 else own_deck.origin()
	var old_hand = hand.ids.size()
	hand.sync(view.players[viewer].get("hand", []), _card_states(view, viewer, new_actions), origin, animate)
	animated = animated or hand.ids.size() != old_hand
	shown_view = view
	shown_viewer = viewer
	shown_seq = int(view.get("event_seq", 0))
	actions = new_actions
	if str(view.phase) == "shop" and shop.visible:
		shop.sync(view.players[viewer], new_actions, view.players[viewer].get("finished", false))
	log_panel.set_events(view.get("events", []))
	_refresh_controls()
	if animated:
		await queue.wait(0.2 if _reveal_skipped else 0.5)

func _animate_enter(card: Control, lane: Control, order: int) -> void:
	if AnimationQueue.instant:
		return
	var rest = card.position
	var rest_scale = card.scale
	var origin = own_deck.origin() if card.own else enemy_hand.origin()
	if card.own and _pending_origin.x >= 0.0:
		origin = _pending_origin
	card.position = lane.get_global_transform().affine_inverse() * origin - UnitCard.SIZE * 0.5 * rest_scale
	card.scale = rest_scale * 0.55
	card.modulate.a = 0.0
	var tween = card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(AnimationQueue.duration(0.05 * order))
	tween.tween_property(card, "modulate:a", 1.0, AnimationQueue.duration(0.15))
	tween.parallel().tween_property(card, "position", rest, AnimationQueue.duration(0.42))
	tween.parallel().tween_property(card, "scale", rest_scale, AnimationQueue.duration(0.42))
	tween.tween_callback(func(): fx.burst(card.get_global_rect().get_center(), "cast", 0.5 * rest_scale.x))

func _animate_exit(card: Control, died: bool) -> void:
	if AnimationQueue.instant or not is_inside_tree():
		UiKit.discard(card)
		return
	var tween = card.create_tween()
	if died:
		var model = card.model.duplicate()
		model["dies"] = true
		card.apply(model)
		fx.burst(card.get_global_rect().get_center(), "death", card.scale.x)
		tween.tween_property(card, "modulate", Color(1.4, 0.5, 0.45, 1.0), AnimationQueue.duration(0.12))
		tween.tween_property(card, "rotation", deg_to_rad(randf_range(-8.0, 8.0)), AnimationQueue.duration(0.35))
		tween.parallel().tween_property(card, "modulate:a", 0.0, AnimationQueue.duration(0.5))
		tween.parallel().tween_property(card, "scale", card.scale * 0.82, AnimationQueue.duration(0.5))
	else:
		tween.tween_property(card, "position:y", card.position.y + (70.0 if card.own else -70.0), AnimationQueue.duration(0.35))
		tween.parallel().tween_property(card, "modulate:a", 0.0, AnimationQueue.duration(0.35))
	tween.tween_callback(card.queue_free)

func _animate_move(card: Control, from: Vector2) -> void:
	if AnimationQueue.instant:
		return
	var rest = card.position
	card.position = from
	card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(card, "position", rest, AnimationQueue.duration(0.3))

func _flash(card: Control) -> void:
	if AnimationQueue.instant:
		return
	card.create_tween().tween_method(func(value): card.flash = value; card.queue_redraw(), 1.0, 0.0, AnimationQueue.duration(0.35))

## Shop, deployment, hand and overview state that must match the phase.
func _ensure_phase_ui(view: Dictionary, viewer: int, new_actions: Array) -> void:
	var phase = str(view.phase)
	var player: Dictionary = view.players[viewer]
	if phase == "shop":
		if not shop.visible:
			shop.open(false)
		shop.sync(player, new_actions, player.get("finished", false))
	elif shop.visible:
		shop.close()
	if phase == "deployment":
		if not deployment.visible:
			deployment.open()
		deployment.enabled = not player.get("finished", false)
		deployment.sync(view, viewer, new_actions, _opponent_spent_text(view, viewer))
	elif deployment.visible:
		deployment.close()
	hand.set_lowered(phase in ["shop", "deployment"])

# --- Event animations ----------------------------------------------------------

func _anim_play(event: Dictionary, viewer: int) -> void:
	var card_id = str(event.get("card", ""))
	var own = int(event.get("p", 0)) == viewer
	var definition = Library.raw_definition(card_id)
	await _focus_lane(int(shown_view.get("lane", 0)))
	if sfx != null:
		sfx.play("switch-a")
	var from = _pending_origin if own and _pending_origin.x >= 0.0 else (hand.card_center(0) if own else enemy_hand.origin())
	if str(definition.get("kind", "")) == "creep":
		if not own:
			fx.show_cast(card_id, from, 0.45)
			await queue.wait(0.75)
		return
	fx.show_cast(card_id, from, 0.45 if own else 0.95)
	await queue.wait(0.35)
	if event.has("target"):
		var target: Control = board.unit_card(int(event.target))
		if target != null:
			var center = target.get_global_rect().get_center()
			arrow.show_arrow(fx.get_global_transform() * Vector2(size.x - 205, size.y * 0.42), center, true, UiKit.PLAYABLE)
			fx.burst(center, "cast", target.scale.x)
			_flash(target)
	await queue.wait(0.45 if own else 0.85)
	arrow.hide_arrow()

func _anim_ability(event: Dictionary, viewer: int) -> void:
	var card: Control = board.unit_card(int(event.get("uid", -1)))
	if card == null:
		return
	var center = card.get_global_rect().get_center()
	fx.burst(center, "cast", 1.2)
	var ability = Library.loc(str(event.get("card", "")), "ability_name")
	fx.float_text(center + Vector2(0, -40), ability, UiKit.PLAYABLE, 24, 50)
	_flash(card)
	await queue.wait(0.7)

func _anim_pass(event: Dictionary, viewer: int) -> void:
	var own = int(event.get("p", 0)) == viewer
	var panel_rect = enemy_panel.get_global_rect()
	var point = coin.get_global_transform() * coin.center() + Vector2(0, -70) if own else Vector2(panel_rect.get_center().x, panel_rect.end.y + 28.0)
	fx.float_text(point, UiKit.t("BTN_PASS"), UiKit.PAPER, 24, 40 if own else -30)
	if sfx != null:
		sfx.play("click-b")

func _anim_combat(event: Dictionary, viewer: int) -> void:
	var lane_index = int(event.get("lane", 0))
	await _focus_lane(lane_index)
	hud.combat_lane = lane_index
	hud.queue_redraw()
	_refresh_controls()
	fx.banner(UiKit.t("PHASE_COMBAT"), UiKit.GOLD_BRIGHT, 0.6, 46, _river_y())
	await queue.wait(0.55)
	var lane = board.lanes[lane_index]
	var models: Dictionary = board.lane_models[lane_index]
	for side in range(2):
		for column in range(lane.columns[side].size()):
			var uid = int(lane.columns[side][column])
			if uid == -1 or not lane.cards.has(uid) or not models.has(uid):
				continue
			var card: Control = lane.cards[uid]
			var model: Dictionary = models[uid]
			var target_point: Vector2
			if model.get("tower", false):
				target_point = lane.towers[0 if side == 1 else 1].emblem_center()
			else:
				var target_column = column + int(model.get("arrow", 0))
				var target_uid = int(lane.columns[1 - side][target_column]) if target_column >= 0 and target_column < lane.columns[1 - side].size() else -1
				target_point = lane.cards[target_uid].get_global_rect().get_center() if lane.cards.has(target_uid) else card.get_global_rect().get_center()
			_lunge(card, target_point)
	if sfx != null:
		sfx.play("click-a")
	await queue.wait(0.16)
	for uid in models:
		if not uid is int or not lane.cards.has(uid):
			continue
		var damage = int(models[uid].get("damage", 0))
		if damage > 0:
			var center = lane.cards[uid].get_global_rect().get_center()
			fx.float_text(center, "-%d" % damage, UiKit.DAMAGE, 34)
			fx.burst(center, "hit", lane.cards[uid].scale.x)
			_flash(lane.cards[uid])
	var dealt: Array = event.get("damage", [0, 0])
	for side in range(2):
		var amount = int(dealt[viewer]) if side == 0 else int(dealt[1 - viewer])
		if amount <= 0:
			continue
		var tower: Control = lane.towers[side]
		var beside = tower.get_global_rect()
		fx.float_text(Vector2(beside.end.x + 58.0 * tower.scale.x, beside.get_center().y), "-%d" % amount, UiKit.DAMAGE, 68, 70)
		fx.burst(tower.emblem_center(), "tower" if amount >= 6 else "hit", 1.2)
		fx.shake(tower, 12.0, 0.4)
	await queue.wait(0.8)
	hud.combat_lane = -1

func _lunge(card: Control, target_point: Vector2) -> void:
	if AnimationQueue.instant:
		return
	var rest = card.position
	var center = card.get_global_rect().get_center()
	var direction = (target_point - center)
	var reach = minf(54.0, direction.length() * 0.4) * card.scale.x
	var offset = direction.normalized() * reach if direction.length() > 1.0 else Vector2.ZERO
	var tween = card.create_tween()
	tween.tween_property(card, "position", rest + offset, AnimationQueue.duration(0.16)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "position", rest, AnimationQueue.duration(0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _anim_structure_fall(event: Dictionary, viewer: int, lane_index: int) -> void:
	var own = int(event.get("p", 0)) == viewer
	var tower: Control = board.tower(lane_index, own)
	fx.burst(tower.emblem_center(), "tower", 2.2)
	fx.shake(board, 14.0, 0.5)
	var key = "BANNER_TOWER_FALL" if str(event.k) == "tower_fall" else "BANNER_ANCIENT_FALL"
	fx.banner(UiKit.t(key), UiKit.DAMAGE if own else UiKit.GOLD_BRIGHT, 0.7, 52, _river_y())
	await queue.wait(1.0)

func _anim_lane_open(event: Dictionary) -> void:
	await queue.wait(0.25)
	var lane_index = int(event.get("lane", 0))
	var tween = board.slide_to(lane_index, AnimationQueue.duration(0.55))
	fx.banner(EventText.lane_name(lane_index), UiKit.GOLD_BRIGHT, 0.4, 46, _river_y())
	await queue.finish(tween)
	_refresh_controls()

func _enter_shop(view: Dictionary, viewer: int, new_actions: Array) -> void:
	hud.combat_lane = -1
	show_hint("")
	_set_band(_shop_band)
	await queue.finish(board.set_overview(true, AnimationQueue.duration(0.45)))
	shop.open(true)
	shop.sync(view.players[viewer], new_actions, view.players[viewer].get("finished", false))
	hand.set_lowered(true)
	if sfx != null:
		sfx.play("switch-b")
	await queue.wait(0.35)

func _enter_deployment(view: Dictionary, viewer: int, new_actions: Array) -> void:
	shop.close()
	show_hint("")
	_set_band(_deploy_band)
	if not board.overview:
		await queue.finish(board.set_overview(true, AnimationQueue.duration(0.4)))
	else:
		board.apply_camera()
	deployment.open()
	deployment.sync(view, viewer, new_actions, _opponent_spent_text(view, viewer))
	fx.banner(UiKit.t("PHASE_DEPLOYMENT_ROUND", {"n": int(view.get("round", 1))}), UiKit.GOLD_BRIGHT, 0.5, 56)
	await queue.wait(0.6)

## The reveal, once both players have confirmed. The enemy's heroes fly from
## the opponent strip into their lanes' staging fans; then, lane by lane,
## every unit placed this round gets its combat position: a highlight hops
## over the candidate slots and stops on the one the engine chose, and the
## staged card flies there. The rows settle, and pathing slabs show where
## each unblocked unit will attack before the arrows appear. A click, Space,
## Enter or Esc skips to the end. Runs before the board syncs to `view`.
func _anim_deployment_reveal(event: Dictionary, view: Dictionary, viewer: int) -> void:
	_revealing = true
	_reveal_skip = AnimationQueue.instant
	_reveal_tweens = []
	# Nothing may hide the reveal: a held card and an open zoom go first.
	_cancel_hold()
	inspect.close()
	reveal_catcher.visible = not _reveal_skip
	deployment.begin_reveal()
	# The coin goes dark: no one can act until the board settles (the queue
	# going idle mid-reveal keeps it dark too, see _refresh_controls).
	coin.set_state(false, false, UiKit.t("HUD_WAITING"), "")
	for lane in board.lanes:
		lane.preview_hidden = true
	# Online states arrive through JSON: every number may be a float.
	var units: Array = []
	for raw in event.get("units", []):
		units.append({"uid": int(raw.get("uid", -1)), "p": int(raw.get("p", 0)), "card": str(raw.get("card", "")),
			"hero": bool(raw.get("hero", false)), "lane": clampi(int(raw.get("lane", 0)), 0, 2), "slot": int(raw.get("slot", 0))})
	if not _reveal_skip:
		_ensure_reveal_staging(units, view, viewer)
		# Step 1: the opponent's lane choices.
		var enemy_heroes = units.filter(func(unit): return unit.hero and unit.p != viewer)
		for unit in enemy_heroes:
			var from = deployment.opponent_card_center(unit.uid)
			if from.x < 0.0:
				from = hud.chip_center(unit.uid)
			if from.x < 0.0:
				from = enemy_hand.origin()
			deployment.hide_opponent_card(unit.uid)
			board.lanes[unit.lane].stage_enemy_hero(unit.uid, board.staged_model(_reveal_unit(view, unit.uid), false), from,
				DeploymentOverlay.STRIP_SCALE)
			if sfx != null:
				sfx.play("switch-a")
			await _reveal_wait(0.08)
		await _reveal_wait(0.45)
		deployment.opponent_strip.visible = false
		# Step 2: lanes left to right.
		for lane_index in range(3):
			if _reveal_skip:
				break
			var entries = units.filter(func(unit): return unit.lane == lane_index)
			if not entries.is_empty():
				await _reveal_lane(lane_index, entries, view, viewer)
	if _reveal_skip:
		_reveal_skipped = not AnimationQueue.instant
		_finish_reveal_now(view, viewer)
	else:
		for lane in board.lanes:
			lane.reset_reveal()
	reveal_catcher.visible = false
	_revealing = false
	_revealed_this_state = true

## Waits `seconds` (scaled by the animation speed), ending early on skip.
func _reveal_wait(seconds: float) -> void:
	var elapsed = 0.0
	var duration = AnimationQueue.duration(seconds)
	while elapsed < duration and not _reveal_skip and is_inside_tree():
		await get_tree().process_frame
		elapsed += get_process_delta_time()

## A unit of `view` by uid, as it waits to enter (no lane, so its stats
## carry no lane auras).
func _reveal_unit(view: Dictionary, uid: int) -> Dictionary:
	for lane in view.lanes:
		for row in lane.units:
			for unit in row:
				if unit != null and int(unit.uid) == uid:
					var copy: Dictionary = unit.duplicate()
					copy.lane = -1
					return copy
	return {}

## The staging matches what the reveal places (it does unless the viewer
## changed in hot-seat play): creeps of both sides and your heroes.
func _ensure_reveal_staging(units: Array, view: Dictionary, viewer: int) -> void:
	for lane_index in range(3):
		var lane = board.lanes[lane_index]
		var sides: Array = [[], []]
		var creeps: Array = [[], []]
		for unit in units:
			if unit.lane != lane_index or (unit.hero and unit.p != viewer):
				continue
			var side = 1 if unit.p == viewer else 0
			var spec = {"card_id": unit.card, "uid": unit.uid if unit.hero else -1, "kind": "hero" if unit.hero else "creep",
				"movable": false, "selected": false, "hidden": false, "model": board.staged_model(_reveal_unit(view, unit.uid), side == 1)}
			if unit.hero:
				spec.key = "h%d" % unit.uid
				sides[side].append(spec)
			else:
				spec.key = "c%d_%d" % [side, creeps[side].size()]
				creeps[side].append(spec)
		var wanted: Array = []
		var current: Array = []
		for side in range(2):
			sides[side] = creeps[side] + sides[side]
			for spec in sides[side]:
				wanted.append(spec.key)
			for entry in lane.staged[side]:
				current.append(entry.key)
		wanted.sort()
		current.sort()
		if wanted != current:
			lane.set_staged(sides[0], sides[1])

## Settles one lane: final columns, the deciding highlight and a flight for
## each placed unit (in the engine's placement order), then the rows close
## the staging strip and the pathing slabs show where unblocked units attack.
func _reveal_lane(lane_index: int, entries: Array, view: Dictionary, viewer: int) -> void:
	reveal_lane_started.emit(lane_index)
	var lane = board.lanes[lane_index]
	var change: Dictionary = board.sync_lane(lane_index, view, viewer)
	var placed: Dictionary = {}
	for entry in entries:
		placed[entry.uid] = true
	for card in change.added:
		card.modulate.a = 0.0
		lane.flying[card.uid] = true
	for card in change.removed:
		UiKit.discard(card)
	for card in change.moved:
		var rest = card.position
		card.position = change.moved[card]
		_reveal_tweens.append(_tween_to(card, "position", rest, 0.3))
	var candidates: Array = [[], []]
	for side in range(2):
		for column in range(lane.columns[side].size()):
			var uid = int(lane.columns[side][column])
			if uid == -1 or placed.has(uid):
				candidates[side].append(column)
	lane.candidates = candidates
	_reveal_tweens.append(_tween_to(lane, "candidate_alpha", 1.0, 0.15))
	await _reveal_wait(0.15)
	var claimed: Array = [{}, {}]
	for entry in entries:
		if _reveal_skip:
			return
		var side = 1 if entry.p == viewer else 0
		var column = lane.columns[side].find(entry.uid)
		if column == -1:
			continue
		await _reveal_roulette(lane, side, column, entry.uid, claimed[side])
		if _reveal_skip:
			return
		claimed[side][column] = true
		_reveal_flight(lane, entry, side, column)
	await _reveal_wait(0.32)
	if _reveal_skip:
		return
	lane.roulette = {}
	lane.build_slabs(board.lane_models[lane_index])
	var settle = lane.close_staging(AnimationQueue.duration(0.3))
	if settle != null:
		_reveal_tweens.append(settle)
	_reveal_tweens.append(_tween_to(lane, "candidate_alpha", 0.0, 0.3))
	_reveal_tweens.append(_tween_to(lane, "slab_t", 1.0, 0.36))
	await _reveal_wait(0.36)
	if _reveal_skip:
		return
	lane.preview_hidden = false
	_reveal_tweens.append(_tween_to(lane, "slab_alpha", 0.0, 0.15))
	await _reveal_wait(0.16)
	if _reveal_skip:
		return
	for uid in lane.cards:
		lane.cards[uid].modulate.a = 1.0
	lane.reset_reveal()
	lane.layout()

## The deciding highlight: 3-5 decelerating hops over the free candidate
## slots of `side`, ending on `column`. Purely visual: the hops come from a
## UI-only generator seeded by the unit, never the match's random stream.
func _reveal_roulette(lane: Control, side: int, column: int, uid: int, claimed: Dictionary) -> void:
	var options: Array = lane.candidates[side].filter(func(value): return not claimed.has(value))
	if options.size() <= 1:
		lane.roulette = {"side": side, "column": column, "landing": true}
		lane.queue_redraw()
		await _reveal_wait(0.1)
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = uid * 7919 + int(lane.lane_index)
	var durations = [0.03, 0.04, 0.05, 0.06, 0.08]
	var hops = rng.randi_range(3, 5)
	var sequence: Array = []
	var others = options.filter(func(value): return value != column)
	for hop in range(hops - 1):
		# Never the same slot twice in a row, and not the final slot just before landing.
		var previous = sequence.back() if not sequence.is_empty() else -1
		var last = hop == hops - 2
		var pool = options.filter(func(value): return value != previous and not (last and value == column))
		if pool.is_empty():
			pool = others
		sequence.append(pool[rng.randi_range(0, pool.size() - 1)])
	sequence.append(column)
	for index in range(sequence.size()):
		lane.roulette = {"side": side, "column": sequence[index], "landing": index == sequence.size() - 1}
		lane.queue_redraw()
		if sfx != null and index == sequence.size() - 1:
			sfx.play("tap-b")
		await _reveal_wait(durations[durations.size() - sequence.size() + index])
		if _reveal_skip:
			return

## Flies the staged card for `entry` into its combat position along a curve
## that bows toward the river, then lands it on the board card.
func _reveal_flight(lane: Control, entry: Dictionary, side: int, column: int) -> void:
	var card: Control = lane.cards.get(entry.uid)
	if card == null:
		return
	var staged: Control = lane.take_staged("h%d" % entry.uid) if entry.hero else lane.take_staged_kind(side, "creep")
	var start: Vector2
	if staged != null:
		start = staged.position + UnitCard.SIZE * 0.5
		card.rotation = staged.rotation
		card.scale = staged.scale
		UiKit.discard(staged)
	else:
		start = lane.fan_center(side, 0, 1)
		card.rotation = 0.0
		card.scale = Vector2.ONE * lane.STAGE_SCALE
	card.modulate.a = 1.0
	card.position = start - UnitCard.SIZE * 0.5
	lane.move_child(card, -1)
	var finish = lane.slot_center(column, side == 1)
	var bend = (start + finish) * 0.5 + Vector2(0, -40.0 if side == 1 else 40.0)
	var fly = func(t: float) -> void:
		var point = start * (1.0 - t) * (1.0 - t) + bend * 2.0 * (1.0 - t) * t + finish * t * t
		card.position = point - UnitCard.SIZE * 0.5
	var land = func() -> void:
		lane.flying.erase(entry.uid)
		lane.candidates[side].erase(column)
		lane.layout()
		fx.burst(card.get_global_rect().get_center(), "cast", 0.4 * card.scale.x)
		_flash(card)
		if sfx != null:
			sfx.play("tap-a")
	var duration = AnimationQueue.duration(0.3)
	var tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(fly, 0.0, 1.0, duration)
	tween.tween_property(card, "rotation", 0.0, duration)
	tween.tween_property(card, "scale", Vector2.ONE * lane._scale, duration)
	tween.chain().tween_callback(land)
	_reveal_tweens.append(tween)

## A reveal tween of one property (tracked so a skip can stop it).
func _tween_to(target: Object, property: String, value, seconds: float) -> Tween:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, property, value, AnimationQueue.duration(seconds))
	return tween

## Skip: stop every reveal animation and show the settled board at once,
## exactly as a completed reveal leaves it.
func _finish_reveal_now(view: Dictionary, viewer: int) -> void:
	for tween in _reveal_tweens:
		if tween is Tween and tween.is_valid():
			tween.kill()
	_reveal_tweens = []
	for lane in board.lanes:
		lane.clear_staging()
		lane.reset_reveal()
	_free_removed(board.sync(view, viewer, []))
	for lane in board.lanes:
		for uid in lane.cards:
			var card: Control = lane.cards[uid]
			card.modulate = Color.WHITE
			card.rotation = 0.0
			card.flash = 0.0
			card.scale = Vector2.ONE * lane._scale
			card.queue_redraw()
		lane.layout()
	deployment.opponent_strip.visible = false

func _exit_deployment(view: Dictionary) -> void:
	if not _reveal_skipped:
		await queue.wait(0.35 if _revealed_this_state else 0.7)
	deployment.close()
	hand.set_lowered(false)
	board.slide_to(int(view.lane), 0.0)
	await queue.finish(board.set_overview(false, AnimationQueue.duration(0.3 if _reveal_skipped else 0.5)))
	_set_band(_view_band)
	fx.banner(EventText.lane_name(int(view.lane)), UiKit.GOLD_BRIGHT, 0.4, 46, _river_y())
	await queue.wait(0.15 if _reveal_skipped else 0.3)

func _show_game_over(view: Dictionary, viewer: int) -> void:
	if _game_over_shown:
		return
	_game_over_shown = true
	await queue.wait(0.6)
	_show_result(view, viewer)

func _show_result(view: Dictionary, viewer: int) -> void:
	game_over.disabled_actions = ["again", "save"] if controller.is_guest() else []
	game_over.show_result(int(view.winner), viewer, controller.mode == controller.MODE_LOCAL, _towers_text(view, viewer), _matchup_text(view, viewer))

func _focus_lane(lane_index: int) -> void:
	if board.zoom > 0.01 and str(shown_view.get("phase", "")) == "action":
		await queue.finish(board.set_overview(false, AnimationQueue.duration(0.35)))
	if board.focus_lane != lane_index or absf(board.focus - lane_index) > 0.01:
		await queue.finish(board.slide_to(lane_index, AnimationQueue.duration(0.4)))

## Global y of the river in lane view (banners sit on it), or -1 in overview.
func _river_y() -> float:
	if board.overview:
		return -1.0
	var lane: Control = board.lanes[board.focus_lane]
	return (lane.get_global_transform() * Vector2(0, lane.river_y())).y

func _set_band(band: Vector2) -> void:
	board.overview_top = band.x
	board.overview_bottom = band.y
	board.apply_camera()

# --- Controls ------------------------------------------------------------------

func _refresh_controls() -> void:
	if shown_view.is_empty():
		return
	var view = shown_view
	var viewer = shown_viewer
	var phase = str(view.phase)
	var busy = queue.busy
	match phase:
		"action":
			var my_turn = {"type": "pass"} in actions
			if busy and hud.combat_lane != -1:
				coin.set_state(false, false, UiKit.t("PHASE_COMBAT"), "")
			elif my_turn:
				coin.set_state(true, true, UiKit.t("BTN_PASS"), UiKit.t("HUD_INITIATIVE_YOU"))
			else:
				coin.set_state(false, false, UiKit.t("HUD_OPPONENT_TURN"), UiKit.t("HUD_INITIATIVE_OPPONENT"))
		"shop":
			var can = {"type": "finish_shop"} in actions
			coin.set_state(can, can, UiKit.t("BTN_FINISH_SHOPPING") if can else UiKit.t("HUD_WAITING"), UiKit.t("SHOP_HINT") if can else "")
		"deployment":
			if _revealing:
				# Both sides confirmed: the reveal plays and nothing can move.
				coin.set_state(false, false, UiKit.t("HUD_WAITING"), "")
			else:
				var can = {"type": "finish_deployment"} in actions
				var waiting = view.players[viewer].get("finished", false)
				var coin_hint = ""
				if not waiting and not deployment.hero_cards.is_empty():
					coin_hint = UiKit.t("DEPLOY_DRAG_HINT")
				elif not waiting and not view.players[viewer].get("plans", {}).is_empty():
					coin_hint = UiKit.t("DEPLOY_ALL_ASSIGNED")
				coin.set_state(can, can, UiKit.t("BTN_CONFIRM_DEPLOYMENT") if not waiting else UiKit.t("HUD_WAITING"), coin_hint)
		_:
			coin.set_state(false, false, UiKit.t("PHASE_FINISHED"), "")
	coin.enabled = coin.enabled and not busy
	var names = _player_names(viewer)
	var players: Array = view.players
	var acting_enemy = phase == "action" and int(view.active_player) != viewer and int(view.winner) == -1
	enemy_panel.set_values(names[1], int(players[1 - viewer].gold), int(players[1 - viewer].get("deck_count", 0)),
		int(players[1 - viewer].get("hand_count", 0)), acting_enemy)
	own_panel.set_values(names[0], int(players[viewer].gold), int(players[viewer].get("deck_count", 0)),
		int(players[viewer].get("hand_count", players[viewer].get("hand", []).size())), phase == "action" and not acting_enemy)
	var online = controller.mode == controller.MODE_ONLINE
	enemy_panel.set_connection(controller.steam_bridge.connection_info() if online else {})
	own_deck.set_count(int(players[viewer].get("deck_count", 0)), UiKit.t("TERM_DECK"))
	enemy_deck.set_count(int(players[1 - viewer].get("deck_count", 0)))
	enemy_hand.set_count(int(players[1 - viewer].get("hand_count", 0)))
	hud.sync(view, viewer, board.lane_models, board.focus_lane)

func _player_names(viewer: int) -> Array:
	if controller == null:
		return ["", ""]
	match controller.mode:
		controller.MODE_AI:
			return [UiKit.t("PLAYER_YOU"), UiKit.t("PLAYER_AI")]
		controller.MODE_ONLINE:
			var opponent = controller.opponent_name()
			return [UiKit.t("PLAYER_YOU"), opponent if not opponent.is_empty() else UiKit.t("PLAYER_OPPONENT")]
	return [UiKit.t("PLAYER_N", {"n": viewer + 1}), UiKit.t("PLAYER_N", {"n": 2 - viewer})]

func _card_states(view: Dictionary, viewer: int, new_actions: Array) -> Array:
	var states: Array = []
	var hand_ids: Array = view.players[viewer].get("hand", [])
	for index in range(hand_ids.size()):
		var playable = false
		for action in new_actions:
			if action.get("type", "") == "play" and int(action.get("hand", -1)) == index:
				playable = true
				break
		states.append({"playable": true} if playable else {"playable": false, "reason": _reason(str(hand_ids[index]), view, viewer)})
	return states

## Why a hand card cannot be played right now.
func _reason(card_id: String, view: Dictionary, viewer: int) -> String:
	if view.phase != "action":
		return UiKit.t("REASON_NOT_ACTION_PHASE")
	if int(view.active_player) != viewer:
		return UiKit.t("REASON_OPPONENT_TURN")
	var card = Library.raw_definition(card_id)
	if int(card.get("cost", 0)) > int(view.lanes[int(view.lane)].mana[viewer]):
		return UiKit.t("REASON_NEED_MANA", {"n": int(card.get("cost", 0))})
	if str(card.get("color", "")) != "item":
		var matching = false
		for unit in view.lanes[int(view.lane)].units[viewer]:
			if unit != null and unit.hero and unit.color == card.color and not unit.get("silenced", false):
				matching = true
		if not matching:
			return UiKit.t("REASON_NEED_HERO", {"color": UiKit.t("COLOR_" + str(card.color).to_upper())})
	return UiKit.t("REASON_NO_TARGET")

func _opponent_spent_text(view: Dictionary, viewer: int) -> String:
	var events: Array = view.get("events", [])
	var start = 0
	for index in range(events.size() - 1, -1, -1):
		if str(events[index].get("k", "")) == "shop_open":
			start = index
			break
	var count = 0
	var gold = 0
	for index in range(start, events.size()):
		var event = events[index]
		if str(event.get("k", "")) == "buy" and int(event.get("p", -1)) == 1 - viewer:
			count += 1
			gold += int(event.get("gold", 0))
	return UiKit.t("SHOP_OPPONENT_SPENT", {"n": count, "gold": gold}) if count > 0 else ""

func _towers_text(view: Dictionary, viewer: int) -> String:
	var fallen = [0, 0]
	for lane in view.lanes:
		for player in range(2):
			if lane.structures[player].get("ancient", false):
				fallen[player] += 1
	var names = _player_names(viewer)
	return UiKit.t("RESULT_TOWERS", {"player1": names[0], "n1": fallen[1 - viewer], "player2": names[1], "n2": fallen[viewer]})

func _matchup_text(view: Dictionary, viewer: int) -> String:
	return UiKit.t("DECKS_VS", {"deck1": Library.preset_text(str(view.players[viewer].get("preset", ""))),
		"deck2": Library.preset_text(str(view.players[1 - viewer].get("preset", "")))})

func show_hint(text: String, seconds: float = 3.0) -> void:
	if text.is_empty():
		hint_label.visible = false
		return
	hint_label.text = text
	hint_label.visible = true
	_hint_time = seconds
	_place_hint()

# --- Input ---------------------------------------------------------------------

func can_play() -> bool:
	return not queue.busy and not pass_screen.visible and not inspect.visible and not game_over.visible and not reconnect.visible \
		and str(shown_view.get("phase", "")) == "action"

func _process(delta: float) -> void:
	if _hint_time > 0.0 and hold.is_empty():
		_hint_time -= delta
		if _hint_time <= 0.0:
			hint_label.visible = false
	if not _unit_press.is_empty():
		_unit_press.time += delta
		if _unit_press.time >= LONG_PRESS:
			var uid = int(_unit_press.uid)
			_unit_press = {}
			inspect_unit(uid)
	if hold.is_empty():
		return
	if hold.mode == "pending":
		_press_time += delta
		if _press_time >= LONG_PRESS:
			var card_id = str(hand.ids[hold.index]) if hold.index < hand.ids.size() else ""
			_cancel_hold()
			if not card_id.is_empty():
				inspect_card(card_id)
			return
	# Hovering a screen edge while aiming a cross-lane card switches lanes:
	# once per visit to the edge, and never while over a chevron (a click
	# there already switched).
	var middle = _mouse.y > size.y * 0.25 and _mouse.y < size.y * 0.7
	var direction = -1 if _mouse.x < EDGE else (1 if _mouse.x > size.x - EDGE else 0)
	if not middle or direction == 0:
		_edge_time = 0.0
		_edge_armed = true
	elif _edge_armed and hold.get("cross_lane", false) and hold.mode in ["drag", "click"] and not _over_chevron(_mouse):
		_edge_time += delta
		if _edge_time > 0.5:
			_edge_time = 0.0
			_edge_armed = false
			view_lane(board.focus_lane + direction)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or input_blocked.call():
		return
	if event is InputEventMouse:
		_mouse = get_global_transform() * make_input_local(event).position
		if not _unit_press.is_empty():
			var released = event is InputEventMouseButton and not event.pressed
			if released or _mouse.distance_to(_unit_press.point) > DRAG_THRESHOLD:
				_unit_press = {}
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_key(event):
			get_viewport().set_input_as_handled()
		return
	if hold.is_empty():
		return
	if event is InputEventMouseMotion:
		if hold.mode == "pending" and _mouse.distance_to(hold.press) > DRAG_THRESHOLD:
			hold.mode = "drag"
		_update_hold(_mouse)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_hold()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				if hold.mode == "drag":
					_commit(_mouse)
				elif hold.mode == "pending":
					hold.mode = "click"
					_update_hold(_mouse)
				get_viewport().set_input_as_handled()
			elif hold.mode == "click":
				if _over_chevron(_mouse):
					return
				var other = hand.index_at(_mouse)
				if other != -1 and other != hold.index:
					_cancel_hold()
					return
				_commit(_mouse)
				get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> bool:
	if _revealing and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		_reveal_skip = true
		return true
	match event.keycode:
		KEY_ESCAPE:
			if not hold.is_empty():
				_cancel_hold()
			elif inspect.visible:
				inspect.close()
			elif log_panel.visible:
				log_panel.toggle(false)
			elif not pass_screen.visible:
				menu_requested.emit()
			return true
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if pass_screen.visible:
				pass_screen.confirm()
			else:
				press_coin()
			return true
		KEY_TAB:
			toggle_overview()
			return true
		KEY_1, KEY_2, KEY_3:
			view_lane(event.keycode - KEY_1)
			return true
		KEY_LEFT:
			view_lane(board.focus_lane - 1)
			return true
		KEY_RIGHT:
			view_lane(board.focus_lane + 1)
			return true
		KEY_L:
			toggle_log()
			return true
	return false

func _over_chevron(point: Vector2) -> bool:
	for chevron in board.chevrons:
		if chevron.visible and chevron.get_global_rect().has_point(point):
			return true
	return false

func _on_hand_pressed(index: int, button: int) -> void:
	if index < 0 or index >= hand.ids.size():
		return
	var press_point = hand.cards[index].get_global_rect().get_center()
	if button == MOUSE_BUTTON_RIGHT:
		_cancel_hold()
		inspect_card(str(hand.ids[index]))
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if not hold.is_empty():
		_cancel_hold()
	if not can_play():
		show_hint(_reason(str(hand.ids[index]), shown_view, shown_viewer) if not queue.busy else "", 2.5)
		return
	var plays = _plays_for(index)
	if plays.is_empty():
		show_hint(_reason(str(hand.ids[index]), shown_view, shown_viewer), 2.5)
		fx.shake(hand.cards[index], 5.0, 0.2)
		return
	_begin_hold(index, plays, _mouse if _mouse != Vector2.ZERO else press_point)

func _plays_for(index: int) -> Array:
	var plays: Array = []
	for action in actions:
		if action.get("type", "") == "play" and int(action.get("hand", -1)) == index:
			plays.append(action)
	return plays

func _begin_hold(index: int, plays: Array, press_point: Vector2) -> void:
	var kind = "untargeted"
	if plays[0].has("position"):
		kind = "creep"
	elif plays[0].has("destination"):
		kind = "redirect"
	elif plays[0].has("target"):
		kind = "target"
	hold = {"index": index, "plays": plays, "kind": kind, "mode": "pending", "press": press_point,
		"source": -1, "card": hand.cards[index],
		"cross_lane": bool(Library.raw_definition(str(hand.ids[index])).get("cross_lane", false))}
	_edge_armed = not (_mouse.x < EDGE or _mouse.x > size.x - EDGE)
	_press_time = 0.0
	if sfx != null:
		sfx.play("tap-a")
	hand.stop_tween(hand.cards[index])
	hand.held = index
	hand.hovered = -1
	hand.cards[index].hovered = false
	hand.cards[index].selected = true
	hand.layout(true)
	_focus_now(int(shown_view.lane))
	_setup_targets()
	_update_hold(press_point)

## Moves the camera to the active lane immediately (input feedback).
func _focus_now(lane_index: int) -> void:
	if board.overview:
		board.set_overview(false, AnimationQueue.duration(0.25))
	if board.focus_lane != lane_index:
		board.slide_to(lane_index, AnimationQueue.duration(0.3))

func _setup_targets() -> void:
	_clear_targets()
	var lane = board.lanes[int(shown_view.lane)]
	match hold.kind:
		"creep":
			var positions: Array = []
			for play in hold.plays:
				positions.append(int(play.position))
			lane.set_ghost_slots(positions)
		"target", "redirect":
			if hold.source == -1:
				for play in hold.plays:
					var card = board.unit_card(int(play.target))
					if card != null:
						card.target_state = 1
			else:
				var source: Control = board.unit_card(int(hold.source))
				if source != null:
					source.target_state = 3
				for play in hold.plays:
					if int(play.target) != int(hold.source):
						continue
					var destination = int(play.destination)
					if destination == 0:
						var tower = _redirect_tower()
						if tower != null:
							tower.target_state = 1
					else:
						var card = board.unit_card(destination)
						if card != null:
							card.target_state = 1

func _redirect_tower() -> Control:
	var source: Control = board.unit_card(int(hold.get("source", -1)))
	if source == null:
		return null
	return board.tower(board.lane_of_uid(source.uid), not source.own)

func _clear_targets() -> void:
	for lane in board.lanes:
		for uid in lane.cards:
			lane.cards[uid].target_state = 0
			lane.cards[uid].queue_redraw()
		for tower in lane.towers:
			tower.target_state = 0
			tower.queue_redraw()
		if not lane.ghost_slots.is_empty():
			lane.set_ghost_slots([])

## The play that would happen if the held card were released at `point`.
func _candidate_at(point: Vector2) -> Dictionary:
	if hold.is_empty():
		return {}
	match hold.kind:
		"untargeted":
			if point.y < size.y - HAND_ZONE and board.lane_at(point) != -1:
				return {"action": hold.plays[0]}
		"creep":
			var position = board.lanes[int(shown_view.lane)].slot_at(point)
			for play in hold.plays:
				if int(play.position) == position:
					return {"action": play, "slot": position}
		"target":
			var card = board.unit_at(point)
			if card != null:
				for play in hold.plays:
					if int(play.target) == card.uid:
						return {"action": play, "uid": card.uid}
		"redirect":
			if hold.source == -1:
				var card = board.unit_at(point)
				if card != null:
					for play in hold.plays:
						if int(play.target) == card.uid:
							return {"source": card.uid}
			else:
				var card = board.unit_at(point)
				var destination = card.uid if card != null else -1
				var tower = _redirect_tower()
				if card == null and tower != null and tower.get_global_rect().has_point(point):
					destination = 0
				for play in hold.plays:
					if int(play.target) == int(hold.source) and int(play.destination) == destination:
						return {"action": play, "uid": destination}
	return {}

func _update_hold(point: Vector2) -> void:
	if hold.is_empty():
		return
	var candidate = _candidate_at(point)
	var card: Control = hold.card
	if not is_instance_valid(card):
		_cancel_hold()
		return
	var follow = hold.mode == "drag" and hold.kind in ["untargeted", "creep"]
	if follow:
		hold.lifted = false
		if hold.get("lift_tween") != null and hold.lift_tween.is_valid():
			hold.lift_tween.kill()
		card.rotation = 0.0
		card.scale = Vector2(0.78, 0.78)
		card.position = hand.get_global_transform().affine_inverse() * point - Vector2(card.size.x * 0.5, card.size.y * 1.08)
		arrow.hide_arrow()
	else:
		if not hold.get("lifted", false):
			hold.lifted = true
			# Aim from beside the own tower so the card never hides it.
			var lifted = Vector2(hand.size.x * 0.5 - 300.0 - card.size.x, hand.size.y - card.size.y * 0.86 - 52.0)
			if AnimationQueue.instant:
				card.position = lifted
				card.rotation = 0.0
				card.scale = Vector2(0.86, 0.86)
			else:
				var tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(card, "position", lifted, AnimationQueue.duration(0.16))
				tween.tween_property(card, "rotation", 0.0, AnimationQueue.duration(0.16))
				tween.tween_property(card, "scale", Vector2(0.86, 0.86), AnimationQueue.duration(0.16))
				hold.lift_tween = tween
		var source_point = card.get_global_transform() * Vector2(card.size.x * 0.5, 8.0)
		if hold.kind == "redirect" and hold.source != -1:
			var source_card: Control = board.unit_card(int(hold.source))
			if source_card != null:
				source_point = source_card.front_point()
		arrow.show_arrow(source_point, point, not candidate.is_empty(), UiKit.TARGET)
	# Hover feedback on the candidate.
	var hovered_uid = int(candidate.get("uid", candidate.get("source", -999)))
	for lane in board.lanes:
		for uid in lane.cards:
			var unit_card: Control = lane.cards[uid]
			if unit_card.target_state in [1, 2]:
				unit_card.target_state = 2 if uid == hovered_uid else 1
		if not lane.ghost_slots.is_empty():
			lane.hovered_slot = int(candidate.get("slot", -999))
			lane.queue_redraw()
	var tower = _redirect_tower() if hold.kind == "redirect" and hold.source != -1 else null
	if tower != null:
		tower.target_state = 2 if hovered_uid == 0 else 1
	var keys = {"untargeted": "HINT_DROP_TO_CAST", "creep": "HINT_SELECT_POSITION", "target": "HINT_SELECT_TARGET",
		"redirect": "HINT_SELECT_TARGET" if hold.source == -1 else "HINT_SELECT_DESTINATION"}
	show_hint(UiKit.t(keys[hold.kind]) + "   " + UiKit.t("HINT_RIGHT_CLICK_CANCEL"), 0.5)

func _commit(point: Vector2) -> void:
	var candidate = _candidate_at(point)
	if candidate.is_empty():
		_cancel_hold()
		return
	if candidate.has("source"):
		hold.source = int(candidate.source)
		hold.mode = "click"
		_setup_targets()
		_update_hold(point)
		return
	var card: Control = hold.card
	_pending_origin = card.get_global_rect().get_center() if is_instance_valid(card) else point
	if is_instance_valid(card):
		card.visible = false
	var action: Dictionary = candidate.action
	_cancel_hold()
	var result = controller.act(action)
	if not result.get("ok", false) and is_instance_valid(card):
		card.visible = true
		_pending_origin = Vector2(-1, -1)

func _cancel_hold() -> void:
	if hold.is_empty():
		return
	var card: Control = hold.get("card")
	if is_instance_valid(card):
		card.selected = false
		card.queue_redraw()
	hold = {}
	arrow.hide_arrow()
	_clear_targets()
	hand.held = -1
	hand.layout(true)
	hint_label.visible = false

func _on_board_pressed(point: Vector2, button: int, double_click: bool) -> void:
	if not hold.is_empty():
		return
	var phase = str(shown_view.get("phase", ""))
	# Staged units: right-click inspects, a press on your hero drags it.
	if phase == "deployment" and deployment.visible and deployment.handle_board_press(point, button):
		return
	var card: Control = board.unit_at(point)
	if button == MOUSE_BUTTON_RIGHT:
		if card != null:
			inspect_unit(card.uid)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if phase == "deployment" and deployment.handle_board_click(point):
		return
	if card != null and card.ability_hit(point):
		use_ability(card.uid)
		return
	if card != null:
		_unit_press = {"uid": card.uid, "point": point, "time": 0.0}
	if double_click and phase == "action":
		toggle_overview()
		return
	if board.overview and phase == "action":
		var lane = board.lane_at(point)
		if lane != -1:
			view_lane(lane)

func _on_shop_card_input(event: InputEvent, source: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var card_id = str(shown_view.players[shown_viewer].get("shop", {}).get(source, ""))
		if not card_id.is_empty():
			inspect_card(card_id)

func _on_reconnect_action(action: String) -> void:
	match action:
		"claim":
			controller.claim_win()
		"leave":
			controller.leave_online()

func _on_game_over_action(action: String) -> void:
	if action == "board":
		game_over.visible = false
		return
	game_over_action.emit(action)

# --- Commands and public helpers (also the test facade) -------------------

func press_coin() -> void:
	if queue.busy or pass_screen.visible or shown_view.is_empty():
		return
	var phase = str(shown_view.phase)
	var command = {}
	match phase:
		"action":
			command = {"type": "pass"}
		"shop":
			command = {"type": "finish_shop"}
		"deployment":
			command = {"type": "finish_deployment"}
	if command.is_empty() or not command in actions:
		return
	_cancel_hold()
	if sfx != null:
		sfx.play("click-b")
	controller.act(command)

func buy(source: String) -> void:
	for action in actions:
		if action.get("type", "") == "buy" and action.get("source", "") == source:
			_hand_origin = shop.slot_center(source)
			if sfx != null:
				sfx.play("switch-b")
			controller.act(action)
			return

func hold_secret() -> void:
	if {"type": "hold"} in actions:
		controller.act({"type": "hold"})

func deploy_hero(uid: int, lane: int) -> void:
	var command = {"type": "deploy", "unit": uid, "lane": lane}
	if command in actions:
		if sfx != null:
			sfx.play("click-a")
		controller.act(command)

## Takes a planned hero back to the tray (before confirming).
func undeploy_hero(uid: int) -> void:
	var command = {"type": "undeploy", "unit": uid}
	if command in actions:
		if sfx != null:
			sfx.play("click-b")
		controller.act(command)

func use_ability(uid: int) -> bool:
	var command = {"type": "ability", "unit": uid}
	if command in actions and can_play():
		controller.act(command)
		return true
	show_hint(UiKit.t("HINT_ABILITY_UNAVAILABLE"), 2.0)
	return false

func view_lane(index: int) -> void:
	index = clampi(index, 0, 2)
	if board.overview and str(shown_view.get("phase", "")) == "action":
		board.set_overview(false, AnimationQueue.duration(0.35))
	board.slide_to(index, AnimationQueue.duration(0.4))
	hud.camera_lane = index
	hud.queue_redraw()

func toggle_overview() -> void:
	if str(shown_view.get("phase", "")) != "action":
		return
	board.set_overview(not board.overview, AnimationQueue.duration(0.4))

func toggle_log() -> void:
	log_panel.toggle(not log_panel.visible)

func inspect_card(card_id: String) -> void:
	inspect.show_card(card_id)

func inspect_unit(uid: int) -> void:
	var model = board.model(uid)
	if not model.is_empty():
		inspect.show_card(str(model.unit.card), model)

## Click-mode play: pick up hand card `index` (returns false if unplayable).
func select_card(index: int) -> bool:
	_on_hand_pressed(index, MOUSE_BUTTON_LEFT)
	if hold.is_empty():
		return false
	hold.mode = "click"
	return true

func selected_hand() -> int:
	return int(hold.get("index", -1))

func selected_source() -> int:
	return int(hold.get("source", -1))

## Completes a click-mode play on unit `uid` (first or second stage).
func target_unit(uid: int) -> bool:
	if hold.is_empty():
		return false
	var card = board.unit_card(uid)
	if card == null:
		return false
	_commit(card.get_global_rect().get_center())
	return true

func choose_position(position: int) -> bool:
	if hold.is_empty() or hold.kind != "creep":
		return false
	_commit(board.lanes[int(shown_view.lane)].slot_global_center(position))
	return true

## Second stage of Battlefield Control: a unit uid, or 0 for the tower.
func choose_destination(uid: int) -> bool:
	if hold.is_empty() or hold.kind != "redirect" or hold.source == -1:
		return false
	if uid == 0:
		var tower = _redirect_tower()
		if tower == null:
			return false
		_commit(tower.get_global_rect().get_center())
		return true
	return target_unit(uid)

func hand_card_point(index: int) -> Vector2:
	return hand.card_center(index)

func unit_point(uid: int) -> Vector2:
	var card = board.unit_card(uid)
	return card.get_global_rect().get_center() if card != null else Vector2.ZERO

func slot_point(position: int) -> Vector2:
	return board.lanes[int(shown_view.lane)].slot_global_center(position)

func tower_point(lane_index: int, own: bool) -> Vector2:
	return board.tower(lane_index, own).get_global_rect().get_center()

func lane_point(lane_index: int) -> Vector2:
	var lane: Control = board.lanes[lane_index]
	return lane.get_global_transform() * Vector2(lane.size.x * 0.5, lane.size.y * 0.45)

func coin_point() -> Vector2:
	return coin.get_global_transform() * coin.center()

func ability_point(uid: int) -> Vector2:
	var card = board.unit_card(uid)
	if card == null or card.ability_rect().size == Vector2.ZERO:
		return Vector2.ZERO
	return card.get_global_transform() * card.ability_rect().get_center()

## Full-screen catcher shown while the deployment reveal plays: any click
## skips to the end. It says so at the bottom centre.
class RevealCatcher:
	extends Control
	signal skipped

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			skipped.emit()
			accept_event()

	func _draw() -> void:
		UiKit.draw_text(self, UiKit.body_font(), UiKit.t("DEPLOY_SKIP_HINT"), Vector2(size.x * 0.5, size.y * 0.655), 14,
			Color(UiKit.PAPER, 0.6), -1.0, 2)
