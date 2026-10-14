extends SceneTree
func _initialize() -> void:
	var history=preload("res://runtime_performance_history.gd").new()
	history.path="user://verify-performance-history.jsonl";history.limit_bytes=100
	for suffix in ["",".previous"]:
		if FileAccess.file_exists(history.path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(history.path+suffix))
	assert(history.append({"room":"MP010_00.MAP","performance_cpu":{"source_tick":{"max_us":21000}}},[{"category":"source_tick","duration_us":21000}])==OK)
	assert(history.append({"room":"MP100_01.MAP","performance_cpu":{}},[])==OK)
	assert(FileAccess.file_exists(history.path+".previous"))
	var earlier:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(history.path+".previous").strip_edges())
	var latest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(history.path).strip_edges())
	assert(earlier.room=="MP010_00.MAP" and earlier.slow_events[0].duration_us==21000)
	assert(latest.room=="MP100_01.MAP" and latest.performance_cpu.is_empty())
	history.limit_bytes=100000
	assert(history.append({"room":"MP010_01.MAP"},[])==OK)
	assert(FileAccess.get_file_as_string(history.path).strip_edges().split("\n").size()==2)
	for suffix in ["",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(history.path+suffix))
	print("PASS: level timings survive idle/menu reports, append and bounded-history rotation")
	quit(0)
