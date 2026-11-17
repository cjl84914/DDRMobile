extends SceneTree

## The note arrows must keep cycling through the eight colours of arrow.png
## while the chart plays: the frame comes from the clock, not from the note, so
## every arrow on the field changes colour together.
##
## The arrows are drawn from a pre-rotated atlas built at startup (one column
## per lane rotation, one row per colour), so the atlas has to match the source
## sheet rotated exactly like the old per-note draw_set_transform did.
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var main = load("res://main.tscn").instantiate()
	var sheet: Texture2D = load("res://assets/stepmania/arrow.png")
	check(sheet.get_width() == 128 and sheet.get_height() == 1024, "arrow sheet must hold eight 128px frames")
	var step: float = main.ARROW_COLOR_CYCLE_SECONDS
	check(step > 0.0, "colour cycle must advance over time")
	# Eight consecutive steps visit every frame once, then wrap around.
	for index in main.ARROW_FRAME_COUNT:
		check(main._arrow_frame_index(index * step) == index, "step %d shows frame %d" % [index, index])
	check(main._arrow_frame_index(main.ARROW_FRAME_COUNT * step) == 0, "cycle wraps back to the first frame")
	# The frame changes only when the step boundary passes, and holds mid-step.
	check(main._arrow_frame_index(step * 0.5) == 0, "frame holds until the step ends")
	check(main._arrow_frame_index(step * 1.5) == 1, "frame advances one step later")
	check(main._arrow_frame_index(-step * 0.5) == main.ARROW_FRAME_COUNT - 1, "negative time wraps into the sheet")

	# Colour is per-clock, so every lane crops the same colour row.
	for lane in main.LANE_COUNT:
		for frame in main.ARROW_FRAME_COUNT:
			var source: Rect2 = main._arrow_source(frame, lane)
			check(source == Rect2(lane * 128, frame * 128, 128, 128), "lane %d frame %d crops its atlas cell" % [lane, frame])
			check(source.end.x <= 128 * main.LANE_COUNT and source.end.y <= sheet.get_height(), "lane %d frame %d stays inside the atlas" % [lane, frame])
	check(main._arrow_source(0, 1).position.x - main._arrow_source(0, 0).position.x == 128.0, "atlas maps lanes across columns")

	# The atlas must equal the source frame rotated by the lane rotation,
	# because the notes no longer rotate themselves at draw time.
	var atlas_texture: ImageTexture = main._build_arrow_atlas()
	check(atlas_texture != null, "atlas builds from the arrow sheet")
	if atlas_texture != null:
		var atlas := atlas_texture.get_image()
		check(atlas.get_width() == 128 * main.LANE_COUNT and atlas.get_height() == 128 * main.ARROW_FRAME_COUNT, "atlas holds every lane/colour cell")
		var sheet_image := sheet.get_image()
		for lane in main.LANE_COUNT:
			var quarter_turns := posmod(int(roundf(main.LANE_ROTATIONS[lane] / (PI / 2.0))), 4)
			for frame in main.ARROW_FRAME_COUNT:
				var reference: Image = sheet_image.get_region(Rect2i(0, frame * 128, 128, 128))
				for turn in quarter_turns:
					reference.rotate_90(CLOCKWISE)
				var cell := atlas.get_region(Rect2i(lane * 128, frame * 128, 128, 128))
				check(cell.get_data() == reference.get_data(), "lane %d frame %d is the rotated source frame" % [lane, frame])
		# Neighbouring frames really are different colours, not a flat atlas.
		check(atlas.get_region(Rect2i(0, 0, 128, 128)).get_data() != atlas.get_region(Rect2i(0, 128, 128, 128)).get_data(), "colour frames differ")
	main.free()
	if failures == 0:
		print("Note colour tests: PASS")
	else:
		print("Note colour tests: FAIL (%d)" % failures)
	quit(1 if failures else 0)
