extends Control
## DDR 2ndMIX style song select screen.
##
## Presentation and input only: main.gd owns chart/audio state and answers the
## signals below, then pushes the resolved state back with `set_song_state` /
## `set_chart_state`. Layout is authored in a 1280x720 design space that is
## scaled and centred inside the real viewport, so every helper takes design
## units and converts at the end.

signal song_requested(index: int)
signal difficulty_requested(index: int)
signal play_requested
signal version_requested(version: String)
signal version_focus_changed(active: bool)

const CATALOG := preload("res://scripts/song_catalog.gd")
const DESIGN := Vector2(1280, 720)
const SLOTS := 5
const SLOT_PITCH := 224.0
const BANNER := Vector2(200, 62)
const COVER := Rect2(480, 80, 320, 320)
const LADDER_TOP := 132.0
const LADDER_STEP := 46.0
const PENTAGON := Vector2(300, 392)
const STRIP_TOP := 520.0
const STRIP_Y := 552.0

const INK := Color("1b2a33")
const INK_SOFT := Color("4d6470")
const GOLD := Color("ffe07a")
const GOLD_SHADOW := Color("6b3f00")
const TEAL := Color("2ecbc4")
const PINK := Color("ff2f9d")

var version := ""
var all_versions: Array = []
var versions: Array = []
var songs: Array = []
var played: Dictionary = {}
var song_index := 0
var chart_index := 0
var charts: Array = []
var chart_error := ""
var preview_active := false
var playable := false

var _version_focus := 0 # 0 means a song; 1..N identify strip entries.
var _scroll := 0.0
var _scroll_target := 0.0
var _cover_pop := 1.0
var _meter_pop := 1.0
var _time := 0.0
var _sc := 1.0
var _org := Vector2.ZERO
var _hit: Dictionary = {}
var _sparkles: Array = []
var _sky: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sky = _make_sky()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	for i in 110:
		_sparkles.append({
			"at": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(1.2, 3.4),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.6, 1.8),
		})

