extends Control

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const SteamBridge = preload("res://scripts/network/steam_bridge.gd")
const CardFace = preload("res://scripts/ui/card_face.gd")
const GOLD = Color("d1ae75")
const MUTED = Color("8897a8")
const COLORS = {"red": Color("c76560"), "blue": Color("66a0d0"),
	"green": Color("79aa79"), "black": Color("a38bbd"),
	"neutral": Color("8797a3"), "item": Color("d1ae75")}

var engine = MatchEngine.new()
var bot = Bot.new()
var steam_bridge: Node
var bot_timer: Timer
var root_box: VBoxContainer
var selected_hand: int = -1
var selected_source: int = -1
var inspected_card: String = "axe"
var inspector_image
var inspector_title: Label
var inspector_effect: Label
var texture_cache: Dictionary = {}
var mode: int = 0
var local_player: int = 0
var current_seed: int = 10414
var notice: String = "Select a card, then a highlighted target. Two consecutive passes trigger combat."
var online_view: Dictionary = {}
var online_actions: Array = []
var replay_dialog: FileDialog
var deck_selections: Array = ["starter", "green_assault"]

func _ready() -> void:
	_build_theme()
	steam_bridge = SteamBridge.new()
	add_child(steam_bridge)
	steam_bridge.status_changed.connect(_steam_status)
	steam_bridge.match_received.connect(_online_state)
	steam_bridge.command_received.connect(_online_command)
	bot_timer = Timer.new()
	bot_timer.one_shot = true
	bot_timer.wait_time = 0.55
	bot_timer.timeout.connect(_bot_step)
	add_child(bot_timer)
	engine.start(current_seed, deck_selections)
	_render()
	_schedule_bot()

func _build_theme() -> void:
	var palette = Theme.new()
	palette.default_font_size = 15
	palette.set_color("font_color", "Label", Color("e4e7eb"))
	palette.set_color("font_color", "Button", Color("e4e7eb"))
	palette.set_color("font_disabled_color", "Button", Color("677282"))
	palette.set_constant("separation", "VBoxContainer", 6)
	palette.set_constant("separation", "HBoxContainer", 10)
	palette.set_stylebox("normal", "Button", _style(Color("182332"), Color("334255"), 6))
	palette.set_stylebox("hover", "Button", _style(Color("24344a"), GOLD, 6))
	palette.set_stylebox("pressed", "Button", _style(Color("354058"), GOLD, 6))
	palette.set_stylebox("disabled", "Button", _style(Color("111b27"), Color("253041"), 6))
	palette.set_stylebox("panel", "PanelContainer", _style(Color("111b27"), Color("2b3849"), 9))
	theme = palette

func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _render() -> void:
	if root_box != null:
		remove_child(root_box.get_parent())
		root_box.get_parent().queue_free()
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)
	var view = _view()
	var player = _view_player(view)
	var actions = _actions(player)
	_header(view, player)
	var status_row = HBoxContainer.new()
	root_box.add_child(status_row)
	var phase_title = "ROUND %d  /  %s" % [view.round, str(view.phase).to_upper()]
	if view.phase == "action":
		phase_title += "  /  LANE %d  /  PLAYER %d TO ACT" % [view.lane + 1, view.active_player + 1]
	elif view.winner != -1:
		phase_title += "  /  " + ("DRAW" if view.winner == 2 else "PLAYER %d WINS" % (view.winner + 1))
	_label(status_row, phase_title, 16, GOLD)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(spacer)
	_label(status_row, "Gold %d    Deck %d    Enemy hand %d" % [view.players[player].gold,
		view.players[player].deck_count, view.players[1 - player].hand_count], 14, MUTED)
	var middle = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(middle)
	var board = HBoxContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(board)
	for lane_index in range(3):
		_lane_panel(board, view, player, lane_index, actions)
	_sidebar(middle, view, player, actions)
	var hint = _label(root_box, notice, 14, GOLD)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hand(root_box, view, player, actions)
	_label(root_box, "%s vs %s  •  Hover to read  •  Click to play  •  Gold borders mark legal targets" % [view.players[0].deck_name, view.players[1].deck_name], 12, MUTED)

