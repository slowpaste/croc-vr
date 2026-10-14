extends SceneTree
func _initialize() -> void:call_deferred("verify")
func finish_notice(world: Node) -> void:
	for tick in range(58):assert(world.process_source_save_menu(0,0))
	assert(world.source_main_mode==5 and not world.source_load_screen.visible)
func verify() -> void:
	var directory := "user://save-menu-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_menu_state.selected_index=12;world.source_pickup_counts[3]=27
	world.source_menu_progress_flags={0:0x8006,4:0x8000,43:0x8000,45:0x8000}
	world.source_stage_pickup_slots=[1,0,0,1,0,0,0,1]
	assert(world.enter_source_save_menu())
	assert(world.source_main_mode==11 and world.source_save_state.new_path==slots.slot_path(1))
	assert(world.process_source_save_menu(0,0x800000) and not FileAccess.file_exists(slots.slot_path(1)))
	assert(world.process_source_save_menu(0,0) and world.source_save_state.save_counter==3 and world.source_save_state.saved_percentage==13)
	var saved := preload("res://source_save_store.gd").new(slots.slot_path(1)).read_record()
	var decoded := preload("res://source_campaign_save.gd").decode(saved.record)
	assert(decoded.lives==27 and decoded.level==22 and decoded.room==0)
	finish_notice(world)
	world.source_pickup_counts[3]=9
	assert(world.enter_source_save_menu())
	assert(world.process_source_save_menu(0,0x800000) and world.source_save_state.overwrite)
	assert(world.source_save_state.navigation.selected==1 and preload("res://source_save_store.gd").new(slots.slot_path(1)).read_record().record==saved.record)
	assert(world.process_source_save_menu(0,0x800000) and not world.source_save_state.overwrite)
	assert(world.process_source_save_menu(0,0x800000))
	assert(world.process_source_save_menu(0,0x10000))
	assert(world.process_source_save_menu(0,0x800000) and world.source_save_state.pending_path==slots.slot_path(1))
	assert(world.process_source_save_menu(0,0))
	assert(preload("res://source_campaign_save.gd").decode(preload("res://source_save_store.gd").new(slots.slot_path(1)).read_record().record).lives==9)
	finish_notice(world)
	var corrupt := PackedByteArray([1,2,3])
	var file := FileAccess.open(slots.slot_path(1),FileAccess.WRITE);file.store_buffer(corrupt);file.close()
	assert(world.enter_source_save_menu())
	assert(world.process_source_save_menu(0,0x800000))
	assert(world.process_source_save_menu(0,0x10000))
	assert(world.process_source_save_menu(0,0x800000) and world.process_source_save_menu(0,0))
	assert(world.source_main_mode==11 and not str(world.source_save_state.save_error).is_empty() and world.source_save_state.pending_path=="")
	assert(FileAccess.get_file_as_bytes(slots.slot_path(1))==corrupt)
	assert(world.process_source_save_menu(0,0x800000) and world.source_main_mode==5)
	assert(world.enter_source_save_menu() and world.process_source_save_menu(0,0x100000) and world.source_main_mode==5)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(slots.slot_path(1))==OK and DirAccess.remove_absolute(directory)==OK)
	print("PASS: live Save new slot/deferred campaign write/result return, default-cancel overwrite, explicit overwrite and cancel")
	quit(0)
