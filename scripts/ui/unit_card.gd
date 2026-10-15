extends Control
## A unit on the board (hero or creep), 120x170 before the lane's scale.
##
## Colour bar (with weapon/armor/accessory slots for heroes), cropped art with
## a name ribbon, attack/armor/health badges (attack green when buffed, health
## red when damaged), active-ability and passive badges, up to four status,
## flag and keyword badges on the right edge (EFFECT_SYSTEM_SPEC.md §8.5), the
## combat arrow chevron on the river-facing edge, and the live damage preview:
## a red "-N" tag, plus grey art with a red cross and skull when the unit will
## die. Item slots whose item has an active ability are buttons (§8.3): they
## glow while it can be used and show the rounds left on its cooldown.

const Library = preload("res://scripts/core/card_library.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const SIZE = Vector2(120, 170)
const BAR_H = 20.0
const STATS_TOP = 132.0
const SLOT_ICONS = {"weapon": "sword", "armor": "shield", "accessory": "suit_hearts"}
const DAMAGED = Color("ff8a7a")
const MAX_BADGES = 4
const BADGE_RADIUS = 11.0
const BADGE_STEP = 24.0
const SLOTS = ["weapon", "armor", "accessory"]
const SLOT_SIZE = Vector2(22, 14)
const GREY_SHADER = """
shader_type canvas_item;
uniform float amount = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g) * 0.8, amount), c.a);
}
"""

## Display model from the board: unit, own, attack, armor, health,
## max_health, base_attack, base_armor, arrow, tower, damage, heal, dies,
## badges, keywords, abilities, mods, has_active, ability_ready, cooldown,
## passive, preview_hidden.
var model: Dictionary = {}
var uid: int = -1
var card_id: String = ""
var own: bool = true
## 0 none, 1 legal target, 2 hovered legal target, 3 chosen source (or the
## selected staged hero), 4 movable staged hero.
var target_state: int = 0
var hovered: bool = false
var flash: float = 0.0
var ghost: bool = false
## 0 resting on the table, 1 lifted (deployment staging, drags): a deeper,
## larger shadow.
var floating: float = 0.0
## Hides the combat preview (arrow, damage tag, death mark, grey art) even
## when the model has one; the lane sets it while a reveal plays.
var preview_hidden: bool = false:
	set(value):
		if preview_hidden != value:
			preview_hidden = value
			apply(model)
## 1 right after a status or modification lands, easing to 0 (badge pop).
var badge_pop: float = 0.0
## 0..1: the purple condemn mark drawn before a condemned unit is removed.
var condemn_mark: float = 0.0
var _pulse: float = 0.0
var _mark: Control
static var _grey: ShaderMaterial

func _init() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark = Control.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.size = SIZE
	_mark.draw.connect(_draw_death_mark)
	add_child(_mark)

func apply(display: Dictionary) -> void:
	model = display
	var unit: Dictionary = display.get("unit", {})
	uid = int(unit.get("uid", -1))
	card_id = str(unit.get("card", ""))
	own = display.get("own", true)
	material = _grey_material() if _marked_dying() else null
	_mark.queue_redraw()
	queue_redraw()

func refresh() -> void:
	queue_redraw()
	_mark.queue_redraw()

func is_hero() -> bool:
	return model.get("unit", {}).get("hero", false)

## True while no combat preview (arrow, damage, death) may be shown: the
## planning phase, a reveal in progress, ghost cards.
func hides_preview() -> bool:
	return ghost or preview_hidden or model.get("preview_hidden", false)

## Local rectangle of the active-ability badge (empty when there is none).
func ability_rect() -> Rect2:
	if not model.get("has_active", false):
		return Rect2()
	return Rect2(Vector2(3, BAR_H + 4), Vector2(26, 26))

func ability_hit(global_point: Vector2) -> bool:
	var rect = ability_rect()
	if rect.size == Vector2.ZERO:
		return false
	return rect.has_point(get_global_transform().affine_inverse() * global_point)

## Local rectangle of the item slot `slot` in the colour bar (heroes only).
func item_rect(slot: String) -> Rect2:
	var index = SLOTS.find(slot)
	if index == -1 or not is_hero():
		return Rect2()
	var left = SIZE.x * 0.5 - SLOT_SIZE.x * 1.5 - 3.0
	return Rect2(Vector2(left + index * (SLOT_SIZE.x + 3.0), 3), SLOT_SIZE)

## The item slot under `global_point` whose item has an active ability ("" if
## none): a little larger than the slot, so it is easy to hit.
func item_hit(global_point: Vector2) -> String:
	var local = get_global_transform().affine_inverse() * global_point
	for slot in SLOTS:
		if not item_ability(slot).is_empty() and item_rect(slot).grow(3.0).has_point(local):
			return slot
	return ""

## The model's ability entry of the item in `slot` ({source, card, cd, ready}),
## or {} when that item has no active ability.
func item_ability(slot: String) -> Dictionary:
	var unit: Dictionary = model.get("unit", {})
	if not unit.get("items", {}).has(slot):
		return {}
	var oid = int(unit.get("item_state", {}).get(slot, {}).get("oid", -1))
	for entry in model.get("abilities", []):
		if int(entry.get("source", -2)) == oid:
			return entry
	return {}

## The item oid in `slot` (-1 when empty).
func item_oid(slot: String) -> int:
	return int(model.get("unit", {}).get("item_state", {}).get(slot, {}).get("oid", -1))

## The badge kinds drawn on the right edge, in order ("more" for the +n disc).
func badge_kinds() -> Array:
	var badges: Array = model.get("badges", [])
	var shown = badges.size() if badges.size() <= MAX_BADGES else MAX_BADGES - 1
	var out: Array = []
	for index in range(shown):
		out.append(str(badges[index].get("k", "")))
	if badges.size() > shown:
		out.append("more")
	return out

func _items_ready() -> bool:
	for entry in model.get("abilities", []):
		if entry.get("ready", false) and int(entry.get("source", -1)) != uid:
			return true
	return false

## Global position of the chevron tip (where attacks leave the card).
func front_point() -> Vector2:
	var local = Vector2(SIZE.x * 0.5, -6.0 if own else SIZE.y + 6.0)
	return get_global_transform() * local

func _process(delta: float) -> void:
	if target_state != 0 or model.get("ability_ready", false) or _items_ready():
		_pulse = fmod(_pulse + delta * 3.0, TAU)
		queue_redraw()

func _grey_material() -> ShaderMaterial:
	if _grey == null:
		var shader = Shader.new()
		shader.code = GREY_SHADER
		_grey = ShaderMaterial.new()
		_grey.shader = shader
	return _grey

func _draw() -> void:
	if model.is_empty():
		return
	var unit: Dictionary = model.unit
	var rect = Rect2(Vector2.ZERO, SIZE)
	var color_id = str(unit.get("color", "neutral"))
	var bar_color = UiKit.card_color(color_id)
	var alpha = 0.55 if ghost else 1.0
	match target_state:
		1:
			UiKit.draw_glow(self, rect, 8.0, UiKit.TARGET, 0.7 + 0.3 * sin(_pulse))
		2:
			UiKit.draw_glow(self, rect, 8.0, UiKit.GOLD_BRIGHT, 1.6)
		3:
			UiKit.draw_glow(self, rect, 8.0, UiKit.PLAYABLE, 1.4)
		4:
			UiKit.draw_glow(self, rect, 8.0, UiKit.PLAYABLE, 0.8)
	# Shadow (deeper and larger while the card floats) and body.
	var shadow = Rect2(rect.position + Vector2(0, lerpf(5.0, 14.0, floating)), rect.size).grow(6.0 * floating)
	draw_colored_polygon(UiKit.round_rect_points(shadow, 8.0 + 6.0 * floating), Color(0, 0, 0, lerpf(0.4, 0.55, floating) * alpha))
	UiKit.draw_round_rect(self, rect, Color(0.09, 0.085, 0.08, alpha), 8.0)
	var art_rect = Rect2(2, BAR_H, SIZE.x - 4, STATS_TOP - BAR_H)
	var real_art = CardArt.draw(self, art_rect, card_id, true, Color(1, 1, 1, alpha))
	# Dying units get their name on the unshaded overlay, above the cross.
	if real_art and not _marked_dying():
		_draw_name(self, alpha)
	# Colour bar with item slots for heroes.
	draw_colored_polygon(_top_bar_points(), Color(bar_color, alpha))
	draw_line(Vector2(0, BAR_H), Vector2(SIZE.x, BAR_H), Color(0, 0, 0, 0.5), 1.5)
	if unit.get("hero", false):
		_draw_slots(unit.get("items", {}), alpha)
	elif UiKit.is_zh() and Library.current_skin() == "three_kingdoms" and Library.faction(card_id) != "neutral":
		UiKit.draw_text(self, UiKit.title_font(), UiKit.faction_seal(card_id), Vector2(SIZE.x * 0.5, BAR_H * 0.5), 13, Color(UiKit.PAPER, 0.8 * alpha))
	# Stats.
	var stats_rect = Rect2(0, STATS_TOP, SIZE.x, SIZE.y - STATS_TOP)
	draw_colored_polygon(_bottom_points(stats_rect), Color(UiKit.card_color_dark(color_id).darkened(0.15), alpha))
	draw_line(Vector2(0, STATS_TOP), Vector2(SIZE.x, STATS_TOP), Color(0, 0, 0, 0.6), 1.5)
	_draw_stats(stats_rect, alpha)
	_draw_badges(unit, alpha)
	UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, 8.0, Color(bar_color.lightened(0.25), alpha), 2.0)
	if hovered:
		UiKit.draw_round_rect(self, rect.grow(1), Color.TRANSPARENT, 9.0, Color(1, 1, 1, 0.55), 1.5)
	if flash > 0.0:
		UiKit.draw_round_rect(self, rect, Color(1, 0.93, 0.8, flash * 0.42), 8.0)
	if not hides_preview():
		_draw_arrow()

