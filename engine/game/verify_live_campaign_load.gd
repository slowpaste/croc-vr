extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var path := "user://campaign-load-test-"+str(OS.get_process_id())+".bin"
	assert(not FileAccess.file_exists(path))
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=path
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_menu_progress_flags={4:0x8000,0:0x8006}
	world.source_stage_pickup_slots=[1,1,0,0,0,0,0,0]
	world.source_menu_announcement_history=[1,2,3,4,5,6,7,8]
	world.source_menu_state.selected_index=12;world.source_pickup_counts[3]=27
	assert(world.write_source_campaign().written)
	world.source_menu_progress_flags.clear();world.source_stage_pickup_slots.fill(0);world.source_pickup_counts[3]=3
	assert(world.load_source_campaign())
	assert(world.map_name=="MP100_02.MAP" and world.source_main_mode==5 and not world.source_controller_enabled)
	assert(world.source_menu_state.selected_index==12 and world.source_pickup_counts[3]==27 and world.source_menu_progress_flags[0]==0x8006)
	assert(world.source_stage_pickup_slots==[128,0,0,0,0,0,0,0] and world.source_menu_announcement_history==[1,2,3,4,5,6,7,8])
	for tick in range(60):world.tick_source_actors()
	for actor in world.source_actors:assert(actor.vm.fault=="")
	var old_flags: Dictionary=world.source_menu_progress_flags.duplicate()
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(PackedByteArray([1,2,3]));file.close()
	assert(not world.load_source_campaign() and world.map_name=="MP100_02.MAP" and world.source_menu_progress_flags==old_flags)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(path)==OK)
	print("PASS: live campaign load restores saved progress/lives/history, prunes pickups and runs correct island selector; corrupt load preserves room/progress")
	quit(0)
