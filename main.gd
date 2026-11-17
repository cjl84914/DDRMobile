extends Control

# A finger stays assigned to its initial lane until it is lifted.
signal lane_changed(lane: int, pressed: bool)

const LANE_COUNT := 4
const KEYS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const LABELS := ["←", "↓", "↑", "→"]
const COLORS := [Color("44c8f5"), Color("9d87ff"), Color("f580bc"), Color("ffbc58")]

var fingers: Dictionary = {}
var keys_down: Dictionary = {}
var lane_counts := [0, 0, 0, 0]
enum GameState { TITLE, READY, PLAYING, RESULTS }
var game_state := GameState.TITLE
var paused := false
var menu: Control
## The results overlay (scripts/result_screen.gd) draws itself from one snapshot.
var result
var menu_button: Button
var result_counts := {}
var grade_counts := {}
# StepMania fallback theme, normal drain and default life difficulty.
const LIFE_REGEN_AFTER_MISS := 5
const LIFE_MAX := 100.0
const LIFE_START := 50.0
const LIFE_DELTAS := {"MARVELOUS": 0.8, "PERFECT": 0.8, "GREAT": 0.4, "GOOD": 0.0, "BOO": -4.0, "MISS": -8.0, "hold_complete": 0.8, "hold_break": -8.0}
const GRADES := ["MARVELOUS", "PERFECT", "GREAT", "GOOD", "BOO", "MISS"]
var life := LIFE_START
var life_regen_remaining := 0
var failed := false
var clearing_inputs := false
var audio_ended_at := -1
var pause_button: Button
var exit_button: Button
var title_button: Button
var offset_panel: HBoxContainer
var offset_label: Label
const DEFAULT_OFFSET_MS := -80
var offset_ms := DEFAULT_OFFSET_MS
var offset_changed := false
const OFFSET_CONFIG := "user://sync.cfg"
const PLAYED_CONFIG := "user://played.cfg"
const SONG_CATALOG := preload("res://scripts/song_catalog.gd")
const SONG_SELECT := preload("res://scripts/song_select.gd")
const RESULTS := preload("res://scripts/result_screen.gd")
const TITLE_SCREEN := preload("res://scripts/title_screen.gd")
var songs: Array = []
var all_songs: Array = []
var song_versions: Array = []
var song_version := ""
var title_screen: Control
var song_picker: Control
var played: Dictionary = {}
var select_button: Button
var available_charts: Array = []
var music: AudioStreamPlayer
var preview_player: AudioStreamPlayer
var preview_countdown := 0.0
var preview_remaining := 0.0
var song_background: Texture2D
var chart_notes: Array = []
var chart_error := ""
var paused_song_time := 0.0
var judge
var judge_time := -INF
var last_judgement := ""
var judgement_until := 0.0
var touch_feedback := ""
var touch_feedback_until := 0.0
const SCROLL_SPEED := 320.0 # pixels per second; visual spacing only
const OPTIONS_SETTINGS := preload("res://scripts/options_settings.gd")
var scroll_direction := "upward"
var arrow_style := OPTIONS_SETTINGS.COLOR_2
# Default StepMania sprite sheets; see assets/stepmania/README.md for provenance.
const JUDGMENT_TEXTURE := preload("res://assets/stepmania/Judgment Normal 1x6.png")
const ARROW_TEXTURE := preload("res://assets/stepmania/arrow.png")
const COLOR2_ARROW_TEXTURE := preload("res://assets/stepmania/Down Tap Addition 4x4 (doubleres).png")
const RECEPTOR_TEXTURE := preload("res://assets/stepmania/receptor.png")
const MOBILE_NOTE_TEXTURE := preload("res://assets/stepmania/_bar tap note 2x8.png")
const MOBILE_MONO_TEXTURE := preload("res://assets/stepmania/Bar Hold Head active.png")
const MOBILE_COLOR1_TEXTURE := preload("res://assets/stepmania/Bar Roll Head active.png")
const MOBILE_RECEPTOR_TEXTURE := preload("res://assets/stepmania/_bar receptor tap.png")
const MOBILE_EXPLOSION_TEXTURE := preload("res://assets/stepmania/Bar Tap Explosion bright.png")
const MOBILE_NOTE_SOURCE := Rect2(0, 0, 64, 64)
const GLOW_TEXTURE := preload("res://assets/stepmania/glow.png")
const FLASH_DURATION := 0.25
## The picker plays a clip of the highlighted song once the selection rests.
const PREVIEW_DELAY := 0.4
const PREVIEW_VOLUME_DB := -6.0
var lane_flash_times := [-INF, -INF, -INF, -INF]
const LIFE_FRAME_TEXTURE := preload("res://assets/stepmania/life-frame.png")
const COMBO_LABEL_TEXTURE := preload("res://assets/stepmania/_combo.png")
# All these StepMania sprites are padded, so sizes are matched on the ink (the
# drawn glyphs) rather than on the sprite boxes.
const JUDGMENT_ROW_HEIGHT := 32.0
const JUDGMENT_INK_HEIGHT := 23.0
# _combo.png is 128×24 with the word occupying only a 19px band starting at y=3;
# horizontally the ink runs from x=20 to x=108.
const COMBO_LABEL_SIZE := Vector2(128, 24)
const COMBO_LABEL_INK_TOP := 3.0
const COMBO_LABEL_INK_HEIGHT := 19.0
const COMBO_LABEL_INK_LEFT := 20.0
const COMBO_LABEL_INK_WIDTH := 88.0
## Gap between the digits' ink and the word's ink, as a fraction of the text height.
const COMBO_LABEL_GAP := 0.2
# combo-numbers.png cells are 88×128 with ~85px of ink starting at y=27; the
# per-digit ink widths keep the word tight against the last digit.
const COMBO_DIGIT_CELL := Vector2(88, 128)
const COMBO_DIGIT_INK_TOP := 27.0
const COMBO_DIGIT_INK_HEIGHT := 85.0
const COMBO_DIGIT_INK_LEFT: Array[float] = [15.0, 21.0, 15.0, 15.0, 13.0, 16.0, 15.0, 14.0, 14.0, 14.0]
const COMBO_DIGIT_INK_WIDTH: Array[float] = [58.0, 37.0, 59.0, 59.0, 62.0, 58.0, 59.0, 60.0, 60.0, 59.0]
const COMBO_TEXTURE := preload("res://assets/stepmania/combo-numbers.png")
const COMBO_STROKE_TEXTURE := preload("res://assets/stepmania/combo-stroke.png")
const JUDGMENT_ROWS := {"FLAWLESS": 0, "PERFECT": 1, "GREAT": 2, "GOOD": 3, "BAD": 4, "MISS": 5}
const LANE_ROTATIONS := [PI / 2.0, 0.0, PI, -PI / 2.0]
# arrow.png stacks eight 128px arrows that differ only in colour, so the note
# arrows can keep cycling through them while the chart plays.
const ARROW_FRAME_SIZE := 128
const ARROW_FRAME_COUNT := 8
## Time each colour stays on screen before the whole field advances one frame.
## Every note shares the phase, so the arrows change colour together.
const ARROW_COLOR_CYCLE_MS := 200
const ARROW_COLOR_CYCLE_SECONDS := ARROW_COLOR_CYCLE_MS / 1000.0
## Rebuilt once at startup as a pre-rotated atlas: one column per lane rotation,
## one row per colour frame. See `_build_arrow_atlas`.
var arrow_atlas: ImageTexture
var color2_arrow_atlas: ImageTexture
var ui_font: Font
var lane_label_sizes: Array[Vector2] = []

