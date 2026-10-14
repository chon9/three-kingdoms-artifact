extends Control
## Transient effects drawn above the board: floating damage numbers,
## particle bursts (Kenney Particle Pack), phase banners, screen shake and
## the large card shown while a played card resolves. Every effect respects
## AnimationQueue.speed and does nothing when AnimationQueue.instant is set.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")

var cast_card: Control

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point

## A number that pops, rises and fades ("-4" red, "+2" green).
func float_text(global_point: Vector2, text: String, color: Color, font_size: int = 30, rise: float = 64.0) -> void:
	if AnimationQueue.instant or not is_inside_tree():
		return
	var label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_override("font", UiKit.bold_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	label.add_theme_constant_override("outline_size", maxi(4, int(font_size * 0.22)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var label_size = label.get_minimum_size()
	label.size = label_size
	label.pivot_offset = label_size * 0.5
	label.position = _local(global_point) - label_size * 0.5
	label.scale = Vector2(0.4, 0.4)
	var tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), AnimationQueue.duration(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, AnimationQueue.duration(0.08))
	tween.parallel().tween_property(label, "position:y", label.position.y - rise, AnimationQueue.duration(0.9)).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, AnimationQueue.duration(0.35))
	tween.tween_callback(label.queue_free)

## Particle burst: "death", "hit", "cast", "tower", "gold", "heal".
func burst(global_point: Vector2, kind: String, scale_factor: float = 1.0) -> void:
	if AnimationQueue.instant or not is_inside_tree():
		return
	var specs = {
		"death": [["smoke_04", 14, Color(0.75, 0.72, 0.68, 0.7), 0.9, 0.35, false], ["spark_04", 10, Color(1.0, 0.55, 0.3, 0.9), 0.6, 0.18, true]],
		"hit": [["slash_02", 1, Color(1, 0.92, 0.8, 0.95), 0.28, 0.45, true], ["spark_01", 8, Color(1, 0.8, 0.5, 0.9), 0.4, 0.12, true]],
		"cast": [["magic_03", 6, Color(0.6, 0.85, 1.0, 0.85), 0.7, 0.3, true], ["twirl_01", 2, Color(0.9, 0.8, 1.0, 0.7), 0.6, 0.6, true]],
		"tower": [["flame_03", 12, Color(1.0, 0.55, 0.2, 0.9), 0.8, 0.35, true], ["smoke_01", 10, Color(0.4, 0.38, 0.35, 0.7), 1.2, 0.5, false]],
		"gold": [["star_06", 10, Color(1.0, 0.85, 0.35, 0.95), 0.7, 0.12, true]],
		"heal": [["star_01", 10, Color(0.5, 1.0, 0.6, 0.9), 0.7, 0.12, true]]}
	for spec in specs.get(kind, specs.hit):
		var particles = CPUParticles2D.new()
		particles.texture = UiKit.particle(spec[0])
		particles.amount = spec[1]
		particles.lifetime = spec[3]
		particles.one_shot = true
		particles.explosiveness = 0.92
		particles.spread = 180.0
		particles.gravity = Vector2(0, -30)
		particles.initial_velocity_min = 30.0 * scale_factor
		particles.initial_velocity_max = 150.0 * scale_factor
		particles.scale_amount_min = spec[4] * 0.6 * scale_factor
		particles.scale_amount_max = spec[4] * scale_factor
		particles.angle_min = -180.0
		particles.angle_max = 180.0
		particles.color = spec[2]
		var ramp = Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		particles.color_ramp = ramp
		particles.speed_scale = AnimationQueue.speed
		if spec[5]:
			var additive = CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			particles.material = additive
		particles.position = _local(global_point)
		add_child(particles)
		particles.emitting = true
		particles.finished.connect(particles.queue_free)

## Big brush-stroke banner across the screen ("Combat", "Victory", ...),
## centred on `center_y` (global; the lane's river) or the middle.
func banner(text: String, color: Color = UiKit.GOLD_BRIGHT, hold: float = 0.6, font_size: int = 64, center_y: float = -1.0) -> void:
	if AnimationQueue.instant or not is_inside_tree():
		return
	var strip = Banner.new()
	strip.text = text
	strip.color = color
	strip.font_size = font_size
	strip.size = Vector2(size.x, font_size * 1.32)
	var middle = _local(Vector2(0, center_y)).y if center_y >= 0.0 else size.y * 0.42
	strip.position = Vector2(0, middle - strip.size.y * 0.5)
	strip.modulate.a = 0.0
	add_child(strip)
	var tween = strip.create_tween()
	tween.tween_property(strip, "modulate:a", 1.0, AnimationQueue.duration(0.16))
	tween.parallel().tween_property(strip, "reveal", 1.0, AnimationQueue.duration(0.28)).from(0.0)
	tween.tween_interval(AnimationQueue.duration(hold))
	tween.tween_property(strip, "modulate:a", 0.0, AnimationQueue.duration(0.3))
	tween.tween_callback(strip.queue_free)

## Shakes a control around its current position.
func shake(target: Control, strength: float = 10.0, time: float = 0.35) -> void:
	if AnimationQueue.instant or target == null:
		return
	var origin = target.position
	var tween = target.create_tween()
	var steps = 7
	for step in range(steps):
		var falloff = 1.0 - float(step) / steps
		tween.tween_property(target, "position", origin + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff,
			AnimationQueue.duration(time / steps))
	tween.tween_property(target, "position", origin, AnimationQueue.duration(0.05))

## Shows a played card large on the right side while it resolves.
func show_cast(card_id: String, from_global: Vector2, hold: float) -> Tween:
	clear_cast()
	if AnimationQueue.instant or not is_inside_tree():
		return null
	var card = CardView.new()
	card.setup(card_id)
	card.set_size_keep(Vector2(250, 364))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	cast_card = card
	var rest = Vector2(size.x - 330, size.y * 0.42 - 182)
	card.position = _local(from_global) - card.size * 0.5
	card.scale = Vector2(0.45, 0.45)
	card.modulate.a = 0.0
	var tween = card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", rest, AnimationQueue.duration(0.3))
	tween.parallel().tween_property(card, "scale", Vector2.ONE, AnimationQueue.duration(0.3))
	tween.parallel().tween_property(card, "modulate:a", 1.0, AnimationQueue.duration(0.18))
	tween.tween_interval(AnimationQueue.duration(hold))
	tween.tween_property(card, "modulate:a", 0.0, AnimationQueue.duration(0.25))
	tween.tween_callback(clear_cast)
	burst(get_global_transform() * (rest + card.size * 0.5), "cast", 1.4)
	return tween

func clear_cast() -> void:
	if is_instance_valid(cast_card):
		UiKit.discard(cast_card)
	cast_card = null

## A brush-stroke strip with large calligraphy text.
class Banner:
	extends Control
	var text: String = ""
	var color: Color = Color.WHITE
	var font_size: int = 64
	var reveal: float = 1.0:
		set(value):
			reveal = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center = size * 0.5
		var width = size.x * 0.66 * reveal
		# A dark scrim with feathered ends, gold rules on its edges, and the
		# text fully opaque with a heavy outline so it reads over any board.
		var stroke = Rect2(center.x - width * 0.5, 0, width, size.y)
		var feather = width * 0.22
		var scrim = Color(0.02, 0.02, 0.03, 0.78)
		UiKit.draw_hgradient(self, Rect2(stroke.position, Vector2(feather, stroke.size.y)), Color(scrim, 0.0), scrim)
		draw_rect(Rect2(stroke.position + Vector2(feather, 0), Vector2(width - feather * 2.0, stroke.size.y)), scrim)
		UiKit.draw_hgradient(self, Rect2(Vector2(stroke.end.x - feather, 0), Vector2(feather, stroke.size.y)), scrim, Color(scrim, 0.0))
		for y in [1.0, size.y - 1.0]:
			draw_line(Vector2(stroke.position.x + width * 0.14, y), Vector2(stroke.end.x - width * 0.14, y), Color(color, 0.7), 2.0)
		UiKit.draw_text(self, UiKit.title_font(), text, center, font_size, Color(color, 1.0), size.x * 0.8, maxi(6, int(font_size * 0.14)),
			Color(0.06, 0.02, 0.0, 0.95))
