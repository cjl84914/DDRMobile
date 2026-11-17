extends SceneTree

## Drives the picker the way a player does: keyboard steps, touch targets and
## the PLAY button, checking that navigation stays in sync with the resolved
## chart state and that the strip keeps the selection visible.

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(main.game_state == main.GameState.TITLE and main.title_screen.visible, "boot lands on the title screen")
	main.title_screen.focus_item(0)
	main.title_screen.confirm()
	await process_frame
	var picker = main.song_picker
	check(picker.visible and main.song_version == "Dance Dance Revolution", "picker starts on first mix")
	check(str(picker.current_song().title) == "BUTTERFLY", "picker starts on first mix BUTTERFLY")
	main._on_version_requested("Dance Dance Revolution 2ndMIX")
	main._select_song(2)
	check(picker.charts.size() == main.available_charts.size(), "picker received the chart list")

	# Right/left cycle difficulty and the resolved chart follows.
	var start_chart: int = picker.chart_index
	picker._step_chart(1)
	check(picker.chart_index == start_chart + 1, "RIGHT advances the difficulty")
	check(main.chart_notes == main.available_charts[picker.chart_index].notes, "chart notes follow the ladder")
	picker._step_chart(-1)
	check(picker.chart_index == start_chart, "LEFT walks back")
	while picker.chart_index > 0:
		picker._step_chart(-1)
	picker._step_chart(-1)
	check(picker.chart_index == picker.charts.size() - 1, "difficulty wraps backwards")
	picker._step_chart(1)
	check(picker.chart_index == 0, "difficulty wraps forwards")

	# Arrow keys: LEFT/RIGHT pick a song, UP/DOWN the difficulty.
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	var before: int = picker.song_index
	picker._unhandled_input(right)
	check(picker.song_index == before + 1, "RIGHT selects the next song")
	var left := InputEventKey.new()
	left.physical_keycode = KEY_LEFT
	left.pressed = true
	picker._unhandled_input(left)
	check(picker.song_index == before, "LEFT selects the previous song")
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	up.pressed = true
	var chart_before: int = picker.chart_index
	picker._unhandled_input(up)
	check(picker.chart_index == wrapi(chart_before - 1, 0, picker.charts.size()), "UP moves to an easier difficulty")
	var down := InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	down.pressed = true
	picker._unhandled_input(down)
	check(picker.chart_index == chart_before, "DOWN moves back to the harder difficulty")

	# Up/down change song; every 2ndMIX song carries a background.
	picker._step_song(1)
	check(picker.song_index == 3 and main.song_background != null, "stepping selects the next song")
	check(not main.chart_notes.is_empty(), "the new song resolves a chart")
	picker._step_song(-3)
	check(picker.song_index == 0, "stepping returns to the first song")
	picker._step_song(-1)
	check(picker._version_focus == picker.versions.size() and picker.song_index == 0, "left of the first song is the final version entry")
	picker._step_song(1)
	check(picker.song_index == 0 and picker._version_focus == 0, "stepping returns to the first song")

	# The strip scroll window keeps the selection on screen.
	for i in 12:
		picker._step_song(1)
	check(picker.song_index == 12, "twelve steps land on song 13")
	check(absf(picker._scroll_target - (12.0 + picker.versions.size() - 2.0)) < 0.01, "strip scrolls to keep the selection centred")
	picker._scroll = picker._scroll_target
	await process_frame
	picker._layout()
	check(picker._hit.has("banner:12") and picker._hit.has("banner:10"), "visible banners are tappable")
	check(picker._hit.has("play"), "play button is tappable")
	picker._click((picker._hit["banner:12"] as Rect2).get_center())
	check(picker.song_index == 12 and main.game_state == main.GameState.READY, "tapping the selected banner does not start the song")
	picker._click((picker._hit["banner:11"] as Rect2).get_center())
	check(picker.song_index == 11 and main.game_state == main.GameState.READY, "tapping another banner only selects it")
	picker._layout()
	picker._click((picker._hit["next"] as Rect2).get_center())
	check(picker.song_index == 12, "right button advances exactly one song")
	picker._layout()
	picker._click((picker._hit["prev"] as Rect2).get_center())
	check(picker.song_index == 11, "left button moves exactly one song")
	main._select_song(0)
	picker._layout()
	check(picker._hit.has("prev") and picker._hit.has("next"), "first song follows the version entries")
	picker._click((picker._hit["next"] as Rect2).get_center())
	check(picker.song_index == 1, "next works even when the strip cannot scroll")
	main._select_song(main.songs.size() - 1)
	picker._layout()
	check(picker._hit.has("prev") and not picker._hit.has("next"), "last song ends the strip")
	picker._click((picker._hit["prev"] as Rect2).get_center())
	check(picker.song_index == main.songs.size() - 2, "previous works at the end of the strip")
	main._select_song(11)
	picker._layout()
	var next_position: Vector2 = (picker._hit["next"] as Rect2).get_center()
	var touch := InputEventScreenTouch.new()
	touch.position = next_position
	touch.pressed = true
	picker._gui_input(touch)
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.position = next_position
	emulated_mouse.pressed = true
	picker._gui_input(emulated_mouse)
	check(picker.song_index == 12, "a touch and its emulated mouse event advance only one song")
	var real_mouse := InputEventMouseButton.new()
	real_mouse.button_index = MOUSE_BUTTON_LEFT
	real_mouse.position = next_position
	real_mouse.pressed = true
	picker._gui_input(real_mouse)
	check(picker.song_index == 13, "a real mouse click still advances one song")
	main._select_song(11)

	# PLAY only starts a chart this game can judge.
	check(main.can_play(), "selected chart is playable")
	picker._layout()
	picker._click((picker._hit["play"] as Rect2).get_center())
	check(main.game_state == main.GameState.PLAYING, "PLAY starts the song")
	check(not picker.visible, "picker hides once the run starts")
	main._finish_game()
	main._show_selection()
	await process_frame
	check(picker.visible and picker.song_index == 11, "results return to the same song")

	main.available_charts = [{"difficulty": "Easy", "meter": 3, "notes": [{"type": "lift", "lane": 1, "time": 1.0}]}]
	main._select_difficulty(0)
	picker._layout()
	picker._click((picker._hit["play"] as Rect2).get_center())
	check(main.game_state == main.GameState.READY, "unplayable chart cannot be started by touch")
	check(picker.chart_error.contains("lift"), "unplayable chart explains itself")

	main.queue_free()
	await process_frame
	print("Song select UI: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