func _make_sky() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	gradient.colors = PackedColorArray([Color("f7feff"), Color("d9f1fc"), Color("b3e2f6")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.55, 1.0)
	texture.width = 64
	texture.height = 96
	return texture

# ---------------------------------------------------------------- public state

func setup(song_list: Array, played_songs: Dictionary) -> void:
	_set_version_focus(0)
	songs = song_list
	played = played_songs
	song_index = 0
	chart_index = 0
	charts = []
	chart_error = ""
	playable = false
	preview_active = false
	_scroll = 0.0
	_scroll_target = 0.0
	queue_redraw()

func setup_versions(entries: Array) -> void:
	all_versions = entries.duplicate(true)
	_refresh_versions()

func set_version_state(selected_version: String) -> void:
	version = selected_version
	_refresh_versions()

func _refresh_versions() -> void:
	_set_version_focus(0)
	versions = all_versions.filter(func(entry): return str(entry.get("id", "")) != version)
	_ensure_visible()
	queue_redraw()

func _focused_version() -> Dictionary:
	if _version_focus <= 0 or _version_focus > versions.size():
		return {}
	return versions[_version_focus - 1]

func set_song_state(index: int, song_charts: Array, selected: int, error_text: String, can_start: bool) -> void:
	_set_version_focus(0)
	var changed := index != song_index
	song_index = clampi(index, 0, maxi(songs.size() - 1, 0))
	charts = song_charts
	chart_index = clampi(selected, 0, maxi(charts.size() - 1, 0))
	chart_error = error_text
	playable = can_start
	if changed:
		_cover_pop = 0.0
	_ensure_visible()
	queue_redraw()

func set_chart_state(index: int, error_text: String, can_start: bool) -> void:
	if index != chart_index:
		_meter_pop = 0.0
	chart_index = clampi(index, 0, maxi(charts.size() - 1, 0))
	chart_error = error_text
	playable = can_start
	queue_redraw()

## Lit while the picker is playing a clip of the highlighted song.
func set_preview_state(active: bool) -> void:
	if active == preview_active:
		return
	preview_active = active
	queue_redraw()

func mark_played(songs_played: Dictionary) -> void:
	played = songs_played
	queue_redraw()

func current_song() -> Dictionary:
	if _version_focus != 0 or song_index < 0 or song_index >= songs.size():
		return {}
	return songs[song_index]

func current_chart() -> Dictionary:
	if _version_focus != 0 or chart_index < 0 or chart_index >= charts.size():
		return {}
	return charts[chart_index]

# ---------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and not event.echo and event.pressed:
		match event.physical_keycode:
			KEY_LEFT: _step_song(-1)
			KEY_RIGHT: _step_song(1)
			# The ladder runs Beginner -> Challenge downward, so UP is easier.
			KEY_UP: _step_chart(-1)
			KEY_DOWN: _step_chart(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _request_play()
			_: return
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_click(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		# A touchscreen may also generate an emulated mouse event for the same tap.
		# The screen-touch event above already handled it; keep real mouse input.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step_song(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step_song(1)
		accept_event()

func _click(at: Vector2) -> void:
	_layout()
	for key in _hit:
		if not (_hit[key] as Rect2).has_point(at):
			continue
		if key == "play":
			_request_play()
		elif key == "prev":
			_step_song(-1)
		elif key == "next":
			_step_song(1)
		elif str(key).begins_with("version:"):
			var selected_version := int(str(key).substr(8))
			_set_version_focus(selected_version)
			_ensure_visible()
			_activate_version()
		elif str(key).begins_with("diff:"):
			difficulty_requested.emit(int(str(key).substr(5)))
		elif str(key).begins_with("banner:"):
			var index := int(str(key).substr(7))
			if index != song_index or _version_focus != 0:
				_set_version_focus(0)
				song_requested.emit(index)
		return

func _step_chart(delta: int) -> void:
	if _version_focus != 0 or charts.size() < 2:
		return
	difficulty_requested.emit(wrapi(chart_index + delta, 0, charts.size()))

func _set_version_focus(value: int) -> void:
	var was_active := _version_focus != 0
	_version_focus = value
	if was_active != (_version_focus != 0):
		version_focus_changed.emit(_version_focus != 0)
	queue_redraw()

func _strip_index() -> int:
	return song_index + versions.size() if _version_focus == 0 else _version_focus - 1

func _step_song(delta: int) -> void:
	var total := songs.size() + versions.size()
	if total == 0:
		return
	var index := wrapi(_strip_index() + delta, 0, total)
	if index < versions.size():
		_set_version_focus(index + 1)
		_ensure_visible()
	else:
		_set_version_focus(0)
		song_requested.emit(index - versions.size())

func _activate_version() -> void:
	if _version_focus != 0 and str(_focused_version().get("id", "")) != version:
		version_requested.emit(str(_focused_version().get("id", "")))

func _request_play() -> void:
	if _version_focus != 0:
		_activate_version()
	elif playable:
		play_requested.emit()

func _ensure_visible() -> void:
	_scroll_target = clampf(_strip_index() - (SLOTS - 1) / 2.0, 0.0, maxf(songs.size() + versions.size() - SLOTS, 0.0))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_scroll = lerpf(_scroll, _scroll_target, minf(1.0, delta * 12.0))
	if absf(_scroll - _scroll_target) < 0.002:
		_scroll = _scroll_target
	_cover_pop = minf(1.0, _cover_pop + delta * 5.0)
	_meter_pop = minf(1.0, _meter_pop + delta * 6.0)
	queue_redraw()

# --------------------------------------------------------------------- layout

func _scale() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)

func _p(x: float, y: float) -> Vector2:
	return _org + Vector2(x, y) * _sc

func _d(rect: Rect2) -> Rect2:
	return Rect2(_org + rect.position * _sc, rect.size * _sc)

## Design-space rects plus the device-space hit boxes that mirror them.
func _layout() -> Dictionary:
	_sc = _scale()
	_org = (size - DESIGN * _sc) / 2.0
	_hit = {}
	var rects := {
		"cover": COVER,
		"play": Rect2(940, 392, 220, 74),
		"prev": Rect2(34, 566, 40, 52),
		"next": Rect2(1206, 566, 40, 52),
	}
	var ladder: Array = []
	for tier in CATALOG.TIERS:
		var row := Rect2(20, LADDER_TOP + CATALOG.TIERS.find(tier) * LADDER_STEP - 8, 180, 42)
		ladder.append(row)
		var index := _chart_index_of_tier(tier)
		if index >= 0 and _version_focus == 0:
			_hit["diff:%d" % index] = _d(row)
	rects["ladder"] = ladder
	var banners: Array = []
	for slot in range(SLOTS):
		var index: int = int(round(_scroll)) + slot
		var banner := Rect2(_banner_x(slot), STRIP_Y, BANNER.x, BANNER.y)
		banners.append(banner)
		if index >= 0 and index < versions.size():
			_hit["version:%d" % (index + 1)] = _d(banner.grow(6.0))
		elif index >= versions.size() and index < songs.size() + versions.size():
			_hit["banner:%d" % (index - versions.size())] = _d(banner.grow(6.0))
	rects["banners"] = banners
	_hit["play"] = _d(rects.play)
	if _strip_index() > 0:
		_hit["prev"] = _d(rects.prev)
	if _strip_index() < songs.size() + versions.size() - 1:
		_hit["next"] = _d(rects.next)
	return rects

func _banner_x(slot: int) -> float:
	return 640.0 - (SLOTS - 1) * SLOT_PITCH / 2.0 - BANNER.x / 2.0 + slot * SLOT_PITCH

func _chart_index_of_tier(tier: String) -> int:
	for i in charts.size():
		if str(charts[i].get("difficulty", "")) == tier:
			return i
	return -1

func _chart_of_tier(tier: String) -> Dictionary:
	var index := _chart_index_of_tier(tier)
	return {} if index < 0 else charts[index]

# ---------------------------------------------------------------------- paint

func _draw() -> void:
	var rects := _layout()
	_draw_sky()
	_draw_header()
	_draw_left_panel()
	_draw_cover(rects.cover)
	_draw_right_panel(rects)
	_draw_strip(rects)

func _draw_sky() -> void:
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false)
	for sparkle in _sparkles:
		var pulse: float = 0.35 + 0.35 * (0.5 + 0.5 * sin(_time * sparkle.speed + sparkle.phase))
		var at: Vector2 = _p(sparkle.at.x * DESIGN.x, sparkle.at.y * DESIGN.y)
		draw_circle(at, sparkle.radius * _sc, Color(1, 1, 1, pulse))
	for offset in [0.0, 320.0]:
		var points := PackedVector2Array([
			_p(-200 + offset, 720), _p(120 + offset, 720),
			_p(560 + offset, 0), _p(240 + offset, 0),
		])
		draw_colored_polygon(points, Color(1, 1, 1, 0.26))

func _draw_header() -> void:
	var points := PackedVector2Array([
		_p(390, 0), _p(890, 0), _p(940, 52), _p(340, 52),
	])
	draw_polygon(points, PackedColorArray([
		Color("2f8ceb"), Color("1d6fd0"), Color("0f3f8f"), Color("1a5cb5"),
	]))
	draw_line(_p(340, 52), _p(940, 52), Color(1, 1, 1, 0.6), maxf(1.0, 2.0 * _sc), true)
	_text(640, 36, "SELECT A SONG", 30, Color.WHITE, Color(0, 0, 0, 0.35), true)

func _draw_left_panel() -> void:
	_capsule(Rect2(40, 70, 160, 36), TEAL, "1P")
	if _version_focus != 0:
		return
	var selected_tier := str(current_chart().get("difficulty", ""))
	for tier in CATALOG.TIERS:
		var row: int = CATALOG.TIERS.find(tier)
		var chart := _chart_of_tier(tier)
		var y := LADDER_TOP + row * LADDER_STEP
		var active: bool = str(tier) == selected_tier and not charts.is_empty()
		if active:
			draw_colored_polygon(_round_points(_d(Rect2(18, y - 10, 186, 44)), 10.0 * _sc), Color(1, 1, 1, 0.85))
		var bar_color: Color = CATALOG.tier_bar(tier) if not chart.is_empty() else Color("c3cfd6")
		draw_colored_polygon(_round_points(_d(Rect2(28, y + 4, 16, 22)), 4.0 * _sc), bar_color)
		var number := str(int(chart.get("meter", 0))) if not chart.is_empty() else "–"
		var pop: float = 1.0 + (0.3 * (1.0 - _meter_pop) if active else 0.0)
		_text(82, y + 28, number, 26 * pop, INK if not chart.is_empty() else Color("9fb0ba"), Color(1, 1, 1, 0.9), active)
	if charts.is_empty():
		return
	_text(300, 226, str(current_chart().get("ddr", "—")), 56, GOLD, GOLD_SHADOW, true)
	var meter := str(int(current_chart().get("meter", 0)))
	var size: float = 108.0 * (1.0 + 0.16 * (1.0 - _meter_pop))
	_draw_pentagon(meter, size)

func _draw_pentagon(meter: String, font_size: float) -> void:
	var difficulty := str(current_chart().get("difficulty", ""))
	# The pentagon borrows the ladder colour so bar and badge always agree.
	var fill: Color = CATALOG.tier_bar(difficulty).lightened(0.62) if not difficulty.is_empty() else Color("c3cfd6")
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 5:
		var angle := -PI / 2.0 + i * TAU / 5.0
		outer.append(_p(PENTAGON.x + cos(angle) * 116.0, PENTAGON.y + sin(angle) * 116.0))
		inner.append(_p(PENTAGON.x + cos(angle) * 108.0, PENTAGON.y - 3.0 + sin(angle) * 108.0))
	draw_colored_polygon(outer, fill.darkened(0.28))
	draw_colored_polygon(inner, fill)
	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(1, 1, 1, 0.85), maxf(1.5, 2.5 * _sc), true)
	_text(PENTAGON.x, PENTAGON.y + font_size * 0.34, meter, font_size, INK, Color(1, 1, 1, 0.55), true)

