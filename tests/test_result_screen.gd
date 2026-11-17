extends SceneTree

## Pins the results overlay's presentation contract: the arcade score format,
## the FAILED/CLEARED wording, the six detailed judgement rows and the two
## navigation buttons.

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var screen = load("res://scripts/result_screen.gd").new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	await process_frame
	screen.show_result({
		"title": "BUTTERFLY", "artist": "smile.dk", "cover": null,
		"tier": "BASIC", "meter": 3, "grade": "A", "score": 12345,
		"combo": 229, "cleared": false,
		"counts": {"MARVELOUS": 116, "PERFECT": 74, "GREAT": 59, "GOOD": 14, "OK": 0, "MISS": 1, "holds": 4, "breaks": 1},
	})
	check(screen.score_text() == "012,345", "score uses the six digit comma format")
	check(screen.grade_text() == "A" and screen.max_combo() == 229, "grade and combo follow the snapshot")
	for grade in ["AAA", "AA", "A", "B", "C", "D", "E"]:
		check(screen.GRADE_TEXTURES.get(grade) is Texture2D, "grade %s has an image" % grade)
	check(screen.GRADE_TEXTURES["A"].resource_path.ends_with("Tier04.png"), "A uses the A image")
	check(screen.GRADE_TEXTURES["E"].resource_path.ends_with("Failed.png"), "E uses the failed image")
	check(screen.status_text() == "FAILED" and not screen.cleared(), "failing runs read FAILED")
	var rows: Array = screen.rows()
	check(rows.size() == 6, "six detailed judgement rows")
	check(rows[0].label == "MARVELOUS" and rows[0].value == 116, "row order starts at MARVELOUS")
	check(rows[4].label == "O.K." and rows[4].value == 0 and rows[5].label == "Miss" and rows[5].value == 1, "O.K. and Miss close the list")
	check(rows[1].color != rows[2].color and rows[3].color != rows[4].color, "each judgement keeps its own colour")
	screen.show_result({"title": "x", "cleared": true, "score": 0, "grade": "E", "counts": {}})
	check(screen.status_text() == "CLEARED" and screen.score_text() == "000,000", "cleared runs read CLEARED with a zero score")
	check(screen.rows()[0].value == 0, "missing counts fall back to zero")

	var retried := [false]
	var selected := [false]
	screen.retry_pressed.connect(func() -> void: retried[0] = true)
	screen.select_pressed.connect(func() -> void: selected[0] = true)
	screen.retry_button.pressed.emit()
	screen.select_button.pressed.emit()
	check(retried[0] and selected[0], "retry and song select buttons emit their signals")
	check(screen.retry_button.size.x >= 48.0 and screen.select_button.size.y >= 44.0, "result buttons stay touch sized")

	screen.queue_free()
	await process_frame
	print("Result screen tests: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
