extends "res://probe_first_room_route.gd"
# Direct-room diagnostic; earned access is checked by the continuous parent route.
func probe() -> void:
	var world=load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
	var fault: String=await run_first_stage_bonus(world,true)
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if fault.is_empty() else 1)