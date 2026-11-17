extends SceneTree

## Offline render of the results overlay for visual review.
## Godot tools/result_preview.gd --path . --resolution 1280x720

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var shot := OS.get_environment("SHOT_PATH")
	if shot.is_empty():
		shot = "res://docs/reference/result-preview.png"
	var cover_path := OS.get_environment("SHOT_COVER")
	var cover: Texture2D = null
	if not cover_path.is_empty() and ResourceLoader.exists(cover_path, "Texture2D"):
		cover = load(cover_path)
	var screen = load("res://scripts/result_screen.gd").new()
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	screen.show_result({
		"title": OS.get_environment("SHOT_TITLE") if not OS.get_environment("SHOT_TITLE").is_empty() else "BUTTERFLY",
		"artist": OS.get_environment("SHOT_ARTIST") if not OS.get_environment("SHOT_ARTIST").is_empty() else "smile.dk",
		"cover": cover,
		"tier": "BASIC", "meter": 3, "grade": OS.get_environment("SHOT_GRADE") if not OS.get_environment("SHOT_GRADE").is_empty() else "E",
		"score": 0, "combo": 229, "cleared": false,
		"counts": {"MARVELOUS": 116, "PERFECT": 74, "GREAT": 59, "GOOD": 14, "OK": 0, "MISS": 1, "holds": 12, "breaks": 0},
	})
	for i in 6:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(shot)
	print("saved ", shot, " ", image.get_size())
	quit(0)
