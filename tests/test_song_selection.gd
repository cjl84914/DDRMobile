extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.song_version == main.song_versions[0].id and main.song_picker.song_index == 0 and main.can_play(), "first folder and its first playable song are initially selected")
	main._on_version_requested("Dance Dance Revolution 2ndMIX")
	check(main.songs.size() == 24, "the 2ndMIX line-up is catalogued")
	check(main.songs[0].title == "AM-3P" and main.songs[2].title == "BOOM BOOM DOLLAR", "2ndMIX line-up is alphabetical and complete")
	var demo_visible := false
	for song in main.songs:
		if str(song.dir).begins_with("goin-under") or str(song.dir).begins_with("springtime"):
			demo_visible = true
	check(not demo_visible, "the three demo songs are hidden from the picker")
	main._enter_game_mode()
	check(main.song_picker != null and main.song_picker.visible, "picker is the ready screen")
	check(main.song_picker.song_index == 0 and main.song_background != null, "second mix falls back to its first song")
	main._select_song(0)
	main._update_preview(1.0)
	main.song_picker._step_song(-1)
	check(main.song_picker._version_focus != 0 and not main.preview_player.playing and main.preview_countdown == 0.0, "version entry stops the previous song preview")
	main._show_title()
	main._enter_game_mode()
	check(main.preview_countdown == 0.0, "returning to a version entry does not restart the song preview")
	main.song_picker.version_requested.emit("Dance Dance Revolution")
	check(main.song_version == "Dance Dance Revolution" and main.songs.size() == 12, "switching to first mix shows its 12 songs")
	check(main.song_picker.current_song().title == "BUTTERFLY" and main.can_play(), "first mix selects playable BUTTERFLY")
	main.song_picker.version_requested.emit("Dance Dance Revolution 2ndMIX")
	check(main.song_version == "Dance Dance Revolution 2ndMIX" and main.songs.size() == 24, "switching back restores second mix")
	check(main.song_picker.song_index == 0 and main.can_play(), "second mix falls back to its first song")
	for i in main.songs.size():
		main._select_song(i)
		check(main.song_background != null, "every 2ndMIX song has a background: " + main.songs[i].title)
	main._select_song(3)
	main._select_song(-1)
	check(main.song_background == null, "invalid selection clears old background")
	check(not main.can_play() and not main.chart_error.is_empty() and main.music.stream == null, "invalid selection fails closed")
	check(main.song_picker.chart_error == main.chart_error, "picker mirrors the failure")
	check(main._background_rect(Vector2(100, 100), Vector2(200, 100)) == Rect2(0, -50, 200, 200), "background covers landscape without distortion")
	check(main._background_rect(Vector2(100, 100), Vector2(100, 200)) == Rect2(-50, 0, 200, 200), "background covers portrait without distortion")

	# Arcade chart metadata drives the ladder and the pentagon meter.
	main._select_song(2)
	var easy_default: int = main.song_picker._chart_index_of_tier("Easy")
	check(main.song_picker.chart_index == easy_default, "a song opens on its BASIC chart")
	var basics := 0
	for chart in main.available_charts:
		if chart.ddr == "BASIC":
			basics += 1
	check(basics == 1, "BOOM BOOM DOLLAR has one BASIC chart")
	var easy: int = main.song_picker._chart_index_of_tier("Easy")
	check(easy >= 0 and int(main.available_charts[easy].meter) == 2, "BASIC 2 matches the arcade chart")
	main._select_difficulty(easy)
	check(main.can_play() and not main.chart_notes.is_empty(), "playable difficulty selects notes")
	check(main.song_picker.chart_index == easy and main.song_picker.playable, "picker follows the resolved chart")

	# Anything this game cannot judge must fail closed and stay visible.
	main._select_song(2)
	main.available_charts = [
		{"difficulty": "Easy", "meter": 2, "notes": [{"type": "tap", "lane": 0, "time": 1.0}]},
		{"difficulty": "Hard", "meter": 9, "notes": [{"type": "mine", "lane": 0, "time": 1.0}]},
		{"difficulty": "Challenge", "meter": 12, "notes": [{"type": "roll", "lane": 0, "time": 1.0}]},
	]
	main._select_difficulty(0)
	check(main.can_play() and main.chart_notes[0].type == "tap", "playable difficulty starts")
	main._select_difficulty(1)
	check(not main.can_play() and main.chart_error.contains("mine"), "mine difficulty is rejected visibly")
	main._select_difficulty(2)
	check(not main.can_play() and main.chart_error.contains("roll"), "roll difficulty is rejected visibly")
	main._start_game()
	check(main.game_state == main.GameState.READY, "unsupported difficulty cannot start")
	main.available_charts.append({"notes": [], "warnings": ["orphan tail"]})
	main._select_difficulty(3)
	check(not main.can_play() and main.chart_error.contains("orphan tail"), "chart warnings are rejected visibly")
	main._select_difficulty(99)
	check(not main.can_play() and main.chart_notes.is_empty(), "invalid difficulty clears old notes")
	check(main.song_picker.chart_error == main.chart_error, "picker mirrors the difficulty rejection")
	main.queue_free()
	await process_frame
	print("Song selection: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
