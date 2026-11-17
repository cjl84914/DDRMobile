extends SceneTree

func _initialize() -> void:
	for path in ["res://assets/stepmania/_combo.png", "res://assets/stepmania/Judgment Normal 1x6.png", "res://assets/stepmania/combo-numbers.png"]:
		var image := Image.new()
		var err := image.load(ProjectSettings.globalize_path(path))
		if err != OK:
			print(path, " load failed: ", err)
			continue
		var w := image.get_width()
		var h := image.get_height()
		var min_x := w
		var min_y := h
		var max_x := -1
		var max_y := -1
		var opaque := 0
		for y in h:
			for x in w:
				if image.get_pixel(x, y).a > 0.05:
					opaque += 1
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
		print(path, " ", w, "x", h, " opaque=", opaque, " bbox=", Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	quit(0)
