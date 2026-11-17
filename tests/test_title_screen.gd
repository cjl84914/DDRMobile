extends SceneTree

## Boots the real main scene and drives the title screen the way a player does:
## the menu contents, the navigation keys, touch targets, and the transition
## from GAME MODE into the picker.

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var title = main.title_screen
	check(title != null and title.is_visible_in_tree(), "the title screen is the boot screen")
	check(main.game_state == main.GameState.TITLE, "boot state is TITLE")
	check(not main.song_picker.visible, "the picker stays hidden behind the title")
	check(not main.pause_button.visible and not main.menu.visible, "no gameplay chrome on the title")

	# --- the menu matches the arcade minus TRAINING MODE
	var labels := []
	for item in title.items():
		labels.append(str(item.label))
	check(labels == ["GAME MODE", "OPTIONS", "EXIT"], "menu is GAME/OPTIONS/EXIT: %s" % [labels])
	check(not labels.has("TRAINING MODE"), "TRAINING MODE is not offered")
	check(not labels.has("EDIT MODE"), "EDIT MODE stays hidden until the editor exists")
	check(title.COPYRIGHT == "© 2026 DDR-Mobile Ver 0.1", "copyright line is the project footer")

	# --- keyboard navigation wraps and confirm reports the focused entry
	check(title.selected == 0, "GAME MODE starts focused")
	title._unhandled_input(_down())
	check(title.selected == 1, "DOWN moves to OPTIONS")
	title._unhandled_input(_down())
	check(title.selected == 2, "DOWN moves to EXIT")
	title._unhandled_input(_down(KEY_UP))
	check(title.selected == 1, "UP moves back")
	for i in 3:
		title._unhandled_input(_down())
	check(title.selected == 1, "navigation wraps around the menu")

	# --- OPTIONS opens the popup, which owns the setting rows
	title.focus_item(1)
	title.confirm()
	check(main.game_state == main.GameState.TITLE and title.visible and title.options_open(), "OPTIONS opens over the title")
	var popup = title.options
	check(popup.row_count() == 2, "the popup lists two settings")
	check(popup.focus_row == 0, "the first setting starts focused")
	title._unhandled_input(_down(KEY_DOWN))
	check(popup.focus_row == 1, "DOWN focuses the next setting")
	title._unhandled_input(_down(KEY_UP))
	check(popup.focus_row == 0, "UP focuses the previous setting")
	title._unhandled_input(_down(KEY_UP))
	check(popup.focus_row == popup.row_count(), "UP wraps to EXIT")
	var exit_direction = popup.value(0)
	var exit_style = popup.value(1)
	title._unhandled_input(_down(KEY_LEFT))
	title._unhandled_input(_down(KEY_RIGHT))
	check(popup.focus_row == popup.row_count() and popup.value(0) == exit_direction and popup.value(1) == exit_style, "LEFT and RIGHT on EXIT leave settings unchanged")
	title._unhandled_input(_down(KEY_DOWN))
	check(popup.focus_row == 0, "DOWN wraps from EXIT to the first setting")
	title._unhandled_input(_down(KEY_DOWN))
	title._unhandled_input(_down(KEY_DOWN))
	check(popup.focus_row == popup.row_count(), "DOWN reaches EXIT")
	title._unhandled_input(_down(KEY_ENTER))
	check(not title.options_open(), "ENTER on EXIT closes the popup")
	title.confirm()
	check(title.options_open(), "OPTIONS can be reopened")
	popup.focus_row = 1
	var style_before = popup.value(1)
	title._unhandled_input(_down(KEY_RIGHT))
	check(popup.value(1) != style_before, "RIGHT cycles the focused value")
	title._unhandled_input(_down(KEY_LEFT))
	check(popup.value(1) == style_before, "LEFT cycles it back")
	title._unhandled_input(_down(KEY_ESCAPE))
	check(not title.options_open(), "ESC returns to the title menu")
	check(title.selected_id() == "options", "the menu keeps OPTIONS focused afterwards")

	# --- touch: tapping a menu row opens the popup, arrows cycle, EXIT closes
	title.focus_item(0)
	# Headless has no window, so lay the control out the way the 720p window does.
	title.size = title.DESIGN
	title._press_at(title.item_rect(1).get_center())
	check(title.selected == 1 and title.options_open(), "tapping OPTIONS opens it")
	title.size = title.DESIGN
	popup.size = title.DESIGN
	var direction_before = popup.value(0)
	title._press_at(popup.arrow_rect(0, 1).get_center())
	check(popup.value(0) != direction_before, "tapping the right arrow cycles the focused setting")
	title._press_at(popup.arrow_rect(0, -1).get_center())
	check(popup.value(0) == direction_before, "tapping the left arrow cycles it back")
	title._press_at(popup.value_rect(1).get_center())
	check(popup.focus_row == 1, "tapping another setting focuses it")
	title._press_at(popup.exit_rect().get_center())
	check(not title.options_open(), "tapping EXIT returns to the title")

	# --- GAME MODE hands over to the picker
	title.focus_item(0)
	title.confirm()
	await process_frame
	check(main.game_state == main.GameState.READY, "GAME MODE enters READY")
	check(not title.visible, "the title screen hides on GAME MODE")
	check(main.song_picker.visible, "the picker takes over")
	check(main.song_version == "Dance Dance Revolution" and main.song_picker.current_song().title == "BUTTERFLY", "the picker opens on first mix BUTTERFLY")
	check(main.preview_countdown > 0.0, "entering the picker re-arms the preview")
	check(main.title_button.visible, "the picker offers a way back to the title")

	# --- back to the title from the picker, by button and by ESC
	main.title_button.pressed.emit()
	check(main.game_state == main.GameState.TITLE and title.visible, "the TITLE button returns home")
	check(not main.song_picker.visible and not main.title_button.visible, "returning home hides the picker")
	check(main.preview_countdown == 0.0 or not main.preview_player.playing, "returning home silences the preview")
	title.focus_item(0)
	title.confirm()
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	main._unhandled_input(escape)
	check(main.game_state == main.GameState.TITLE and title.visible, "ESC on the picker also returns home")
	title.focus_item(0)
	title.confirm()
	check(main.game_state == main.GameState.READY and main.song_picker.visible, "GAME MODE re-enters the picker")

	# --- leaving results goes back to the picker, never to the title
	main._start_game()
	check(main.game_state == main.GameState.PLAYING, "a chart can start from the picker")
	main._show_selection()
	check(main.game_state == main.GameState.READY and main.song_picker.visible, "results return to the picker")
	check(not title.visible, "the title does not reappear after a run")

	print("Title screen: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures > 0 else 0)

func _down(code: Key = KEY_DOWN) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event
