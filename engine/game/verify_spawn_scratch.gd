extends SceneTree
func _initialize() -> void:
	var scratch := preload("res://source_spawn_scratch.gd").new()
	assert(scratch.pose().has("fault"))
	# Replay independently observed native writer order and values.
	scratch.evaluator_save(0x20000000,0x04000000)
	scratch.sound_header(0x429b0)
	scratch.camera_query(0x80080f78)
	assert(scratch.pose().angles == Vector3i(3960,-32760,10672))
	assert(scratch.pose().writers == ["camera_query_a1","sound_header_address"])
	var unchanged: Dictionary = scratch.pose()
	# Native If/LetGVar frame32 evaluators do not overlap SpawnFrom's pose.
	scratch.evaluator_frame(32,0x20000000,0x04000000)
	assert(scratch.pose() == unchanged)
	# Dying/muted trace: evaluator overwrites the sound word; camera only replaces0.
	scratch.evaluator_frame(88,0x20000000,0x04000000)
	scratch.camera_query(0x80080f78)
	assert(scratch.pose().angles == Vector3i(3960,-32760,0))
	assert(scratch.pose().writers == ["camera_query_a1","evaluator_s3"])
	# PlaySound frame56 + SPU helper112 saves sample address at local60.
	assert(scratch.stack_write(168,60,0x4fa70,"sound_header_address"))
	assert(scratch.pose().angles == Vector3i(3960,-32760,-1424))
	var previous: Dictionary = scratch.pose()
	assert(not scratch.write_word(8,123,"invalid"))
	assert(scratch.pose() == previous)
	assert(scratch.camera_update_queries([],0,0).calls == 0 and scratch.pose() == previous)
	assert(scratch.camera_update_queries([false,true],0x807fea34,0x807fe980).has("fault") and scratch.pose() == previous)
	assert(scratch.camera_update_queries([false,true],0x807fea30,0x807fe980).calls == 2)
	assert(scratch.pose().angles == Vector3i(-5656,-32641,-1424))
	# Independent normal and forced-alternate camera observations share the
	# same entry stack. The alternate pointer is derived from nested frames.
	assert(not scratch.camera_query_frame(0x807fea30,0x807fe980,false).has("fault"))
	assert(scratch.pose().angles == Vector3i(3960,-32760,-1424))
	scratch.sound_header(0x429b0)
	assert(not scratch.camera_query_frame(0x807fea30,0x807fe980,true).has("fault"))
	assert(scratch.pose().angles == Vector3i(-5656,-32641,10672))
	assert(scratch.pose().writers[0] == "upper_terrain_point_pointer")
	previous = scratch.pose()
	assert(scratch.camera_query_frame(0x807fea34,0x807fe980,true).has("fault"))
	assert(scratch.pose() == previous)
	print("PASS: ordered native scratch writers reproduce audible/muted spawn poses, retain writer provenance and reject unknown/invalid writes")
	quit(0)