func _marked_dying() -> bool:
	return model.get("dies", false) and not hides_preview()

func _draw_name(canvas: CanvasItem, alpha: float) -> void:
	UiKit.draw_vgradient(canvas, Rect2(2, STATS_TOP - 30, SIZE.x - 4, 30), Color(0, 0, 0, 0), Color(0, 0, 0, 0.82 * alpha))
	# At overview scale the name grows in card space so it stays legible
	# (about 10 px on screen), shrinking only to fit the card's width.
	var font_size = int(maxf(15.0, 10.5 / maxf(0.3, scale.x)))
	UiKit.draw_text(canvas, UiKit.title_font(), Library.loc(card_id), Vector2(SIZE.x * 0.5, STATS_TOP - 11), font_size,
		Color(UiKit.PAPER, alpha * (0.88 if _marked_dying() else 1.0)), SIZE.x - 10, 4, Color(0, 0, 0, 0.9))

func _top_bar_points() -> PackedVector2Array:
	var points = PackedVector2Array()
	var radius = 8.0
	for step in range(5):
		var angle = PI + PI * 0.5 * step / 4.0
		points.append(Vector2(radius, radius) + Vector2(cos(angle), sin(angle)) * radius)
	for step in range(5):
		var angle = PI * 1.5 + PI * 0.5 * step / 4.0
		points.append(Vector2(SIZE.x - radius, radius) + Vector2(cos(angle), sin(angle)) * radius)
	points.append(Vector2(SIZE.x, BAR_H))
	points.append(Vector2(0, BAR_H))
	return points

