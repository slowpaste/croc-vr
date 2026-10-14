extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var directory := "user://startup-save-selection-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var settings := {"scheme":2,"music":40,"effects":119,"mode":0,"center_x":128,"center_y":128,"minimum_x":0,"minimum_y":0,"maximum_x":255,"maximum_y":255,"screen_x":0,"screen_y":0}
	assert(preload("res://source_save_store.gd").new(slots.slot_path(4)).write_options(settings).written)
	settings.music=88
	assert(preload("res://source_save_store.gd").new(slots.slot_path(9)).write_options(settings).written)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	root.add_child(world)
	for frame in range(5):await process_frame
	world.set_process(false);world.set_physics_process(false)
	assert(world.source_options_save_path==slots.slot_path(4) and world.source_music_volume==40 and world.source_effects_volume==119 and world.source_options_state.scheme==2)
	assert(world.source_main_mode==2 and world.source_cutscene_progress.scene==0 and world.source_pickup_counts[3]==3 and world.source_menu_progress_flags.is_empty())
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	var file := FileAccess.open(slots.slot_path(4),FileAccess.WRITE);file.store_buffer(PackedByteArray([1,2,3]));file.close()
	world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0);root.add_child(world)
	for frame in range(5):await process_frame
	world.set_process(false);world.set_physics_process(false)
	assert(not world.source_saved_options_error.is_empty() and world.source_music_volume==80 and world.source_effects_volume==127)
	assert(world.source_options_save_path==slots.slot_path(0) and world.source_main_mode==2 and world.source_menu_progress_flags.is_empty())
	assert(FileAccess.get_file_as_bytes(slots.slot_path(4))==PackedByteArray([1,2,3]))
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	for slot in [4,9]:assert(DirAccess.remove_absolute(slots.slot_path(slot))==OK)
	assert(DirAccess.remove_absolute(directory)==OK)
	print("PASS: original startup selects lowest existing save for settings while retaining original opening/fresh campaign")
	quit(0)
