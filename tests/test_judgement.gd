extends SceneTree

const Judge = preload("res://scripts/judgement.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	# Both signs, exact boundaries and just outside each boundary; exact W5
	# must still hit, and a late hit just outside W5 becomes a miss.
	for i in range(Judge.GRADE_WINDOWS.size()):
		var window: float = Judge.GRADE_WINDOWS[i]
		for sign_value in [-1.0, 1.0]:
			var boundary: float = 1.0 + sign_value * window
			var judge = Judge.new([{"lane": 0, "type": "tap", "time": 1.0}])
			var events: Array = judge.press(0, boundary)
			check(events.size() == 1 and events[0].get("grade") == Judge.GRADES[i], "grade boundary %d %s" % [i, sign_value])
			judge = Judge.new([{"lane": 0, "type": "tap", "time": 1.0}])
			events = judge.press(0, 1.0 + sign_value * (window + 0.000001))
			if i < Judge.GRADES.size() - 1:
				check(events.size() == 1 and events[0].get("grade") == Judge.GRADES[i + 1], "outside grade %d %s" % [i, sign_value])
			elif sign_value < 0:
				check(events.is_empty(), "outside early W5")
			else:
				check(events.size() == 1 and events[0].kind == "miss" and events[0].grade == "MISS", "outside late W5")
	var graded_hold = Judge.new([{"lane": 2, "type": "hold", "time": 1.0, "end_time": 2.0}])
	var start: Dictionary = graded_hold.press(2, 1.04)[0]
	check(start.kind == "hold_start" and start.grade == "PERFECT" and start.lane == 2 and start.note_index == 0 and is_equal_approx(start.delta, 0.04), "hold head grade and event fields")
	var tail: Dictionary = graded_hold.advance(2.0)[0]
	check(tail.kind == "hold_complete" and not tail.has("grade"), "hold tail has no tap grade")
	var j = Judge.new([{"lane": 0, "type": "tap", "time": 1.0}, {"lane": 1, "type": "tap", "time": 1.0}, {"lane": 2, "type": "tap", "time": 2.0}])
	check(j.press(0, 1.0 - Judge.WINDOW)[0].kind == "tap", "early inclusive boundary")
	check(j.press(1, 1.0 + Judge.WINDOW)[0].kind == "tap", "late inclusive boundary")
	check(j.score == 200 and j.combo == 0 and j.max_combo == 0, "BOO breaks combo")
	check(j.advance(2.0 + Judge.WINDOW).is_empty(), "miss boundary inclusive")
	check(j.advance(2.181)[0].kind == "miss" and j.combo == 0 and j.max_combo == 0, "late miss")
	check(j.note_state(0) == "hit" and j.note_state(2) == "missed", "note states")

	j = Judge.new([{"lane": 0, "type": "tap", "time": 1.0}])
	check(j.press(0, 0.819).is_empty(), "outside early boundary")
	check(j.press(1, 1.0).is_empty(), "wrong lane")
	check(j.press(0, 1.181)[0].kind == "miss", "outside late boundary")

	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 2.0}, {"lane": 1, "type": "hold", "time": 1.0, "end_time": 2.0}])
	check(j.press(0, 1.0)[0].kind == "hold_start", "hold start")
	check(j.press(1, 1.0)[0].kind == "hold_start", "simultaneous holds")
	check(j.release(0, 1.899)[0].kind == "hold_break", "release before tolerance breaks")
	check(j.release(1, 2.0)[0].kind == "hold_complete", "tail inclusive")
	check(j.note_state(0) == "broken" and j.note_state(1) == "completed", "hold states")
	check(j.score == 200 and j.combo == 0, "hold score and break")

	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 2.0}])
	j.press(0, 1.0)
	check(j.advance(1.9).is_empty() and j.note_state(0) == "holding", "window does not auto-complete")
	check(j.release(0, 1.9)[0].kind == "hold_complete", "tolerance boundary inclusive")
	check(j.combo == 1 and j.score == 100 and j.advance(2.0).is_empty(), "completion preserves score and is emitted once")

	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 2.0}], 0.25)
	j.press(0, 1.0)
	check(j.release(0, 1.75)[0].kind == "hold_complete", "configurable window")
	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 2.0}], -1.0)
	j.press(0, 1.0)
	check(j.release(0, 1.999)[0].kind == "hold_break", "negative window clamps to zero")

	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 1.05}], 1.0)
	j.press(0, 0.9)
	check(j.release(0, 0.95)[0].kind == "hold_break", "early press and release before scheduled start cannot complete")
	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 1.05}], 1.0)
	j.press(0, 0.9)
	check(j.release(0, 1.0)[0].kind == "hold_complete", "short hold release at scheduled start")
	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 2.0}])
	check(j.release(0, 1.95)[0].kind == "miss" and j.note_state(0) == "missed", "unpressed hold cannot complete")

	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 2.0}])
	j.press(0, 1.0)
	check(j.clear_holds(1.95)[0].kind == "hold_break", "pause in release window still breaks")
	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 2.0}])
	j.press(0, 1.0)
	check(j.clear_holds(2.0)[0].kind == "hold_complete", "pause at tail completes normally")

	j = Judge.new([{"lane": 0, "type": "hold", "time": 1.0, "end_time": 3.0}])
	j.press(0, 1.0)
	check(j.clear_holds(1.5)[0].kind == "hold_break", "pause clears hold")
	check(j.clear_holds(1.5).is_empty() and j.advance(3.0).is_empty(), "cleared hold does not return")
	check(j.note_state(0) == "broken", "pause state")

	j = Judge.new([{"lane": 0, "type": "tap", "time": 1.1}, {"lane": 0, "type": "tap", "time": 1.0}])
	check(j.press(0, 1.02)[0].note_index == 1, "nearest note regardless of input order")
	check(j.press(0, 1.1)[0].note_index == 0, "remaining note")
	j = Judge.new([{"lane": 0, "type": "tap", "time": 1.0}, {"lane": 0, "type": "tap", "time": 2.0}, {"lane": 0, "type": "tap", "time": 3.0}])
	j.press(0, 1.0)
	check(j.combo == 1 and j.score == 100, "first hit starts combo with base score")
	j.press(0, 2.11)
	check(j.combo == 0 and j.score == 210, "GOOD receives prior combo bonus then breaks combo")
	j.press(0, 3.0)
	check(j.combo == 1 and j.score == 310, "combo bonus resets after GOOD")
	var streak = Judge.new([{ "lane": 0, "type": "tap", "time": 1.0 }, { "lane": 0, "type": "tap", "time": 2.0 }, { "lane": 0, "type": "tap", "time": 3.0 }])
	streak.press(0, 1.0)
	streak.press(0, 2.0)
	streak.press(0, 3.0)
	check(streak.score == 330 and streak.combo == 3, "consecutive hits earn increasing combo bonuses")
	# Life settles only once per row, without changing per-note events or score.
	j = Judge.new([{"lane": 0, "type": "tap", "beat": 4.0, "time": 1.0}, {"lane": 1, "type": "hold", "beat": 4.0, "time": 1.0, "end_time": 2.0}])
	var first: Dictionary = j.press(0, 0.90)[0]
	var last: Dictionary = j.press(1, 1.02)[0]
	check(not first.has("row_judged") and last.get("row_judged", false) and last.row_grade == "MARVELOUS", "row selects latest offset, not worst grade")
	check(j.advance(2.0)[0].kind == "hold_complete", "row hold tail remains independent")
	j = Judge.new([{"lane": 0, "type": "tap", "time": 1.0}, {"lane": 1, "type": "tap", "time": 1.0}])
	first = j.press(0, 1.0)[0]
	last = j.advance(1.181)[0]
	check(not first.has("row_judged") and last.get("row_judged", false) and last.row_grade == "MISS", "partial row settles as miss")
	check(j.advance(1.2).is_empty(), "row settles once")
	j = Judge.new([{"lane": 0, "type": "tap", "time": 1.0}, {"lane": 1, "type": "tap", "time": 1.0}])
	var misses: Array = j.advance(1.181)
	check(misses.size() == 2 and not misses[0].has("row_judged") and misses[1].get("row_judged", false) and misses[1].row_grade == "MISS", "all-miss row settles once")
	j = Judge.new([{"lane": 0, "type": "tap", "beat": 1.0, "time": 1.0}, {"lane": 1, "type": "tap", "beat": 2.0, "time": 1.0}])
	check(j.press(0, 1.0)[0].get("row_judged", false) and j.press(1, 1.0)[0].get("row_judged", false), "distinct beats at same time are distinct rows")
	if failures == 0:
		print("Judgement tests: PASS")
	else:
		print("Judgement tests: FAIL (%d)" % failures)
	quit(1 if failures else 0)
