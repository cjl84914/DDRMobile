extends SceneTree

const Catalog = preload("res://scripts/song_catalog.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var first := Catalog.load_entries(false, 1)
	var second := Catalog.load_entries(false, 2)
	check(first.size() == 12, "12 first mix songs")
	check(second.size() == 24, "24 second mix songs")
	check(Catalog.entries().size() >= 36, "default includes both original mixes")
	check(Catalog.entries(false, 3).is_empty(), "unknown mix is empty")
	var parser = preload("res://scripts/sm_parser.gd")
	var variable: Dictionary = parser.parse_text("#BPM:120;#GAP:0;#CHANGEBPM:8=60;#SINGLE:BASIC:3:4444;#SINGLE:MANIAC:8:4!4;")
	check(variable.ok and variable.charts.size() == 1, "unsupported difficulty does not hide valid charts")
	if variable.ok:
		check(is_equal_approx(variable.charts[0].notes[3].time, 1.0), "DWI BPM change uses eighth-beat positions")
	for entry in first:
		check(entry.mix == "Dance Dance Revolution" and FileAccess.file_exists(entry.audio_path), "first mix audio: " + entry.title)
		check(entry.error.is_empty() and not entry.charts.is_empty(), "first mix charts: " + entry.title + " " + entry.error)
		check(FileAccess.file_exists(entry.banner_path) and FileAccess.file_exists(entry.background_path), "first mix artwork files: " + entry.title)
		check(entry.charts.any(func(chart): return chart.problem.is_empty()), "playable chart: " + entry.title)
	for entry in second:
		check(entry.mix == "Dance Dance Revolution 2ndMIX" and entry.error.is_empty(), "second mix unchanged: " + entry.title)
	check(Catalog.default_index(first) == 0 and Catalog.default_index(second) == 0, "each folder defaults to its first song")
	print("First mix catalog: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
