extends SceneTree

## Renders gameplay at successive colour phases so the note-arrow colour cycle
## can be reviewed against the real play field:
## Godot --path . --resolution 1280x720 --script tools/note_colors_preview.gd
## Writes $SHOT_PATH (or /tmp/ddr-note-colors.png) plus -0..-3 phase variants.

const LANES := 4
const PHASES := 4
const NOTE_TIMES := [0.35, 0.60, 0.85, 1.10, 1.35, 1.60, 1.85, 2.10]

func _initialize() -> void:
	call_deferred("run")

func _initialize_playfield(main: Control) -> void:
	main.menu.visible = false
	main.title_screen.visible = false
	main.pause_button.visible = false
	main.exit_button.visible = false
	main.offset_panel.visible = false
	main.scroll_direction = "upward"
	main.judge = null
	main.game_state = main.GameState.PLAYING

## Charts are shifted by the same amount the sync offset advances the clock, so
## the arrows stay put while only the colour phase changes between captures.
func _chart_at(shift: float) -> Array:
	var notes := []
	for index in NOTE_TIMES.size():
		notes.append({"lane": index % LANES, "type": "tap", "time": NOTE_TIMES[index] + shift})
	notes.append({"lane": 1, "type": "hold", "time": 2.30 + shift, "end_time": 2.70 + shift})
	return notes

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_initialize_playfield(main)
	# Freeze the song clock at zero; the sync offset drives the colour phase.
	main.music.stop()
	main.music.stream = null
	var base := OS.get_environment("SHOT_PATH")
	if base.is_empty():
		base = "/tmp/ddr-note-colors.png"
	var stem := base.get_basename()
	for phase in PHASES:
		var shift: float = phase * main.ARROW_COLOR_CYCLE_SECONDS
		main.chart_notes = _chart_at(shift)
		main.offset_ms = int(roundf(shift * 1000.0))
		main.queue_redraw()
		await process_frame
		await process_frame
		var path := "%s-%d.png" % [stem, phase]
		root.get_texture().get_image().save_png(path)
		print("saved ", path, " frame=", main._arrow_frame_index(main.chart_time()))
	quit(0)
