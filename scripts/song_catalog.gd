extends RefCounted
## Song inventory behind the picker.
##
## Parsing every chart in the project costs about 50 ms, so the whole catalog is
## resolved once at start-up: charts, textures, BPM and artist are ready before
## the first frame and switching songs never touches the disk.
##
## A chart is only playable when the parser succeeded and none of its notes use
## a type this game does not implement (see `chart_problem`).

const PARSER := preload("res://scripts/sm_parser.gd")

const BASE := "res://assets/songs/"
const FIRST_MIX_DIR := "Dance Dance Revolution/"
const SECOND_MIX_DIR := "Dance Dance Revolution 2ndMIX/"
const ROULETTE := "PARANOIA MAX (DIRTY MIX) (in roulette)"
## Arcade previews are 15 s clips; charts may override both values.
const PREVIEW_FALLBACK := 15.0
const PREVIEW_MAX := 30.0
const TIERS := ["Beginner", "Easy", "Medium", "Hard", "Challenge"]
# StepMania step types shown with their DDR arcade names.
const DDR_NAMES := {
	"Beginner": "BEGINNER", "Easy": "BASIC", "Medium": "ANOTHER",
	"Hard": "MANIAC", "Challenge": "TRICK",
}
const TIER_BARS := {
	"Beginner": Color("43d6f0"), "Easy": Color("ff9a3c"), "Medium": Color("ff4d5e"),
	"Hard": Color("5ce07a"), "Challenge": Color("e05bff"),
}
## Every directory directly under the song root is a generation.
## IDs are directory names, stable across scans. Imported images are resolved by
## ResourceLoader, while chart files must be included by the export preset.
static func generations() -> Array:
	var result: Array = []
	for name in _directories(BASE):
		var image: Texture2D = null
		var files := _files(BASE + name)
		files.sort()
		for file in files:
			if file.get_basename() == name and _is_image(file):
				image = _texture(BASE + name + "/" + file)
				if image != null:
					break
		if image == null:
			for file in files:
				if _is_image(file):
					image = _texture(BASE + name + "/" + file)
					if image != null:
						break
		result.append({"id": name, "title": name, "image": image})
	return result

static func _is_image(file: String) -> bool:
	return file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]

