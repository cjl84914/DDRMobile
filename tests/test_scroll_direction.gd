extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1280, 720)
	main.scroll_direction = "upward"
	assert(is_equal_approx(main._target_y(), 720.0 * 0.18))
	assert(main._note_y(2.0, 1.0) > main._target_y())
	main.scroll_direction = "downward"
	assert(is_equal_approx(main._target_y(), 720.0 * 0.85))
	assert(main._note_y(2.0, 1.0) < main._target_y())
	assert(is_equal_approx(main._note_y(1.0, 1.0), main._target_y()))
	# Equal time steps cover more distance as the note approaches the target.
	var far: float = main._note_y(2.0, 1.0)
	var middle: float = main._note_y(2.0, 1.5)
	var near: float = main._note_y(2.0, 2.0)
	assert(near - middle > middle - far)
	var duration: float = main._target_y() / main.SCROLL_SPEED
	assert(is_equal_approx(main._note_y(3.0, 3.0 - duration), 0.0))
	assert(main._note_y(3.0, 3.0 - duration - 0.1) < 0.0)
	assert(main._note_y(3.0, 3.01) > main._target_y())
	assert(is_equal_approx(near, main._target_y()))
	# At the same instant, equal-interval notes spread further apart near
	# the bottom than at the top; compare centers without changing note size.
	var far_gap: float = main._note_y(2.0, 0.8) - main._note_y(2.25, 0.8)
	var near_gap: float = main._note_y(2.0, 1.9) - main._note_y(2.25, 1.9)
	assert(near_gap > far_gap)
	var target: float = main._target_y()
	var progress_a: float = 1.0 - 0.1 / duration
	var progress_b: float = 1.0 - 0.35 / duration
	var previous_gap: float = target * (pow(progress_a, 2.0) - pow(progress_b, 2.0))
	assert(near_gap > previous_gap)
	for lane in 4:
		assert(main._lane_at(Vector2((lane + 0.5) * 320.0, 719.0)) == lane)
		assert(is_equal_approx(main._downward_lane_edge(lane, 720.0), lane * 320.0))
		assert(is_equal_approx(main._downward_lane_edge(lane + 1, 720.0) - main._downward_lane_edge(lane, 720.0), 320.0))
	# Edges continue to diverge past the target instead of turning vertical.
	assert(main._downward_lane_edge(1, 720.0) < main._downward_lane_edge(1, main._target_y()))
	assert(main._downward_lane_edge(3, 720.0) > main._downward_lane_edge(3, main._target_y()))
	assert(main._lane_at(Vector2(320.0, 100.0)) == 1)
	assert(main._lane_at(Vector2(1280.0, 100.0)) == -1)
	assert(main._downward_lane_edge(1, 0.0) - main._downward_lane_edge(0, 0.0) > 0.0)
	assert(main._downward_lane_edge(1, 0.0) - main._downward_lane_edge(0, 0.0) < 320.0)
	assert(main._downward_note_height(0.0) < main._downward_note_height(main._target_y() * 0.5))
	assert(main._downward_note_height(main._target_y() * 0.5) < main._downward_note_height(main._target_y()))
	assert(is_equal_approx(main._downward_note_height(main._target_y()), 1.5 * maxf(720.0 * 0.045, 12.0)))
	main.queue_free()
	print("Scroll direction tests: PASS")
	quit(0)
