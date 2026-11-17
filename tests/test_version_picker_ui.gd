extends SceneTree

var failures := 0
var requests: Array[String] = []
var songs_requested: Array[int] = []
var focus_events: Array[bool] = []
var plays := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var picker = load("res://scripts/song_select.gd").new()
	root.add_child(picker)
	picker.size = Vector2(1280, 720)
	picker.version_requested.connect(func(value: String): requests.append(value))
	picker.song_requested.connect(func(value: int): songs_requested.append(value); picker.set_song_state(value, [{"difficulty": "Easy"}], 0, "", true))
	picker.version_focus_changed.connect(func(value: bool): focus_events.append(value))
	picker.play_requested.connect(func(): plays += 1)
	picker.setup_versions([{ "id": "first", "title": "First", "image": null }, { "id": "second", "title": "Second", "image": null }])
	picker.set_version_state("second")
	picker.setup([{"title": "A"}, {"title": "B"}], {})
	picker.set_song_state(1, [{"difficulty": "Easy"}], 0, "", true)
	picker._layout()
	check(picker._hit.has("version:1") and not picker._hit.has("version:2"), "only alternative version appears in strip")
	check((picker._hit["version:1"] as Rect2).position.x < (picker._hit["banner:0"] as Rect2).position.x, "alternative version precedes songs")
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	picker._unhandled_input(right)
	check(picker._version_focus == 1 and picker.song_index == 1 and songs_requested.is_empty(), "keyboard reaches version without changing song index")
	check(picker.current_song().is_empty() and picker.current_chart().is_empty(), "version focus hides stale song information")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	picker._unhandled_input(enter)
	check(requests == ["first"] and plays == 0 and picker.version == "second", "enter requests version, never play, controller remains authoritative")
	picker.set_version_state("first")
	check(picker.versions.size() == 1 and picker.versions[0].id == "second", "switching hides current and restores previous version")
	picker._unhandled_input(right)
	picker._unhandled_input(enter)
	check(requests == ["first", "second"], "keyboard reaches second generation")
	picker._unhandled_input(right)
	check(songs_requested == [0] and picker._version_focus == 0, "wrap returns to actual song index")
	picker.size = Vector2(640, 360)
	picker._layout()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = (picker._hit["version:1"] as Rect2).get_center()
	picker._gui_input(touch)
	check(requests == ["first", "second", "second"], "scaled touch activates version entry")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = (picker._hit["version:1"] as Rect2).get_center()
	picker._gui_input(mouse)
	check(requests == ["first", "second", "second", "second"], "mouse activates alternative version")
	picker.setup([], {})
	check(picker._version_focus == 0 and picker.charts.is_empty() and not picker.playable, "setup clears focus and stale state")
	picker._step_song(1)
	check(picker._version_focus == 1, "entries remain navigable with no songs")
	picker.queue_free()
	await process_frame
	print("Version picker UI: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