func _bottom_points(rect: Rect2) -> PackedVector2Array:
	var points = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
	var radius = 8.0
	for step in range(5):
		var angle = PI * 0.5 * step / 4.0
		points.append(Vector2(rect.end.x - radius, rect.end.y - radius) + Vector2(cos(angle), sin(angle)) * radius)
	for step in range(5):
		var angle = PI * 0.5 + PI * 0.5 * step / 4.0
		points.append(Vector2(rect.position.x + radius, rect.end.y - radius) + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw_slots(items: Dictionary, alpha: float) -> void:
	for slot in SLOTS:
		var rect = item_rect(slot)
		var filled = items.has(slot)
		var ability = item_ability(slot) if filled else {}
		var ready = ability.get("ready", false)
		var cooldown = int(ability.get("cd", 0))
		if ready:
			UiKit.draw_glow(self, rect, 3.0, UiKit.PLAYABLE, 0.75 + 0.3 * sin(_pulse))
		var rim = Color(UiKit.GOLD_BRIGHT, alpha) if filled else Color(1, 1, 1, 0.22 * alpha)
		if ready:
			rim = Color(UiKit.PLAYABLE, alpha)
		UiKit.draw_round_rect(self, rect, Color(UiKit.card_color("item"), alpha) if filled else Color(0, 0, 0, 0.35 * alpha), 2.0,
			rim, 1.5 if not ability.is_empty() else 1.0)
		UiKit.draw_icon(self, SLOT_ICONS[slot], Rect2(rect.get_center() - Vector2(5, 5), Vector2(10, 10)),
			Color(0.12, 0.08, 0.02, alpha) if filled else Color(1, 1, 1, 0.38 * alpha))
		if cooldown > 0:
			UiKit.draw_round_rect(self, rect, Color(0.02, 0.02, 0.03, 0.62 * alpha), 2.0)
			UiKit.draw_text(self, UiKit.bold_font(), str(cooldown), rect.get_center(), 12, Color(UiKit.PAPER, alpha), -1.0, 2)
		elif not ability.is_empty():
			# A small book mark: this item has an ability to use.
			draw_circle(rect.position + Vector2(rect.size.x - 1.0, 1.0), 3.5, Color(UiKit.PLAYABLE if ready else UiKit.PAPER_DIM, alpha))

func _draw_stats(rect: Rect2, alpha: float) -> void:
	var unit: Dictionary = model.unit
	var attack = int(model.get("attack", unit.get("attack", 0)))
	var armor = int(model.get("armor", unit.get("armor", 0)))
	var health = int(model.get("health", unit.get("health", 0)))
	var max_health = int(model.get("max_health", health))
	var attack_color = UiKit.BUFF if attack > int(model.get("base_attack", attack)) else UiKit.PAPER
	if attack < int(model.get("base_attack", attack)):
		attack_color = UiKit.DAMAGE
	var armor_color = UiKit.BUFF if armor > int(model.get("base_armor", armor)) else (UiKit.DAMAGE if armor < int(model.get("base_armor", armor)) else UiKit.PAPER)
	# Damaged health is a light coral (not dark red) so it reads on the badge.
	var health_color = DAMAGED if health < max_health else (UiKit.BUFF if max_health > int(unit.get("max_health", max_health)) else UiKit.PAPER)
	var center_y = rect.get_center().y + 1.0
	var badge = Color(0.13, 0.13, 0.14, 0.95 * alpha)
	var rim = Color(0.8, 0.77, 0.71, alpha)
	# Attack: round badge with a sword behind the number.
	var attack_center = Vector2(22, center_y)
	draw_circle(attack_center, 15.0, rim)
	draw_circle(attack_center, 13.5, badge)
	UiKit.draw_icon(self, "sword", Rect2(attack_center - Vector2(11, 11), Vector2(22, 22)), Color(1, 1, 1, 0.13 * alpha))
	UiKit.draw_text(self, UiKit.bold_font(), str(attack), attack_center, 19, Color(attack_color, alpha), -1.0, 3)
	# Armor: shield.
	var armor_center = Vector2(60, center_y)
	UiKit.draw_icon(self, "shield", Rect2(armor_center - Vector2(15, 15), Vector2(30, 30)), rim)
	UiKit.draw_icon(self, "shield", Rect2(armor_center - Vector2(13, 13), Vector2(26, 26)), badge)
	UiKit.draw_text(self, UiKit.bold_font(), str(armor), armor_center + Vector2(0, -1), 17, Color(armor_color, alpha), -1.0, 3)
	# Health: heart.
	var health_center = Vector2(98, center_y)
	UiKit.draw_icon(self, "suit_hearts", Rect2(health_center - Vector2(16, 15), Vector2(32, 30)), rim)
	UiKit.draw_icon(self, "suit_hearts", Rect2(health_center - Vector2(14, 13), Vector2(28, 26)), badge)
	UiKit.draw_text(self, UiKit.bold_font(), str(health), health_center + Vector2(0, -2), 18, Color(health_color, alpha), -1.0, 4, Color(0, 0, 0, 0.95))

func _draw_badges(unit: Dictionary, alpha: float) -> void:
	var y = BAR_H + 17.0
	if model.get("has_active", false):
		var center = Vector2(16, y)
		var ready = model.get("ability_ready", false)
		var cooldown = int(model.get("cooldown", unit.get("cooldown", 0)))
		if ready:
			draw_circle(center, 16.0 + 2.0 * sin(_pulse), Color(UiKit.PLAYABLE, 0.35))
		UiKit.draw_disc(self, center, 12.0, Color(0.1, 0.16, 0.22, alpha) if cooldown == 0 else Color(0.12, 0.12, 0.12, alpha),
			UiKit.PLAYABLE if ready else Color(0.55, 0.55, 0.55, alpha), 2.0)
		UiKit.draw_icon(self, "book_open", Rect2(center - Vector2(7, 7), Vector2(14, 14)), Color(1, 1, 1, alpha if cooldown == 0 else 0.35 * alpha))
		if cooldown > 0:
			UiKit.draw_text(self, UiKit.bold_font(), str(cooldown), center, 15, Color(UiKit.PAPER, alpha), -1.0, 3)
		y += 28.0
	if model.get("passive", false):
		var center = Vector2(16, y)
		UiKit.draw_disc(self, center, 10.0, Color(0.16, 0.13, 0.08, alpha), Color(UiKit.GOLD, alpha), 1.5)
		UiKit.draw_icon(self, "flag_triangle", Rect2(center - Vector2(6, 6), Vector2(12, 12)), Color(UiKit.GOLD_BRIGHT, alpha))
	# Statuses, flags and keywords on the right edge: up to four, then +n.
	var badges: Array = model.get("badges", [])
	var shown = badges.size() if badges.size() <= MAX_BADGES else MAX_BADGES - 1
	var radius = BADGE_RADIUS * (1.0 + 0.45 * badge_pop)
	for index in range(shown):
		var badge: Dictionary = badges[index]
		UiKit.draw_badge(self, str(badge.get("k", "")), int(badge.get("v", 1)), _badge_center(index), radius, alpha)
	if badges.size() > shown:
		var center = _badge_center(shown)
		UiKit.draw_disc(self, center, BADGE_RADIUS, Color(0.12, 0.12, 0.13, alpha), Color(0.7, 0.7, 0.7, alpha), 1.5)
		UiKit.draw_text(self, UiKit.bold_font(), "+%d" % (badges.size() - shown), center, 12, Color(UiKit.PAPER, alpha), -1.0, 2)

func _badge_center(index: int) -> Vector2:
	return Vector2(SIZE.x - 15.0, BAR_H + 16.0 + index * BADGE_STEP)

## Badge tooltip text (BADGE_* in ui.csv), for hover and inspect.
static func badge_text(badge: Dictionary) -> String:
	return UiKit.t_n("BADGE_" + str(badge.get("k", "")).to_upper(), int(badge.get("v", 1)))

## Redraws both layers (the badge pop and the condemn mark animate these).
func set_badge_pop(value: float) -> void:
	badge_pop = value
	queue_redraw()

func set_condemn_mark(value: float) -> void:
	condemn_mark = value
	_mark.queue_redraw()

## Combat arrow on the river-facing edge: a short arrow pointing straight
## ahead or diagonally at the target; gold-red when it will hit the tower.
func _draw_arrow() -> void:
	var column_offset = int(model.get("arrow", 0))
	var toward = -1.0 if own else 1.0
	var direction = Vector2(column_offset, toward).normalized()
	var base = Vector2(SIZE.x * 0.5 + column_offset * 34.0, (-3.0 if own else SIZE.y + 3.0))
	var side = direction.orthogonal()
	var neck = base + direction * 5.0
	var tip = base + direction * 17.0
	var left = neck + side * 8.0
	var right = neck - side * 8.0
	var tail = base - direction * 5.0
	var color = Color("ffb35c") if model.get("tower", false) else Color(0.96, 0.94, 0.9)
	var outline = Color(0.12, 0.07, 0.03, 0.9)
	draw_line(tail + Vector2(0, 2), neck + Vector2(0, 2), Color(0, 0, 0, 0.5), 6.0, true)
	draw_line(tail, neck, outline, 6.0, true)
	draw_line(tail, neck, color, 3.5, true)
	var head = PackedVector2Array([tip, left, right])
	var shadow = PackedVector2Array()
	for point in head:
		shadow.append(point + Vector2(0, 2))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
	draw_colored_polygon(head, color)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), outline, 1.5, true)

