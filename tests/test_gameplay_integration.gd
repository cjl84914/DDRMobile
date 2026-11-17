extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.offset_ms = 0
	main.chart_notes = preload("res://scripts/sm_parser.gd").parse_file("res://assets/test_chart.sm").charts[0].notes
	main.music.stream = load("res://assets/test_beat.wav")
	main.chart_error = ""
	main._start_game()
	# Freeze the scene's clock so input travels through the real lane signal deterministically.
	main.music.stream_paused = true
	main.paused = true
	main.paused_song_time = 1.0
	main.chart_notes = [
		{"lane": 0, "type": "tap", "time": 1.0},
		{"lane": 1, "type": "hold", "time": 2.0, "end_time": 3.0},
	]
	main.judge = preload("res://scripts/judgement.gd").new(main.chart_notes)
	main.judge_time = -INF
	main._change_lane(0, 1)
	assert(main.judge.score == 100 and main.judge.combo == 1 and main.judge.note_state(0) == "hit")
	main._change_lane(0, -1)
	main.paused_song_time = 2.0
	main._change_lane(1, 1)
	assert(main.judge.score == 210 and main.judge.note_state(1) == "holding")
	main.paused_song_time = 2.5
	main.clear_inputs()
	assert(main.judge.note_state(1) == "broken" and main.judge.combo == 0)
	assert(main.last_judgement == "HOLD BREAK")
	main.queue_free()
	await process_frame
	print("Gameplay integration: PASS")
	quit()
