extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_physics_process(false)
	var before: Dictionary=world.source_player_movement_state.duplicate(true)
	var valid: bool=world.initialize_source_demo_scene({"level":30,"room":1})
	print("FRESH_DEMO_MOTION: ",JSON.stringify({"valid":valid,"before":before,"after":world.source_player_movement_state,"entry":world.source_player_entry_state,"player_pc":world.source_player_actor.vm.pc if world.source_player_actor!=null else -1,"ground":world.source_player_actor.source_ground if world.source_player_actor!=null else {},"fault":world.source_transition_fault}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if valid else 1)
