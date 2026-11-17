extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var result: Dictionary = preload("res://scripts/sm_parser.gd").parse_file("res://assets/test_chart.sm")
	if not result.ok:
		push_error(result.error)
		quit(1)
		return
	for note in result.charts[0].notes:
		if absf(note.time / 0.5 - roundf(note.time / 0.5)) > 0.00001:
			push_error("Note does not land on metronome beat")
			quit(1)
			return
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(480, 800)
	var target: float = main._target_y()
	if target >= main.size.y / 2.0 or main._note_y(1.0, 1.0) != target or main._note_y(2.0, 1.0) <= target or main._note_y(2.0, 1.5) >= main._note_y(2.0, 1.0):
		push_error("Notes must travel upward toward the top receptors")
		quit(1)
		return
	main.scroll_direction = "downward"
	if main.MOBILE_NOTE_TEXTURE.resource_path != "res://assets/stepmania/_bar tap note 2x8.png" or main.MOBILE_NOTE_SOURCE != Rect2(0, 0, 64, 64):
		push_error("Mobile notes must use one frame of the bar note sprite sheet")
		quit(1)
		return
	for lane in range(4):
		if main._mobile_note_source(lane) != Rect2(0, 0, 64, 64):
			push_error("All mobile notes must use the red sprite")
			quit(1)
			return
	for y in [0.0, main._target_y(), main.size.y]:
		var width: float = main._downward_lane_edge(1.0, y) - main._downward_lane_edge(0.0, y)
		if absf(main._downward_note_height(y) / width - main.MOBILE_NOTE_SOURCE.size.y / main.MOBILE_NOTE_SOURCE.size.x) > 0.001:
			push_error("Mobile notes must preserve the sprite aspect ratio")
			quit(1)
			return
	var note_rect := Rect2(100, 200, 100, 100)
	var receptor_rect: Rect2 = main._mobile_receptor_rect(note_rect)
	if receptor_rect.get_center().distance_to(note_rect.get_center()) > 0.001 or absf(receptor_rect.size.x * 70.0 / 128.0 - note_rect.size.x * 62.0 / 64.0) > 0.001 or absf(receptor_rect.size.y * 24.0 / 128.0 - note_rect.size.y * 16.0 / 64.0) > 0.001:
		push_error("Receptor artwork must match the arriving note's visible size")
		quit(1)
		return
	main.scroll_direction = "upward"
	var life_frame: Rect2 = main._life_frame_rect(main._play_area())
	if life_frame.position.y > main.size.y * 0.15 or life_frame.end.y > main.size.y * 0.3:
		push_error("Life bar must stay in the top band of the screen")
		quit(1)
		return
	var score_rect: Rect2 = main._score_rect()
	if score_rect.position.y != 12.0 or absf(score_rect.end.x - (main.size.x - 12.0)) > 0.01:
		push_error("Score must sit in the top-right corner of the screen")
		quit(1)
		return
	if life_frame.intersects(score_rect):
		push_error("Life bar and score must not overlap")
		quit(1)
		return
	for state in ["pending", "holding", "missed", "broken"]:
		if not main._note_visible_state(state):
			push_error("Note state should remain visible: " + state)
			quit(1)
			return
	for state in ["hit", "completed"]:
		if main._note_visible_state(state):
			push_error("Completed note should be hidden: " + state)
			quit(1)
			return
	if main.JUDGMENT_TEXTURE.resource_path != "res://assets/stepmania/Judgment Normal 1x6.png":
		push_error("Incorrect judgment texture")
		quit(1)
		return
	var labels := ["FLAWLESS", "PERFECT", "GREAT", "GOOD", "BAD", "MISS"]
	for i in range(labels.size()):
		var source: Rect2 = main._judgment_source(labels[i])
		if source != Rect2(0, i * 32, 192, 32):
			push_error("Incorrect judgment sprite for " + labels[i])
			quit(1)
			return
	for digit in range(10):
		if main._combo_digit_source(digit) != Rect2((digit % 4) * 88, (digit / 4) * 128, 88, 128):
			push_error("Incorrect combo digit sprite for %d" % digit)
			quit(1)
			return
	if main._combo_digit_source(-1).has_area() or main._combo_digit_source(10).has_area():
		push_error("Invalid combo digits should have no sprite")
		quit(1)
		return
	if main.COMBO_LABEL_TEXTURE.resource_path != "res://assets/stepmania/_combo.png":
		push_error("Combo label should use _combo.png")
		quit(1)
		return
	var layout: Dictionary = main._combo_layout(27, Vector2(640, 400))
	var digit_rects: Array = layout["digits"]
	if digit_rects.size() != 2:
		push_error("Combo row needs one rect per digit")
		quit(1)
		return
	# The player reads the glyphs, not the padded sprite boxes, so the combo row
	# must match the judgment sprite's ink height.
	var judgment_width := minf(main._play_area().size.x * 0.65, 316.0)
	var expected_ink: float = judgment_width / 6.0 * main.JUDGMENT_INK_HEIGHT / main.JUDGMENT_ROW_HEIGHT
	var text_height: float = layout["text_height"]
	if absf(text_height - expected_ink) > 0.01:
		push_error("Combo glyphs should match the judgment ink height")
		quit(1)
		return
	var label: Rect2 = layout["label"]
	var label_ink: float = label.size.y * main.COMBO_LABEL_INK_HEIGHT / main.COMBO_LABEL_SIZE.y
	if absf(label_ink - text_height) > 0.01:
		push_error("Combo label ink should match the digit ink height")
		quit(1)
		return
	if absf(label.size.x / label.size.y - main.COMBO_LABEL_SIZE.x / main.COMBO_LABEL_SIZE.y) > 0.01:
		push_error("Combo label should keep the _combo.png aspect")
		quit(1)
		return
	# Spacing is measured between ink edges: the word should sit just after the
	# last digit's ink, not after that digit's padded sprite box.
	var digit_scale: float = digit_rects[-1].size.y / main.COMBO_DIGIT_CELL.y
	var last_digit := 7
	var digit_ink_right: float = digit_rects[-1].position.x + (main.COMBO_DIGIT_INK_LEFT[last_digit] + main.COMBO_DIGIT_INK_WIDTH[last_digit]) * digit_scale
	var label_ink_left: float = label.position.x + main.COMBO_LABEL_INK_LEFT * label.size.y / main.COMBO_LABEL_SIZE.y
	var ink_gap: float = label_ink_left - digit_ink_right
	if ink_gap < 0.0:
		push_error("Combo label ink should not overlap the digits")
		quit(1)
		return
	if ink_gap > text_height * 0.5:
		push_error("Combo label should sit close to the digits")
		quit(1)
		return
	var digit_ink_mid: float = digit_rects[0].position.y + digit_rects[0].size.y * (main.COMBO_DIGIT_INK_TOP + main.COMBO_DIGIT_INK_HEIGHT / 2.0) / main.COMBO_DIGIT_CELL.y
	var label_ink_mid: float = label.position.y + label.size.y * (main.COMBO_LABEL_INK_TOP + main.COMBO_LABEL_INK_HEIGHT / 2.0) / main.COMBO_LABEL_SIZE.y
	if absf(digit_ink_mid - label_ink_mid) > 0.5:
		push_error("Combo digits and label ink should share a centre line")
		quit(1)
		return
	var wide: Dictionary = main._combo_layout(123456789012, Vector2(640, 400))
	var wide_digits: Array = wide["digits"]
	var wide_label: Rect2 = wide["label"]
	var wide_scale: float = wide_digits[0].size.y / main.COMBO_DIGIT_CELL.y
	var wide_ink_left: float = wide_digits[0].position.x + main.COMBO_DIGIT_INK_LEFT[1] * wide_scale
	var wide_ink_right: float = wide_label.position.x + (main.COMBO_LABEL_INK_LEFT + main.COMBO_LABEL_INK_WIDTH) * wide_label.size.y / main.COMBO_LABEL_SIZE.y
	if wide_ink_right - wide_ink_left > main._play_area().size.x + 0.5:
		push_error("Long combos should shrink to fit the play area")
		quit(1)
		return
	if wide_digits[0].size.y >= digit_rects[0].size.y:
		push_error("Long combos should shrink the digits")
		quit(1)
		return
	if main._judgment_source("HOLD OK").has_area():
		push_error("Hold results should use their text fallback")
		quit(1)
		return
	main.queue_free()
	await process_frame
	print("Visual and beat timing tests: PASS")
	quit(0)
