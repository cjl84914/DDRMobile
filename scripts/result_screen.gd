extends Control
## DDR 2ndMIX style results screen.
##
## Presentation only: main.gd owns the run and pushes a finished snapshot in
## with `show_result`. Layout is authored in a 1280x720 design space that is
## scaled and centred inside the real viewport, so every helper takes design
## units and converts at the end.
##
## Top: grade letter, score, chart (SINGLE / BASIC / meter) and the song art.
## Bottom left: the cleared result (FAILED / CLEARED). Bottom right: the
## detailed judgement counts, headed by MAX COMBO.

signal retry_pressed
signal select_pressed

const CATALOG := preload("res://scripts/song_catalog.gd")
const DESIGN := Vector2(1280, 720)

const BANNER := Rect2(300, 0, 680, 44)
const PLAYER_PILL := Rect2(-30, 70, 156, 34)
const GRADE_RECT := Rect2(150, 115, 200, 116)
const GRADE_TEXTURES := {
	"AAAA": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Tier01.png"),
	"AAA": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Tier02.png"),
	"AA": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Tier03.png"),
	"A": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Tier04.png"),
	"B": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Tier05.png"),
	"C": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Tier06.png"),
	"D": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Tier07.png"),
	"E": preload("res://assets/stepmania/GradeDisplay /GradeDisplayEval Failed.png"),
}
const SCORE_PILL := Rect2(177, 262, 104, 22)
const SCORE_AT := Vector2(348, 334)
const TIER_AT := Vector2(433, 68)
const DIFF_AT := Vector2(433, 96)
const METER_AT := Vector2(433, 126)
const COVER := Rect2(543, 57, 200, 204)
const TITLE_AT := Vector2(641, 296)
const ARTIST_AT := Vector2(641, 322)
const LEFT_CARD := Rect2(158, 356, 465, 290)
const LEFT_TAB := Rect2(158, 356, 232, 40)
const LEFT_STATUS := Vector2(390, 512)
const RIGHT_CARD := Rect2(671, 356, 444, 290)
const RIGHT_HEAD := Rect2(671, 356, 444, 46)
const ROW_TOP := 432.0
const ROW_STEP := 34.0
const RETRY_RECT := Rect2(390, 660, 210, 46)
const SELECT_RECT := Rect2(630, 660, 250, 46)

const INK := Color("16324a")
const INK_SOFT := Color("45606f")
const NAVY := Color("0f2436")
const TEAL := Color("2ecbc4")
const PANEL_EDGE := Color("cbbadd")

## Detailed results rows in arcade order; `O.K.` is this project's BOO grade.
const ROWS := [
	["MARVELOUS", Color("1b2b3a")],
	["PERFECT", Color("bd8820")],
	["GREAT", Color("25784a")],
	["GOOD", Color("155a66")],
	["O.K.", Color("9e3a25")],
	["Miss", Color("1b2b3a")],
]

var data := {
	"title": "", "artist": "", "cover": null, "tier": "", "meter": 0,
	"grade": "D", "score": 0, "combo": 0, "counts": {}, "cleared": false,
}
var retry_button: Button
var select_button: Button

var _time := 0.0
var _laid_out := Vector2(-1, -1)
var _sc := 1.0
var _org := Vector2.ZERO
var _sky: GradientTexture2D
var _glow: GradientTexture2D
var _sparkles: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sky = _make_sky()
	_glow = _make_glow()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	for i in 90:
		_sparkles.append({
			"at": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(1.0, 3.0),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.6, 1.8),
		})
	retry_button = _make_button("RETRY", TEAL)
	select_button = _make_button("SONG SELECT", Color("f2f6f9"))
	_place_buttons()

