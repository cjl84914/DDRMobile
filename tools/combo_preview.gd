extends SceneTree

# Renders main.tscn with a forced combo so the combo row can be inspected
# without playing a chart. Run with a real display driver (not --headless).

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
	main.judge.combo = 27
	main.judge.score = 1234567
	main.game_state = 2
	main.last_judgement = "GREAT"
	main.judgement_until = 999999.0
	main.set_process(false)
	main.menu.visible = false
	main.queue_redraw()
	for i in 4:
		await process_frame
	var image := root.get_texture().get_image()
	print("image size: ", image.get_size())
	print("save: ", image.save_png("res://.combo_preview.png"))
	quit(0)
