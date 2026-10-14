extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var directory := "user://delete-menu-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var record := preload("res://source_save_record.gd").new_record()
	var settings := {"scheme":0,"music":80,"effects":127,"mode":1,"center_x":128,"center_y":128,"minimum_x":0,"minimum_y":0,"maximum_x":255,"maximum_y":255,"screen_x":0,"screen_y":0}
	record=preload("res://source_save_record.gd").patch_options(record,settings).record
	for slot in [1,2]:assert(preload("res://source_save_store.gd").new(slots.slot_path(slot)).write_copies(record+record).written)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	assert(world.enter_source_title_options())
	world.source_options_state.navigation.selected=2
	assert(world.process_source_options(0,0x800000) and world.source_options_state.page==4)
	world.source_options_state.navigation.selected=0
	assert(world.process_source_options(0,0x800000) and world.source_main_mode==10 and world.source_options_state.pending_action=="")
	assert(world.source_delete_state.navigation.selected==1)
	assert(world.process_source_delete_menu(0,0x10000) and world.process_source_delete_menu(0,0x800000))
	assert(world.source_delete_state.overwrite and world.source_delete_state.navigation.selected==1)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	assert(world.source_load_screen.panel.output.get_texture().get_image().save_png("res://../build/delete-confirmation-preview.png")==OK)
	assert(FileAccess.file_exists(slots.slot_path(1)))
	assert(world.process_source_delete_menu(0,0x800000) and not world.source_delete_state.overwrite)
	assert(world.process_source_delete_menu(0,0x10000) and world.process_source_delete_menu(0,0x800000))
	assert(world.process_source_delete_menu(0,0x10000) and world.process_source_delete_menu(0,0x800000))
	assert(FileAccess.file_exists(slots.slot_path(1)))
	assert(world.process_source_delete_menu(0,0) and not FileAccess.file_exists(slots.slot_path(1)) and FileAccess.file_exists(slots.slot_path(2)))
	assert(world.process_source_delete_menu(0,0x100000) and world.source_main_mode==8 and world.source_options_state.page==4)
	assert(world.process_source_options(0,0))
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(slots.slot_path(2))==OK and DirAccess.remove_absolute(directory)==OK)
	print("PASS: live Misc Delete enters mode10 without pending freeze, defaults Return/NO, explicit YES removes selected slot only and returns Options")
	quit(0)
