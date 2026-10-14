extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.sample_source_player_controls();world.tick_source_actors()
	var door: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="BonusDoor":door=actor;break
	assert(door!=null and not door.model_data.is_empty() and not door.mesh_parts.is_empty())
	var handle := -1
	for index in range(1,door.handles.size()):
		if str(door.handles[index].get("name",""))==door.model_name:handle=index;break
	assert(handle>0)
	var primary: int=door.primary_flags
	var secondary: int=door.secondary_flags
	var clip: String=door.clip_name
	var playing: bool=door.clip_playing
	var parts: Array=door.mesh_parts.duplicate()
	var bodies: Array=door.camera_bodies.duplicate()
	# Execute the actual null-model command reached by the earned door route.
	assert(door.vm.instructions[177].op==58)
	assert(door.asl_command(door.vm.instructions[177],door.vm)=="continue")
	assert(door.model_data.is_empty() and door.model_name=="" and door.mesh_parts.is_empty())
	assert(door.primary_flags==primary and door.secondary_flags==(secondary&~0x30))
	assert(door.clip_name==clip and door.clip_playing==playing)
	assert(door.model_surface_candidates_at(door.position,world.source_player_actor).is_empty())
	for part in parts:assert(not part.visible and part.is_queued_for_deletion())
	for body in bodies:assert(body.collision_layer==0)
	assert(door.asl_command({"op":58,"args":[[{"op":4,"value":handle},{"op":18}]]},door.vm)=="continue")
	assert(not door.model_data.is_empty() and not door.mesh_parts.is_empty())
	assert(door.primary_flags==primary and door.clip_name==clip and door.clip_playing==playing)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: authored BonusDoor SetModel(0) clears visuals/collision, preserves flags/animation and supports restoring a model")
	quit(0)