func _draw_damage_tag() -> void:
	var damage = int(model.get("damage", 0))
	if damage <= 0 or hides_preview():
		return
	var text = "-%d" % damage
	var font = UiKit.bold_font()
	var width = maxf(26.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10.0)
	var rect = Rect2(Vector2(SIZE.x - width * 0.55, SIZE.y - 12), Vector2(width, 20))
	UiKit.draw_round_rect(_mark, rect, Color("a3221b"), 3.0, Color("ff8a70"), 1.0)
	UiKit.draw_text(_mark, font, text, rect.get_center(), 15, Color.WHITE)

## Drawn on an unshaded child so it stays red on greyed (dying) cards.
func _draw_death_mark() -> void:
	_draw_damage_tag()
	if condemn_mark > 0.0:
		_draw_condemn_mark()
	if not _marked_dying():
		return
	var center = Vector2(SIZE.x * 0.5, (BAR_H + STATS_TOP) * 0.5)
	var arm = 40.0
	for sign_value in [-1.0, 1.0]:
		var a = center + Vector2(-arm, -arm * 1.1 * sign_value)
		var b = center + Vector2(arm, arm * 1.1 * sign_value)
		_mark.draw_line(a + Vector2(0, 2), b + Vector2(0, 2), Color(0, 0, 0, 0.45), 9.0, true)
		_mark.draw_line(a, b, Color("d42a22"), 7.0, true)
	_mark.draw_circle(center, 15.0, Color(0, 0, 0, 0.55))
	UiKit.draw_icon(_mark, "skull", Rect2(center - Vector2(12, 12), Vector2(24, 24)), Color("f1e9dc"))
	if not CardArt.art(card_id).is_empty():
		_draw_name(_mark, 1.0)

## Condemn: a purple brush stroke across the art, drawn in as `condemn_mark`
## grows (the death animation follows at the sync).
func _draw_condemn_mark() -> void:
	var center = Vector2(SIZE.x * 0.5, (BAR_H + STATS_TOP) * 0.5)
	var start = center + Vector2(-46, 40)
	var finish = start.lerp(center + Vector2(46, -40), condemn_mark)
	var purple = Color("b157e6")
	_mark.draw_line(start + Vector2(0, 2), finish + Vector2(0, 2), Color(0, 0, 0, 0.45), 11.0, true)
	_mark.draw_line(start, finish, Color(purple, 0.92), 8.0, true)
	_mark.draw_circle(center, 13.0 * condemn_mark, Color(0.1, 0.02, 0.14, 0.6 * condemn_mark))
	UiKit.draw_icon(_mark, "skull", Rect2(center - Vector2(10, 10) * condemn_mark, Vector2(20, 20) * condemn_mark), Color(purple.lightened(0.4), condemn_mark))
