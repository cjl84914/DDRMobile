extends SceneTree
const Parser = preload("res://scripts/sm_parser.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var result: Dictionary = Parser.parse_file("res://tests/fixtures/basic.sm")
	check(result.ok, "fixture parses: " + result.get("error", ""))
	if result.ok:
		check(result.metadata.title == "Example: Title" and result.metadata.music == "https://example.test/song.ogg", "metadata preserves colon and URL")
		check(result.bpm == 120.0 and result.offset == 0.25, "timing")
		var chart: Dictionary = result.charts[0]
		check(chart.difficulty == "Easy" and chart.meter == 3 and chart.description == "fixture", "chart metadata")
		var notes: Array = chart.notes
		check(notes.size() == 3, "tap and hold count")
		if notes.size() == 3:
			check(notes[0].lane == 0 and notes[0].type == "tap" and is_equal_approx(notes[0].time, -0.25), "tap and offset")
			check(notes[1].type == "hold" and notes[1].lane == 1 and is_equal_approx(notes[1].beat, 1.0) and is_equal_approx(notes[1].end_beat, 5.0) and is_equal_approx(notes[1].end_time, 2.25), "hold across measures")
			check(notes[2].lane == 3 and is_equal_approx(notes[2].beat, 6.0), "second measure tap")
	check(not Parser.parse_file("res://tests/fixtures/missing.sm").ok, "missing file")
	var base := "#TITLE:T;#OFFSET:0;#BPMS:0=120;#NOTES:dance-single::Easy:1:0,0,0,0,0:\n1000\n0000\n0000\n0000;"
	check(Parser.parse_text(base).ok, "minimal chart")
	check(Parser.parse_text(base.replace("#OFFSET:0", "#OFFSET:-1")).charts[0].notes[0].time == 1.0, "negative offset")
	var bad := [
		base.replace("0=120", "0=120,4=140"), base.replace("0=120", "1=120"),
		base.replace("0=120", "0=0"), base.replace("#OFFSET:0;", ""),
		base.replace("#OFFSET:0", "#OFFSET:nan"), base + "#STOPS:1=1;",
		base + "#DELAYS:0=1;", base + "#WARPS:0=4;", base + "#UNKNOWN:value;",
		base.replace("dance-single", "dance-double"), base.replace("1000", "M000"),
		base.replace("1000", "4000"), base.replace("1000", "3000"),
		base.replace("1000", "2000"), base.replace("1000\n0000", "2000\n1000"),
		base.replace("1000", "10000"), base.replace("1000\n0000\n0000\n0000", ""),
		base + "#OFFSET:0;", base.trim_suffix(";"), base + "garbage",
		base.replace("Easy:1:", "Easy:nope:")
	]
	for i in range(bad.size()):
		var rejected: Dictionary = Parser.parse_text(bad[i])
		check(not rejected.ok and not rejected.error.is_empty(), "invalid case %d rejected" % i)
	var multiple := base + "#NOTES:dance-single::Hard:5::\n0100\n0000;"
	check(Parser.parse_text(multiple).charts.size() == 2, "multiple charts")
	var ssc := "#VERSION:0.83;#TITLE:SSC;#OFFSET:0;#BPMS:0=120;#TIMESIGNATURES:0=4=4;#NOTEDATA:;#STEPSTYPE:dance-single;#DIFFICULTY:Hard;#METER:8;#OFFSET:-1;#BPMS:0=120,4=60;#NOTES:\n4000\n0000\n0000\n0000\n,\n3000\nM000\n0000\n0000;"
	var parsed: Dictionary = Parser.parse_text(ssc)
	check(parsed.ok, "SSC chart parses: " + parsed.get("error", ""))
	if parsed.ok:
		var notes: Array = parsed.charts[0].notes
		check(notes.size() == 2 and notes[0].type == "roll" and notes[1].type == "mine", "roll and mine preserved")
		check(is_equal_approx(notes[0].time, 1.0) and is_equal_approx(notes[0].end_time, 3.0) and is_equal_approx(notes[1].time, 4.0), "chart timing and piecewise BPM")
	check(not Parser.parse_text(ssc.replace("4=60", "4=0")).ok, "invalid local BPM rejected")
	check(not Parser.parse_text(ssc.replace("0=4=4", "0=3=4")).ok, "unsupported meter rejected")
	check(not Parser.parse_text(ssc.replace("#NOTES:", "#STOPS:4=1;#NOTES:")).ok, "chart stop rejected")
	var orphan: Dictionary = Parser.parse_text(ssc.replace("4000", "0000"))
	check(orphan.ok and orphan.charts[0].warnings.size() == 1, "SSC orphan tail reported")
	var root := "/Users/alexcai/workspace/stepmania/Songs/StepMania 5/"
	for file in ["Goin' Under/Goin' Under.ssc", "Goin' Under/Goin' Under.sm", "MechaTribe Assault/Mecha-Tribe Assault.ssc", "Springtime/Springtime.ssc"]:
		if FileAccess.file_exists(root + file):
			var original: Dictionary = Parser.parse_file(root + file)
			check(original.ok, "original %s parses: %s" % [file, original.get("error", "")])
			if original.ok:
				check(original.charts.size() == 5, "original %s has five single charts" % file)
	var dwi := "#TITLE:DWI;#FILE:song.mp3;#BPM:120;#GAP:250;#SINGLE:BASIC:3:4(268)[40]B;"
	var d: Dictionary = Parser.parse_text(dwi)
	check(d.ok, "DWI parses: " + d.get("error", ""))
	if d.ok:
		var n: Array = d.charts[0].notes
		check(d.metadata.music == "song.mp3" and d.charts[0].difficulty == "Easy" and is_equal_approx(d.offset, -0.25), "DWI metadata and GAP")
		check(n.size() == 7 and n[0].lane == 0 and is_equal_approx(n[0].time, 0.25), "DWI lane and gap")
		check(is_equal_approx(n[1].beat, 0.5) and is_equal_approx(n[3].beat, 1.0) and is_equal_approx(n[4].beat, 1.25) and is_equal_approx(n[5].beat, 1.25 + 1.0 / 3.0), "DWI subdivisions and jump timing")
	check(not Parser.parse_text(dwi.replace("(268)", "(268]")).ok, "DWI mismatched subdivision rejected")
	check(not Parser.parse_text(dwi.replace("#GAP:250", "#GAP:nan")).ok, "DWI invalid GAP rejected")
	check(not Parser.parse_text(dwi.replace("4(268)", "4!4(268)")).ok, "DWI unsupported hold rejected")
	var dir := DirAccess.open("res://assets/songs/Dance Dance Revolution 2ndMIX")
	check(dir != null, "2ndMIX directory exists")
	if dir:
		dir.list_dir_begin()
		var folder := dir.get_next()
		var count := 0
		while not folder.is_empty():
			if dir.current_is_dir() and not folder.begins_with("."):
				var path := "res://assets/songs/Dance Dance Revolution 2ndMIX/%s/%s.dwi" % [folder, folder]
				var real: Dictionary = Parser.parse_file(path)
				check(real.ok, "2ndMIX %s: %s" % [folder, real.get("error", "")])
				count += 1
			folder = dir.get_next()
		check(count == 24, "all 24 real 2ndMIX files tested")
	var brilliant: Dictionary = Parser.parse_file("res://assets/songs/Dance Dance Revolution 2ndMIX/BRILLIANT 2U/BRILLIANT 2U.dwi")
	if brilliant.ok:
		var first: Dictionary = brilliant.charts[0].notes[0]
		check(is_equal_approx(first.beat, 24.0) and is_equal_approx(first.time, 9.831) and first.lane == 2, "real chart first note timing")
	print("SM parser tests: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(1 if failures else 0)
