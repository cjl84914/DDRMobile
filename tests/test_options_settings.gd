extends SceneTree

const SETTINGS := preload("res://scripts/options_settings.gd")
const TEST_PATH := "user://test_options_settings.cfg"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	check(SETTINGS.load_scroll_direction(TEST_PATH) == SETTINGS.UPWARD, "missing settings use upward")
	check(SETTINGS.save_scroll_direction(SETTINGS.DOWNWARD, TEST_PATH) == OK, "save downward")
	check(SETTINGS.load_scroll_direction(TEST_PATH) == SETTINGS.DOWNWARD, "downward survives reload")
	check(SETTINGS.save_scroll_direction("invalid", TEST_PATH) == ERR_INVALID_PARAMETER, "reject invalid value")
	check(SETTINGS.load_scroll_direction(TEST_PATH) == SETTINGS.DOWNWARD, "invalid save preserves value")
	var config := ConfigFile.new()
	config.load(TEST_PATH)
	config.set_value("other", "value", 42)
	config.save(TEST_PATH)
	check(SETTINGS.save_scroll_direction(SETTINGS.UPWARD, TEST_PATH) == OK, "save upward")
	config.load(TEST_PATH)
	check(config.get_value("other", "value") == 42, "other settings preserved")
	config.set_value("display", "scroll_direction", "broken")
	config.save(TEST_PATH)
	check(SETTINGS.load_scroll_direction(TEST_PATH) == SETTINGS.UPWARD, "invalid stored value falls back")
	check(SETTINGS.load_arrow_style(TEST_PATH) == SETTINGS.COLOR_2, "missing arrow style defaults to color 2")
	for style in SETTINGS.ARROW_STYLES:
		check(SETTINGS.save_arrow_style(style, TEST_PATH) == OK, "save arrow style " + style)
		check(SETTINGS.load_arrow_style(TEST_PATH) == style, "reload arrow style " + style)
	check(SETTINGS.save_arrow_style("invalid", TEST_PATH) == ERR_INVALID_PARAMETER, "reject invalid arrow style")
	check(SETTINGS.load_arrow_style(TEST_PATH) == SETTINGS.COLOR_2, "invalid style save preserves value")
	check(SETTINGS.save_scroll_direction(SETTINGS.DOWNWARD, TEST_PATH) == OK, "save direction alongside style")
	check(SETTINGS.load_arrow_style(TEST_PATH) == SETTINGS.COLOR_2, "direction save preserves arrow style")
	config.load(TEST_PATH)
	config.set_value("display", "arrow_style", "broken")
	config.save(TEST_PATH)
	check(SETTINGS.load_arrow_style(TEST_PATH) == SETTINGS.COLOR_2, "invalid stored arrow style falls back")
	check(SETTINGS.save_arrow_style(SETTINGS.COLOR_1, TEST_PATH) == OK, "save style alongside direction")
	check(SETTINGS.load_scroll_direction(TEST_PATH) == SETTINGS.DOWNWARD, "style save preserves direction")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("Options settings: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