func _header(view: Dictionary, player: int) -> void:
	var row = HBoxContainer.new()
	root_box.add_child(row)
	var titles = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	_label(titles, "ARTIFACT · CLASSIC REVIVAL", 26, GOLD)
	_label(titles, "%s  /  %s" % [view.players[player].deck_name.to_upper(), view.players[1 - player].deck_name.to_upper()], 11, MUTED)
	var selector = OptionButton.new()
	selector.add_item("Play against AI")
	selector.add_item("Local two-player")
	selector.select(mini(mode, 1))
	selector.item_selected.connect(_change_mode)
	selector.disabled = mode == 2
	row.add_child(selector)
	_button(row, "New match", _new_match, mode == 2 and not steam_bridge.is_host)
	_button(row, "Save replay", _save_replay, mode == 2 and not steam_bridge.is_host)
	_button(row, "Load replay", _open_replay, mode == 2)
	_button(row, "Steam", _open_steam)
	_button(row, "Decks", _open_decks, mode == 2 and not steam_bridge.is_host)
	_button(row, "Log", _open_log)
	if mode == 1:
		_label(row, "Viewing P%d" % (player + 1), 14, GOLD)

func _lane_panel(parent: Control, view: Dictionary, player: int, lane_index: int, actions: Array) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 265
	var active = view.phase == "action" and view.lane == lane_index
	panel.add_theme_stylebox_override("panel", _style(Color("141f2c") if active else Color("0e1721"), GOLD if active else Color("293545"), 9))
	parent.add_child(panel)
	var column = VBoxContainer.new()
	panel.add_child(column)
	var names = ["LEFT LANE", "MIDDLE LANE", "RIGHT LANE"]
	_label(column, names[lane_index] + ("  •  ACTIVE" if active else ""), 16, GOLD if active else MUTED)
	var lane = view.lanes[lane_index]
	_structure_label(column, lane, 1 - player, false, lane_index)
	_unit_row(column, view, player, 1 - player, lane_index, actions)
	var divider = HSeparator.new()
	column.add_child(divider)
	var preview_engine = _display_engine(view)
	var forecast = preview_engine.combat_preview(lane_index)
	_label(column, "STRUCTURE DAMAGE   ↑ %d   ↓ %d" % [forecast.tower_damage[player], forecast.tower_damage[1 - player]], 12, GOLD)
	_label(column, "Attack / Armor / Health", 11, MUTED)
	column.add_child(HSeparator.new())
	_unit_row(column, view, player, player, lane_index, actions)
	_structure_label(column, lane, player, true, lane_index)

func _structure_label(parent: Control, lane: Dictionary, side: int, own: bool, lane_index: int) -> void:
	var structure = lane.structures[side]
	var noun = "ANCIENT" if structure.ancient else "TOWER"
	var owner = "YOUR" if own else "ENEMY"
	var command_side = -1
	if selected_source != -1 and lane_index == _view().lane:
		var source = _display_engine(_view()).find_unit(selected_source)
		if not source.is_empty() and side != source.owner:
			command_side = side
	if command_side != -1:
		_button(parent, "Choose %s %s as target" % [owner.to_lower(), noun.to_lower()], _choose_combat_destination.bind(0))
	else:
		_label(parent, "%s %s    %d HP    %d / %d MANA" % [owner, noun, structure.health,
			lane.mana[side], lane.max_mana[side]], 12, Color("95bda7") if own else Color("cf9294"))
	var health_bar = ProgressBar.new()
	health_bar.max_value = 80 if structure.ancient else 40
	health_bar.value = structure.health
	health_bar.show_percentage = false
	health_bar.custom_minimum_size.y = 6
	health_bar.add_theme_stylebox_override("background", _style(Color("080f18"), Color("080f18"), 2))
	health_bar.add_theme_stylebox_override("fill", _style(Color("527f6b") if own else Color("9b535b"), Color.TRANSPARENT, 2))
	parent.add_child(health_bar)

