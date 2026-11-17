extends RefCounted
## SM and SSC dance-single subset; SSC supports chart timing and BPM changes.
## Chart warnings identify ignored orphan hold tails in source SSC charts.
## Holds, rolls and mines remain distinct; callers must implement their semantics.

const METADATA := ["TITLE", "SUBTITLE", "ARTIST", "TITLETRANSLIT", "SUBTITLETRANSLIT", "ARTISTTRANSLIT", "GENRE", "CREDIT", "BANNER", "BACKGROUND", "LYRICSPATH", "CDTITLE", "MUSIC", "SAMPLESTART", "SAMPLELENGTH", "SELECTABLE"]
const EMPTY_TIMING := ["STOPS", "FREEZES", "DELAYS", "WARPS", "SPEEDS", "SCROLLS", "TICKCOUNTS", "TIMESIGNATURES", "FAKES", "LABELS", "COMBOS", "BGCHANGES", "FGCHANGES", "KEYSOUNDS", "ATTACKS"]

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _number(text: String) -> bool:
	return text.strip_edges().is_valid_float() and is_finite(text.strip_edges().to_float())

static func parse_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open file: %s" % path)
	return parse_text(file.get_as_text())

static func parse_text(text: String) -> Dictionary:
	# Only whole-line comments are removed; inline // in metadata can be a URL.
	var lines := text.trim_prefix("\ufeff").replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var cleaned := PackedStringArray()
	for line in lines:
		if not line.strip_edges().begins_with("//"):
			cleaned.append(line)
	var source := "\n".join(cleaned)
	if source.to_upper().contains("#NOTEDATA:"):
		return _parse_ssc(source)
	if source.to_upper().contains("#SINGLE:") or source.to_upper().contains("#BPM:"):
		return _parse_dwi(source)
	var tags: Dictionary = {}
	var chart_values: Array = []
	var pos := 0
	while pos < source.length():
		while pos < source.length() and source.substr(pos, 1) in [" ", "\t", "\n"]:
			pos += 1
		if pos == source.length():
			break
		if source.substr(pos, 1) != "#":
			return _fail("Expected tag at character %d" % pos)
		var colon := source.find(":", pos + 1)
		var semi := source.find(";", pos + 1)
		if colon < 0 or semi < 0 or colon > semi:
			return _fail("Malformed or unterminated tag")
		var key := source.substr(pos + 1, colon - pos - 1).strip_edges().to_upper()
		var value := source.substr(colon + 1, semi - colon - 1).strip_edges()
		if key == "NOTES":
			chart_values.append(value)
		elif key in METADATA or key in EMPTY_TIMING or key in ["BPMS", "OFFSET"]:
			if tags.has(key):
				return _fail("Duplicate tag: %s" % key)
			tags[key] = value
			if key in EMPTY_TIMING and not value.is_empty():
				return _fail("Unsupported feature: %s" % key)
		else:
			return _fail("Unsupported tag: %s" % key)
		pos = semi + 1
	if not tags.has("BPMS") or not tags.has("OFFSET"):
		return _fail("BPMS and OFFSET are required")
	var bpms: PackedStringArray = tags["BPMS"].split(",", true)
	if bpms.size() != 1:
		return _fail("Exactly one BPM is required")
	var pair := bpms[0].split("=", true)
	if pair.size() != 2 or not _number(pair[0]) or not _number(pair[1]):
		return _fail("Invalid BPM")
	var bpm := pair[1].strip_edges().to_float()
	if pair[0].strip_edges().to_float() != 0.0 or bpm <= 0.0 or not _number(tags["OFFSET"]):
		return _fail("BPM must be positive at beat zero and OFFSET finite")
	var offset: float = tags["OFFSET"].to_float()
	if chart_values.is_empty():
		return _fail("At least one NOTES chart is required")
	var charts: Array = []
	for value in chart_values:
		if chart_values.size() > 1 and value.get_slice(":", 0).strip_edges().to_lower() != "dance-single":
			continue
		var result := _parse_chart(value, bpm, offset, [], chart_values.size() > 1)
		if not result.ok:
			return result
		charts.append(result.chart)
	if charts.is_empty():
		return _fail("No supported dance-single chart")
	var metadata: Dictionary = {}
	for key in METADATA:
		if tags.has(key):
			metadata[key.to_lower()] = tags[key]
	return {"ok": true, "error": "", "metadata": metadata, "bpm": bpm, "offset": offset, "charts": charts}

