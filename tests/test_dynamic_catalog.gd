extends SceneTree

const Catalog = preload("res://scripts/song_catalog.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var generations: Array = Catalog.generations()
	check(generations.any(func(g): return g.id == "Dance Dance Revolution 3rdMIX"), "discovers third generation")
	check(generations.any(func(g): return g.id == "Demo"), "every song root directory is a generation")
	var songs: Array = Catalog.load_entries()
	check(not songs.is_empty(), "catalog finds songs")
	check(songs.any(func(s): return s.version == "Dance Dance Revolution 3rdMIX"), "discovers third generation songs")
	for song in songs:
		check(song.version == song.mix and song.banner != null and song.background != null, "complete song metadata")
		check(ResourceLoader.exists(song.audio_path, "AudioStream") and FileAccess.file_exists(song.chart_path), "song resources exist")
		check(song.charts.any(func(c): return c.problem.is_empty()), "song has playable chart")
	check(Catalog.load_entries(false, "nonexistent generation").is_empty(), "unknown generation empty")
	check(Catalog._load_song("Demo", "goin-under").is_empty(), "missing artwork excludes incomplete song")
	check(not Catalog.chart_problem({"notes": [{"type": "mine"}]}).is_empty(), "unsupported note rejected")
	check(not Catalog.chart_problem({"notes": [], "warnings": ["bad"]}).is_empty(), "chart warnings rejected")
	print("Dynamic catalog: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
