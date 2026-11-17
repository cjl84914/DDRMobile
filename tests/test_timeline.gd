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
	if not main.chart_error.is_empty() or main.chart_notes.is_empty() or not main.music.playing:
		push_error("Test chart or audio failed to start: " + main.chart_error)
		quit(1)
		return
	await create_timer(0.3).timeout
	var before: float = main.song_time()
	if before <= 0.0:
		push_error("Audio timeline did not advance")
		quit(1)
		return
	main._toggle_pause()
	var paused_at: float = main.song_time()
	if absf(paused_at - before) > 0.05:
		push_error("Timeline jumped when paused: %f -> %f" % [before, paused_at])
		quit(1)
		return
	main.offset_ms = 100
	if absf(main.chart_time() - paused_at - 0.1) > 0.001:
		push_error("Positive sync offset should advance chart time by 100 ms")
		quit(1)
		return
	main.judge_time = -INF
	if absf(main._judgement_time() - main.chart_time()) > 0.001:
		push_error("Judgement must use the same adjusted chart time as rendering")
		quit(1)
		return
	main.offset_ms = 0
	main.judge_time = -INF
	await create_timer(0.2).timeout
	if absf(main.song_time() - paused_at) > 0.05:
		push_error("Audio timeline moved while paused")
		quit(1)
		return
	main._toggle_pause()
	await create_timer(0.2).timeout
	if main.song_time() <= before:
		push_error("Audio timeline did not resume")
		quit(1)
		return
	main.queue_free()
	await process_frame
	print("Timeline tests: PASS")
	quit(0)
