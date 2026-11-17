extends Control
## Modal OPTIONS popup: setting names in a left column, their current values in
## the right one, and the focused row inverted to black with a left and a right
## arrow. Mirrors the arcade options screen: Up/Down move the focus, Left/Right
## (or tapping either arrow) cycle the focused value, EXIT closes the popup.
##
## The node only draws and holds the pending values. title_screen owns the title
## menu and forwards key presses and design-space pointer points here, so the
## popup never competes with the menu for the same input. main.gd re-reads the
## saved values when a chart starts, so an edit applies to the next song without
## restarting the app.

signal closed

const OPTIONS_SETTINGS := preload("res://scripts/options_settings.gd")
const TITLE_FONT := preload("res://assets/fonts/Inter_18pt-Bold.ttf")
const DESIGN := Vector2(1280, 720)

const PANEL := Rect2(244, 104, 792, 488)
const HEADER_BASELINE := 158.0
const SEPARATOR_Y := 186.0
const TABLE_X := 276.0
const TABLE_W := 728.0
const LABEL_W := 396.0
const ROW_TOP := 210.0
const ROW_H := 78.0
const FOOTER := Rect2(TABLE_X, 506, TABLE_W, 54)
const EXIT_SIZE := Vector2(156, 42)
const ARROW_W := 52.0

const ACCENT := Color("9fe9ff")
const INACTIVE_LABEL := Color("b8c6d0")
const INACTIVE_VALUE := Color("dce7ee")

## Saved settings file; tests point this at a throwaway path.
var settings_path := OPTIONS_SETTINGS.PATH
var focus_row := 0

var _rows: Array = []
var _values: Array = []
var _notice := ""
var _notice_until := 0


func _init() -> void:
	_rows = [
		{
			"id": "scroll_direction",
			"label": "BUTTON MODE",
			"values": [OPTIONS_SETTINGS.UPWARD, OPTIONS_SETTINGS.DOWNWARD],
		},
		{
			"id": "arrow_style",
			"label": "ARROW STYLE",
			"values": OPTIONS_SETTINGS.ARROW_STYLES.duplicate(),
		},
	]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	if _notice.is_empty():
		return
	if Time.get_ticks_msec() >= _notice_until:
		_notice = ""
		queue_redraw()


# --- Popup lifecycle ---------------------------------------------------------

func open() -> void:
	_reload()
	focus_row = 0
	_notice = ""
	visible = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _reload() -> void:
	_values.clear()
	for row in _rows:
		_values.append(_load_value(str(row.id)))


func _load_value(id: String) -> Variant:
	match id:
		"scroll_direction":
			return OPTIONS_SETTINGS.load_scroll_direction(settings_path)
		"arrow_style":
			return OPTIONS_SETTINGS.load_arrow_style(settings_path)
	return null


func _save_value(id: String, setting: Variant) -> bool:
	match id:
		"scroll_direction":
			return OPTIONS_SETTINGS.save_scroll_direction(str(setting), settings_path) == OK
		"arrow_style":
			return OPTIONS_SETTINGS.save_arrow_style(str(setting), settings_path) == OK
	return false


# --- State readouts (also used by the tests) ---------------------------------

func rows() -> Array:
	return _rows


func row_count() -> int:
	return _rows.size()


func row_label(index: int) -> String:
	return str(_rows[index].label)


func row_values(index: int) -> Array:
	return _rows[index].values


func value(index: int) -> Variant:
	return _values[index]


func value_label(index: int) -> String:
	var current: Variant = _values[index]
	if str(_rows[index].id) == "scroll_direction":
		return "DESKTOP" if current == OPTIONS_SETTINGS.UPWARD else "MOBILE"
	return str(current).to_upper().replace("_", " ")


func notice_text() -> String:
	return _notice


# --- Input -------------------------------------------------------------------

func move_focus(step: int) -> void:
	focus_row = wrapi(focus_row + step, 0, _rows.size() + 1)
	queue_redraw()


func cycle(step: int) -> bool:
	if focus_row == _rows.size():
		return false
	var row: Dictionary = _rows[focus_row]
	var choices: Array = row.values
	var index: int = maxi(choices.find(_values[focus_row]), 0)
	var next: Variant = choices[wrapi(index + step, 0, choices.size())]
	if not _save_value(str(row.id), next):
		_notice = "COULD NOT SAVE"
		_notice_until = Time.get_ticks_msec() + 2000
		queue_redraw()
		return false
	_values[focus_row] = next
	queue_redraw()
	return true


func confirm() -> void:
	if focus_row == _rows.size():
		close()
	else:
		cycle(1)


