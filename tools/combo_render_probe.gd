extends SceneTree

# Renders the combo row offscreen so the layout can be measured without a window.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var main = load("res://main.tscn").instantiate()
	viewport.add_child(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(480, 800)
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	print("image size: ", image.get_size())
	var err := image.save_png("res://.combo_preview.png")
	print("save: ", err)
	quit(0)
