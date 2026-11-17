extends RefCounted
## Persistent player options. Values are stable identifiers, not display labels.

const PATH := "user://options.cfg"
const UPWARD := "upward"
const DOWNWARD := "downward"
const MONOCHROME := "monochrome"
const COLOR_1 := "color_1"
const COLOR_2 := "color_2"
const ARROW_STYLES := [MONOCHROME, COLOR_1, COLOR_2]

static func load_scroll_direction(path: String = PATH) -> String:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return UPWARD
	var value: Variant = config.get_value("display", "scroll_direction", UPWARD)
	if value != UPWARD and value != DOWNWARD:
		return UPWARD
	return value

static func save_scroll_direction(value: String, path: String = PATH) -> Error:
	if value != UPWARD and value != DOWNWARD:
		return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.load(path) # Preserve other options when updating this one.
	config.set_value("display", "scroll_direction", value)
	return config.save(path)

static func load_arrow_style(path: String = PATH) -> String:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return COLOR_2
	var value: Variant = config.get_value("display", "arrow_style", COLOR_2)
	return value if value in ARROW_STYLES else COLOR_2

static func save_arrow_style(value: String, path: String = PATH) -> Error:
	if value not in ARROW_STYLES:
		return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("display", "arrow_style", value)
	return config.save(path)
