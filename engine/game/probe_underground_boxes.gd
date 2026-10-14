extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.tick_source_actors()
	for actor in world.source_actors:
		if not "block" in str(actor.source_name).to_lower():continue
		print("BOX: name=",actor.source_name," position=",actor.position," pc=",actor.vm.pc," model=",actor.model_name," flags=",actor.primary_flags)
		var keys: Array=actor.vm.instructions.keys();keys.sort()
		for index in range(mini(keys.size(),40)):print("BOX_OP: ",actor.vm.instructions[keys[index]])
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	quit(0)
