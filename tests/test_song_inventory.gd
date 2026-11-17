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
	for i in main.songs.size():
		main._select_song(i)
		var playable := 0
		for chart in main.available_charts:
			if main._chart_problem(chart).is_empty():
				playable += 1
		print("%s: %d/%d playable; %s" % [main.songs[i].title, playable, main.available_charts.size(), main.chart_error])
		check(playable > 0 and main.chart_error.is_empty() and main.music.stream != null, "song is complete: " + main.songs[i].title)
		check(not main.chart_notes.is_empty(), "default chart resolved: " + main.songs[i].title)
		check(main.song_picker.song_index == i, "picker tracks the song: " + main.songs[i].title)
		check(main.song_picker.charts.size() == main.available_charts.size(), "picker sees every chart: " + main.songs[i].title)
		main._start_game()
		check(main.game_state == main.GameState.PLAYING and main.judge != null, "play starts: " + main.songs[i].title)
		check(not main.song_picker.visible, "picker hides while playing: " + main.songs[i].title)
		main._finish_game()
		check(main.game_state == main.GameState.RESULTS, "results shown: " + main.songs[i].title)
		check(main.menu.visible and main.menu_button.text == "RETRY", "results offer a retry: " + main.songs[i].title)
		main._show_selection()
		check(main.game_state == main.GameState.READY, "selection returns: " + main.songs[i].title)
		check(main.song_picker.visible and main.song_picker.song_index == i, "picker restored: " + main.songs[i].title)
	main.queue_free()
	await process_frame
	print("Song inventory: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
