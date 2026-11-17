extends SceneTree

var failures := 0
var main: Control
var changes: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func touch(index: int, x: float, pressed: bool, y: float = 400.0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = Vector2(x, y)
	event.pressed = pressed
	main._input(event)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	main._input(event)

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.offset_ms = 0
	main.chart_notes = preload("res://scripts/sm_parser.gd").parse_file("res://assets/test_chart.sm").charts[0].notes
	main.music.stream = load("res://assets/test_beat.wav")
	main.chart_error = ""
	main._start_game()
	# Exercise input state independently of chart misses and life depletion.
	main.judge = null
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1280, 720)
	main.lane_changed.connect(func(lane: int, pressed: bool): changes.append([lane, pressed]))
	for lane in 4:
		var code: Key = [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT][lane]
		key(code, true)
		check(main.lane_counts[lane] == 1, "arrow key presses lane %d" % lane)
		key(code, false)
		check(main.lane_counts == [0, 0, 0, 0], "arrow key releases lane %d" % lane)
	for code in [KEY_D, KEY_F, KEY_J, KEY_K]:
		key(code, true)
		check(main.lane_counts == [0, 0, 0, 0], "old keyboard binding is ignored")
	changes.clear()
	var area: Rect2 = main._play_area()
	var x0 := area.position.x + area.size.x / 8.0
	var x1 := area.position.x + area.size.x * 3.0 / 8.0
	touch(1, x0, true)
	touch(2, x1, true)
	check(main.lane_counts == [1, 1, 0, 0], "two simultaneous lanes")
	touch(1, x1, false)
	check(main.lane_counts == [0, 1, 0, 0], "release stays on original lane")
	touch(3, x1, true)
	check(main.touch_feedback == "L2: RELEASE FIRST", "overlapping same-lane touch gives feedback")
	touch(2, x1, false)
	check(main.lane_counts == [0, 1, 0, 0], "same lane remains held by another finger")
	key(KEY_DOWN, true)
	touch(3, x1, false)
	check(main.lane_counts == [0, 1, 0, 0], "keyboard and touch share lane")
	key(KEY_DOWN, false)
	check(main.lane_counts == [0, 0, 0, 0], "last input releases lane")
	touch(4, x0, true)
	main._toggle_pause()
	check(main.lane_counts == [0, 0, 0, 0] and main.fingers.is_empty(), "pause clears input")
	touch(5, x1, true)
	check(main.fingers.is_empty(), "paused input ignored")
	main._toggle_pause()
	touch(4, x0, false)
	check(main.lane_counts == [0, 0, 0, 0], "stale release is harmless")
	key(KEY_LEFT, true)
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.lane_counts == [0, 0, 0, 0] and main.keys_down.is_empty(), "focus loss clears input")
	touch(6, x1, true)
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(main.lane_counts == [0, 0, 0, 0], "background clears input")
	check(changes == [[0, true], [1, true], [0, false], [1, false], [0, true], [0, false], [0, true], [0, false], [1, true], [1, false]], "signals only on aggregate state transitions")
	for notification in [Node.NOTIFICATION_APPLICATION_FOCUS_IN, Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		touch(7, x0, true)
		key(KEY_DOWN, true)
		var before := changes.size()
		main.notification(notification)
		check(main.lane_counts == [0, 0, 0, 0] and main.fingers.is_empty() and main.keys_down.is_empty(), "lifecycle notification clears all inputs: %d" % notification)
		check(changes.size() == before + 2, "lifecycle emits lane releases")
		main.notification(notification)
		check(changes.size() == before + 2, "repeated lifecycle notification is idempotent")
		touch(7, x0, false)
		key(KEY_DOWN, false)
		check(main.lane_counts == [0, 0, 0, 0], "late releases after lifecycle are harmless")
	print("Input tests: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
