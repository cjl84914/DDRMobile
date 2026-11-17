extends SceneTree

## The picker plays a short clip of the highlighted song once the selection
## rests, stops it when the player starts the song, and re-arms on the way back.
## Timers are driven directly so the test does not depend on wall-clock frames.

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
	await process_frame
	main._enter_game_mode()
	main._on_version_requested("Dance Dance Revolution 2ndMIX")
	var picker = main.song_picker

	# --- data: the arcade sample-start tags resolve to seconds
	var song: Dictionary = main.songs[2]
	check(str(song.title) == "BOOM BOOM DOLLAR", "preview fixture is BOOM BOOM DOLLAR")
	var window: Vector2 = main.SONG_CATALOG.preview_window(song)
	check(is_equal_approx(window.x, 43.11) and is_equal_approx(window.y, 15.0), "SAMPLESTART 43.110 becomes a 15 s clip at 43.11")
	check(is_equal_approx(main.SONG_CATALOG.preview_window(main.songs[0]).x, 44.29), "m:ss sample starts are converted (AM-3P)")
	check(main.SONG_CATALOG.preview_window({"sample_start": 0.0, "sample_length": 0.0}).y == 15.0, "missing SAMPLELENGTH falls back to 15 s")

	# --- the clip waits for the selection to rest
	check(main.preview_countdown > 0.0 and not main.preview_player.playing, "preview waits while the selection settles")
	main._update_preview(0.1)
	check(not main.preview_player.playing, "preview stays silent during the settle delay")
	main._update_preview(1.0)
	check(main.preview_player.playing, "preview starts after the delay")
	check(main.preview_player.stream == main.music.stream, "preview reuses the song audio")
	check(main.preview_remaining > 14.0, "preview counts down from the clip length")
	check(picker.preview_active, "picker shows the preview marker")

	# --- the clip ends by itself
	main._update_preview(20.0)
	check(not main.preview_player.playing, "preview stops after the clip length")
	check(not picker.preview_active, "picker clears the preview marker")
	check(main.preview_remaining == 0.0, "preview timer is cleared")

	# --- moving to another song re-arms instead of leaking audio
	picker._step_song(1)
	check(not main.preview_player.playing and main.preview_countdown > 0.0, "changing song re-arms the preview")
	main._update_preview(1.0)
	check(main.preview_player.playing, "the new song previews too")

	# --- starting the song must silence the preview
	main._start_game()
	check(main.game_state == main.GameState.PLAYING, "song started")
	check(not main.preview_player.playing and main.preview_remaining == 0.0, "starting the song stops the preview")
	check(not picker.preview_active, "preview marker is gone while playing")

	# --- results buffer has no preview, returning to the picker re-arms
	main._finish_game()
	main._update_preview(5.0)
	check(not main.preview_player.playing, "results screen keeps the picker quiet")
	main._show_selection()
	check(main.preview_countdown > 0.0 and not main.preview_player.playing, "returning to song select re-arms the preview")
	main._update_preview(1.0)
	check(main.preview_player.playing, "the restored song previews again")

	main._stop_preview()
	main.queue_free()
	await process_frame
	print("Song preview: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