## Small "now playing a clip" marker under the song metadata.
func _draw_preview_badge() -> void:
	var phase := Time.get_ticks_msec() / 260.0
	var ink := Color("ff4f9a")
	for i in range(3):
		var height := 6.0 + 8.0 * (0.5 + 0.5 * sin(phase + i * 0.9))
		draw_rect(_d(Rect2(1052.0 + i * 8.0, 356.0 - height, 5.0, height)), ink)
	_text(1136, 356, "PREVIEW", 14, ink, Color(1, 1, 1, 0.75), true)

func _draw_cover(cover: Rect2) -> void:
	var song := current_song()
	if _version_focus != 0:
		draw_rect(_d(cover.grow(7.0)), Color.WHITE)
		var entry := _focused_version()
		var texture: Texture2D = entry.get("image")
		var title := str(entry.get("title", entry.get("id", "")))
		if texture != null:
			draw_texture_rect(texture, _d(cover), false)
		else:
			_paint_placeholder(cover, title, "", 78.0)
			_text(640, 265, _fit(title, cover.size.x - 20, 22), 22, Color.WHITE, Color.BLACK, true)
		_text(640, 438, _fit("SELECT " + title, 620, 30), 30, INK, Color.WHITE, true)
		return
	var grow: float = 1.0 - 0.04 * (1.0 - _cover_pop)
	var square := Rect2(cover.get_center() - cover.size * grow / 2.0, cover.size * grow)
	draw_colored_polygon(_round_points(_d(Rect2(square.position + Vector2(0, 6), square.size).grow(9.0)), 8.0 * _sc), Color(0, 0, 0, 0.16))
	draw_rect(_d(square.grow(7.0)), Color.WHITE)
	var texture: Texture2D = song.get("background")
	if texture != null:
		# Square frame: a dimmed stretch of the 4:3 art fills the edges, then the
		# whole artwork is drawn contained so the arcade title is never cropped.
		draw_texture_rect(texture, _d(square), false)
	else:
		_paint_placeholder(square, str(song.get("title", "?")), str(song.get("hardest_tier", "")), 78.0)
	if not played.has(str(song.get("dir", ""))):
		_new_badge(Vector2(square.position.x + 34, square.position.y + 26), 34.0)
	_text(640, 438, _fit(str(song.get("title", "")), 620.0, 30), 30, INK, Color(1, 1, 1, 0.9), true)
	var artist := str(song.get("artist", ""))
	_text(640, 462, _fit(artist if not artist.is_empty() else "DDR MOBILE", 640.0, 17), 17, INK_SOFT, Color(1, 1, 1, 0.7), false)
	_text(640, 68, _bpm_text(song), 17, INK_SOFT, Color(1, 1, 1, 0.7), true)
	_text(640, 482, "%02d / %02d" % [song_index + 1, songs.size()], 13, Color(0.1, 0.2, 0.25, 0.6), Color(1, 1, 1, 0.5), false)