func _ready() -> void:
	ui_font = ThemeDB.fallback_font
	arrow_atlas = _build_arrow_atlas()
	color2_arrow_atlas = _build_color2_arrow_atlas()
	lane_label_sizes.resize(LANE_COUNT)
	for lane in LANE_COUNT:
		lane_label_sizes[lane] = ui_font.get_string_size(str(LABELS[lane]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	preview_player = AudioStreamPlayer.new()
	preview_player.volume_db = PREVIEW_VOLUME_DB
	add_child(preview_player)
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.position = Vector2(size.x - 140, 16)
	pause_button.size = Vector2(120, 48)
	pause_button.pressed.connect(_toggle_pause)
	add_child(pause_button)
	exit_button = Button.new()
	exit_button.text = "SONG SELECT"
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.position = Vector2(size.x - 220, 140)
	exit_button.size = Vector2(200, 56)
	exit_button.visible = false
	exit_button.pressed.connect(_exit_to_selection)
	add_child(exit_button)
	title_button = Button.new()
	title_button.text = "◀ TITLE"
	title_button.focus_mode = Control.FOCUS_NONE
	title_button.size = Vector2(126, 44)
	title_button.visible = false
	title_button.pressed.connect(_show_title)
	# Match the picker's dark-on-teal language instead of the default OS button.
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.09, 0.15, 0.19, 0.85)
	pill.set_corner_radius_all(16)
	for state in ["normal", "hover", "pressed", "focus"]:
		title_button.add_theme_stylebox_override(state, pill)
	title_button.add_theme_font_size_override("font_size", 20)
	title_button.add_theme_color_override("font_color", Color("9fe9ff"))
	add_child(title_button)
	_setup_offset_controls()
	_load_offset()
	music = AudioStreamPlayer.new()
	add_child(music)
	lane_changed.connect(_on_lane_changed)
	song_versions = SONG_CATALOG.generations()
	all_songs = SONG_CATALOG.load_entries()
	if not song_versions.is_empty():
		song_version = str(song_versions[0].id)
	songs = all_songs.filter(func(song): return song.get("version", "") == song_version)
	_load_played()
	_setup_picker()
	_setup_menu()
	_select_song(SONG_CATALOG.default_index(songs))
	_setup_title()
	pause_button.visible = false
	_show_title()

func _setup_title() -> void:
	title_screen = TITLE_SCREEN.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.menu_selected.connect(_on_title_selected)
	add_child(title_screen)
	# The picker draws itself over everything added before it; keep the TITLE
	# button on top so it stays tappable while the picker owns the screen.
	title_button.move_to_front()

func _show_title() -> void:
	_stop_preview()
	game_state = GameState.TITLE
	pause_button.visible = false
	exit_button.visible = false
	offset_panel.visible = false
	menu.visible = false
	if song_picker != null:
		song_picker.visible = false
	if title_screen != null:
		title_screen.visible = true
	title_button.visible = false
	queue_redraw()

func _enter_game_mode() -> void:
	if title_screen != null:
		title_screen.visible = false
	game_state = GameState.READY
	if song_picker != null:
		song_picker.visible = true
	title_button.visible = true
	_arm_preview()
	queue_redraw()

func _on_title_selected(action: String) -> void:
	match action:
		"game":
			_enter_game_mode()
		"exit":
			get_tree().quit()
		_:
			if title_screen != null:
				title_screen.show_notice("%s IS NOT AVAILABLE YET" % action.to_upper())

func _setup_picker() -> void:
	song_picker = SONG_SELECT.new()
	song_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	song_picker.setup_versions(song_versions)
	song_picker.setup(songs, played)
	song_picker.set_version_state(song_version)
	song_picker.version_requested.connect(_on_version_requested)
	song_picker.version_focus_changed.connect(_on_version_focus_changed)
	song_picker.song_requested.connect(_on_song_requested)
	song_picker.difficulty_requested.connect(_on_difficulty_requested)
	song_picker.play_requested.connect(_on_play_requested)
	add_child(song_picker)

func _setup_menu() -> void:
	# Results overlay only: the picker owns the READY screen.
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	add_child(menu)
	result = RESULTS.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.retry_pressed.connect(_start_game)
	result.select_pressed.connect(_show_selection)
	menu.add_child(result)
	menu_button = result.retry_button
	select_button = result.select_button
	menu_button.disabled = not chart_error.is_empty()

## Project-local weighted accuracy, not a claim of original DDR grading/scoring.
## A failed run grades E, matching the arcade's lowest letter.
func _result_rating() -> String:
	if failed:
		return "E"
	var total := chart_notes.size()
	if total == 0:
		return "—"
	var weighted := float(grade_counts.get("MARVELOUS", 0)) + float(grade_counts.get("PERFECT", 0)) * 0.98 + float(grade_counts.get("GREAT", 0)) * 0.65 + float(grade_counts.get("GOOD", 0)) * 0.25
	var accuracy := weighted / total
	if accuracy >= 0.95:
		return "AAA"
	if accuracy >= 0.90:
		return "AA"
	if accuracy >= 0.80:
		return "A"
	if accuracy >= 0.65:
		return "B"
	if accuracy >= 0.50:
		return "C"
	return "D"

## The picker asks for a song; every resolution stays in one place so both the
## keyboard/touch path and the tests share the exact same validation.
func _on_version_focus_changed(active: bool) -> void:
	if active:
		_stop_preview()

func _on_version_requested(version: String) -> void:
	if version == song_version or not song_versions.any(func(item): return item.id == version):
		return
	_stop_preview()
	song_version = version
	songs = all_songs.filter(func(song): return song.get("version", "") == song_version)
	song_picker.setup(songs, played)
	song_picker.set_version_state(song_version)
	_select_song(SONG_CATALOG.default_index(songs))

func _on_song_requested(index: int) -> void:
	_select_song(index)

func _on_difficulty_requested(index: int) -> void:
	_select_difficulty(index)

func _on_play_requested() -> void:
	_start_game()

func can_play() -> bool:
	return chart_error.is_empty() and not chart_notes.is_empty() and music != null and music.stream != null

func _sync_picker(index: int, selected := -1) -> void:
	if song_picker == null:
		return
	var chart: int = selected if selected >= 0 else _chart_index()
	song_picker.set_song_state(index, available_charts, chart, chart_error, can_play())

func _chart_index() -> int:
	if song_picker == null:
		return 0
	return song_picker.chart_index

func _select_song(index: int) -> void:
	available_charts = []
	chart_notes = []
	music.stop()
	music.stream = null
	chart_error = ""
	song_background = null
	if index < 0 or index >= songs.size():
		chart_error = "Invalid song selection"
		_sync_picker(index)
		return
	var song: Dictionary = songs[index]
	song_background = song.get("background")
	if not str(song.get("error", "")).is_empty():
		chart_error = str(song.error)
	elif song.get("charts", []).is_empty():
		chart_error = "No playable charts"
	elif not ResourceLoader.exists(song.audio_path):
		chart_error = "Audio unavailable: %s" % song.get("audio", "")
	else:
		music.stream = load(song.audio_path) as AudioStream
		if music.stream == null:
			chart_error = "Audio could not be loaded: %s" % song.get("audio", "")
		else:
			available_charts = song.charts.duplicate()
	if chart_error.is_empty():
		# Arcade default is BASIC: prefer the Easy chart, else the first playable one.
		var initial := -1
		for i in available_charts.size():
			if not _chart_problem(available_charts[i]).is_empty():
				continue
			if initial < 0:
				initial = i
			if str(available_charts[i].get("difficulty", "")) == "Easy":
				initial = i
				break
		initial = maxi(initial, 0)
		_sync_picker(index, initial)
		_select_difficulty(initial)
	else:
		_sync_picker(index, 0)
	_arm_preview()

## Song preview: waiting a beat keeps fast scrolling quiet, and the clip stops
## by itself so the picker is never a jukebox.
func _arm_preview() -> void:
	_stop_preview()
	if song_picker != null and song_picker._version_focus != 0:
		return
	preview_countdown = PREVIEW_DELAY
	if song_picker != null:
		song_picker.set_preview_state(false)

func _stop_preview() -> void:
	preview_countdown = 0.0
	preview_remaining = 0.0
	if preview_player != null and preview_player.playing:
		preview_player.stop()
	if song_picker != null:
		song_picker.set_preview_state(false)

func _start_preview() -> void:
	if game_state != GameState.READY or music.stream == null:
		return
	var song: Dictionary = current_song()
	if song.is_empty():
		return
	var window: Vector2 = SONG_CATALOG.preview_window(song)
	if window.y <= 0.5:
		return
	preview_player.stream = music.stream
	preview_player.play(window.x)
	preview_remaining = window.y
	if song_picker != null:
		song_picker.set_preview_state(true)

func _update_preview(delta: float) -> void:
	if game_state != GameState.READY or song_picker == null or not song_picker.visible:
		return
	if preview_countdown > 0.0:
		preview_countdown -= delta
		if preview_countdown <= 0.0:
			_start_preview()
		return
	if preview_remaining > 0.0:
		preview_remaining -= delta
		if preview_remaining <= 0.0:
			_stop_preview()
			if song_picker != null:
				song_picker.set_preview_state(false)

func _chart_problem(chart: Dictionary) -> String:
	return SONG_CATALOG.chart_problem(chart)

func _select_difficulty(index: int) -> void:
	if index < 0 or index >= available_charts.size():
		chart_notes = []
		chart_error = "Invalid difficulty selection"
		if song_picker != null:
			song_picker.set_chart_state(index, chart_error, false)
		return
	chart_notes = available_charts[index].notes
	chart_error = _chart_problem(available_charts[index])
	menu_button.disabled = not chart_error.is_empty()
	if song_picker != null:
		song_picker.set_chart_state(index, chart_error, can_play())

func _exit_to_selection() -> void:
	if game_state != GameState.PLAYING or not paused:
		return
	_show_selection()

func _show_selection() -> void:
	var previous_song: int = song_picker.song_index if song_picker != null else 0
	var selected_difficulty: int = _chart_index()
	clear_inputs()
	music.stop()
	music.stream_paused = false
	paused = false
	offset_changed = false
	paused_song_time = 0.0
	audio_ended_at = -1
	judge_time = -INF
	result_counts = {}
	last_judgement = ""
	touch_feedback = ""
	game_state = GameState.READY
	judge = null
	pause_button.visible = false
	exit_button.visible = false
	offset_panel.visible = false
	menu.visible = false
	if song_picker != null:
		song_picker.visible = true
	title_button.visible = true
	_select_song(previous_song)
	if selected_difficulty >= 0 and selected_difficulty < available_charts.size():
		_select_difficulty(selected_difficulty)

func _start_game() -> void:
	_stop_preview()
	if chart_error != "" or music.stream == null or game_state == GameState.PLAYING:
		return
	if song_picker != null:
		song_picker.visible = false
	title_button.visible = false
	_mark_played()
	scroll_direction = OPTIONS_SETTINGS.load_scroll_direction()
	arrow_style = OPTIONS_SETTINGS.load_arrow_style()
	clear_inputs()
	judge = preload("res://scripts/judgement.gd").new(chart_notes)
	judge_time = -INF
	lane_flash_times = [-INF, -INF, -INF, -INF]
	paused = false
	offset_changed = false
	paused_song_time = 0.0
	audio_ended_at = -1
	result_counts = {"tap": 0, "hold_start": 0, "hold_complete": 0, "miss": 0, "hold_break": 0}
	grade_counts = {}
	for grade in GRADES:
		grade_counts[grade] = 0
	life = LIFE_START
	life_regen_remaining = 0
	failed = false
	last_judgement = ""
	touch_feedback = ""
	music.stop()
	music.stream_paused = false
	game_state = GameState.PLAYING
	menu.visible = false
	pause_button.visible = false
	pause_button.text = "PAUSE"
	offset_panel.visible = false
	music.play()

func _finish_game() -> void:
	if game_state != GameState.PLAYING:
		return
	# Transition before releasing inputs: cleanup must not produce new judgements.
	game_state = GameState.RESULTS
	clear_inputs()
	music.stop()
	pause_button.visible = false
	exit_button.visible = false
	offset_panel.visible = false
	var chart: Dictionary = available_charts[_chart_index()] if _chart_index() >= 0 and _chart_index() < available_charts.size() else {}
	result.show_result({
		"title": str(current_song().get("title", "")),
		"artist": str(current_song().get("artist", "")),
		"cover": song_background,
		"tier": SONG_CATALOG.tier_name(str(chart.get("difficulty", ""))),
		"meter": int(chart.get("meter", 0)),
		"grade": _result_rating(),
		"score": judge.score,
		"combo": judge.max_combo,
		"cleared": not failed,
		"counts": {
			"MARVELOUS": int(grade_counts.get("MARVELOUS", 0)),
			"PERFECT": int(grade_counts.get("PERFECT", 0)),
			"GREAT": int(grade_counts.get("GREAT", 0)),
			"GOOD": int(grade_counts.get("GOOD", 0)),
			"OK": int(grade_counts.get("BOO", 0)),
			"MISS": int(grade_counts.get("MISS", 0)),
			"holds": int(result_counts.get("hold_complete", 0)),
			"breaks": int(result_counts.get("hold_break", 0)),
		},
	})
	menu_button.text = "RETRY"
	select_button.visible = true
	menu.visible = true

func _load_played() -> void:
	var config := ConfigFile.new()
	if config.load(PLAYED_CONFIG) != OK:
		return
	for key in config.get_section_keys("played"):
		played[key] = true

func _mark_played() -> void:
	if song_picker == null or played.has(str(current_song().get("dir", ""))):
		return
	var song := current_song()
	if song.is_empty():
		return
	played[str(song.get("dir", ""))] = true
	song_picker.mark_played(played)
	var config := ConfigFile.new()
	for key in played:
		config.set_value("played", key, true)
	# A read-only sandbox only costs the NEW badge, so a failed save is not fatal.
	var error := config.save(PLAYED_CONFIG)
	if error != OK:
		print_debug("Could not save played songs: ", error_string(error))

func current_song() -> Dictionary:
	if song_picker == null:
		return songs[0] if not songs.is_empty() else {}
	return song_picker.current_song()

func _chart_end_time() -> float:
	var end := 0.0
	for note in chart_notes:
		end = maxf(end, float(note.time) + preload("res://scripts/judgement.gd").WINDOW + 0.001)
		if note.type == "hold":
			end = maxf(end, float(note.end_time))
	return end

# Change calibration only while paused; restart the scene when resuming so the
# judge's monotonic clock and already-judged notes cannot move backwards.
func _setup_offset_controls() -> void:
	offset_panel = HBoxContainer.new()
	offset_panel.position = Vector2(size.x - 350, 80)
	offset_panel.visible = false
	add_child(offset_panel)
	var earlier := Button.new()
	earlier.text = "-10 ms"
	earlier.focus_mode = Control.FOCUS_NONE
	earlier.pressed.connect(_change_offset.bind(-10))
	offset_panel.add_child(earlier)
	offset_label = Label.new()
	offset_label.custom_minimum_size.x = 150
	offset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offset_panel.add_child(offset_label)
	var later := Button.new()
	later.text = "+10 ms"
	later.focus_mode = Control.FOCUS_NONE
	later.pressed.connect(_change_offset.bind(10))
	offset_panel.add_child(later)

func _load_offset() -> void:
	var config := ConfigFile.new()
	if config.load(OFFSET_CONFIG) == OK:
		var value = config.get_value("sync", "offset_ms", DEFAULT_OFFSET_MS)
		if typeof(value) == TYPE_INT:
			offset_ms = clampi(value, -500, 500)
	_update_offset_label()

func _update_offset_label() -> void:
	offset_label.text = "SYNC %+d ms" % offset_ms

func _change_offset(delta: int) -> void:
	var next := clampi(offset_ms + delta, -500, 500)
	if next == offset_ms:
		return
	offset_ms = next
	offset_changed = true
	_update_offset_label()
	var config := ConfigFile.new()
	config.set_value("sync", "offset_ms", offset_ms)
	var error := config.save(OFFSET_CONFIG)
	if error != OK:
		push_error("Could not save sync offset: %s" % error_string(error))

func _process(delta: float) -> void:
	_update_preview(delta)
	# Align the title button with the picker's bottom control hints.
	var picker_scale := minf(size.x / 1280.0, size.y / 720.0)
	var picker_origin := (size - Vector2(1280, 720) * picker_scale) / 2.0
	title_button.scale = Vector2.ONE * picker_scale
	title_button.position = picker_origin + Vector2(210, 658) * picker_scale
	# Keep controls attached to the right edge when the viewport changes.
	pause_button.position.x = size.x - pause_button.size.x - 20.0
	exit_button.position.x = size.x - exit_button.size.x - 20.0
	offset_panel.position.x = size.x - offset_panel.size.x - 20.0
	if game_state == GameState.PLAYING and judge != null and not paused:
		if not music.playing and audio_ended_at < 0:
			audio_ended_at = Time.get_ticks_usec()
		_apply_judgements(judge.advance(_judgement_time()))
		if game_state == GameState.PLAYING and audio_ended_at >= 0 and chart_time() >= _chart_end_time():
			_finish_game()
	queue_redraw()

func chart_time() -> float:
	return song_time() + offset_ms / 1000.0

func _judgement_time() -> float:
	judge_time = maxf(judge_time, chart_time())
	return judge_time

func _on_lane_changed(lane: int, pressed: bool) -> void:
	if judge == null or game_state != GameState.PLAYING or clearing_inputs:
		return
	var now := _judgement_time()
	_apply_judgements(judge.press(lane, now) if pressed else judge.release(lane, now))

func _apply_judgements(events: Array) -> void:
	if game_state != GameState.PLAYING:
		return
	var depleted := false
	for event in events:
		var kind: String = event.get("kind", "")
		if not result_counts.has(kind):
			continue
		result_counts[kind] += 1
		var life_key := kind
		match kind:
			"tap", "hold_start", "miss":
				var grade: String = "MISS" if kind == "miss" else str(event.get("grade", "MARVELOUS"))
				if grade not in GRADES:
					continue
				grade_counts[grade] = grade_counts.get(grade, 0) + 1
				life_key = grade
				if kind in ["tap", "hold_start"] and (scroll_direction == "downward" or grade in ["MARVELOUS", "PERFECT"]):
					var lane := int(event.get("lane", -1))
					if lane >= 0 and lane < LANE_COUNT:
						lane_flash_times[lane] = chart_time()
				last_judgement = {"MARVELOUS": "FLAWLESS", "BOO": "BAD"}.get(grade, grade)
			"hold_complete": last_judgement = "HOLD OK"
			"hold_break": last_judgement = "HOLD BREAK"
		if kind in ["tap", "hold_start", "miss"]:
			if not event.get("row_judged", false):
				judgement_until = chart_time() + 0.7
				continue
			life_key = str(event.row_grade)
		var delta := float(LIFE_DELTAS.get(life_key, 0.0))
		if delta < 0.0:
			life_regen_remaining = LIFE_REGEN_AFTER_MISS
		else:
			life_regen_remaining = maxi(life_regen_remaining - 1, 0)
			if life_regen_remaining > 0:
				delta = 0.0
		if not depleted:
			life = clampf(life + delta, 0.0, LIFE_MAX)
		if life <= 0.0:
			depleted = true
		judgement_until = chart_time() + 0.7
	if depleted:
		life = 0.0
		failed = true
		_finish_game()

func song_time() -> float:
	if music == null or music.stream == null:
		return 0.0
	if paused:
		return paused_song_time
	if game_state == GameState.READY:
		return 0.0
	if audio_ended_at >= 0:
		return music.stream.get_length() + (Time.get_ticks_usec() - audio_ended_at) / 1000000.0
	if not music.playing:
		return music.stream.get_length()
	return music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, \
			NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, \
			NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		clear_inputs()

func _input(event: InputEvent) -> void:
	if game_state != GameState.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not paused and not fingers.has(event.index) and not _over_pause(event.position):
				var lane := _lane_at(event.position)
				if lane >= 0:
					_record_touch_feedback(lane)
					fingers[event.index] = lane
					_change_lane(lane, 1)
		elif fingers.has(event.index):
			var lane: int = fingers[event.index]
			fingers.erase(event.index)
			_change_lane(lane, -1)
	elif event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_ESCAPE and event.pressed:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		var lane := KEYS.find(event.physical_keycode)
		if lane < 0:
			return
		if event.pressed and not paused and not keys_down.has(event.physical_keycode):
			keys_down[event.physical_keycode] = lane
			_change_lane(lane, 1)
		elif not event.pressed and keys_down.has(event.physical_keycode):
			keys_down.erase(event.physical_keycode)
			_change_lane(lane, -1)

func _unhandled_input(event: InputEvent) -> void:
	# The picker owns its own keys; ESC is the one way back to the title.
	if game_state != GameState.READY:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_stop_preview()
		_show_title()
		get_viewport().set_input_as_handled()


# Report the nearest same-lane note, including misses, without changing judgment.
# This measures event processing time, not the hardware touch timestamp.
func _record_touch_feedback(lane: int) -> void:
	var now := _judgement_time()
	if lane_counts[lane] > 0:
		touch_feedback = "L%d: RELEASE FIRST" % (lane + 1)
	else:
		var best_delta := INF
		for note in chart_notes:
			if int(note.lane) == lane:
				var delta: float = now - float(note.time)
				if absf(delta) < absf(best_delta):
					best_delta = delta
		if is_finite(best_delta) and absf(best_delta) <= 0.5:
			touch_feedback = "L%d: %s %d ms" % [lane + 1, "LATE" if best_delta >= 0.0 else "EARLY", roundi(absf(best_delta) * 1000.0)]
		else:
			touch_feedback = "L%d: NO NEAR NOTE" % (lane + 1)
	touch_feedback_until = chart_time() + 2.0

func _lane_at(pos: Vector2) -> int:
	var area := _play_area()
	if not area.has_point(pos):
		return -1
	return mini(int((pos.x - area.position.x) / (area.size.x / LANE_COUNT)), LANE_COUNT - 1)

func _play_area() -> Rect2:
	if scroll_direction == "downward":
		return Rect2(Vector2.ZERO, size)
	var width := minf(size.x * 0.92, size.y * 1.35)
	return Rect2((size.x - width) / 2.0, 0, width, size.y)

func _over_pause(pos: Vector2) -> bool:
	return pause_button != null and pause_button.visible and Rect2(pause_button.position, pause_button.size).has_point(pos)

func _change_lane(lane: int, delta: int) -> void:
	var was_pressed: bool = lane_counts[lane] > 0
	lane_counts[lane] += delta
	assert(lane_counts[lane] >= 0)
	var is_pressed: bool = lane_counts[lane] > 0
	if was_pressed != is_pressed:
		lane_changed.emit(lane, is_pressed)
	queue_redraw()

func clear_inputs() -> void:
	if clearing_inputs:
		return
	clearing_inputs = true
	if judge != null and music != null and game_state == GameState.PLAYING:
		_apply_judgements(judge.clear_holds(_judgement_time()))
	fingers.clear()
	keys_down.clear()
	for lane in LANE_COUNT:
		if lane_counts[lane] > 0:
			lane_counts[lane] = 0
			lane_changed.emit(lane, false)
	clearing_inputs = false
	queue_redraw()

func _toggle_pause() -> void:
	if game_state != GameState.PLAYING:
		return
	if paused and offset_changed:
		game_state = GameState.RESULTS
		_start_game()
		return
	if not paused:
		paused_song_time = song_time()
	paused = not paused
	if not paused and audio_ended_at >= 0:
		audio_ended_at = Time.get_ticks_usec() - int((paused_song_time - music.stream.get_length()) * 1000000.0)
	clear_inputs()
	if game_state != GameState.PLAYING:
		paused = false
		return
	if music != null:
		music.stream_paused = paused
	pause_button.text = "RESUME" if paused else "PAUSE"
	offset_panel.visible = paused
	exit_button.visible = paused
	queue_redraw()

func _note_visible_state(state: String) -> bool:
	return state in ["pending", "holding", "missed", "broken"]

# The colour phase depends on the clock, not on the note, so every arrow on the
# field changes colour at the same moment and keeps cycling while the chart runs.
func _arrow_frame_index(now: float) -> int:
	# Whole milliseconds keep exact step boundaries from drifting, and posmod
	# wraps the onset (negative chart times from a negative sync offset).
	var step := floori(float(roundi(now * 1000.0)) / float(ARROW_COLOR_CYCLE_MS))
	return posmod(step, ARROW_FRAME_COUNT)

func _arrow_source(frame: int, lane: int) -> Rect2:
	return Rect2(lane * ARROW_FRAME_SIZE, frame * ARROW_FRAME_SIZE, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE)

# Color 1 cycles all notes together; monochrome uses the original red frame.
# Color 2 cycles the sixteen frames of its own sprite sheet.
func _note_arrow_frame(_note: Dictionary, now: float) -> int:
	if arrow_style == OPTIONS_SETTINGS.COLOR_1:
		return _arrow_frame_index(now)
	if arrow_style == OPTIONS_SETTINGS.COLOR_2:
		return posmod(floori(float(roundi(now * 1000.0)) / float(ARROW_COLOR_CYCLE_MS)), 16)
	return 0

# Pre-rotate every color and lane once, avoiding per-note draw transforms.
func _build_arrow_atlas(texture: Texture2D = ARROW_TEXTURE) -> ImageTexture:
	var sheet := texture.get_image()
	if sheet == null or sheet.is_empty():
		return null
	var atlas := Image.create_empty(ARROW_FRAME_SIZE * LANE_COUNT, ARROW_FRAME_SIZE * ARROW_FRAME_COUNT, false, sheet.get_format())
	for lane in LANE_COUNT:
		var quarter_turns := posmod(int(roundf(LANE_ROTATIONS[lane] / (PI / 2.0))), 4)
		for frame in ARROW_FRAME_COUNT:
			# Frames are stacked rows in the sheet, so rotate them one by one:
			# rotating the whole sheet would turn the stack into columns.
			var cell: Image = sheet.get_region(Rect2i(0, frame * ARROW_FRAME_SIZE, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE))
			for turn in quarter_turns:
				cell.rotate_90(CLOCKWISE)
			atlas.blit_rect(cell, Rect2i(0, 0, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE), Vector2i(lane * ARROW_FRAME_SIZE, frame * ARROW_FRAME_SIZE))
	return ImageTexture.create_from_image(atlas)

# Arrange the 4×4 sheet as rows in a pre-rotated lane atlas.
func _build_color2_arrow_atlas() -> ImageTexture:
	var sheet := COLOR2_ARROW_TEXTURE.get_image()
	if sheet == null or sheet.is_empty():
		return null
	var atlas := Image.create_empty(ARROW_FRAME_SIZE * LANE_COUNT, ARROW_FRAME_SIZE * 16, false, sheet.get_format())
	for lane in LANE_COUNT:
		var quarter_turns := posmod(int(roundf(LANE_ROTATIONS[lane] / (PI / 2.0))), 4)
		for frame in 16:
			var cell := sheet.get_region(Rect2i((frame % 4) * ARROW_FRAME_SIZE, (frame / 4) * ARROW_FRAME_SIZE, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE))
			for turn in quarter_turns:
				cell.rotate_90(CLOCKWISE)
			atlas.blit_rect(cell, Rect2i(0, 0, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE), Vector2i(lane * ARROW_FRAME_SIZE, frame * ARROW_FRAME_SIZE))
	return ImageTexture.create_from_image(atlas)

func _judgment_source(label: String) -> Rect2:
	if not JUDGMENT_ROWS.has(label):
		return Rect2()
	return Rect2(0, JUDGMENT_ROWS[label] * 32, 192, 32)

func _combo_digit_source(digit: int) -> Rect2:
	if digit < 0 or digit > 9:
		return Rect2()
	return Rect2((digit % 4) * 88, (digit / 4) * 128, 88, 128)

func _score_rect() -> Rect2:
	var width := minf(size.x * 0.32, 280.0)
	return Rect2(size.x - width - 12.0, 12.0, width, width * 48.0 / 200.0)

func _draw_score(value: int) -> void:
	var digits := str(maxi(value, 0)).pad_zeros(8)
	var bounds := _score_rect()
	var advance := bounds.size.x / digits.length()
	for i in range(digits.length()):
		var source := _combo_digit_source(int(digits.substr(i, 1)))
		var dest := Rect2(bounds.position + Vector2(i * advance, 0), Vector2(advance, bounds.size.y))
		draw_texture_rect_region(COMBO_STROKE_TEXTURE, dest, source)
		draw_texture_rect_region(COMBO_TEXTURE, dest, source, Color("fbe9dd"))

## Pure layout so tests can check the combo row without rendering.
## Returns {"digits": Array[Rect2], "label": Rect2, "advance": float, "text_height": float}.
## All three sprites carry padding, so sizes are matched on their ink (the drawn
## glyphs), not on the sprite boxes: the judgment rows are 32px tall with 23px
## of ink, and the combo digits/label are scaled so their ink is that same
## height. Spacing is measured between ink edges too, so the word sits right
## next to the digits instead of after their padding. The row shrinks only if it
## would overflow the play area.
func _combo_layout(value: int, center: Vector2) -> Dictionary:
	var digits := str(maxi(value, 0))
	var area := _play_area()
	var judgment_width := minf(area.size.x * 0.65, 316.0)
	var judgment_height := judgment_width / 6.0
	var text_height := judgment_height * JUDGMENT_INK_HEIGHT / JUDGMENT_ROW_HEIGHT
	var digit_scale := text_height / COMBO_DIGIT_INK_HEIGHT
	var label_scale := text_height / COMBO_LABEL_INK_HEIGHT
	var digit_size := COMBO_DIGIT_CELL * digit_scale
	var label_size := COMBO_LABEL_SIZE * label_scale
	var advance := COMBO_DIGIT_CELL.x * digit_scale * 0.75
	var first := int(digits.substr(0, 1))
	var last := int(digits.substr(digits.length() - 1, 1))
	var digit_ink_left := COMBO_DIGIT_INK_LEFT[first] * digit_scale
	var digit_ink_right := advance * (digits.length() - 1) + (COMBO_DIGIT_INK_LEFT[last] + COMBO_DIGIT_INK_WIDTH[last]) * digit_scale
	var label_ink_left := COMBO_LABEL_INK_LEFT * label_scale
	var label_ink_width := COMBO_LABEL_INK_WIDTH * label_scale
	var ink_gap := text_height * COMBO_LABEL_GAP
	var ink_width := (digit_ink_right - digit_ink_left) + ink_gap + label_ink_width
	var fit := minf(1.0, area.size.x / ink_width) if ink_width > 0.0 else 1.0
	text_height *= fit
	digit_size *= fit
	label_size *= fit
	advance *= fit
	ink_gap *= fit
	digit_ink_left *= fit
	digit_ink_right *= fit
	label_ink_left *= fit
	label_ink_width *= fit
	ink_width = (digit_ink_right - digit_ink_left) + ink_gap + label_ink_width
	# Anchor on the ink band so the row stays centred regardless of padding.
	var ink_left := center.x - ink_width / 2.0
	var left := ink_left - digit_ink_left
	# Align the ink bands, not the padded boxes, on a common centre line.
	var ink_center_y := center.y + text_height / 2.0
	var digit_ink_mid := (COMBO_DIGIT_INK_TOP + COMBO_DIGIT_INK_HEIGHT / 2.0) / COMBO_DIGIT_CELL.y
	var label_ink_mid := (COMBO_LABEL_INK_TOP + COMBO_LABEL_INK_HEIGHT / 2.0) / COMBO_LABEL_SIZE.y
	var digit_top := ink_center_y - digit_ink_mid * digit_size.y
	var digit_rects: Array[Rect2] = []
	for i in range(digits.length()):
		digit_rects.append(Rect2(Vector2(left + i * advance, digit_top), digit_size))
	var label_x := ink_left + (digit_ink_right - digit_ink_left) + ink_gap - label_ink_left
	var label_rect := Rect2(Vector2(label_x, ink_center_y - label_ink_mid * label_size.y), label_size)
	return {"digits": digit_rects, "label": label_rect, "advance": advance, "text_height": text_height}

func _draw_combo(value: int, center: Vector2) -> void:
	var layout := _combo_layout(value, center)
	var digits := str(maxi(value, 0))
	var digit_rects: Array = layout["digits"]
	for i in range(digit_rects.size()):
		var source := _combo_digit_source(int(digits.substr(i, 1)))
		draw_texture_rect_region(COMBO_STROKE_TEXTURE, digit_rects[i], source)
		draw_texture_rect_region(COMBO_TEXTURE, digit_rects[i], source, Color("fbe9dd"))
	draw_texture_rect(COMBO_LABEL_TEXTURE, layout["label"], false)

func _draw_lane_texture(texture: Texture2D, source: Rect2, center: Vector2, extent: float, lane: int, tint := Color.WHITE) -> void:
	draw_set_transform(center, LANE_ROTATIONS[lane])
	draw_texture_rect_region(texture, Rect2(Vector2(-extent / 2.0, -extent / 2.0), Vector2(extent, extent)), source, tint)
	draw_set_transform(Vector2.ZERO)

func _background_rect(texture_size: Vector2, viewport_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var scale_factor := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	var scaled := texture_size * scale_factor
	return Rect2((viewport_size - scaled) / 2.0, scaled)

func _target_y() -> float:
	return size.y * (0.85 if scroll_direction == "downward" else 0.18)

func _note_y(note_time: float, current_time: float) -> float:
	var remaining := note_time - current_time
	if scroll_direction != "downward":
		return _target_y() + remaining * SCROLL_SPEED
	# Compress distant notes toward the top, then accelerate smoothly as they
	# approach the judgment line. Keep off-screen notes outside the playfield.
	var target := _target_y()
	var duration := maxf(target, 2.0) / SCROLL_SPEED
	if remaining >= duration:
		return -(remaining - duration) * SCROLL_SPEED
	const PERSPECTIVE_POWER := 2.5
	if remaining <= 0.0:
		return target - remaining * SCROLL_SPEED * PERSPECTIVE_POWER
	var progress := 1.0 - remaining / duration
	return target * pow(progress, PERSPECTIVE_POWER)

# Downward lanes widen continuously to the bottom screen corners.
# Time and judgment are unchanged; only the visual projection differs.
func _downward_lane_edge(lane_edge: float, y: float) -> float:
	var depth := maxf(y / maxf(size.y, 1.0), 0.0)
	var width := size.x * lerpf(0.12, 1.0, depth)
	return (size.x - width) * 0.5 + width * lane_edge / LANE_COUNT

func _mobile_note_texture() -> Texture2D:
	if arrow_style == OPTIONS_SETTINGS.MONOCHROME:
		return MOBILE_MONO_TEXTURE
	if arrow_style == OPTIONS_SETTINGS.COLOR_1:
		return MOBILE_COLOR1_TEXTURE
	return MOBILE_NOTE_TEXTURE

func _mobile_note_source(_lane: int, now: float = 0.0) -> Rect2:
	var frame := posmod(floori(float(roundi(now * 1000.0)) / float(ARROW_COLOR_CYCLE_MS)), 7) if arrow_style == OPTIONS_SETTINGS.COLOR_2 else 0
	return Rect2(0, frame * 64, 64, 64)

# Match the visible artwork, not the differently padded texture canvases:
# note cell ink 62×16 of 64×64; receptor ink 70×24 of 128×128.
func _mobile_receptor_rect(note_rect: Rect2) -> Rect2:
	var receptor_size := note_rect.size * Vector2((62.0 / 64.0) / (70.0 / 128.0), (16.0 / 64.0) / (24.0 / 128.0))
	return Rect2(note_rect.get_center() - receptor_size * 0.5, receptor_size)

func _downward_note_height(y: float) -> float:
	var lane_width := _downward_lane_edge(1.0, y) - _downward_lane_edge(0.0, y)
	return lane_width * MOBILE_NOTE_SOURCE.size.y / MOBILE_NOTE_SOURCE.size.x

func _downward_bar(lane: int, y1: float, y2: float, color: Color) -> void:
	var top := clampf(minf(y1, y2), 0.0, size.y)
	var bottom := clampf(maxf(y1, y2), 0.0, size.y)
	if bottom <= top:
		return
	var points := PackedVector2Array([
		Vector2(_downward_lane_edge(lane, top), top),
		Vector2(_downward_lane_edge(lane + 1, top), top),
		Vector2(_downward_lane_edge(lane + 1, bottom), bottom),
		Vector2(_downward_lane_edge(lane, bottom), bottom),
	])
	draw_colored_polygon(points, color)

func _life_frame_rect(area: Rect2) -> Rect2:
	# Keep the bar clear of the top-right score on narrow screens.
	var room := _score_rect().position.x - 24.0 - 12.0
	var frame_width := clampf(minf(area.size.x - 20.0, 462.0), 0.0, maxf(room, 0.0))
	var frame_height := frame_width * 64.0 / 462.0
	return Rect2(12.0, 8.0, frame_width, frame_height)

func _draw() -> void:
	if game_state == GameState.TITLE or game_state == GameState.READY:
		# The title screen and the picker own the screen; no play field here.
		return
	# The cover-fitted background always fills the viewport, so the opaque base
	# rect is only needed when there is no background to hide it.
	var screen := Rect2(Vector2.ZERO, size)
	var background := Rect2()
	if song_background != null:
		background = _background_rect(song_background.get_size(), size)
	if song_background == null or not background.encloses(screen):
		draw_rect(screen, Color("101321"))
	if song_background != null:
		# Darken through the texture's own modulate instead of a second
		# full-screen blend pass: same look, one less overdraw layer on mobile.
		draw_texture_rect(song_background, background, false, Color(0.65, 0.65, 0.65))
	var area := _play_area()
	var lane_width := area.size.x / LANE_COUNT
	if scroll_direction == "downward":
		for lane in LANE_COUNT:
			var lane_color := Color(Color.WHITE, 0.13 if lane_counts[lane] == 0 else 0.32)
			_downward_bar(lane, 0.0, size.y, lane_color)
			draw_line(Vector2(_downward_lane_edge(lane, 0.0), 0.0), Vector2(_downward_lane_edge(lane, size.y), size.y), Color(1, 1, 1, 0.35), 2.0)
			var target := _target_y()
			var left := _downward_lane_edge(lane, target)
			var right := _downward_lane_edge(lane + 1, target)
			var height := _downward_note_height(target)
			var receptor_rect := _mobile_receptor_rect(Rect2(left, target - height * 0.5, right - left, height))
			draw_texture_rect(MOBILE_RECEPTOR_TEXTURE, receptor_rect, false)
			var flash_age: float = chart_time() - lane_flash_times[lane]
			if flash_age >= 0.0 and flash_age < FLASH_DURATION:
				draw_texture_rect(MOBILE_EXPLOSION_TEXTURE, receptor_rect, false, Color(1, 1, 1, 1.0 - flash_age / FLASH_DURATION))
	for lane in LANE_COUNT:
		if scroll_direction == "downward":
			continue
		var rect := Rect2(area.position.x + lane * lane_width, 0, lane_width, area.size.y)
		var center := Vector2(rect.get_center().x, _target_y())
		var extent := minf(lane_width * 0.8, 120.0)
		_draw_lane_texture(RECEPTOR_TEXTURE, Rect2(0, 0, 128, 128), center, extent, lane, Color(1, 1, 1, 1.0 if lane_counts[lane] > 0 else 0.65))
		var flash_age: float = chart_time() - lane_flash_times[lane]
		if flash_age >= 0.0 and flash_age < FLASH_DURATION:
			_draw_lane_texture(GLOW_TEXTURE, Rect2(0, 0, 128, 128), center, extent * (1.0 + 0.35 * flash_age / FLASH_DURATION), lane, Color(1, 1, 1, 1.0 - flash_age / FLASH_DURATION))
		if OS.get_name() not in ["Android", "iOS"]:
			var text_size: Vector2 = lane_label_sizes[lane]
			draw_string(ui_font, center + Vector2(-text_size.x / 2.0, text_size.y / 3.0), LABELS[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	var target_y := _target_y()
	var current_time := chart_time()
	var note_extent := minf(lane_width * 0.8, 120.0)
	var color2 := arrow_style == OPTIONS_SETTINGS.COLOR_2
	var active_atlas := color2_arrow_atlas if color2 else arrow_atlas
	for index in chart_notes.size():
		var note: Dictionary = chart_notes[index]
		var state: String = judge.note_state(index) if judge != null else "pending"
		if not _note_visible_state(state):
			continue
		var y: float = _note_y(note.time, current_time)
		if state == "holding":
			y = target_y
		var center_x: float = area.position.x + (note.lane + 0.5) * lane_width
		if scroll_direction == "downward":
			if note.type == "hold":
				var end_y: float = _note_y(note.end_time, current_time)
				_downward_bar(int(note.lane), y, end_y, Color(1.0, 0.2, 0.2, 0.4))
			var thickness := _downward_note_height(y)
			if y >= 0.0 and y <= size.y:
				var left := _downward_lane_edge(note.lane, y)
				var right := _downward_lane_edge(note.lane + 1, y)
				draw_texture_rect_region(_mobile_note_texture(), Rect2(left, y - thickness * 0.5, right - left, thickness), _mobile_note_source(int(note.lane), current_time))
			continue
		if note.type == "hold":
			var end_y: float = _note_y(note.end_time, current_time)
			if maxf(y, end_y) >= 0.0 and minf(y, end_y) <= size.y:
				var top := maxf(minf(y, end_y), 0.0)
				var bottom := minf(maxf(y, end_y), size.y)
				draw_rect(Rect2(center_x - lane_width * 0.18, top, lane_width * 0.36, maxf(bottom - top, 0.0)), Color(COLORS[note.lane], 0.55))
		if y >= -20.0 and y <= size.y + 20.0:
			var lane_index := int(note.lane)
			var arrow_frame := _note_arrow_frame(note, current_time)
			if active_atlas != null:
				# One plain textured rect: no per-note transform push/pop.
				draw_texture_rect_region(active_atlas, Rect2(center_x - note_extent * 0.5, y - note_extent * 0.5, note_extent, note_extent), _arrow_source(arrow_frame, lane_index))
			else:
				var source := Rect2((arrow_frame % 4) * ARROW_FRAME_SIZE, (arrow_frame / 4) * ARROW_FRAME_SIZE, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE) if color2 else Rect2(0, arrow_frame * ARROW_FRAME_SIZE, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE)
				_draw_lane_texture(COLOR2_ARROW_TEXTURE if color2 else ARROW_TEXTURE, source, Vector2(center_x, y), note_extent, lane_index)
	if judge != null:
		var font := ui_font
		_draw_score(judge.score)
		if judge.combo >= 2:
			_draw_combo(judge.combo, Vector2(area.get_center().x, size.y * 0.52))
		var frame_rect := _life_frame_rect(area)
		var life_rect := Rect2(frame_rect.position + frame_rect.size * Vector2(0.07, 0.35), frame_rect.size * Vector2(0.86, 0.30))
		draw_rect(life_rect, Color("32373e"))
		draw_rect(Rect2(life_rect.position, Vector2(life_rect.size.x * clampf(life / LIFE_MAX, 0.0, 1.0), life_rect.size.y)), Color("55e28b") if life > 25.0 else Color("ff5a68"))
		# One multiline draw instead of 79 separate draw_line commands.
		var ticks := PackedVector2Array()
		ticks.resize(79 * 2)
		for segment in range(1, 80):
			var x := life_rect.position.x + life_rect.size.x * segment / 80.0
			ticks[(segment - 1) * 2] = Vector2(x, life_rect.position.y)
			ticks[(segment - 1) * 2 + 1] = Vector2(x, life_rect.end.y)
		draw_multiline(ticks, Color(0, 0, 0, 0.15), 1.0)
		draw_texture_rect(LIFE_FRAME_TEXTURE, frame_rect, false)
		if not last_judgement.is_empty() and current_time <= judgement_until:
			var source := _judgment_source(last_judgement)
			if source.has_area():
				var width := minf(area.size.x * 0.65, 316.0)
				draw_texture_rect_region(JUDGMENT_TEXTURE, Rect2(area.get_center().x - width / 2.0, size.y * 0.44 - width * source.size.y / source.size.x / 2.0, width, width * source.size.y / source.size.x), source)
			else:
				var text_width := font.get_string_size(last_judgement, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
				draw_string(font, Vector2(area.get_center().x - text_width / 2.0, size.y * 0.44), last_judgement, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	if not chart_error.is_empty():
		draw_string(ui_font, Vector2(20, size.y - 30), chart_error, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 20, Color.RED)
	if paused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		var font := ui_font
		var text := "PAUSED"
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48)
		draw_string(font, size / 2.0 + Vector2(-text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
