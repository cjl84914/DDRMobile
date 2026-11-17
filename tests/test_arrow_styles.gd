extends SceneTree

const SETTINGS := preload("res://scripts/options_settings.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var main = load("res://main.tscn").instantiate()
	main.arrow_style = SETTINGS.MONOCHROME
	check(main._mobile_note_texture() == main.MOBILE_MONO_TEXTURE, "mobile monochrome uses hold head")
	for lane in 4:
		for time in [0.0, 0.4, 1.2]:
			check(main._note_arrow_frame({"beat": 0.5, "lane": lane}, time) == 0, "monochrome uses the original red frame")
	for lane in 4:
		for time in [0.0, 0.4, 1.2]:
			check(main._mobile_note_source(lane, time) == Rect2(0, 0, 64, 64), "mobile monochrome stays red")
	main.arrow_style = SETTINGS.COLOR_1
	check(main._mobile_note_texture() == main.MOBILE_COLOR1_TEXTURE, "mobile color 1 uses roll head")
	for lane in 4:
		for frame in main.ARROW_FRAME_COUNT:
			var time: float = frame * main.ARROW_COLOR_CYCLE_SECONDS
			check(main._note_arrow_frame({"beat": 0.5, "lane": lane}, time) == frame, "color 1 cycles in sync")
	main.arrow_style = SETTINGS.COLOR_2
	check(main._mobile_note_texture() == main.MOBILE_NOTE_TEXTURE, "mobile color 2 uses animated bar sheet")
	for lane in 4:
		for frame in 16:
			check(main._note_arrow_frame({"lane": lane}, frame * main.ARROW_COLOR_CYCLE_SECONDS) == frame, "color 2 cycles frame %d" % frame)
	check(main._note_arrow_frame({}, 16 * main.ARROW_COLOR_CYCLE_SECONDS) == 0, "color 2 wraps")
	for lane in 4:
		for frame in 7:
			check(main._mobile_note_source(lane, frame * main.ARROW_COLOR_CYCLE_SECONDS) == Rect2(0, frame * 64, 64, 64), "mobile color 2 cycles in sync")
	check(main._mobile_note_source(0, 7 * main.ARROW_COLOR_CYCLE_SECONDS) == Rect2(0, 0, 64, 64), "mobile color 2 wraps")
	check(main._mobile_note_source(0, -main.ARROW_COLOR_CYCLE_SECONDS) == Rect2(0, 6 * 64, 64, 64), "mobile color 2 wraps negative time")
	var atlas: ImageTexture = main._build_color2_arrow_atlas()
	check(atlas != null, "color 2 atlas builds")
	if atlas != null:
		var sheet: Image = main.COLOR2_ARROW_TEXTURE.get_image()
		var image := atlas.get_image()
		for lane in 4:
			for frame in 16:
				var reference := sheet.get_region(Rect2i((frame % 4) * 128, (frame / 4) * 128, 128, 128))
				for turn in posmod(int(roundf(main.LANE_ROTATIONS[lane] / (PI / 2.0))), 4):
					reference.rotate_90(CLOCKWISE)
				check(image.get_region(Rect2i(lane * 128, frame * 128, 128, 128)).get_data() == reference.get_data(), "color 2 lane %d frame %d" % [lane, frame])
	main.free()
	print("Arrow style tests: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