static func _parse_chart(value: String, bpm: float, offset: float, segments: Array = [], extended: bool = false) -> Dictionary:
	var fields := value.split(":", true, 5)
	if fields.size() != 6:
		return _fail("NOTES requires five headers and note data")
	var step_type := fields[0].strip_edges()
	if step_type.to_lower() != "dance-single":
		return _fail("Unsupported step type: %s" % step_type)
	var meter := fields[3].strip_edges()
	if not meter.is_valid_int() or meter.to_int() < 0:
		return _fail("Invalid chart meter")
	var notes: Array = []
	var warnings: Array = []
	var active: Dictionary = {}
	var measures := fields[5].split(",", true)
	for measure_index in range(measures.size()):
		var rows: Array = []
		for line in measures[measure_index].split("\n"):
			var row := line.strip_edges()
			if not row.is_empty():
				rows.append(row)
		if rows.is_empty():
			return _fail("Empty measure %d" % measure_index)
		for row_index in range(rows.size()):
			var row: String = rows[row_index]
			if row.length() != 4:
				return _fail("Expected four lanes at measure %d row %d" % [measure_index, row_index])
			var beat := float(measure_index) * 4.0 + float(row_index) * 4.0 / float(rows.size())
			var time := _beat_time(beat, segments, bpm, offset)
			if not is_finite(time):
				return _fail("Computed note time is not finite")
			for lane in range(4):
				var symbol := row.substr(lane, 1)
				if symbol == "0":
					continue
				if symbol == "1" or symbol == "2" or (extended and symbol in ["M", "4"]):
					if active.has(lane):
						return _fail("Note overlaps hold on lane %d" % lane)
					var kind := "tap" if symbol == "1" else ("hold" if symbol == "2" else ("roll" if symbol == "4" else "mine"))
					var note := {"lane": lane, "type": kind, "beat": beat, "time": time}
					notes.append(note)
					if symbol in ["2", "4"]:
						active[lane] = note
				elif symbol == "3":
					if not active.has(lane):
						if not segments.is_empty():
							warnings.append("Unmatched hold tail at beat %s lane %d" % [beat, lane])
							continue
						return _fail("Unmatched hold tail on lane %d" % lane)
					active[lane]["end_beat"] = beat
					active[lane]["end_time"] = time
					active.erase(lane)
				else:
					return _fail("Unsupported note '%s' at measure %d row %d" % [symbol, measure_index, row_index])
	if not active.is_empty():
		return _fail("Unclosed hold")
	return {"ok": true, "chart": {"step_type": step_type, "description": fields[1].strip_edges(), "difficulty": fields[2].strip_edges(), "meter": meter.to_int(), "radar": fields[4].strip_edges(), "notes": notes, "warnings": warnings}}


# Piecewise-constant BPM integration, with beat zero as the time origin.
static func _beat_time(beat: float, segments: Array, bpm: float, offset: float) -> float:
	var seconds := -offset
	var previous := 0.0
	var current := bpm
	for segment in segments:
		if segment.beat > beat:
			break
		seconds += (segment.beat - previous) * 60.0 / current
		previous = segment.beat
		current = segment.bpm
	return seconds + (beat - previous) * 60.0 / current

static func _parse_bpms(value: String) -> Dictionary:
	var segments: Array = []
	var previous := -1.0
	for item in value.split(",", true):
		var pair := item.split("=", true)
		if pair.size() != 2 or not _number(pair[0]) or not _number(pair[1]):
			return _fail("Invalid BPM")
		var beat := pair[0].strip_edges().to_float()
		var bpm := pair[1].strip_edges().to_float()
		if bpm <= 0.0 or beat <= previous or (segments.is_empty() and beat != 0.0):
			return _fail("BPMs must start at zero and have strictly increasing beats and positive values")
		segments.append({"beat": beat, "bpm": bpm})
		previous = beat
	return {"ok": true, "segments": segments}

