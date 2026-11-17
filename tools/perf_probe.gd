extends SceneTree

## Measures gameplay frame rate so note rendering changes can be compared:
## Godot --path . --resolution 1280x720 --disable-vsync --script tools/perf_probe.gd
## PERF_FRAMES / PERF_NOTES tune the run; prints average FPS and frame time.

func _initialize() -> void:
	call_deferred("run")

func _dense_chart(count: int, spacing: float) -> Array:
	var notes := []
	for index in count:
		notes.append({"lane": index % 4, "type": "tap", "time": index * spacing})
	for index in int(count / 8):
		var time := index * spacing * 8.0
		notes.append({"lane": index % 4, "type": "hold", "time": time, "end_time": time + 0.4})
	return notes

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.menu.visible = false
	main.title_screen.visible = false
	main.pause_button.visible = false
	main.exit_button.visible = false
	main.offset_panel.visible = false
	main.scroll_direction = "upward"
	main.judge = null
	var note_count := int(OS.get_environment("PERF_NOTES")) if not OS.get_environment("PERF_NOTES").is_empty() else 600
	main.chart_notes = _dense_chart(note_count, 0.05)
	main.game_state = main.GameState.PLAYING
	# Hold the clock so the same note set stays on screen for every frame.
	main.music.stop()
	main.music.stream = null
	main.paused = true
	main.paused_song_time = 3.0
	main.offset_ms = 0
	Engine.max_fps = 0
	for i in 5:
		await process_frame
	var frames := int(OS.get_environment("PERF_FRAMES")) if not OS.get_environment("PERF_FRAMES").is_empty() else 600
	var worst := 0.0
	var total := 0.0
	var draw_calls := 0
	var start := Time.get_ticks_usec()
	var last := start
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := (now - last) / 1000.0
		last = now
		total += frame_ms
		worst = maxf(worst, frame_ms)
		draw_calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	print("PERF notes=%d frames=%d sec=%.2f fps=%.1f avg=%.2fms worst=%.2fms draw_calls=%.0f" % [note_count, frames, seconds, frames / seconds, total / frames, worst, float(draw_calls) / frames])
	quit(0)
