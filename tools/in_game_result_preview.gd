extends SceneTree

## Renders main.tscn with a finished run so the results overlay can be reviewed
## in its real context: Godot --path . --resolution 1280x720 \
##   --script tools/in_game_result_preview.gd

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.chart_notes = [
		{"lane": 0, "type": "tap", "time": 1.0},
		{"lane": 1, "type": "tap", "time": 2.0},
	]
	main.music.stream = load("res://assets/test_beat.wav")
	main.chart_error = ""
	main.menu_button.disabled = false
	main.offset_ms = 0
	main._start_game()
	main.judge = preload("res://scripts/judgement.gd").new(main.chart_notes)
	main.judge_time = -INF
	main._apply_judgements(main.judge.press(0, 1.0))
	main._apply_judgements(main.judge.press(1, 1.0))
	main._apply_judgements(main.judge.advance(3.0))
	main.grade_counts["MARVELOUS"] = 116
	main.grade_counts["PERFECT"] = 74
	main.grade_counts["GREAT"] = 59
	main.grade_counts["GOOD"] = 14
	main.grade_counts["MISS"] = 1
	main.result_counts["hold_complete"] = 12
	if not OS.get_environment("SHOT_FAIL").is_empty():
		main.failed = true
		main.judge.score = 0
		main.judge.max_combo = 229
	main._finish_game()
	for i in 8:
		await process_frame
	var shot := OS.get_environment("SHOT_PATH")
	if shot.is_empty():
		shot = "res://docs/reference/result-failed.png" if not OS.get_environment("SHOT_FAIL").is_empty() else "res://docs/screenshots/results.png"
	root.get_texture().get_image().save_png(shot)
	print("saved ", shot)
	quit(0)