static func _parse_ssc(source: String) -> Dictionary:
	var global: Dictionary = {}
	var chart: Dictionary = {}
	var blocks: Array = []
	var in_chart := false
	var pos := 0
	var known := METADATA + EMPTY_TIMING + ["VERSION", "ORIGIN", "PREVIEWVID", "JACKET", "CDIMAGE", "DISCIMAGE", "DISPLAYBPM", "BPMS", "OFFSET", "CHARTNAME", "STEPSTYPE", "DESCRIPTION", "CHARTSTYLE", "DIFFICULTY", "METER", "RADARVALUES", "NOTES"]
	while pos < source.length():
		while pos < source.length() and source.substr(pos, 1) in [" ", "\t", "\n"]:
			pos += 1
		if pos == source.length():
			break
		if source.substr(pos, 1) != "#":
			return _fail("Expected tag at character %d" % pos)
		var colon := source.find(":", pos + 1)
		var semi := source.find(";", pos + 1)
		if colon < 0 or semi < 0 or colon > semi:
			return _fail("Malformed or unterminated tag")
		var key := source.substr(pos + 1, colon - pos - 1).strip_edges().to_upper()
		var value := source.substr(colon + 1, semi - colon - 1).strip_edges()
		if key == "NOTEDATA":
			if not value.is_empty():
				return _fail("Invalid NOTEDATA")
			if in_chart:
				blocks.append(chart)
			chart = {}
			in_chart = true
		else:
			if not key in known:
				return _fail("Unsupported tag: %s" % key)
			var target := chart if in_chart else global
			if target.has(key):
				return _fail("Duplicate tag: %s" % key)
			target[key] = value
		pos = semi + 1
	if in_chart:
		blocks.append(chart)
	if not global.has("BPMS") or not global.has("OFFSET") or not _number(global.OFFSET):
		return _fail("BPMS and finite OFFSET are required")
	var global_bpm := _parse_bpms(global.BPMS)
	if not global_bpm.ok:
		return global_bpm
	var charts: Array = []
	for block in blocks:
		if block.get("STEPSTYPE", "").to_lower() != "dance-single":
			continue
		for key in ["STEPSTYPE", "DIFFICULTY", "METER", "NOTES"]:
			if not block.has(key):
				return _fail("Missing chart tag: %s" % key)
		var effective := global.duplicate()
		effective.merge(block, true)
		for key in ["STOPS", "FREEZES", "DELAYS", "WARPS", "FAKES", "BGCHANGES", "FGCHANGES", "KEYSOUNDS", "ATTACKS"]:
			if not effective.get(key, "").is_empty():
				return _fail("Unsupported feature: %s" % key)
		# Only the 4/4 measure grid is implemented; these other fields affect
		# display or scoring, not beat-to-time conversion.
		var signatures: String = effective.get("TIMESIGNATURES", "")
		if not signatures.is_empty():
			var parts := signatures.split("=", true)
			if parts.size() != 3 or not _number(parts[0]) or parts[0].to_float() != 0.0 or parts[1].strip_edges() != "4" or parts[2].strip_edges() != "4":
				return _fail("Unsupported time signature")
		if not _number(effective.OFFSET):
			return _fail("Invalid chart offset")
		var timing := _parse_bpms(effective.BPMS)
		if not timing.ok:
			return timing
		var segments: Array = timing.segments
		var bpm: float = segments[0].bpm
		var offset: float = effective.OFFSET.to_float()
		var value: String = "%s:%s:%s:%s:%s:%s" % [block.STEPSTYPE, block.get("DESCRIPTION", ""), block.DIFFICULTY, block.METER, block.get("RADARVALUES", ""), block.NOTES]
		var parsed := _parse_chart(value, bpm, offset, segments, true)
		if not parsed.ok:
			return parsed
		parsed.chart["bpms"] = segments
		parsed.chart["offset"] = offset
		charts.append(parsed.chart)
	if charts.is_empty():
		return _fail("No supported dance-single chart")
	var metadata: Dictionary = {}
	for key in METADATA:
		if global.has(key):
			metadata[key.to_lower()] = global[key]
	return {"ok": true, "error": "", "metadata": metadata, "bpm": global_bpm.segments[0].bpm, "offset": global.OFFSET.to_float(), "charts": charts}