func handle_key(code: Key) -> bool:
	match code:
		KEY_ESCAPE, KEY_BACKSPACE:
			close()
		KEY_UP, KEY_W:
			move_focus(-1)
		KEY_DOWN, KEY_S:
			move_focus(1)
		KEY_LEFT, KEY_A:
			cycle(-1)
		KEY_RIGHT, KEY_D:
			cycle(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			confirm()
		_:
			return false
	return true


## `point` is in design space (title_screen converts it). Returns whether the
## tap landed on the popup.
func press_at(point: Vector2) -> bool:
	if exit_rect().has_point(point):
		close()
		return true
	for index in _rows.size():
		if index != focus_row:
			if label_rect(index).has_point(point) or value_rect(index).has_point(point):
				focus_row = index
				queue_redraw()
				return true
			continue
		if arrow_rect(index, -1).has_point(point):
			cycle(-1)
			return true
		if arrow_rect(index, 1).has_point(point):
			cycle(1)
			return true
		if label_rect(index).has_point(point) or value_rect(index).has_point(point):
			return true
	return false


# --- Geometry ----------------------------------------------------------------

func row_rect(index: int) -> Rect2:
	return Rect2(TABLE_X, ROW_TOP + index * ROW_H, TABLE_W, ROW_H)


func label_rect(index: int) -> Rect2:
	return Rect2(TABLE_X, ROW_TOP + index * ROW_H, LABEL_W, ROW_H)


func value_rect(index: int) -> Rect2:
	return Rect2(TABLE_X + LABEL_W, ROW_TOP + index * ROW_H, TABLE_W - LABEL_W, ROW_H)


func arrow_rect(index: int, direction: int) -> Rect2:
	var cell := value_rect(index)
	if direction < 0:
		return Rect2(cell.position.x, cell.position.y, ARROW_W, cell.size.y)
	return Rect2(cell.end.x - ARROW_W, cell.position.y, ARROW_W, cell.size.y)


func exit_rect() -> Rect2:
	return Rect2(FOOTER.end.x - EXIT_SIZE.x - 8.0, FOOTER.position.y + 6.0, EXIT_SIZE.x, EXIT_SIZE.y)


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var sc := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	if sc <= 0.0:
		sc = 1.0
	draw_set_transform((size - DESIGN * sc) * 0.5, 0.0, Vector2(sc, sc))

	# Dim the title screen so the popup reads as a modal over it.
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(0.02, 0.05, 0.08, 0.88))
	draw_rect(PANEL, Color(0.035, 0.062, 0.086, 0.97))
	draw_rect(PANEL, Color(ACCENT, 0.35), false, 2.0)

	var font := TITLE_FONT
	_centered_in(font, "OPTIONS", Rect2(PANEL.position.x, PANEL.position.y + 26.0, PANEL.size.x, 60.0), 40, Color.WHITE)
	draw_line(
		Vector2(PANEL.position.x + 32.0, SEPARATOR_Y),
		Vector2(PANEL.end.x - 32.0, SEPARATOR_Y),
		Color(1, 1, 1, 0.12),
		2.0
	)

	for index in _rows.size():
		_draw_row(font, index)
	_draw_footer(font)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_row(font: Font, index: int) -> void:
	var focused := index == focus_row
	var label := label_rect(index)
	var cell := value_rect(index)

	if focused:
		draw_rect(label, Color.BLACK)
		draw_rect(cell, Color.BLACK)
	else:
		draw_rect(label, Color(0.075, 0.10, 0.13, 0.98))
		draw_rect(cell, Color(0.10, 0.135, 0.165, 0.98))

	if index < _rows.size() - 1:
		draw_line(
			Vector2(TABLE_X, label.end.y),
			Vector2(TABLE_X + TABLE_W, label.end.y),
			Color(1, 1, 1, 0.06),
			1.0
		)

	_centered_in(font, row_label(index), label, 26, Color.WHITE if focused else INACTIVE_LABEL)

	var label_text := value_label(index)
	var text_size := 26
	while text_size > 18 and font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x > cell.size.x - 116.0:
		text_size -= 1
	_centered_in(font, label_text, cell, text_size, Color.WHITE if focused else INACTIVE_VALUE)

	if focused:
		draw_rect(row_rect(index), Color(ACCENT, 0.9), false, 2.0)
		_draw_arrow(arrow_rect(index, -1).get_center(), -1, Color.WHITE)
		_draw_arrow(arrow_rect(index, 1).get_center(), 1, Color.WHITE)


func _draw_arrow(center: Vector2, direction: int, colour: Color) -> void:
	var half_w := 9.0
	var half_h := 13.0
	var points := PackedVector2Array()
	if direction < 0:
		points = PackedVector2Array([
			center + Vector2(half_w, -half_h),
			center + Vector2(half_w, half_h),
			center + Vector2(-half_w, 0.0),
		])
	else:
		points = PackedVector2Array([
			center + Vector2(-half_w, -half_h),
			center + Vector2(-half_w, half_h),
			center + Vector2(half_w, 0.0),
		])
	draw_colored_polygon(points, colour)


func _draw_footer(font: Font) -> void:
	draw_rect(FOOTER, Color(0.06, 0.085, 0.11, 0.98))
	draw_rect(FOOTER, Color(1, 1, 1, 0.10), false, 1.0)

	var hint := "UP/DOWN SELECT    LEFT/RIGHT CHANGE"
	var hint_colour := Color(1, 1, 1, 0.55)
	if not _notice.is_empty():
		hint = _notice
		hint_colour = Color("ff8a8a")
	draw_string(
		font,
		Vector2(FOOTER.position.x + 18.0, FOOTER.get_center().y + 6.0),
		hint,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		hint_colour
	)

	var button := exit_rect()
	var exit_focused := focus_row == _rows.size()
	draw_rect(button, Color.BLACK if exit_focused else Color(0.10, 0.16, 0.20, 0.98))
	draw_rect(button, Color(ACCENT, 0.9 if exit_focused else 0.55), false, 2.0 if exit_focused else 1.5)
	_centered_in(font, "EXIT", button, 24, Color.WHITE)


func _centered_in(font: Font, text: String, rect: Rect2, font_size: int, colour: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := rect.get_center().y + (ascent - descent) * 0.5
	draw_string(
		font,
		Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		colour
	)
