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
	main.chart_error = ""
	main.music.stream = load("res://assets/test_beat.wav")
	main._start_game()
	main.music.stream_paused = true
	main.paused = true
	main.paused_song_time = 0.0
	check(is_equal_approx(main.life, 50.0), "initial life")
	for grade in main.GRADES:
		main._apply_judgements([{"kind": "tap" if grade != "MISS" else "miss", "grade": grade, "row_judged": true, "row_grade": grade}])
		check(main.grade_counts[grade] == 1, "count each grade: " + grade)
	check(main.last_judgement == "MISS", "display miss")
	check(is_equal_approx(main.life, 40.0) and main.life_regen_remaining == 5, "miss applies original penalty and recovery delay")
	for i in range(4):
		main._apply_judgements([{"kind": "tap", "grade": "PERFECT", "row_judged": true, "row_grade": "PERFECT"}])
		check(is_equal_approx(main.life, 40.0), "recovery blocked after miss: %d" % i)
	main._apply_judgements([{"kind": "tap", "grade": "PERFECT", "row_judged": true, "row_grade": "PERFECT"}])
	check(is_equal_approx(main.life, 40.8) and main.life_regen_remaining == 0, "fifth nonnegative event recovers")
	main._apply_judgements([{"kind": "tap", "grade": "BOO", "row_judged": true, "row_grade": "BOO"}, {"kind": "tap", "grade": "GOOD", "row_judged": true, "row_grade": "GOOD"}])
	check(is_equal_approx(main.life, 36.8) and main.life_regen_remaining == 4, "zero delta counts toward recovery")
	main._apply_judgements([{"kind": "hold_break"}])
	check(is_equal_approx(main.life, 28.8) and main.life_regen_remaining == 5, "hold break renews recovery delay")
	main.life_regen_remaining = 0
	main.life = 99.9
	main._apply_judgements([{"kind": "hold_start", "grade": "MARVELOUS", "row_judged": true, "row_grade": "MARVELOUS"}, {"kind": "hold_complete"}])
	check(is_equal_approx(main.life, 100.0), "life capped")
	check(main.result_counts.hold_start == 1 and main.result_counts.hold_complete == 1, "hold events counted once")
	main.life = 50.0
	var chord_judge = preload("res://scripts/judgement.gd").new([{ "lane": 0, "type": "tap", "time": 1.0 }, { "lane": 1, "type": "tap", "time": 1.0 }])
	main._apply_judgements(chord_judge.press(0, 1.0))
	check(is_equal_approx(main.life, 50.0), "unfinished chord does not change life")
	main._apply_judgements(chord_judge.press(1, 1.0))
	check(is_equal_approx(main.life, 50.8), "completed chord changes life once")
	main.life = 8.0
	main.chart_notes = [{"lane": 0, "type": "hold", "time": 0.0, "end_time": 10.0}]
	main.judge = preload("res://scripts/judgement.gd").new(main.chart_notes)
	main.judge_time = -INF
	main._change_lane(0, 1)
	main.life = 8.0
	main.clear_inputs()
	check(main.failed and main.game_state == main.GameState.RESULTS, "hold break failure")
	check(main.result_counts.hold_break == 2 and main.lane_counts == [0, 0, 0, 0], "failure cleanup is nonrecursive")
	check(not main.result.cleared() and main.result.status_text() == "FAILED" and main.result.grade_text() == "E", "failure results")
	main._start_game()
	check(not main.failed and is_equal_approx(main.life, 50.0) and main.life_regen_remaining == 0 and main.grade_counts.MISS == 0, "retry resets life, recovery delay and counts")
	main._finish_game()
	check(main.result.cleared() and main.result.status_text() == "CLEARED", "successful finish")
	main.queue_free()
	await process_frame
	print("Life tests: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
