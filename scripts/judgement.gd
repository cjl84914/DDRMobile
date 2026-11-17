extends RefCounted
## Independent judgement engine. All times are song seconds and must be nondecreasing.
## Input notes follow sm_parser.gd; the engine never mutates the supplied array.
## Pause/focus loss: call clear_holds(time), then clear the input layer's keys.
## Release at or after both the note start and end_time - tail window completes
## the hold (inclusive); earlier release breaks it. A window never auto-completes
## a hold. clear_holds ignores the window: only tails actually reached complete.
## The final tap/hold_start/miss event of a judged row includes row_judged=true
## and row_grade. Apply tap life only for that flag; hold tails remain separate.
## Rows use exact beat identity when present, otherwise exact note time.

# StepMania default timing scale 1.0, in seconds (W1–W5).
# The boundaries are inclusive. Scores include a project-local combo bonus.
const GRADE_WINDOWS := [0.0225, 0.045, 0.09, 0.135, 0.18]
const GRADES := ["MARVELOUS", "PERFECT", "GREAT", "GOOD", "BOO"]
const WINDOW := 0.18
const DEFAULT_HOLD_RELEASE_WINDOW := 0.1
const HIT_SCORE := 100
const COMBO_BONUS := 10

var score := 0
var combo := 0
var max_combo := 0
var _notes: Array = []
var _states: Array = []
var _row_keys: Array = []
var _row_members := {}
var _row_results: Array = []
var _settled_rows := {}
var _last_time := -INF
var hold_release_window: float:
	set(value):
		hold_release_window = maxf(value, 0.0) if is_finite(value) else 0.0

func _init(notes: Array = [], release_window: float = DEFAULT_HOLD_RELEASE_WINDOW) -> void:
	hold_release_window = release_window
	_notes = notes.duplicate(true)
	for i in range(_notes.size()):
		var note: Dictionary = _notes[i]
		_states.append("pending")
		_row_results.append({})
		# A tagged key prevents a time-only fixture colliding with a beat row.
		var key := ["beat", note.beat] if note.has("beat") else ["time", note.time]
		_row_keys.append(key)
		if not _row_members.has(key):
			_row_members[key] = []
		_row_members[key].append(i)

func note_state(index: int) -> String:
	return _states[index]

func _event(kind: String, index: int, time: float) -> Dictionary:
	var note: Dictionary = _notes[index]
	var event := {"kind": kind, "lane": int(note.lane), "note_index": index, "time": time, "delta": time - float(note.time)}
	if kind == "tap" or kind == "hold_start":
		# Compare to note time +/- window, avoiding cancellation at exact boundaries.
		for i in range(GRADE_WINDOWS.size()):
			if time >= float(note.time) - GRADE_WINDOWS[i] and time <= float(note.time) + GRADE_WINDOWS[i]:
				event["grade"] = GRADES[i]
				break
	elif kind == "miss":
		event["grade"] = "MISS"
	return event

# StepMania's LastTapNoteScoreTrack gives a miss priority; otherwise it
# selects the largest signed tap offset, breaking equal offsets by higher lane.
func _record_row_result(index: int, event: Dictionary) -> void:
	_row_results[index] = event.duplicate()
	var key = _row_keys[index]
	if _settled_rows.has(key):
		return
	var selected := -1
	for member in _row_members[key]:
		var result: Dictionary = _row_results[member]
		if result.is_empty():
			return
		if selected < 0:
			selected = member
			continue
		var previous: Dictionary = _row_results[selected]
		if result.grade == "MISS":
			if previous.grade != "MISS" or int(result.lane) < int(previous.lane):
				selected = member
		elif previous.grade != "MISS" and (float(result.delta) > float(previous.delta) or (float(result.delta) == float(previous.delta) and int(result.lane) >= int(previous.lane))):
			selected = member
	_settled_rows[key] = true
	event["row_judged"] = true
	event["row_grade"] = _row_results[selected].grade
	if event.row_grade in ["MARVELOUS", "PERFECT", "GREAT"]:
		combo += _row_members[key].size()
		max_combo = maxi(max_combo, combo)
	else:
		combo = 0

func _hit() -> void:
	score += HIT_SCORE + combo * COMBO_BONUS

func _check_time(time: float) -> bool:
	if not is_finite(time) or time < _last_time:
		push_error("Judgement times must be finite and nondecreasing")
		return false
	_last_time = time
	return true

func _advance_checked(time: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(_notes.size()):
		var note: Dictionary = _notes[i]
		if _states[i] == "pending" and time > float(note.time) + WINDOW:
			_states[i] = "missed"
			var miss := _event("miss", i, time)
			_record_row_result(i, miss)
			events.append(miss)
		elif _states[i] == "holding" and time >= float(note.end_time):
			_states[i] = "completed"
			events.append(_event("hold_complete", i, time))
	return events

func advance(time: float) -> Array[Dictionary]:
	if not _check_time(time):
		return []
	return _advance_checked(time)

func press(lane: int, time: float) -> Array[Dictionary]:
	if not _check_time(time):
		return []
	var events := _advance_checked(time)
	var best := -1
	var best_distance := INF
	for i in range(_notes.size()):
		var note: Dictionary = _notes[i]
		if _states[i] != "pending" or int(note.lane) != lane:
			continue
		var distance := absf(time - float(note.time))
		if time >= float(note.time) - WINDOW and time <= float(note.time) + WINDOW and distance < best_distance:
			best = i
			best_distance = distance
	if best >= 0:
		var is_hold: bool = _notes[best].type == "hold"
		_states[best] = "holding" if is_hold else "hit"
		_hit()
		var hit := _event("hold_start" if is_hold else "tap", best, time)
		_record_row_result(best, hit)
		events.append(hit)
		# Handles short holds already at their tail when pressed.
		if is_hold and time >= float(_notes[best].end_time):
			_states[best] = "completed"
			events.append(_event("hold_complete", best, time))
	return events

func release(lane: int, time: float) -> Array[Dictionary]:
	if not _check_time(time):
		return []
	var events := _advance_checked(time)
	for i in range(_notes.size()):
		if _states[i] == "holding" and int(_notes[i].lane) == lane:
			var note: Dictionary = _notes[i]
			if time >= float(note.time) and time >= float(note.end_time) - hold_release_window:
				_states[i] = "completed"
				events.append(_event("hold_complete", i, time))
			else:
				_states[i] = "broken"
				combo = 0
				events.append(_event("hold_break", i, time))
	return events

func clear_holds(time: float) -> Array[Dictionary]:
	if not _check_time(time):
		return []
	var events := _advance_checked(time)
	for i in range(_notes.size()):
		if _states[i] == "holding":
			_states[i] = "broken"
			combo = 0
			events.append(_event("hold_break", i, time))
	return events