func _make_sky() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	gradient.colors = PackedColorArray([Color("f4fbff"), Color("e6f3fb"), Color("f1eafa")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.15, 1.0)
	texture.width = 64
	texture.height = 96
	return texture

## Soft white bloom behind the banner, like the arcade's top light.
func _make_glow() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture

func _make_button(label: String, fill: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill if state == "normal" else (fill.lightened(0.1) if state == "hover" else fill.darkened(0.1))
		style.border_color = Color("b6c6d2")
		style.set_border_width_all(2)
		style.set_corner_radius_all(23)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_font_size_override("font_size", 20)
	if label == "RETRY":
		button.pressed.connect(func() -> void: retry_pressed.emit())
	else:
		button.pressed.connect(func() -> void: select_pressed.emit())
	add_child(button)
	return button

# ------------------------------------------------------------------ public state

func show_result(snapshot: Dictionary) -> void:
	data = snapshot.duplicate(true)
	_time = 0.0
	queue_redraw()

func cleared() -> bool:
	return bool(data.get("cleared", false))

func status_text() -> String:
	return "CLEARED" if cleared() else "FAILED"

func grade_text() -> String:
	return str(data.get("grade", "—"))

func score_text() -> String:
	return _comma(int(data.get("score", 0)))

func max_combo() -> int:
	return int(data.get("combo", 0))

## Label/value pairs of the detailed results, in arcade order.
func rows() -> Array:
	var counts: Dictionary = data.get("counts", {})
	var key_by_label := {
		"MARVELOUS": "MARVELOUS", "PERFECT": "PERFECT", "GREAT": "GREAT",
		"GOOD": "GOOD", "O.K.": "OK", "Miss": "MISS",
	}
	var list: Array = []
	for row in ROWS:
		var label: String = row[0]
		list.append({
			"label": label,
			"value": int(counts.get(key_by_label[label], 0)),
			"color": row[1],
		})
	return list

## `1234` -> `001,234`; past six digits the comma grouping is dropped.
func _comma(value: int) -> String:
	var digits := str(maxi(value, 0))
	if digits.length() > 6:
		return digits
	digits = digits.pad_zeros(6)
	return digits.substr(0, 3) + "," + digits.substr(3, 3)

# ------------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and not event.echo and event.pressed:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not retry_button.disabled:
					retry_pressed.emit()
			KEY_ESCAPE:
				select_pressed.emit()
			_:
				return
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_place_buttons()
	queue_redraw()

# ------------------------------------------------------------------------ layout

func _calc() -> void:
	_sc = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_org = (size - DESIGN * _sc) / 2.0

func _p(x: float, y: float) -> Vector2:
	return _org + Vector2(x, y) * _sc

func _d(rect: Rect2) -> Rect2:
	return Rect2(_org + rect.position * _sc, rect.size * _sc)

func _place_buttons() -> void:
	if _laid_out == size:
		return
	_laid_out = size
	_calc()
	for pair in [[retry_button, RETRY_RECT], [select_button, SELECT_RECT]]:
		var button: Button = pair[0]
		var rect := _d(pair[1])
		button.position = rect.position
		button.size = rect.size
		button.add_theme_font_size_override("font_size", maxi(10, int(round(20.0 * _sc))))

# ------------------------------------------------------------------------- paint

func _draw() -> void:
	_calc()
	_draw_sky()
	_draw_lower_band()
	_draw_banner()
	_draw_grade_and_score()
	_draw_chart_column()
	_draw_cover()
	_draw_clear_card()
	_draw_stats_card()

func _draw_sky() -> void:
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false)
	var bloom := Rect2(-size.x * 0.25, -size.y * 0.75, size.x * 1.5, size.y * 1.5)
	draw_texture_rect(_glow, bloom, false, Color(1, 1, 1, 0.9))
	for sparkle in _sparkles:
		var pulse: float = 0.3 + 0.4 * (0.5 + 0.5 * sin(_time * sparkle.speed + sparkle.phase))
		draw_circle(_p(sparkle.at.x * DESIGN.x, sparkle.at.y * DESIGN.y), sparkle.radius * _sc, Color(0.82, 0.95, 1.0, pulse))

## The arcade fades from cyan-white above into lavender below; the tint starts
## under the score line and gives the two result cards a stage to sit on.
func _draw_lower_band() -> void:
	var band := PackedVector2Array([_p(0, 300), _p(DESIGN.x, 300), _p(DESIGN.x, DESIGN.y), _p(0, DESIGN.y)])
	draw_polygon(band, _vgrad(band, Color(0.90, 0.84, 0.98, 0.0), Color(0.81, 0.72, 0.94, 0.85)))

func _draw_banner() -> void:
	var points := PackedVector2Array([
		_p(BANNER.position.x, BANNER.position.y), _p(BANNER.end.x, BANNER.position.y),
		_p(BANNER.end.x - 14.0, BANNER.end.y), _p(BANNER.position.x + 14.0, BANNER.end.y),
	])
	draw_polygon(points, _vgrad(points, Color("46abe9"), Color("1868c2")))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.9), maxf(1.0, 2.0 * _sc), true)
	_text(613, 31, "Event mode:", 21, Color.WHITE, Color(0, 0, 0, 0.35), true, 2)
	_text(627, 33, "Results", 30, Color.WHITE, Color(0, 0, 0, 0.35), true, 0)

