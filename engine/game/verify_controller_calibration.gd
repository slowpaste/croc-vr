extends SceneTree
const Calibration = preload("res://source_controller_calibration.gd")
func _initialize() -> void:
	var state := {"phase":0,"center":Vector2i.ZERO,"minimum":Vector2i.ZERO,"maximum":Vector2i.ZERO}
	state = Calibration.advance(state,Vector2i(127,129),0x800000)
	if state.phase!=1 or state.center!=Vector2i(127,129) or state.commit: quit(1);return
	state = Calibration.advance(state,Vector2i(0,255),0)
	state = Calibration.advance(state,Vector2i(255,0),0)
	state = Calibration.advance(state,Vector2i(128,128),0x900000)
	if not state.commit or not state.back or state.minimum!=Vector2i.ZERO or state.maximum!=Vector2i(255,255) or state.center!=Vector2i(127,129):
		push_error("Original calibration source-derived capture/commit mismatch");quit(1);return
	var cancelled := Calibration.advance({"phase":0,"center":Vector2i.ZERO,"minimum":Vector2i.ZERO,"maximum":Vector2i.ZERO},Vector2i(128,128),0x100000)
	if not cancelled.back or cancelled.commit or cancelled.phase!=0: quit(1);return
	var normalized := Calibration.normalize(state.center,state.minimum,state.maximum)
	if normalized.status!=1 or normalized.lower_midpoint!=Vector2i(63,64) or normalized.upper_midpoint!=Vector2i(191,192) or normalized.radius!=122 or normalized.half_radius!=63: quit(1);return
	var fallback := Calibration.normalize(Vector2i(128,128),Vector2i(120,120),Vector2i(140,140))
	if fallback.status!=-1 or fallback.center!=Vector2i(128,128) or fallback.minimum!=Vector2i.ZERO or fallback.maximum!=Vector2i(255,255) or fallback.radius!=123: quit(1);return
	if Calibration.normalize(Vector2i(32,32),Vector2i.ZERO,Vector2i(64,64)).radius!=28: quit(1);return
	if Calibration.normalize(Vector2i(31,32),Vector2i.ZERO,Vector2i(64,64)).status!=-1: quit(1);return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-controller-normalization.json"))
	for index in range(0,fixture.observations.size(),2):
		var before: Dictionary = fixture.observations[index]
		var after: Dictionary = fixture.observations[index+1]
		var result := Calibration.normalize(Vector2i(int(before.cx),int(before.cy)),Vector2i(int(before.minx),int(before.miny)),Vector2i(int(before.maxx),int(before.maxy)))
		if result.status!=int(after.status) or result.center!=Vector2i(int(after.cx),int(after.cy)) or result.minimum!=Vector2i(int(after.minx),int(after.miny)) or result.maximum!=Vector2i(int(after.maxx),int(after.maxy)) or result.lower_midpoint!=Vector2i(int(after.lowx),int(after.lowy)) or result.upper_midpoint!=Vector2i(int(after.highx),int(after.highy)) or result.half_radius!=int(after.half_radius) or result.radius!=int(after.radius):
			push_error("Original calibration normalization mismatch");quit(1);return
	print("PASS: calibration capture rules and eight original runtime normalization cases")
	quit(0)
