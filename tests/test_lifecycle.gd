extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.offset_ms = 0
	main.chart_notes = preload("res://scripts/sm_parser.gd").parse_file("res://assets/test_chart.sm").charts[0].notes
	main.music.stream = load("res://assets/test_beat.wav")
	main.chart_error = ""
	main.menu_button.disabled = false
	main._enter_game_mode()
	check(main.game_state == main.GameState.READY and not main.music.playing, "ready waits for start")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_LEFT
	key.pressed = true
	main._input(key)
	check(main.lane_counts == [0, 0, 0, 0], "ready ignores gameplay input")
	main.menu_button.pressed.emit()
	check(main.game_state == main.GameState.PLAYING and main.music.playing, "start begins playback")
	main.music.stream_paused = true
	main.paused = true
	main.paused_song_time = 1.0
	main.chart_notes = [{"lane": 0, "type": "tap", "time": 1.0}, {"lane": 1, "type": "tap", "time": 2.0}]
	main.judge = preload("res://scripts/judgement.gd").new(main.chart_notes)
	main.judge_time = -INF
	main._input(key) # paused, ignored
	main._change_lane(0, 1)
	main._change_lane(0, -1)
	main.paused_song_time = 2.5
	main._apply_judgements(main.judge.advance(main._judgement_time()))
	main._finish_game()
	check(main.game_state == main.GameState.RESULTS and main.judge.score == 100, "results retain score")
	check(main.result_counts.tap == 1 and main.result_counts.miss == 1, "results count events")
	check(main.result.max_combo() == 1, "results show max combo")
	check(main.result.status_text() == "CLEARED" and main.result.score_text() == "000,100", "results show clear status and actual score")
	var rows: Array = main.result.rows()
	check(rows.size() == 6 and rows[0].value == 1 and rows[5].value == 1 and rows[4].value == 0, "results use actual judgement and hold counts")
	check(main.result.data.title == main.current_song().title and not str(main.result.data.tier).is_empty(), "results show selected song and chart")
	check(main.result.GRADE_AT.y < main.result.LEFT_CARD.position.y and main.result.LEFT_CARD.end.x <= main.result.RIGHT_CARD.position.x, "results separate upper rating and lower status/statistics")
	main.grade_counts = {"MARVELOUS": 2}
	check(main._result_rating() == "AAA", "perfect accuracy earns project-local AAA")
	main.grade_counts = {"MARVELOUS": 1, "MISS": 1}
	check(main._result_rating() == "C", "misses reduce project-local rating")
	main._input(key)
	main._finish_game()
	check(main.lane_counts == [0, 0, 0, 0] and main.judge.score == 100, "results ignore input and duplicate finish")
	main.menu_button.pressed.emit()
	check(main.game_state == main.GameState.PLAYING and main.music.playing and not main.paused, "retry restarts playback")
	check(main.judge.score == 0 and main.judge.combo == 0 and main.judge_time == -INF, "retry resets judgement")
	check(main.result_counts.tap == 0 and main.result_counts.miss == 0 and main.fingers.is_empty(), "retry resets results and input")
	main.music.stop()
	main.audio_ended_at = Time.get_ticks_usec() - int((main._chart_end_time() + 1.0) * 1000000.0)
	main._process(0.0)
	check(main.game_state == main.GameState.RESULTS and main.result_counts.miss == 2, "audio end resolves late notes before results")
	main.select_button.pressed.emit()
	var selected_song: int = main.song_picker.song_index
	var selected_difficulty: int = main.song_picker.chart_index
	main.menu_button.pressed.emit()
	check(not main.exit_button.visible, "exit is hidden during play")
	main._exit_to_selection()
	check(main.game_state == main.GameState.PLAYING, "exit requires pause")
	main._toggle_pause()
	check(main.exit_button.visible and main.exit_button.size.x >= 48 and main.exit_button.size.y >= 48, "paused exit is touch sized")
	main.offset_changed = true
	main.exit_button.pressed.emit()
	check(main.game_state == main.GameState.READY and main.song_picker.visible and main.judge == null, "paused exit returns directly to selection without results")
	check(not main.menu.visible, "exit skips the results overlay")
	check(not main.music.playing and not main.music.stream_paused and not main.paused and not main.offset_changed, "exit stops and resets paused audio state")
	check(not main.pause_button.visible and not main.exit_button.visible and not main.offset_panel.visible, "exit hides gameplay controls")
	check(main.song_picker.song_index == selected_song and main.song_picker.chart_index == selected_difficulty, "exit preserves selection")
	check(main.fingers.is_empty() and main.keys_down.is_empty() and main.lane_counts == [0, 0, 0, 0], "exit clears input")
	main.menu_button.pressed.emit()
	check(main.game_state == main.GameState.PLAYING and main.music.playing and not main.paused and main.result_counts.tap == 0, "start after exit begins fresh")
	main._toggle_pause()
	main._toggle_pause()
	check(not main.exit_button.visible and not main.paused, "resume hides exit")
	main.music.stop()
	main.queue_free()
	await process_frame
	print("Lifecycle tests: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