func _draw_grade_and_score() -> void:
	_capsule(PLAYER_PILL, TEAL, "P1", 24)
	var texture: Texture2D = GRADE_TEXTURES.get(grade_text())
	if texture != null:
		draw_texture_rect(texture, _d(GRADE_RECT), false)
	else:
		_text(GRADE_RECT.get_center().x, GRADE_RECT.end.y, grade_text(), 96, NAVY, Color(0, 0, 0, 0), true)
	_capsule(SCORE_PILL, Color("46555f"), "SCORE", 15, Color.WHITE, Color(0, 0, 0, 0.35))
	_text(SCORE_AT.x + 3, SCORE_AT.y + 4, score_text(), 62, Color(0, 0, 0, 0.14), Color(0, 0, 0, 0), true)
	_text(SCORE_AT.x, SCORE_AT.y, score_text(), 62, INK, Color(1, 1, 1, 0.85), true)

func _draw_chart_column() -> void:
	_text(TIER_AT.x, TIER_AT.y, "SINGLE", 25, Color("1f7fc0"), Color(1, 1, 1, 0.75), true)
	var tier := str(data.get("tier", "BASIC"))
	_text(DIFF_AT.x, DIFF_AT.y, tier if not tier.is_empty() else "BASIC", 29, Color("e08a1e"), Color(1, 1, 1, 0.75), true)
	_text(METER_AT.x, METER_AT.y, str(int(data.get("meter", 0))), 33, NAVY, Color(1, 1, 1, 0.75), true)

func _draw_cover() -> void:
	draw_colored_polygon(_round_points(_d(Rect2(COVER.position + Vector2(0, 8), COVER.size).grow(8.0)), 6.0 * _sc), Color(0, 0, 0, 0.16))
	draw_rect(_d(COVER.grow(6.0)), Color.WHITE)
	var texture: Texture2D = data.get("cover")
	if texture != null:
		draw_texture_rect(texture, _d(COVER), false)
	else:
		_paint_placeholder(COVER, str(data.get("title", "?")), str(data.get("tier", "")), 70.0)
	_text(TITLE_AT.x, TITLE_AT.y, _fit(str(data.get("title", "")), 400.0, 30.0), 30, NAVY, Color(1, 1, 1, 0.8), true)
	_text(ARTIST_AT.x, ARTIST_AT.y, _fit(str(data.get("artist", "")), 400.0, 22.0), 22, INK_SOFT, Color(1, 1, 1, 0.8), false)

