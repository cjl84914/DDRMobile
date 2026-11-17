extends SceneTree

var failures := 0
var requests: Array = []
var song_requests: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var picker = load("res://scripts/song_select.gd").new()
	root.add_child(picker)
	picker.size = Vector2(1280, 720)
	picker.version_requested.connect(func(id: String): requests.append(id))
	picker.song_requested.connect(func(index: int): song_requests.append(index))
	picker.setup([{"title": "Song"}], {})
	picker.setup_versions([
		{"id": "dir/a", "title": "First", "image": null},
		{"id": "dir/b", "title": "Second", "image": null},
		{"id": "dir/c", "title": "Third Mix", "image": null},
	])
	picker.set_version_state("dir/c")
	await process_frame
	check(picker._strip_index() == 2 and picker.versions.size() == 2, "current version is absent from strip")
	picker._step_song(-1)
	check(picker._version_focus == 2 and picker.current_song().is_empty(), "last alternative precedes song")
	picker._request_play()
	check(requests == ["dir/b"], "confirm emits directory string")
	picker._scroll = 0
	picker._layout()
	picker._click((picker._hit["version:1"] as Rect2).get_center())
	check(requests == ["dir/b", "dir/a"], "click emits first directory")
	picker._step_song(-1)
	check(song_requests == [0], "navigation wraps to song index zero")
	picker.setup_versions([])
	picker._step_song(1)
	check(song_requests.back() == 0, "zero versions preserves song indexing")
	picker.setup([], {})
	picker._step_song(1)
	check(picker._strip_index() == 0, "empty strip is safe")
	picker.queue_free()
	await process_frame
	print("Dynamic versions UI: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
