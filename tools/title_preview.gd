extends SceneTree

## Offline render of the title screen for visual review.
## Godot tools/title_preview.gd --path . --resolution 1280x720
## Set SHOT_PATH to change the output, SHOT_INDEX to park the cursor on another row.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var shot := OS.get_environment("SHOT_PATH")
	if shot.is_empty():
		shot = "res://docs/screenshots/title.png"
	var index := int(OS.get_environment("SHOT_INDEX")) if not OS.get_environment("SHOT_INDEX").is_empty() else 0
	var screen = load("res://scripts/title_screen.gd").new()
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.size = screen.DESIGN
	await process_frame
	screen.focus_item(index)
	# Let the selection bob settle on a frame that is not mid-oscillation.
	for i in 8:
		await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(shot)
	print("saved ", shot, " ", image.get_size())
	quit(0)