func _unit_row(parent: Control, view: Dictionary, player: int, side: int, lane_index: int, actions: Array) -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 130
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var row = HBoxContainer.new()
	scroll.add_child(row)
	for unit in view.lanes[lane_index].units[side]:
		var tile = Button.new()
		tile.custom_minimum_size = Vector2(112, 126)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tile)
		if unit == null:
			tile.text = "Empty\nslot"
			tile.disabled = true
			continue
		var valid_target = false
		for action in actions:
			if action.type == "play" and int(action.hand) == selected_hand and int(action.get("target", -1)) == int(unit.uid):
				valid_target = selected_source == -1
			if selected_source != -1 and action.type == "play" and int(action.get("target", -1)) == selected_source and int(action.get("destination", -1)) == int(unit.uid):
				valid_target = true
		var accent = COLORS.get(unit.color, MUTED)
		tile.add_theme_stylebox_override("normal", _style(Color("1c2937"), GOLD if valid_target else accent.darkened(0.35), 6))
		var display_engine = _display_engine(view)
		var arrow = "↖" if unit.arrow == -1 else ("↗" if unit.arrow == 1 else "↑")
		if side != player:
			arrow = "↙" if unit.arrow == -1 else ("↘" if unit.arrow == 1 else "↓")
		var content = VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 5
		content.offset_top = 4
		content.offset_right = -5
		content.offset_bottom = -4
		content.add_theme_constant_override("separation", 2)
		tile.add_child(content)
		var definition = engine.library.definition(unit.card)
		var texture = _card_texture(definition)
		if texture != null:
			var cropped = AtlasTexture.new()
			cropped.atlas = texture
			cropped.region = Rect2(0, texture.get_height() * 0.105, texture.get_width(), texture.get_height() * 0.65)
			var portrait = TextureRect.new()
			portrait.texture = cropped
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(portrait)
		var name_label = _label(content, unit.name, 11, accent.lightened(0.2))
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stats = _label(content, "%d / %d / %d  %s" % [display_engine.attack_of(unit), display_engine.armor_of(unit), unit.health, "S" if unit.get("silenced", false) else arrow], 14, GOLD if unit.get("silenced", false) else Color.WHITE)
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.tooltip_text = "%s\n%s\nAttack %d · Armor %d · Health %d" % [unit.name, definition.get("text", ""), display_engine.attack_of(unit), display_engine.armor_of(unit), unit.health]
		tile.mouse_entered.connect(_inspect.bind(str(unit.card)))
		tile.pressed.connect(_target_unit.bind(int(unit.uid)))
	if view.lanes[lane_index].units[side].is_empty():
		_label(row, "No units in this lane", 13, MUTED)

