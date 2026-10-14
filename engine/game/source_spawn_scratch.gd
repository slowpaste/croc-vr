extends RefCounted
const SpawnFrom = preload("res://source_spawn_from.gd")
var words: Array[int] = [0,0]
var known := [false,false]
var writers := ["",""]
const POSE_OFFSET := -112 # SpawnFrom frame216 + local pose104.
func write_word(offset: int, value: int, writer: String) -> bool:
	if offset not in [0,4]: return false
	var index := int(offset/4)
	words[index] = value&0xffffffff
	known[index] = true;writers[index] = writer
	return true
func stack_write(frame_bytes: int, local_offset: int, value: int, writer: String) -> bool:
	var relative := -frame_bytes+local_offset-POSE_OFFSET
	if relative not in [0,4]: return false
	return write_word(relative,value,writer)
func evaluator_frame(parent_frame_bytes: int, saved_s2: int, saved_s3: int) -> void:
	# Evaluator frame96 saves S3 at76, S2 at72. Only overlapping writes survive.
	stack_write(parent_frame_bytes+96,76,saved_s3,"evaluator_s3")
	stack_write(parent_frame_bytes+96,72,saved_s2,"evaluator_s2")
func evaluator_save(saved_s2: int, saved_s3: int) -> void:
	write_word(4,saved_s3,"evaluator_s3")
	write_word(0,saved_s2,"evaluator_s2")
func camera_query(argument_pointer: int) -> void:
	write_word(0,argument_pointer,"camera_query_a1")

func camera_query_frame(entry_stack: int, pose_address: int, alternate: bool) -> Dictionary:
	# Original362b0 frame360/local184 stores the camera map argument. Alternate
	#378b4 frame96 calls30e50 frame96/local16 with a1=parentSP+24 (37974).
	var write_address := entry_stack-96-96+16 if alternate else entry_stack-360+184
	if write_address != pose_address:
		return {"fault":"Camera query frame does not overlap the known spawn pose"}
	if alternate:
		write_word(0,entry_stack-96+24,"upper_terrain_point_pointer")
	else:
		camera_query(0x80080f78)
	return {"ok":true}
func sound_header(sample_address: int) -> void:
	write_word(4,sample_address,"sound_header_address")
func camera_update_queries(query_modes: Array, entry_stack: int, pose_address: int) -> Dictionary:
	# Commit actual camera calls in order; a held pass has no calls and must
	# retain both words. Validate the frame before making any writes.
	for alternate in query_modes:
		var write_address := entry_stack-176
		if write_address != pose_address:
			return {"fault":"Camera update stack does not overlap spawn pose"}
	for alternate in query_modes:
		var result := camera_query_frame(entry_stack,pose_address,bool(alternate))
		if result.has("fault"): return result
	return {"ok":true,"calls":query_modes.size()}
func pose() -> Dictionary:
	if not known[0] or not known[1]: return {"fault":"Unknown SpawnFrom scratch word"}
	return {"angles":SpawnFrom.scratch_angles(words[0],words[1]),"words":words.duplicate(),"writers":writers.duplicate()}
