extends Control
## The curved targeting arrow drawn while a card (or a redirected unit) is
## aimed: a bezier from the source to the cursor with an arrowhead and
## chevrons flowing toward the target. Gold over a legal target, pale
## otherwise.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const SAMPLES = 36

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var valid: bool = false
var tint: Color = UiKit.TARGET
var _phase: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_arrow(source: Vector2, target: Vector2, is_valid: bool, color: Color = UiKit.TARGET) -> void:
	var transform_inverse = get_global_transform().affine_inverse()
	from = transform_inverse * source
	to = transform_inverse * target
	valid = is_valid
	tint = color
	visible = true
	queue_redraw()

func hide_arrow() -> void:
	visible = false

func _process(delta: float) -> void:
	if visible:
		_phase = fmod(_phase + delta * 1.6, 1.0)
		queue_redraw()

func _point(t: float, control: Vector2) -> Vector2:
	var a = from.lerp(control, t)
	var b = control.lerp(to, t)
	return a.lerp(b, t)

func _draw() -> void:
	var distance = from.distance_to(to)
	if distance < 6.0:
		return
	var middle = (from + to) * 0.5
	var lift = minf(240.0, distance * 0.42)
	var control = middle + Vector2(0, -lift) + (to - from).orthogonal().normalized() * minf(40.0, distance * 0.08)
	var color = tint if valid else Color(0.88, 0.86, 0.8)
	var points = PackedVector2Array()
	for index in range(SAMPLES + 1):
		points.append(_point(float(index) / SAMPLES, control))
	# Stop the shaft short of the head.
	var shaft = points.slice(0, SAMPLES - 2)
	draw_polyline(shaft, Color(0, 0, 0, 0.35), 15.0, true)
	draw_polyline(shaft, Color(color, 0.22), 18.0, true)
	draw_polyline(shaft, Color(color, 0.9), 7.0, true)
	draw_polyline(shaft, Color(1, 1, 1, 0.55), 2.0, true)
	# Chevrons travelling along the curve.
	for step in range(6):
		var t = fmod(step / 6.0 + _phase / 6.0, 1.0) * 0.86
		var position = _point(t, control)
		var direction = (_point(minf(1.0, t + 0.02), control) - position).normalized()
		var side = direction.orthogonal() * 5.0
		draw_polyline(PackedVector2Array([position - direction * 5.0 + side, position, position - direction * 5.0 - side]),
			Color(1, 1, 1, 0.75), 2.0, true)
	# Arrowhead.
	var tip = to
	var back = (points[SAMPLES] - points[SAMPLES - 3]).normalized()
	var base = tip - back * 30.0
	var wing = back.orthogonal() * 17.0
	var head = PackedVector2Array([tip, base + wing, base + back * 8.0, base - wing])
	var shadow = PackedVector2Array()
	for point in head:
		shadow.append(point + Vector2(0, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	draw_colored_polygon(head, color)
	var outline = head.duplicate()
	outline.append(head[0])
	draw_polyline(outline, Color(0.12, 0.08, 0.03, 0.9), 2.0, true)
	if valid:
		draw_arc(to, 26.0 + 4.0 * sin(_phase * TAU), 0.0, TAU, 32, Color(color, 0.8), 3.0, true)