func _sidebar(parent: Control, view: Dictionary, player: int, actions: Array) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 255
	parent.add_child(panel)
	var column = VBoxContainer.new()
	panel.add_child(column)
	_label(column, "OPPONENT'S TURN" if view.phase == "action" and view.active_player != player else "YOUR NEXT MOVE", 15, GOLD)
	if view.phase == "action":
		var can_pass = {"type": "pass"} in actions
		_button(column, "Pass / resolve combat", _act.bind({"type": "pass"}), not can_pass)
		_label(column, "First consecutive passer gets\ninitiative in the next lane.", 12, MUTED)
		for unit in view.lanes[view.lane].units[player]:
			if unit != null and unit.get("ability", "") == "draw":
				var command = {"type": "ability", "unit": unit.uid}
				var caption = "J'Muy: draw a card" if int(unit.cooldown) == 0 else "J'Muy: ready in %d rounds" % unit.cooldown
				_button(column, caption, _act.bind(command), command not in actions)
	elif view.phase == "shop":
		_label(column, "Items cost gold; play them for free.", 12, MUTED)
		for source in ["secret", "item", "consumable"]:
			_label(column, {"secret": "SECRET SHOP", "item": "YOUR ITEM DECK", "consumable": "CONSUMABLE"}[source], 12, GOLD)
			var card_id = view.players[player].shop.get(source, "")
			if str(card_id).is_empty():
				_label(column, "Sold / unavailable", 12, MUTED)
				continue
			var card = engine.library.cards[card_id]
			var command = {"type": "buy", "card": card_id, "source": source}
			var button = _button(column, "%s · %d gold" % [card.name, card.price], _act.bind(command), command not in actions)
			button.tooltip_text = card.text
			var effect = _label(column, card.text, 12, MUTED)
			effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_button(column, "Finish shopping", _act.bind({"type": "finish_shop"}), {"type": "finish_shop"} not in actions)
	elif view.phase == "deployment":
		var seen_units: Array = []
		for action in actions:
			if action.type != "deploy" or action.unit in seen_units:
				continue
			seen_units.append(action.unit)
			var hero_name = "Hero"
			for hero in view.players[player].roster:
				if hero.uid == action.unit:
					hero_name = hero.name
			_label(column, hero_name, 13)
			var row = HBoxContainer.new()
			column.add_child(row)
			for lane_index in range(3):
				_button(row, ["Left", "Mid", "Right"][lane_index], _act.bind({"type": "deploy", "unit": action.unit, "lane": lane_index}))
		_button(column, "Confirm deployment", _act.bind({"type": "finish_deployment"}), {"type": "finish_deployment"} not in actions)
		_label(column, "Choices stay hidden until\nboth players confirm.", 12, MUTED)
	column.add_child(HSeparator.new())
	if view.phase in ["action", "finished"]:
		inspector_title = _label(column, "CARD DETAILS", 17, GOLD)
		inspector_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_image = CardFace.new()
		inspector_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		inspector_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inspector_image.custom_minimum_size = Vector2(220, 128)
		inspector_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inspector_image.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_card_preview())
		column.add_child(inspector_image)
		_label(column, "Click artwork to enlarge", 11, MUTED)
		inspector_effect = _label(column, "", 14)
		inspector_effect.custom_minimum_size.x = 220
		inspector_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inspect(inspected_card)
	else:
		inspector_title = null
		inspector_image = null
		inspector_effect = null
		_label(column, "RESERVE & FALLEN HEROES", 12, MUTED)
		for hero in view.players[player].roster:
			if hero.lane == -1:
				var plan = view.players[player].plans.get(str(hero.uid), -1)
				_label(column, "%s\n%s" % [hero.name, "Ready round %d" % hero.ready_round if plan == -1 else "Planned: lane %d" % (plan + 1)], 12, COLORS.get(hero.color, MUTED))

func _hand(parent: Control, view: Dictionary, player: int, actions: Array) -> void:
	_label(parent, "YOUR HAND   /   PLAYER %d   /   %d CARDS" % [player + 1, view.players[player].hand.size()], 13, MUTED)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 214
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var row = HBoxContainer.new()
	scroll.add_child(row)
	for index in range(view.players[player].hand.size()):
		var card = engine.library.get_card(view.players[player].hand[index])
		var playable = false
		for action in actions:
			if action.type == "play" and int(action.hand) == index:
				playable = true
		var tile = Button.new()
		tile.custom_minimum_size = Vector2(122, 205)
		var accent = COLORS.get(card.color, MUTED)
		tile.add_theme_stylebox_override("normal", _style(Color("1c2937") if playable else Color("121b26"), GOLD if index == selected_hand else accent.darkened(0.3), 7))
		var texture = _card_texture(card)
		if texture != null:
			var image_view = CardFace.new()
			image_view.setup(card, texture)
			image_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			image_view.offset_left = 3
			image_view.offset_top = 3
			image_view.offset_right = -3
			image_view.offset_bottom = -18
			image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			image_view.modulate = Color.WHITE if playable else Color(0.65, 0.65, 0.65)
			tile.add_child(image_view)
		else:
			tile.text = "%s\n%d mana\n%s" % [card.name, card.cost, card.text]
		var badge = _label(tile, "PLAY" if playable else _unplayable_reason(card, view, player), 10, GOLD if playable else MUTED)
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		badge.offset_top = -16
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.tooltip_text = card.text + ("" if playable else "\nNeeds your turn, enough mana, and a matching hero in the active lane.")
		tile.pressed.connect(_select_card.bind(index))
		tile.mouse_entered.connect(_inspect.bind(str(card.id)))
		row.add_child(tile)
	if view.players[player].hand.is_empty():
		_label(row, "Your hand is empty. Pass to advance combat.", 14, MUTED)

