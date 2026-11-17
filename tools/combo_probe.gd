extends SceneTree

# Renders main.tscn twice (combo on / off) and reports where the combo row
# lands, so its size can be checked without playing a chart.
# Requires a real display driver.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1280, 720)
	await process_frame
	main.title_screen.visible = false
	main.judge = load("res://scripts/judgement.gd").new(main.chart_notes)
	main.judge.score = 1234567
	main.game_state = 2
	main.last_judgement = "GREAT"
	main.judgement_until = 999999.0
	main.set_process(false)
	main.menu.visible = false
	await process_frame
	await process_frame

	var with_combo := await _capture(main, 27)
	var without_combo := await _capture(main, 0)

	var min_x := 1280
	var min_y := 720
	var max_x := -1
	var max_y := -1
	for y in 720:
		for x in 1280:
			if with_combo.get_pixel(x, y) != without_combo.get_pixel(x, y):
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	print("combo bbox: ", Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	with_combo.save_png("res://.combo_on.png")
	var off_judge := await _capture_judgement(main, "")
	var on_judge := await _capture_judgement(main, "GREAT")
	print("judgment bbox: ", _diff_bbox(on_judge, off_judge))
	if max_x > 0:
		var pad := 16
		var crop_rect := Rect2i(min_x - pad, min_y - pad, max_x - min_x + 1 + pad * 2, max_y - min_y + 1 + pad * 2)
		print("crop rect: ", crop_rect)
		var crop := with_combo.get_region(crop_rect)
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png("res://.combo_crop.png")
	quit(0)

func _capture_judgement(main, label: String) -> Image:
	main.judge.combo = 0
	main.last_judgement = label
	main.judgement_until = 0.0 if label.is_empty() else 999999.0
	main.queue_redraw()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _diff_bbox(a: Image, b: Image) -> Rect2i:
	var min_x := a.get_width()
	var min_y := a.get_height()
	var max_x := -1
	var max_y := -1
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _capture(main, combo: int) -> Image:
	main.judge.combo = combo
	main.queue_redraw()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
