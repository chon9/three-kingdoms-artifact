extends TextureRect
## Original Valve artwork with native UI corrections for pre-patch card fronts.
## PNGs are unchanged; the displayed rules and stats use the supported catalog.

var definition: Dictionary = {}
var correction: ColorRect
var correction_label: Label

func setup(card: Dictionary, card_texture: Texture2D) -> void:
	definition = card
	texture = card_texture
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if texture == null or not card.has("image_patch"):
		return
	correction = ColorRect.new()
	correction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	correction.color = Color("a82e3d") if card.image_patch == "stats" else (Color("9a7f27") if card.image_patch == "price" else Color("111214"))
	correction.clip_contents = true
	add_child(correction)
	correction_label = Label.new()
	correction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	correction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	correction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	correction_label.add_theme_color_override("font_color", Color.WHITE)
	correction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	correction_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	correction_label.text = "%d / %d / %d" % [card.attack, card.armor, card.health] if card.image_patch == "stats" else (str(card.price) if card.image_patch == "price" else str(card.text))
	correction.add_child(correction_label)
	if not resized.is_connected(_position_correction):
		resized.connect(_position_correction)
	call_deferred("_position_correction")

func _position_correction() -> void:
	if not is_instance_valid(correction) or texture == null:
		return
	var ratio = float(texture.get_width()) / float(texture.get_height())
	var draw_height = minf(size.y, size.x / ratio)
	var draw_width = draw_height * ratio
	var origin = (size - Vector2(draw_width, draw_height)) * 0.5
	if definition.image_patch == "stats":
		correction.position = origin + Vector2(draw_width * 0.07, draw_height * 0.905)
		correction.size = Vector2(draw_width * 0.86, draw_height * 0.075)
		correction_label.add_theme_font_size_override("font_size", maxi(7, int(draw_height * 0.04)))
	elif definition.image_patch == "price":
		correction.position = origin + Vector2(draw_width * 0.852, draw_height * 0.925)
		correction.size = Vector2(draw_width * 0.12, draw_height * 0.055)
		correction_label.add_theme_font_size_override("font_size", maxi(9, int(draw_height * 0.038)))
	else:
		correction.position = origin + Vector2(draw_width * 0.06, draw_height * 0.615)
		correction.size = Vector2(draw_width * 0.88, draw_height * 0.32)
		correction_label.add_theme_font_size_override("font_size", maxi(8, int(draw_height * 0.024)))
