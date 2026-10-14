extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var path := "user://saved-options-startup-test-"+str(OS.get_process_id())+".bin"
	assert(not FileAccess.file_exists(path))
	var settings := {"scheme":2,"music":40,"effects":119,"mode":0,"center_x":96,"center_y":128,"minimum_x":0,"minimum_y":0,"maximum_x":192,"maximum_y":255,"screen_x":-8,"screen_y":24}
	assert(preload("res://source_save_store.gd").new(path).write_options(settings).written)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=path
	root.add_child(world)
	for frame in range(5):await process_frame
	world.set_process(false);world.set_physics_process(false)
	assert(world.source_saved_options_error=="" and world.source_music_volume==40 and world.source_effects_volume==119 and world.source_cd_stereo_flag==0)
	assert(world.source_options_state.scheme==2 and world.source_options_state.calibration.center==Vector2i(96,128))
	assert(world.source_options_state.screen_offset==Vector2i(-8,24))
	assert(world.source_main_mode==2 and world.source_cutscene_progress.scene==0)
	assert(world.source_menu_progress_flags.is_empty() and world.source_pickup_counts[3]==3)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	# Corrupt saves keep the original defaults and do not prevent the opening.
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(PackedByteArray([1,2,3]));file.close()
	world=load("res://imported.tscn").instantiate();world.source_options_save_path=path;root.add_child(world)
	for frame in range(5):await process_frame
	world.set_process(false);world.set_physics_process(false)
	assert(not world.source_saved_options_error.is_empty() and world.source_music_volume==80 and world.source_effects_volume==127)
	assert(world.source_main_mode==2 and world.source_cutscene_progress.scene==0)
	assert(FileAccess.get_file_as_bytes(path)==PackedByteArray([1,2,3]))
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(path)==OK)
	print("PASS: startup restores saved options while retaining original opening/fresh progress; corrupt save preserves defaults and opening")
	quit(0)