func _draw_right_panel(rects: Dictionary) -> void:
	_capsule(Rect2(1080, 70, 160, 36), PINK, "INFO")
	var chart := current_chart()
	var rows := [
		["BPM", _bpm_text(current_song()).replace("BPM ", "")],
		["NOTES", str(chart.get("notes", []).size()) if not chart.is_empty() else "—"],
		["HOLDS", str(CATALOG.count_holds(chart)) if not chart.is_empty() else "—"],
		["CHART", str(current_chart().get("ddr", "—"))],
	]
	var y := 176.0
	for row in rows:
		_text(986, y, row[0], 16, INK_SOFT, Color(1, 1, 1, 0.6), true)
		_text(1150, y, str(row[1]), 21, INK, Color(1, 1, 1, 0.8), true)
		draw_line(_p(966, y + 9), _p(1180, y + 9), Color(0.1, 0.2, 0.25, 0.14), maxf(1.0, _sc), true)
		y += 44.0
	_draw_play_button(rects.play)
	if preview_active and _version_focus == 0:
		_draw_preview_badge()
	if _version_focus != 0:
		_text(1050, 508, "CURRENT VERSION" if str(_focused_version().get("id", "")) == version else "SELECT VERSION", 15, INK_SOFT, Color.WHITE, true)
	elif not chart_error.is_empty():
		_text(1050, 508, _fit(chart_error, 330.0, 15), 15, Color("c9302c"), Color(1, 1, 1, 0.75), true)
	elif not playable:
		_text(1050, 508, "SELECT A DIFFICULTY", 15, Color("c9302c"), Color(1, 1, 1, 0.75), true)