static func _files(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			var original := name.trim_suffix(".import").trim_suffix(".remap")
			if not result.has(original):
				result.append(original)
		name = dir.get_next()
	dir.list_dir_end()
	return result

static func _directories(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if dir.current_is_dir() and not name.begins_with("."):
			result.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

## Accepts generation directory ID; integers 1/2 remain compatible with old callers.
## Entries contain only complete, playable songs, in deterministic directory order.
static func entries(include_demo := false, mix_filter = "") -> Array:
	return load_entries(include_demo, mix_filter)

static func load_entries(_include_demo := false, mix_filter = "") -> Array:
	var selected := str(mix_filter)
	if selected == "0":
		selected = ""
	elif selected == "1":
		selected = FIRST_MIX_DIR.trim_suffix("/")
	elif selected == "2":
		selected = SECOND_MIX_DIR.trim_suffix("/")
	var list: Array = []
	var groups := generations()
	for group in groups:
		var generation: String = group.id
		if not selected.is_empty() and selected != generation:
			continue
		for song in _directories(BASE + generation):
			var entry := _load_song(generation, song)
			if not entry.is_empty():
				list.append(entry)
	return list

static func _load_song(generation: String, song: String) -> Dictionary:
	var base := BASE + generation + "/" + song + "/"
	var files: Array = []
	var dir := DirAccess.open(base)
	if dir == null:
		return {}
	dir.list_dir_begin()
	var filename := dir.get_next()
	while not filename.is_empty():
		if not dir.current_is_dir():
			files.append(filename.trim_suffix(".import").trim_suffix(".remap"))
		filename = dir.get_next()
	dir.list_dir_end()
	files.sort()
	var audio := ""
	var banner := ""
	var background := ""
	var charts: Array = []
	for file in files:
		var lower: String = file.to_lower()
		if lower.ends_with(".dwi") or lower.ends_with(".sm") or lower.ends_with(".ssc"):
			if not charts.has(file):
				charts.append(file)
		elif lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav"):
			if audio.is_empty() and ResourceLoader.exists(base + file, "AudioStream"):
				audio = file
		elif lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
			if lower.get_basename().ends_with("-bg"):
				background = file
			elif banner.is_empty():
				banner = file
	if audio.is_empty() or banner.is_empty() or background.is_empty():
		return {}
	var banner_texture := _texture(base + banner)
	var background_texture := _texture(base + background)
	if banner_texture == null or background_texture == null:
		return {}
	for chart_file in charts:
		var entry := {
			"title": song, "dir": generation + "/" + song, "mix": generation, "version": generation,
			"base": base, "chart": chart_file, "audio": audio,
			"chart_path": base + chart_file, "audio_path": base + audio,
			"banner_path": base + banner, "background_path": base + background,
			"banner": banner_texture, "background": background_texture,
			"charts": [], "error": "", "sample_start": 0.0,
			"sample_length": PREVIEW_FALLBACK,
		}
		_resolve_chart(entry)
		if entry.error.is_empty() and not entry.get("hardest", {}).is_empty():
			return entry
	return {}

static func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D

static func _resolve_chart(entry: Dictionary) -> void:
	var parsed: Dictionary = PARSER.parse_file(entry.chart_path)
	if not parsed.get("ok", false):
		entry["error"] = "Chart unavailable: %s" % parsed.get("error", "Parse failed")
		return
	if typeof(parsed.get("charts")) != TYPE_ARRAY or parsed.charts.is_empty():
		entry["error"] = "No playable charts"
		return
	var metadata: Dictionary = parsed.get("metadata", {})
	var title := str(metadata.get("title", "")).strip_edges()
	if not title.is_empty():
		entry["title"] = title
	entry["artist"] = str(metadata.get("artist", "")).strip_edges()
	entry["bpm"] = float(parsed.get("bpm", 0.0))
	entry["sample_start"] = _seconds(metadata.get("samplestart", 0.0))
	entry["sample_length"] = _seconds(metadata.get("samplelength", 0.0))
	for chart in parsed.charts:
		if typeof(chart) != TYPE_DICTIONARY or typeof(chart.get("notes")) != TYPE_ARRAY:
			continue
		var resolved: Dictionary = chart
		resolved["ddr"] = tier_name(str(chart.get("difficulty", "")))
		resolved["problem"] = chart_problem(chart)
		entry.charts.append(resolved)
	_hardest(entry)

## Highest meter that can actually be played; the picker's per-song badge.
static func _hardest(entry: Dictionary) -> void:
	var best: Dictionary = {}
	for chart in entry.charts:
		if not str(chart.problem).is_empty():
			continue
		if best.is_empty() or int(chart.meter) > int(best.meter):
			best = chart
	entry["hardest"] = best
	entry["hardest_meter"] = int(best.get("meter", 0)) if not best.is_empty() else 0
	entry["hardest_tier"] = str(best.get("difficulty", "")) if not best.is_empty() else ""

## Notes this game cannot judge (rolls, mines, lifts, ...) and charts whose
## source produced parse warnings are rejected instead of silently degraded.
static func chart_problem(chart: Dictionary) -> String:
	for note in chart.get("notes", []):
		if typeof(note) != TYPE_DICTIONARY or note.get("type", "") not in ["tap", "hold"]:
			return "Unsupported note type: %s" % (str(note.get("type", "unknown")) if typeof(note) == TYPE_DICTIONARY else "unknown")
	if not chart.get("warnings", []).is_empty():
		return "Chart warnings: %s" % str(chart.get("warnings"))
	return ""

## `#SAMPLESTART` is either plain seconds ("43.110") or m:ss ("0:44.29").
static func _seconds(value) -> float:
	if typeof(value) == TYPE_STRING:
		var text: String = value.strip_edges()
		if text.is_empty():
			return 0.0
		var total := 0.0
		for part in text.split(":"):
			total = total * 60.0 + float(part)
		return total
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return 0.0

## Clip window (start, length) the picker plays while it rests on a song.
static func preview_window(entry: Dictionary) -> Vector2:
	var start: float = maxf(float(entry.get("sample_start", 0.0)), 0.0)
	var length: float = float(entry.get("sample_length", 0.0))
	if length <= 0.5:
		length = PREVIEW_FALLBACK
	return Vector2(start, minf(length, PREVIEW_MAX))

## Song the picker opens on.
static func default_index(_list: Array) -> int:
	return 0

static func tier_name(difficulty: String) -> String:
	return DDR_NAMES.get(difficulty, difficulty.to_upper())

static func tier_bar(difficulty: String) -> Color:
	return TIER_BARS.get(difficulty, Color("8b9aa6"))

static func count_holds(chart: Dictionary) -> int:
	var holds := 0
	for note in chart.get("notes", []):
		if typeof(note) == TYPE_DICTIONARY and note.get("type", "") == "hold":
			holds += 1
	return holds