func _draw_clear_card() -> void:
	_panel(LEFT_CARD, Color("fbf8fe"), PANEL_EDGE)
	var tab := PackedVector2Array([
		_p(LEFT_TAB.position.x, LEFT_TAB.end.y), _p(LEFT_TAB.position.x, LEFT_TAB.position.y + 12.0),
		_p(LEFT_TAB.position.x + 12.0, LEFT_TAB.position.y), _p(LEFT_TAB.end.x - 12.0, LEFT_TAB.position.y),
		_p(LEFT_TAB.end.x, LEFT_TAB.position.y + 12.0), _p(LEFT_TAB.end.x, LEFT_TAB.end.y),
	])
	draw_polygon(tab, _vgrad(tab, Color("c8c3bd"), Color("a9a49e")))
	draw_polyline(tab + PackedVector2Array([tab[0]]), Color(1, 1, 1, 0.55), maxf(1.0, 1.5 * _sc), true)
	_text(LEFT_TAB.position.x + 16.0, LEFT_TAB.position.y + 28.0, "Clear Result", 21, Color("2a2f33"), Color(1, 1, 1, 0.4), true, 0)
	var label := status_text() if cleared() else status_text() + "..."
	_sheared_text(LEFT_STATUS.x, LEFT_STATUS.y, label, 86, NAVY)

func _draw_stats_card() -> void:
	_panel(RIGHT_CARD, Color("f9f3fb"), Color("d3bfe0"))
	# Black header bar, squared at the bottom so it reads as a strip.
	var head := _round_points(_d(RIGHT_HEAD), 10.0 * _sc)
	draw_colored_polygon(head, Color("0b0b0d"))
	draw_rect(_d(Rect2(RIGHT_HEAD.position.x, RIGHT_HEAD.position.y + RIGHT_HEAD.size.y * 0.6, RIGHT_HEAD.size.x, RIGHT_HEAD.size.y * 0.4)), Color("0b0b0d"))
	_text(RIGHT_HEAD.position.x + 22.0, RIGHT_HEAD.position.y + 30.0, "MAX COMBO", 21, Color.WHITE, Color(0, 0, 0, 0.4), true, 0)
	_text(RIGHT_HEAD.end.x - 22.0, RIGHT_HEAD.position.y + 33.0, str(max_combo()), 27, Color.WHITE, Color(0, 0, 0, 0.4), true, 2)
	draw_rect(_d(Rect2(RIGHT_CARD.position.x + 1.0, RIGHT_HEAD.end.y, 4.0, RIGHT_CARD.size.y - RIGHT_HEAD.size.y - 2.0)), Color("25908a"))
	var label_right := RIGHT_CARD.position.x + 232.0
	var value_left := RIGHT_CARD.position.x + 266.0
	var list := rows()
	for i in list.size():
		var row: Dictionary = list[i]
		var baseline := ROW_TOP + i * ROW_STEP
		_text(label_right, baseline, str(row.label), 24, row.color, Color(1, 1, 1, 0.9), true, 2)
		_text(value_left, baseline, str(row.value), 24, INK, Color(1, 1, 1, 0.9), true, 0)
	var counts: Dictionary = data.get("counts", {})
	_text(RIGHT_CARD.get_center().x, RIGHT_CARD.end.y - 14.0,
		"HOLD %d    BREAK %d" % [int(counts.get("holds", 0)), int(counts.get("breaks", 0))],
		15, Color("7d6b8c"), Color(1, 1, 1, 0.85), false)

func _panel(rect: Rect2, fill: Color, edge: Color) -> void:
	draw_colored_polygon(_round_points(_d(Rect2(rect.position + Vector2(0, 6), rect.size)), 12.0 * _sc), Color(0.1, 0.05, 0.2, 0.12))
	var points := _round_points(_d(rect), 12.0 * _sc)
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), edge, maxf(1.0, 2.0 * _sc), true)

func _capsule(rect: Rect2, color: Color, label: String, font_size: float, ink := Color("14313f"), outline := Color(1, 1, 1, 0.5)) -> void:
	var radius := rect.size.y * _sc / 2.0
	var points := _round_points(_d(rect), radius)
	draw_polygon(points, _vgrad(points, color.lightened(0.34), color.darkened(0.18)))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.65), maxf(1.0, 2.0 * _sc), true)
	_text(rect.get_center().x, rect.get_center().y + font_size * 0.36, label, font_size, ink, outline, true)

# ----------------------------------------------------------------- primitives

