extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for actor in world.source_actors:
		if actor.source_name!="UpExit":continue
		print("UP_EXIT_INITIAL: position=",actor.position," pc=",actor.vm.pc," flags=",actor.primary_flags)
		var indices: Array=actor.vm.instructions.keys();indices.sort()
		for index in indices:
			if int(index)<=110:print("UP_EXIT_OP: ",index," ",actor.vm.instructions[index])
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	quit(0)