func _draw_play_button(play: Rect2) -> void:
	var enabled := playable if _version_focus == 0 else str(_focused_version().get("id", "")) != version
	var base: Color = Color("1dbfae") if enabled else Color("9aa9b2")
	draw_colored_polygon(_round_points(_d(Rect2(play.position + Vector2(0, 4), play.size)), 12.0 * _sc), Color(0, 0, 0, 0.18))
	var points := _round_points(_d(play), 12.0 * _sc)
	draw_polygon(points, _vgrad(points, base.lightened(0.3), base.darkened(0.2)))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.8), maxf(1.5, 2.0 * _sc), true)
	_text(1030, play.get_center().y + 12, "PLAY" if _version_focus == 0 else "SELECT", 34, Color.WHITE, Color(0, 0, 0, 0.22), true)
	var center := play.get_center()
	var arrow := PackedVector2Array([
		_p(center.x + 42, center.y - 15),
		_p(center.x + 64, center.y),
		_p(center.x + 42, center.y + 15),
	])
	draw_colored_polygon(arrow, Color(1, 1, 1, 0.95))

func _draw_strip(rects: Dictionary) -> void:
	draw_rect(_d(Rect2(0, STRIP_TOP, DESIGN.x, DESIGN.y - STRIP_TOP)), Color(0.86, 0.96, 1.0, 0.86))
	draw_line(_p(0, STRIP_TOP), _p(DESIGN.x, STRIP_TOP), Color(1, 1, 1, 0.95), maxf(2.0, 3.0 * _sc), true)
	draw_rect(_d(Rect2(60, 532, DESIGN.x - 120, 116)), Color(1, 1, 1, 0.32))
	for slot in range(SLOTS):
		var index: int = int(round(_scroll)) + slot
		if index < 0 or index >= songs.size() + versions.size():
			continue
		if index < versions.size():
			_draw_version_banner(rects.banners[slot], index + 1)
		else:
			_draw_banner(rects.banners[slot], index - versions.size())
	_arrow_button(rects.prev, "◀", _strip_index() > 0)
	_arrow_button(rects.next, "▶", _strip_index() < songs.size() + versions.size() - 1)
	_text(640, 690, "◀ ▶ SELECT       ▲ ▼ DIFFICULTY       ENTER CONFIRM", 16, INK, Color(1, 1, 1, 0.75), true)

func _draw_version_banner(banner: Rect2, generation: int) -> void:
	var selected := _version_focus == generation
	if selected:
		draw_rect(_d(banner.grow(7.0)), TEAL)
	draw_rect(_d(banner), Color.WHITE)
	var entry: Dictionary = versions[generation - 1]
	var texture: Texture2D = entry.get("image")
	if texture != null:
		var image_size := texture.get_size()
		if image_size.x > 0 and image_size.y > 0:
			var fitted := image_size * minf(banner.size.x / image_size.x, banner.size.y / image_size.y)
			draw_texture_rect(texture, _d(Rect2(banner.get_center() - fitted / 2.0, fitted)), false)
	else:
		var title := str(entry.get("title", entry.get("id", "")))
		_paint_placeholder(banner, title, "", 26.0)
		_text(banner.get_center().x, banner.end.y - 5, _fit(title, banner.size.x - 8, 12), 12, Color.WHITE, Color.BLACK, true)