func _text(x: float, baseline: float, text: String, font_size: float, color: Color, outline := Color(0, 0, 0, 0), bold := false, align := 1, edge_scale := 1.0) -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var px := int(round(font_size * _sc))
	if px <= 0:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := _p(x, baseline)
	if align == 1:
		at.x -= width / 2.0
	elif align == 2:
		at.x -= width
	if outline.a > 0.0:
		var edge := maxf(1.0, px * 0.055) * edge_scale
		for dx in [-1.0, 0.0, 1.0]:
			for dy in [-1.0, 0.0, 1.0]:
				if dx == 0.0 and dy == 0.0:
					continue
				draw_string(font, at + Vector2(dx, dy) * edge, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline)
	if bold:
		draw_string(font, at + Vector2(maxf(0.4, _sc * 0.7), 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

## Italic-capable text: the arcade shears its display words to the right.
func _sheared_text(cx: float, baseline: float, text: String, font_size: float, color: Color, shear := -0.2) -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var px := int(round(font_size * _sc))
	if px <= 0:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var origin := _p(cx, baseline) - Vector2(width / 2.0, 0.0)
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(shear, 1.0), origin))
	# A few tight passes thicken the face so thin fallback strokes stay readable.
	for offset in [Vector2.ZERO, Vector2(maxf(0.8, _sc * 0.9), 0.0), Vector2(0.0, maxf(0.6, _sc * 0.6))]:
		draw_string(font, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _fit(text: String, max_width: float, font_size: float) -> String:
	var font := ThemeDB.fallback_font
	var px := int(round(font_size * _sc))
	if px <= 0 or text.is_empty():
		return text
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= max_width * _sc:
		return text
	var trimmed := text
	while trimmed.length() > 1 and font.get_string_size(trimmed + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_width * _sc:
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed.strip_edges() + "…"

## Vertical two-stop shading for a polygon: one colour per vertex.
func _vgrad(points: PackedVector2Array, top: Color, bottom: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	var low := INF
	var high := -INF
	for point in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	var span := maxf(high - low, 1.0)
	for point in points:
		colors.append(top.lerp(bottom, (point.y - low) / span))
	return colors

func _round_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r: float = maxf(0.5, minf(radius, minf(rect.size.x, rect.size.y) / 2.0))
	var points := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI / 2.0, 0.0],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0, PI / 2.0],
		[rect.position + Vector2(r, rect.size.y - r), PI / 2.0, PI],
		[rect.position + Vector2(r, r), PI, PI * 1.5],
	]
	for corner in corners:
		for i in 4:
			var angle: float = corner[1] + (corner[2] - corner[1]) * i / 3.0
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * r)
	return points

func _initials(title: String) -> String:
	var words := title.split(" ", false)
	var text := ""
	for word in words:
		if text.length() >= 2:
			break
		text += str(word).substr(0, 1)
	if text.length() < 2 and not words.is_empty():
		text = str(words[0]).substr(0, 2)
	return text.to_upper()

## Songs without artwork still get a readable tile in the DDR palette.
func _paint_placeholder(rect: Rect2, title: String, tier: String, font_size: float) -> void:
	var base: Color = CATALOG.tier_bar(tier) if not tier.is_empty() else Color("3c7f9c")
	var points := _round_points(_d(rect), 0.0)
	draw_polygon(points, _vgrad(points, base.darkened(0.1), base.darkened(0.55)))
	var sheen := PackedVector2Array([
		_p(rect.position.x, rect.end.y), _p(rect.position.x + rect.size.x * 0.55, rect.position.y),
		_p(rect.position.x + rect.size.x * 0.8, rect.position.y), _p(rect.position.x + rect.size.x * 0.25, rect.end.y),
	])
	draw_colored_polygon(sheen, Color(1, 1, 1, 0.14))
	_text(rect.get_center().x, rect.get_center().y + font_size * 0.36, _initials(title), font_size, Color(1, 1, 1, 0.92), Color(0, 0, 0, 0.3), true)