func _unplayable_reason(card: Dictionary, view: Dictionary, player: int) -> String:
	if view.phase != "action":
		return "NEXT ACTION PHASE"
	if view.active_player != player:
		return "OPPONENT'S TURN"
	if card.cost > view.lanes[view.lane].mana[player]:
		return "NEED %d MANA" % card.cost
	if card.color != "item":
		var matching_hero = false
		for unit in view.lanes[view.lane].units[player]:
			if unit != null and unit.hero and unit.color == card.color and not unit.get("silenced", false):
				matching_hero = true
		if not matching_hero:
			return "NEED %s HERO" % str(card.color).to_upper()
	return "NO LEGAL TARGET"

func _card_texture(definition: Dictionary):
	var path = str(definition.get("image", ""))
	if path.is_empty():
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var texture = load(path) as Texture2D
	texture_cache[path] = texture
	return texture

func _inspect(card_id: String) -> void:
	var card = engine.library.definition(card_id)
	if card.is_empty():
		card = engine.library.heroes[0]
		card_id = card.id
	inspected_card = card_id
	if is_instance_valid(inspector_title):
		inspector_title.text = card.name
		# Rebuild patched overlays when the hovered card changes.
		for child in inspector_image.get_children():
			inspector_image.remove_child(child)
			child.queue_free()
		inspector_image.correction = null
		inspector_image.setup(card, _card_texture(card))
		var suffix = ""
		if card.get("kind", "hero") == "hero":
			var signature = engine.library.get_card(card.get("signature", ""))
			if not signature.is_empty():
				suffix = "\n\nSignature: " + signature.name
		else:
			suffix = "\n\n%s · %d mana" % [str(card.color).capitalize(), card.cost]
		inspector_effect.text = str(card.get("text", "")) + suffix