# DWI positions default to eighth notes; GAP is milliseconds after audio zero.
static func _parse_dwi(source: String) -> Dictionary:
	var tags: Dictionary = {}
	var singles: Array = []
	var pos := 0
	while pos < source.length():
		while pos < source.length() and source.substr(pos, 1) in [" ", "\t", "\n"]:
			pos += 1
		if pos == source.length():
			break
		if source.substr(pos, 1) != "#":
			return _fail("Expected DWI tag at character %d" % pos)
		var colon := source.find(":", pos + 1)
		var semi := source.find(";", pos + 1)
		if colon < 0 or semi < 0 or colon > semi:
			return _fail("Malformed or unterminated DWI tag")
		var key := source.substr(pos + 1, colon - pos - 1).strip_edges().to_upper()
		var value := source.substr(colon + 1, semi - colon - 1).strip_edges()
		if key == "SINGLE":
			singles.append(value)
		elif key in ["DOUBLE", "COUPLE", "SOLO"]:
			pass
		elif key in METADATA or key in ["FILE", "BPM", "GAP", "DISPLAYBPM", "CHANGEBPM"]:
			if tags.has(key):
				return _fail("Duplicate tag: %s" % key)
			tags[key] = value
		else:
			return _fail("Unsupported DWI tag: %s" % key)
		pos = semi + 1
	if not tags.has("BPM") or not _number(tags.BPM) or tags.BPM.to_float() <= 0.0:
		return _fail("DWI BPM must be positive and finite")
	if not tags.has("GAP") or not _number(tags.GAP):
		return _fail("DWI GAP must be finite")
	var bpm: float = tags.BPM.to_float()
	var offset: float = -tags.GAP.to_float() / 1000.0
	var segments: Array = []
	if tags.has("CHANGEBPM") and not tags.CHANGEBPM.is_empty():
		var timing := _parse_bpms("0=%s,%s" % [bpm, _dwi_bpm_changes(tags.CHANGEBPM)])
		if not timing.ok:
			return timing
		segments = timing.segments
	var charts: Array = []
	for value in singles:
		var parsed := _parse_dwi_chart(value, bpm, offset, segments)
		if not parsed.ok:
			# Keep other difficulties when one uses unsupported DWI notation.
			continue
		charts.append(parsed.chart)
	if charts.is_empty():
		return _fail("No supported dance-single chart")
	var metadata: Dictionary = {}
	for key in METADATA:
		if tags.has(key):
			metadata[key.to_lower()] = tags[key]
	if tags.has("FILE"):
		metadata["music"] = tags.FILE
	return {"ok": true, "error": "", "metadata": metadata, "bpm": bpm, "offset": offset, "charts": charts}

# DWI timing positions are expressed in eighth-beat ticks.
static func _dwi_bpm_changes(value: String) -> String:
	var changes: PackedStringArray = []
	for item in value.split(","):
		var pair := item.split("=", true)
		if pair.size() != 2 or not _number(pair[0]):
			return "invalid"
		changes.append("%s=%s" % [pair[0].to_float() / 8.0, pair[1]])
	return ",".join(changes)

static func _parse_dwi_chart(value: String, bpm: float, offset: float, segments: Array = []) -> Dictionary:
	var fields := value.split(":", true, 2)
	if fields.size() != 3 or not fields[1].strip_edges().is_valid_int() or fields[1].strip_edges().to_int() < 0:
		return _fail("Invalid DWI chart header")
	var difficulties := {"BEGINNER": "Beginner", "BASIC": "Easy", "ANOTHER": "Medium", "MANIAC": "Hard", "SMANIAC": "Challenge"}
	var difficulty := fields[0].strip_edges().to_upper()
	if not difficulties.has(difficulty):
		return _fail("Unsupported DWI difficulty: %s" % difficulty)
	var data := fields[2].to_upper().replace(" ", "").replace("\n", "").replace("\t", "").replace("\r", "")
	if data.is_empty():
		return _fail("Empty DWI chart")
	var lanes := {"0": [], "5": [], "1": [0, 1], "2": [1], "3": [1, 3], "4": [0], "6": [3], "7": [0, 2], "8": [2], "9": [2, 3], "A": [1, 2], "B": [0, 3]}
	var notes: Array = []
	var beat := 0.0
	var increment := 0.5
	var closing := ""
	for i in range(data.length()):
		var c := data.substr(i, 1)
		if c in ["(", "[", "{", "`"]:
			if not closing.is_empty():
				return _fail("Nested DWI subdivisions unsupported")
			closing = {"(": ")", "[": "]", "{": "}", "`": "'"}[c]
			increment = {"(": 0.25, "[": 1.0 / 6.0, "{": 1.0 / 16.0, "`": 1.0 / 48.0}[c]
		elif c in [")", "]", "}", "'"]:
			if c != closing:
				return _fail("Mismatched DWI subdivision")
			closing = ""
			increment = 0.5
		else:
			if not lanes.has(c):
				return _fail("Unsupported DWI note: %s" % c)
			for lane in lanes[c]:
				var time := _beat_time(beat, segments, bpm, offset)
				if not is_finite(time):
					return _fail("Computed note time is not finite")
				notes.append({"lane": lane, "type": "tap", "beat": beat, "time": time})
			beat += increment
	if not closing.is_empty():
		return _fail("Unclosed DWI subdivision")
	return {"ok": true, "chart": {"step_type": "dance-single", "description": "", "difficulty": difficulties[difficulty], "meter": fields[1].strip_edges().to_int(), "radar": "", "notes": notes, "warnings": []}}
