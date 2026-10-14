extends RefCounted
static func entry_fade(scene_id: int) -> int:
	# Native50368..50388 uses unsigned(scene_id-10)<9.
	if scene_id < 0 or scene_id >= 24: return 0
	return 3 if scene_id >= 10 and scene_id <= 18 else 1

static func initialize() -> Dictionary:
	return {"ending":false}

# Native505d4..50618: called after the current fade handler, before pose drawing.
static func before_frame(state: Dictionary, tag: int, scene_index: int, scene_count: int) -> Dictionary:
	var result := state.duplicate(true)
	result.start = 0
	if tag == 13 and scene_index == scene_count-1 and not bool(result.ending):
		result.ending = true
		result.start = 8
	return result

# Native50a04..50a80. A newly started fade clears readiness before completion.
static func after_frame(state: Dictionary, held: int, fade_ready: bool, end_marker: bool) -> Dictionary:
	var result := state.duplicate(true)
	result.start = 0
	var ready := fade_ready
	if ready and not bool(result.ending) and (held & 0xf0c780) != 0:
		result.ending = true
		result.start = 8
		ready = false
	result.advance_scene = end_marker or bool(result.ending) and ready
	return result