func _draw_banner(banner: Rect2, index: int) -> void:
	var song: Dictionary = songs[index]
	var selected := index == song_index and _version_focus == 0
	if selected:
		draw_colored_polygon(_round_points(_d(banner.grow(7.0)), 9.0 * _sc), Color(1, 1, 1, 0.95))
		draw_polyline(_round_points(_d(banner.grow(10.0)), 10.0 * _sc), Color("35d0e8"), maxf(2.0, 3.0 * _sc), true)
	var tier := str(song.get("hardest_tier", ""))
	draw_rect(_d(banner), Color("0d2233"))
	var texture: Texture2D = song.get("banner")
	if texture != null:
		draw_texture_rect(texture, _d(banner), false)
	else:
		_paint_placeholder(banner, str(song.get("title", "?")), tier, 26.0)
	if not selected:
		draw_rect(_d(banner), Color(0, 0, 0, 0.24))
	if not played.has(str(song.get("dir", ""))):
		_new_badge(Vector2(banner.position.x + banner.size.x - 22, banner.position.y - 4), 20.0)

func _arrow_button(rect: Rect2, label: String, enabled: bool) -> void:
	var color := Color("1d6fd0") if enabled else Color("b8c7d1")
	var points := _round_points(_d(rect), 8.0 * _sc)
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.7), maxf(1.0, 2.0 * _sc), true)
	_text(rect.get_center().x, rect.get_center().y + 7, label, 20, Color.WHITE, Color(0, 0, 0, 0.2), true)

func _capsule(rect: Rect2, color: Color, label: String) -> void:
	var points := _round_points(_d(rect), rect.size.y * _sc / 2.0)
	draw_colored_polygon(_round_points(_d(Rect2(rect.position + Vector2(0, 3), rect.size)), rect.size.y * _sc / 2.0), Color(0, 0, 0, 0.14))
	draw_polygon(points, _vgrad(points, color.lightened(0.34), color.darkened(0.16)))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.65), maxf(1.0, 2.0 * _sc), true)
	_text(rect.get_center().x, rect.get_center().y + 7, label, 19, Color.WHITE, Color(0, 0, 0, 0.3), true)

func _new_badge(center: Vector2, radius: float) -> void:
	var pulse := 1.0 + 0.07 * sin(_time * 4.0)
	draw_circle(_p(center.x, center.y), radius * 1.12 * pulse * _sc, Color(1, 1, 1, 0.9))
	draw_circle(_p(center.x, center.y), radius * pulse * _sc, PINK)
	_text(center.x, center.y - 1, "NEW", radius * 0.44, Color.WHITE, Color(0, 0, 0, 0.2), true)
	_text(center.x, center.y + radius * 0.52, "SONG", radius * 0.44, Color.WHITE, Color(0, 0, 0, 0.2), true)

# ----------------------------------------------------------------- primitives

func _text(cx: float, baseline: float, text: String, font_size: float, color: Color, outline := Color(0, 0, 0, 0), bold := false) -> void:
	var font := ThemeDB.fallback_font
	var px := int(round(font_size * _sc))
	if px <= 0 or text.is_empty():
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := _p(cx, baseline) - Vector2(width / 2.0, 0.0)
	if outline.a > 0.0:
		var edge := maxf(1.0, px * 0.055)
		for dx in [-1.0, 0.0, 1.0]:
			for dy in [-1.0, 0.0, 1.0]:
				if dx == 0.0 and dy == 0.0:
					continue
				draw_string(font, at + Vector2(dx, dy) * edge, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline)
	if bold:
		draw_string(font, at + Vector2(maxf(0.4, _sc * 0.7), 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _fit(text: String, max_width: float, font_size: float) -> String:
	var font := ThemeDB.fallback_font
	var px := int(round(font_size * _sc))
	if px <= 0:
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

## Packaged songs without artwork still get a readable tile in the DDR palette.
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

func _bpm_text(song: Dictionary) -> String:
	var bpm: float = float(song.get("bpm", 0.0))
	if bpm <= 0.0:
		return "BPM —"
	if absf(bpm - roundf(bpm)) < 0.01:
		return "BPM %d" % int(roundf(bpm))
	return "BPM %.2f" % bpm