func _open_card_preview() -> void:
	var card = engine.library.definition(inspected_card)
	var dialog = AcceptDialog.new()
	dialog.title = card.get("name", "Card")
	dialog.min_size = Vector2i(430, 730)
	add_child(dialog)
	var picture = CardFace.new()
	picture.setup(card, _card_texture(card))
	picture.custom_minimum_size = Vector2(410, 675)
	dialog.add_child(picture)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func _open_log() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Match log"
	add_child(dialog)
	var text_box = RichTextLabel.new()
	text_box.custom_minimum_size = Vector2(580, 470)
	text_box.text = "\n\n".join(_view().events)
	text_box.scroll_following = true
	dialog.add_child(text_box)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func _open_roster() -> void:
	var view = _view()
	var dialog = AcceptDialog.new()
	dialog.title = "Your five heroes"
	add_child(dialog)
	var row = HBoxContainer.new()
	dialog.add_child(row)
	for hero in view.players[_view_player(view)].roster:
		var column = VBoxContainer.new()
		column.custom_minimum_size.x = 165
		row.add_child(column)
		var picture = CardFace.new()
		picture.setup(engine.library.definition(hero.card), _card_texture(engine.library.definition(hero.card)))
		picture.custom_minimum_size = Vector2(160, 270)
		column.add_child(picture)
		_label(column, "Lane %d" % (hero.lane + 1) if hero.lane != -1 else "Ready round %d" % hero.ready_round, 13, GOLD)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func _open_decks() -> void:
	if mode == 2 and not steam_bridge.is_host:
		return
	bot_timer.stop()
	var dialog = AcceptDialog.new()
	dialog.title = "Choose your decks"
	dialog.ok_button_text = "Start this matchup"
	dialog.min_size = Vector2i(1020, 650)
	add_child(dialog)
	var body_scroll = ScrollContainer.new()
	body_scroll.custom_minimum_size = Vector2(1000, 590)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(body_scroll)
	var layout = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(layout)
	var choices = deck_selections.duplicate()
	var row = HBoxContainer.new()
	layout.add_child(row)
	for side in range(2):
		var panel = PanelContainer.new()
		panel.custom_minimum_size.x = 480
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var column = VBoxContainer.new()
		panel.add_child(column)
		_label(column, "YOUR DECK" if side == 0 else "OPPONENT'S DECK", 17, GOLD)
		var selector = OptionButton.new()
		var profiles = engine.library.presets()
		var selected = 0
		for index in range(profiles.size()):
			selector.add_item(profiles[index].name)
			if profiles[index].id == choices[side]:
				selected = index
		selector.select(selected)
		column.add_child(selector)
		var preview = VBoxContainer.new()
		column.add_child(preview)
		_fill_deck_preview(preview, str(choices[side]))
		selector.item_selected.connect(_deck_choice_changed.bind(side, preview, choices))
	var detail = _label(layout, "Each preset has 5 heroes, 40 main cards with hero signatures, and 9 equipment cards.", 13, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var utilities = HBoxContainer.new()
	layout.add_child(utilities)
	_button(utilities, "View current heroes", func():
		dialog.hide()
		dialog.queue_free()
		_open_roster()
		_schedule_bot())
	_button(utilities, "Browse all supported cards", func():
		dialog.hide()
		dialog.queue_free()
		_open_catalog()
		_schedule_bot())
	dialog.confirmed.connect(func():
		deck_selections = choices.duplicate()
		_new_match()
		dialog.queue_free())
	dialog.canceled.connect(func():
		dialog.queue_free()
		_schedule_bot())
	dialog.close_requested.connect(func():
		dialog.queue_free()
		_schedule_bot())
	dialog.popup_centered()

func _deck_choice_changed(index: int, side: int, preview: VBoxContainer, choices: Array) -> void:
	choices[side] = engine.library.presets()[index].id
	_fill_deck_preview(preview, str(choices[side]))

func _fill_deck_preview(preview: VBoxContainer, profile_id: String) -> void:
	for child in preview.get_children():
		preview.remove_child(child)
		child.queue_free()
	var profile = engine.library.preset(profile_id)
	if profile.is_empty():
		return
	var description = _label(preview, profile.description, 13, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 42
	var row = HBoxContainer.new()
	preview.add_child(row)
	for hero_id in profile.heroes:
		var hero = engine.library.definition(hero_id)
		var portrait = CardFace.new()
		portrait.setup(hero, _card_texture(hero))
		portrait.custom_minimum_size = Vector2(80, 140)
		portrait.tooltip_text = hero.name + "\n" + hero.text
		row.add_child(portrait)
	var deck_list = RichTextLabel.new()
	deck_list.custom_minimum_size = Vector2(430, 305)
	deck_list.add_theme_font_size_override("normal_font_size", 13)
	var lines: Array = ["MAIN DECK · 40 cards"]
	for card_id in profile.cards:
		lines.append("%d × %s" % [profile.cards[card_id], engine.library.cards[card_id].name])
	lines.append("\nITEM DECK · 9 cards")
	for card_id in profile.items:
		lines.append("%d × %s" % [profile.items[card_id], engine.library.cards[card_id].name])
	deck_list.text = "\n".join(lines)
	preview.add_child(deck_list)

func _open_catalog() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Supported Artifact Classic cards"
	dialog.min_size = Vector2i(1040, 720)
	add_child(dialog)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000, 650)
	dialog.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	var definitions = engine.library.heroes + engine.library.cards.values()
	for card in definitions:
		var column = VBoxContainer.new()
		column.custom_minimum_size.x = 150
		grid.add_child(column)
		var portrait = CardFace.new()
		portrait.setup(card, _card_texture(card))
		portrait.custom_minimum_size = Vector2(148, 250)
		portrait.tooltip_text = card.text
		column.add_child(portrait)
		var name_label = _label(column, card.name, 13, COLORS.get(card.color, GOLD))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func _label(parent: Control, text_value: String, font_size: int = 15, color: Color = Color("e4e7eb")) -> Label:
	var label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Control, text_value: String, callback: Callable, disabled: bool = false) -> Button:
	var button = Button.new()
	button.text = text_value
	button.disabled = disabled
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _view() -> Dictionary:
	if mode == 2 and not steam_bridge.is_host and not online_view.is_empty():
		return online_view
	return engine.player_view(_view_player(engine.state))

