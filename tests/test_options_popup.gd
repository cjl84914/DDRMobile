extends SceneTree

## Drives scripts/options_screen.gd on its own: row list, value cycling with
## wrap-around, persistence through a throwaway config, pointer hit testing and
## the failure path when the settings file cannot be written.

const OPTIONS_SCREEN := preload("res://scripts/options_screen.gd")
const SETTINGS := preload("res://scripts/options_settings.gd")
const TEST_PATH := "user://test_options_popup.cfg"

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func remove_test_file(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir != null:
		dir.remove(path.get_file())


func run() -> void:
	remove_test_file(TEST_PATH)
	var popup = OPTIONS_SCREEN.new()
	popup.settings_path = TEST_PATH
	popup.size = popup.DESIGN
	popup.open()

	# --- rows describe the real settings, in the order they are drawn
	check(popup.visible, "open() shows the popup")
	check(popup.focus_row == 0, "open() focuses the first row")
	check(popup.row_count() == 2, "two settings are listed")
	check(popup.row_label(0) == "BUTTON MODE", "the first row is BUTTON MODE")
	check(popup.row_label(1) == "ARROW STYLE", "the second row is ARROW STYLE")
	check(popup.value(0) == SETTINGS.UPWARD, "the direction defaults to upward")
	check(popup.value(1) == SETTINGS.COLOR_2, "the style defaults to color 2")
	check(popup.value_label(0) == "DESKTOP", "upward is displayed as DESKTOP")
	check(popup.value_label(1) == "COLOR 2", "the style label is COLOR 2")

	# --- cycling wraps in both directions and persists immediately
	check(popup.cycle(-1), "cycling backwards succeeds")
	check(popup.value(0) == SETTINGS.DOWNWARD and popup.value_label(0) == "MOBILE", "left wraps upward to downward, displayed as MOBILE")
	check(popup.cycle(1), "cycling forward succeeds")
	check(popup.value(0) == SETTINGS.UPWARD, "right wraps downward to upward")
	check(popup.cycle(1), "cycling the direction succeeds")
	check(popup.value(0) == SETTINGS.DOWNWARD, "the direction cycles upward to downward")
	check(SETTINGS.load_scroll_direction(TEST_PATH) == SETTINGS.DOWNWARD, "the direction change is saved")

	popup.move_focus(1)
	check(popup.focus_row == 1, "move_focus(1) moves down a row")
	check(popup.value_label(1) == "COLOR 2", "the style starts at COLOR 2")
	check(popup.cycle(-1), "cycling the style succeeds")
	check(popup.value(1) == SETTINGS.COLOR_1 and popup.value_label(1) == "COLOR 1", "the style cycles to COLOR 1")
	check(SETTINGS.load_arrow_style(TEST_PATH) == SETTINGS.COLOR_1, "the style change is saved")

	# --- reopening reloads the stored values and resets the focus
	popup.close()
	check(not popup.visible, "close() hides the popup")
	popup.open()
	check(popup.focus_row == 0, "reopening focuses the first row again")
	check(popup.value(0) == SETTINGS.DOWNWARD, "reopening reloads the saved direction")
	check(popup.value(1) == SETTINGS.COLOR_1, "reopening reloads the saved style")

	# --- keyboard handling wraps and ignores unrelated keys
	check(popup.handle_key(KEY_UP), "UP is handled")
	check(popup.focus_row == popup.row_count(), "UP wraps from the first row to EXIT")
	var exit_direction = popup.value(0)
	var exit_style = popup.value(1)
	check(popup.handle_key(KEY_LEFT), "LEFT on EXIT is handled")
	check(popup.handle_key(KEY_RIGHT), "RIGHT on EXIT is handled")
	check(popup.focus_row == popup.row_count() and popup.value(0) == exit_direction and popup.value(1) == exit_style, "LEFT and RIGHT on EXIT do not change settings or focus")
	check(popup.handle_key(KEY_DOWN), "DOWN is handled")
	check(popup.focus_row == 0, "DOWN wraps from EXIT to the first row")
	check(popup.handle_key(KEY_DOWN) and popup.handle_key(KEY_DOWN), "DOWN reaches EXIT through the settings")
	check(popup.focus_row == popup.row_count(), "EXIT is reachable moving down")
	check(popup.handle_key(KEY_ENTER), "ENTER on EXIT is handled")
	check(not popup.visible, "ENTER on EXIT closes the popup")
	popup.open()
	check(not popup.handle_key(KEY_F1), "unrelated keys are not handled")

	# --- pointer hit testing: arrows cycle, other rows take focus, EXIT closes
	var direction_before = popup.value(0)
	check(popup.press_at(popup.arrow_rect(0, 1).get_center()), "the right arrow takes the tap")
	check(popup.value(0) != direction_before, "tapping the right arrow cycles forward")
	check(popup.press_at(popup.arrow_rect(0, -1).get_center()), "the left arrow takes the tap")
	check(popup.value(0) == direction_before, "tapping the left arrow cycles back")
	check(popup.press_at(popup.label_rect(1).get_center()), "a tap on another row is taken")
	check(popup.focus_row == 1, "that tap moves the focus")
	check(not popup.press_at(Vector2(20, 20)), "taps outside the popup are ignored")
	var closed := [false]
	popup.closed.connect(func() -> void: closed[0] = true)
	check(popup.press_at(popup.exit_rect().get_center()), "EXIT takes the tap")
	check(not popup.visible and closed[0], "EXIT closes the popup and reports it")

	# --- layout stays inside the panel
	check(popup.value_rect(0).position.x >= popup.label_rect(0).end.x - 1.0, "the value column follows the label column")
	check(popup.label_rect(popup.row_count() - 1).end.y < popup.FOOTER.position.y, "the rows clear the footer")
	check(popup.exit_rect().end.x <= popup.FOOTER.end.x, "EXIT stays inside the footer")
	check(popup.exit_rect().end.y <= popup.FOOTER.end.y, "EXIT stays inside the footer")

	# --- an unwritable settings file leaves the value alone and says so
	var broken = OPTIONS_SCREEN.new()
	broken.settings_path = "res://no_such_directory/options.cfg"
	broken.open()
	var before = broken.value(0)
	check(not broken.cycle(1), "a failed save reports failure")
	check(broken.value(0) == before, "a failed save keeps the old value")
	check(not broken.notice_text().is_empty(), "a failed save explains itself")

	popup.free()
	broken.free()
	remove_test_file(TEST_PATH)
	print("Options popup: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures > 0 else 0)
