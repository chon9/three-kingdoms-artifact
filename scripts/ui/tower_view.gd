extends Control
## A lane structure on its wall: mana box (current over max) on the left, the
## tower or ancient emblem in the middle, health on the right, and the red
## pending-damage tag. It doubles as the Battlefield Control "tower" target.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const SIZE = Vector2(250, 74)
## Medallion glyphs (Sanguo Kai): a walled city for the tower, the capital
## for the ancient. assets/art/ui/tower_ally.png / tower_enemy.png (and
## ancient_ally.png / ancient_enemy.png) replace them when present.
const TOWER_GLYPH = "城"
const ANCIENT_GLYPH = "都"

var own: bool = true
var health: int = 40
var ancient: bool = false
var destroyed: bool = false
var mana: int = 3
var max_mana: int = 3
var pending: int = 0
var will_fall: bool = false
## 0 none, 1 legal target, 2 hovered target.
var target_state: int = 0
var shake: float = 0.0
var flash: float = 0.0
var _pulse: float = 0.0

func _init() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func apply(structure: Dictionary, lane_mana: int, lane_max_mana: int, damage: int) -> void:
	health = int(structure.get("health", 40))
	ancient = structure.get("ancient", false)
	destroyed = structure.get("destroyed", false)
	mana = lane_mana
	max_mana = lane_max_mana
	pending = damage
	will_fall = damage > 0 and damage >= health
	queue_redraw()

func emblem_center() -> Vector2:
	return get_global_transform() * Vector2(SIZE.x * 0.5, SIZE.y * 0.5)

func _process(delta: float) -> void:
	if target_state != 0:
		_pulse = fmod(_pulse + delta * 3.0, TAU)
		queue_redraw()

func _draw() -> void:
	var offset = Vector2(sin(shake * 40.0) * shake * 6.0, 0)
	draw_set_transform(offset)
	var center = SIZE * 0.5
	var tint = UiKit.ALLY_TINT if own else UiKit.ENEMY_TINT
	if target_state > 0:
		draw_circle(center, 44.0 + 3.0 * sin(_pulse), Color(UiKit.TARGET, 0.25 if target_state == 1 else 0.5))
	# Mana box.
	var mana_rect = Rect2(center.x - 106, center.y - 31, 52, 62)
	_panel(mana_rect)
	UiKit.draw_text(self, UiKit.bold_font(), str(mana), mana_rect.position + Vector2(26, 16), 21, Color("cfe9ff"), -1.0, 2)
	draw_line(mana_rect.position + Vector2(12, 31), mana_rect.position + Vector2(40, 31), Color(1, 1, 1, 0.55), 2.0)
	UiKit.draw_text(self, UiKit.bold_font(), str(max_mana), mana_rect.position + Vector2(26, 46), 21, Color("cfe9ff"), -1.0, 2)
	# Health box.
	var health_rect = Rect2(center.x + 44, center.y - 31, 66, 62)
	_panel(health_rect, Color(UiKit.GOLD, 0.9) if ancient else Color(0.55, 0.52, 0.47))
	var health_color = UiKit.PAPER if not destroyed else UiKit.MUTED
	UiKit.draw_text(self, UiKit.bold_font(), str(health), health_rect.get_center(), 30, health_color, health_rect.size.x - 6, 3)
	# Emblem.
	draw_circle(center + Vector2(0, 3), 37.0, Color(0, 0, 0, 0.5))
	draw_circle(center, 36.0, Color(0.32, 0.3, 0.27))
	draw_circle(center, 33.0, tint.darkened(0.55))
	draw_arc(center, 33.0, 0.0, TAU, 40, Color(UiKit.GOLD, 0.9), 2.0, true)
	draw_arc(center, 27.0, 0.0, TAU, 40, Color(UiKit.GOLD_DARK, 0.6), 1.0, true)
	var art = UiKit.tex("res://assets/art/ui/%s_%s.png" % ["ancient" if ancient else "tower", "ally" if own else "enemy"])
	if art != null:
		UiKit.draw_cover(self, art, Rect2(center - Vector2(31, 31), Vector2(62, 62)), Vector2(0.5, 0.5),
			Color.WHITE if not destroyed else Color(0.5, 0.5, 0.5))
	else:
		var glyph = ANCIENT_GLYPH if ancient else TOWER_GLYPH
		UiKit.draw_text(self, UiKit.kai_font(), glyph, center + Vector2(0, 2), 38, Color(0, 0, 0, 0.45))
		UiKit.draw_text(self, UiKit.kai_font(), glyph, center, 38, UiKit.GOLD_BRIGHT if not destroyed else UiKit.MUTED, -1.0, 3)
	if will_fall:
		draw_line(center + Vector2(-22, -22), center + Vector2(22, 22), Color("d42a22"), 6.0, true)
		draw_line(center + Vector2(22, -22), center + Vector2(-22, 22), Color("d42a22"), 6.0, true)
	if pending > 0:
		var text = "-%d" % pending
		var width = maxf(34.0, UiKit.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 12.0)
		var tag = Rect2(health_rect.end.x - 6, health_rect.position.y + 6, width, 28)
		UiKit.draw_round_rect(self, tag, Color("a3221b"), 3.0, Color("ff8a70"), 1.0)
		UiKit.draw_text(self, UiKit.bold_font(), text, tag.get_center(), 20, Color.WHITE)
	if flash > 0.0:
		draw_circle(center, 40.0, Color(1, 0.9, 0.7, flash * 0.6))
	draw_set_transform(Vector2.ZERO)

func _panel(rect: Rect2, rim: Color = Color(0.55, 0.52, 0.47)) -> void:
	draw_colored_polygon(UiKit.round_rect_points(Rect2(rect.position + Vector2(0, 3), rect.size), 7.0), Color(0, 0, 0, 0.45))
	UiKit.draw_round_rect(self, rect, Color(0.1, 0.1, 0.11, 0.95), 7.0, rim, 2.0)
	UiKit.draw_vgradient(self, Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, rect.size.y * 0.4)), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0))