func _view_player(view: Dictionary) -> int:
	if mode == 2:
		return 0 if steam_bridge.is_host else 1
	if mode == 1 and view.phase == "action":
		return int(view.active_player)
	return local_player

func _actions(player: int) -> Array:
	return online_actions if mode == 2 and not steam_bridge.is_host else engine.legal_actions(player)

func _display_engine(view: Dictionary):
	if mode != 2 or steam_bridge.is_host:
		return engine
	var display = MatchEngine.new()
	display.state = view
	return display

func _select_card(index: int) -> void:
	var view = _view()
	selected_source = -1
	_inspect(str(view.players[_view_player(view)].hand[index]))
	for action in _actions(_view_player(view)):
		if action.type == "play" and int(action.hand) == index:
			if not action.has("target"):
				_act(action)
				return
			selected_hand = index
			notice = engine.library.cards[view.players[_view_player(view)].hand[index]].text + " Select a highlighted target."
			_render()
			return
	selected_hand = -1
	notice = "This card cannot be played now. Check your turn, lane hero color, mana, and available targets."
	_render()

func _target_unit(uid: int) -> void:
	if selected_source != -1:
		_choose_combat_destination(uid)
		return
	for action in _actions(_view_player(_view())):
		if action.type == "play" and int(action.hand) == selected_hand and int(action.get("target", -1)) == uid:
			if action.has("destination"):
				selected_source = uid
				notice = "Now choose this unit's combat target: a highlighted opposing unit or its opposing tower."
				_render()
				return
			_act(action)
			return

func _choose_combat_destination(uid: int) -> void:
	for action in _actions(_view_player(_view())):
		if action.type == "play" and int(action.hand) == selected_hand and int(action.get("target", -1)) == selected_source and int(action.get("destination", -1)) == uid:
			_act(action)
			return

func _act(command: Dictionary) -> void:
	var player = _view_player(_view())
	if mode == 2 and not steam_bridge.is_host:
		steam_bridge.send_command(command, int(online_view.revision))
		return
	var result = engine.apply_action(player, command)
	selected_hand = -1
	selected_source = -1
	if not result.ok:
		notice = result.error
	else:
		notice = "Two consecutive passes trigger simultaneous combat. The first passer keeps initiative."
		if mode == 1 and command.type in ["finish_shop", "finish_deployment"]:
			local_player = 1 - local_player
	if mode == 2:
		_send_online_state()
	_render()
	_schedule_bot()

func _schedule_bot() -> void:
	if mode == 0 and not engine.legal_actions(1).is_empty():
		bot_timer.start()

func _bot_step() -> void:
	if mode != 0:
		return
	var command = bot.choose_action(engine, 1)
	if not command.is_empty():
		engine.apply_action(1, command)
		_render()
		_schedule_bot()

func _new_match() -> void:
	if mode == 2 and not steam_bridge.is_host:
		notice = "Only the lobby host can start a new match."
		_render()
		return
	bot_timer.stop()
	current_seed += 1
	if engine.library.presets().is_empty():
		engine = MatchEngine.new()
	var result = engine.start(current_seed, deck_selections)
	if not result.ok:
		notice = result.error
		_render()
		return
	selected_hand = -1
	selected_source = -1
	local_player = 0
	notice = "New match · Seed %d · Play a card or pass." % current_seed
	if mode == 2:
		_send_online_state()
	_render()
	_schedule_bot()

