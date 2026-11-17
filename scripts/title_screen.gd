extends Control
## DDR 2014 style title screen.
##
## Presentation and input only: main.gd owns the state machine and answers the
## `menu_selected` signal. The backdrop is baked by tools/make_title_assets.py
## and the logo is hand-cut art cleaned by tools/clean_title_logo.py, because no
## usable artwork ships with this project.
##
## OPTIONS opens scripts/options_screen.gd as a child popup; this node keeps the
## menu and forwards keys and design-space taps to the popup while it is open.

signal menu_selected(action: String)

const BACKDROP := preload("res://assets/title/backdrop.jpg")
const LOGO := preload("res://assets/title/logo.png")
const TITLE_FONT := preload("res://assets/fonts/Inter_18pt-Bold.ttf")
const OPTIONS_SCREEN := preload("res://scripts/options_screen.gd")

const DESIGN := Vector2(1280, 720)
const LOGO_RECT := Rect2(96, 64, 1088, 300)
const MENU_TOP := 432.0
const MENU_STEP := 56.0
const MENU_SIZE := 38
const MENU_SELECTED_SIZE := 46
const COPYRIGHT := "© 2026 DDR-Mobile Ver 0.1"

## Menu entries in display order. The arcade lists TRAINING MODE and EDIT MODE
## too; neither is built here, so they are hidden rather than shown dead.
const ITEMS := [
	{"id": "game", "label": "GAME MODE", "color": Color("ffe07a")},
	{"id": "options", "label": "OPTIONS", "color": Color("8fc8ff")},
	{"id": "exit", "label": "EXIT", "color": Color("ff6b7a")},
]

const INK := Color("101010")

var selected := 0
var notice := ""
## Child popup holding the player options; created in _ready.
var options: Control

var _sc := 1.0
var _org := Vector2.ZERO
var _time := 0.0
var _notice_until := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	options = OPTIONS_SCREEN.new()
	options.name = "OptionsPopup"
	add_child(options)
	options.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options.closed.connect(_on_options_closed)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if not notice.is_empty() and _time > _notice_until:
		notice = ""
	queue_redraw()


## Transient line under the menu, so a mode that is not built yet answers the
## player instead of failing silently.
func show_notice(text: String, seconds := 2.0) -> void:
	notice = text
	_notice_until = _time + seconds
	queue_redraw()


func items() -> Array:
	return ITEMS


func selected_id() -> String:
	return str(ITEMS[selected].id)


## Programmatic selection, used by tests and by main.gd when a screen hands
## control back to the title.
func focus_item(index: int) -> void:
	selected = wrapi(index, 0, ITEMS.size())
	queue_redraw()


func options_open() -> bool:
	return options != null and options.visible


func open_options() -> void:
	if options == null:
		return
	options.open()
	queue_redraw()


func close_options() -> void:
	if options != null:
		options.close()


func _on_options_closed() -> void:
	queue_redraw()


func confirm() -> void:
	if options_open():
		options.confirm()
	elif selected_id() == "options":
		open_options()
	else:
		menu_selected.emit(selected_id())


func notice_visible() -> bool:
	return not notice.is_empty()


## Screen-space box of one menu row, in design units. Shared by drawing and
## hit testing so a tap always lands where the label is drawn.
func item_rect(index: int) -> Rect2:
	var font := TITLE_FONT
	var font_size := MENU_SELECTED_SIZE if index == selected else MENU_SIZE
	var text_size := font.get_string_size(str(ITEMS[index].label), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := MENU_TOP + index * MENU_STEP
	return Rect2(Vector2(DESIGN.x * 0.5 - text_size.x * 0.5 - 18, baseline - font.get_ascent(font_size) - 8), Vector2(text_size.x + 36, text_size.y + 16))


func _step(step: int) -> void:
	focus_item(selected + step)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if options_open():
			if options.handle_key(event.physical_keycode):
				get_viewport().set_input_as_handled()
			return
		match event.physical_keycode:
			KEY_UP, KEY_W:
				_step(-1)
			KEY_DOWN, KEY_S:
				_step(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				confirm()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_press_at(event.position)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press_at(event.position)
		accept_event()


func _press_at(point: Vector2) -> void:
	var design := _to_design(point)
	if options_open():
		options.press_at(design)
		return
	for index in ITEMS.size():
		if item_rect(index).has_point(design):
			selected = index
			queue_redraw()
			confirm()
			return


func _draw() -> void:
	_sc = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_org = (size - DESIGN * _sc) / 2.0
	draw_set_transform(_org, 0.0, Vector2(_sc, _sc))

	draw_texture_rect(BACKDROP, _cover(BACKDROP.get_size()), false)
	# The baked logo already carries its own ink outline, so it needs no backing.
	# Fit by aspect instead of stretching: the artwork is much wider than the
	# rect, and a stretched wordmark reads as slanted/squashed lettering.
	var logo_size := LOGO.get_size()
	var fit := minf(LOGO_RECT.size.x / logo_size.x, LOGO_RECT.size.y / logo_size.y)
	var draw_size := logo_size * fit
	var logo_origin := LOGO_RECT.position + (LOGO_RECT.size - draw_size) * 0.5
	draw_texture_rect(LOGO, Rect2(logo_origin, draw_size), false)

	var font := TITLE_FONT
	for index in ITEMS.size():
		var item: Dictionary = ITEMS[index]
		var label: String = item.label
		var colour: Color = item.color
		var active := index == selected
		var bob := 0.0
		if active:
			bob = sin(_time * 6.0) * 2.0
		var font_size := MENU_SELECTED_SIZE if active else MENU_SIZE
		var item_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var center := Vector2(DESIGN.x * 0.5, MENU_TOP + index * MENU_STEP + bob)
		var origin := center - Vector2(item_size.x * 0.5, 0.0)
		draw_string_outline(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, INK)
		var tint := Color(1, 1, 1, 1.0) if active else Color(colour.r, colour.g, colour.b, 0.92)
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

	if not notice.is_empty():
		var notice_size := font.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var notice_pos := Vector2(DESIGN.x * 0.5 - notice_size.x * 0.5, MENU_TOP + ITEMS.size() * MENU_STEP + 12.0)
		draw_string_outline(font, notice_pos, notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, INK)
		draw_string(font, notice_pos, notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe07a"))

	var copy_size := font.get_string_size(COPYRIGHT, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var copy_pos := Vector2(DESIGN.x * 0.5 - copy_size.x * 0.5, DESIGN.y - 30.0)
	draw_string_outline(font, copy_pos, COPYRIGHT, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 7, INK)
	draw_string(font, copy_pos, COPYRIGHT, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.95))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Map a control-space point back into design units. Recomputed from `size`
## rather than the cached draw transform, so taps work before the first frame.
func _to_design(point: Vector2) -> Vector2:
	var sc := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	if sc <= 0.0:
		sc = 1.0
	return (point - (size - DESIGN * sc) / 2.0) / sc


## Scale the backdrop so it covers the design box without distorting it.
func _cover(tex_size: Vector2) -> Rect2:
	var factor := maxf(DESIGN.x / tex_size.x, DESIGN.y / tex_size.y)
	var drawn := tex_size * factor
	return Rect2((DESIGN - drawn) * 0.5, drawn)