func _change_mode(index: int) -> void:
	mode = index
	_new_match()

func _save_replay(path: String = "") -> void:
	if path.is_empty():
		path = "user://replays/match_%d_%d.json" % [current_seed, engine.state.revision]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		notice = "Could not save replay: " + error_string(FileAccess.get_open_error())
	else:
		file.store_string(JSON.stringify(engine.replay_data(), "\t"))
		file.close()
		notice = "Replay saved: " + ProjectSettings.globalize_path(path)
	_render()

func _open_replay() -> void:
	replay_dialog = FileDialog.new()
	replay_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	replay_dialog.access = FileDialog.ACCESS_FILESYSTEM
	replay_dialog.filters = PackedStringArray(["*.json ; Match replay"])
	replay_dialog.current_dir = ProjectSettings.globalize_path("user://replays")
	replay_dialog.file_selected.connect(_load_replay)
	replay_dialog.close_requested.connect(replay_dialog.queue_free)
	add_child(replay_dialog)
	replay_dialog.popup_centered_ratio(0.7)

func _load_replay(path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var candidate = MatchEngine.new()
	var result = candidate.load_replay(parsed) if parsed is Dictionary else {"ok": false, "error": "Invalid JSON replay."}
	if result.ok:
		bot_timer.stop()
		engine = candidate
		current_seed = int(parsed.seed)
		deck_selections = parsed.decks.duplicate()
		selected_hand = -1
		selected_source = -1
		local_player = 0
		mode = 1
		notice = "Replay restored at revision %d. Local two-player mode allows inspection and continuation." % engine.state.revision
	else:
		notice = result.error
	_render()
	if is_instance_valid(replay_dialog):
		replay_dialog.queue_free()

func _open_steam() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Steam development lobbies · Spacewar 480"
	dialog.min_size = Vector2i(490, 245)
	add_child(dialog)
	var column = VBoxContainer.new()
	dialog.add_child(column)
	var steam_message = steam_bridge.status
	_label(column, steam_message, 13, MUTED)
	if steam_bridge.available:
		_button(column, "Host friends-only lobby", steam_bridge.host_lobby)
		var lobby_input = LineEdit.new()
		lobby_input.placeholder_text = "Paste your friend's lobby ID"
		column.add_child(lobby_input)
		_button(column, "Join lobby", func(): steam_bridge.join_lobby(lobby_input.text))
		_button(column, "Invite Steam friends", steam_bridge.invite_friends, steam_bridge.lobby_id == 0)
	if steam_bridge.lobby_id != 0:
		_label(column, "Lobby: %d" % steam_bridge.lobby_id, 13, GOLD)
		_button(column, "Copy lobby ID", func(): DisplayServer.clipboard_set(str(steam_bridge.lobby_id)))
		_button(column, "Leave lobby", _leave_online)
	else:
		_label(column, "See docs/STEAM.md for optional GodotSteam setup.\nOffline play works with standard Godot.", 13, MUTED)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func _steam_status(message: String) -> void:
	notice = message
	if steam_bridge.lobby_id != 0 and steam_bridge.is_host and mode != 2:
		mode = 2
		bot_timer.stop()
		engine.start(current_seed, deck_selections)
		selected_hand = -1
		_send_online_state()
	_render()

func _send_online_state() -> void:
	steam_bridge.send_match(engine.player_view(1), engine.legal_actions(1))

func _online_state(view: Dictionary, actions: Array) -> void:
	mode = 2
	bot_timer.stop()
	online_view = view
	online_actions = actions
	selected_hand = -1
	selected_source = -1
	notice = "Connected to host. Player 2."
	_render()

func _online_command(command: Dictionary, revision: int) -> void:
	if not steam_bridge.is_host or mode != 2:
		return
	if revision == engine.state.revision:
		engine.apply_action(1, command)
	_send_online_state()
	_render()

func _leave_online() -> void:
	steam_bridge.leave_lobby()
	mode = 0
	online_view.clear()
	online_actions.clear()
	_new_match()
