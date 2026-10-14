extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var directory := "user://live-load-menu-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../reference/original-campaign-save.json")))
	var record := PackedByteArray();record.resize(256)
	for word in range(64):record.encode_u32(word*4,int(capture.rows[0].words[word]))
	assert(preload("res://source_save_store.gd").new(slots.slot_path(3)).write_copies(record+record).written)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=2
	assert(world.process_source_main_menu_confirmation(0x800000))
	assert(world.source_fade_phase=="load-menu-out" and world.source_fade_state.kind==12)
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition(),world.source_transition_fault)
	assert(world.source_main_mode==9 and world.source_load_screen.visible and world.source_load_state.slots[0].slot==3)
	assert(world.process_source_load_menu(0,0x100000) and world.source_main_mode==1 and world.source_menu_state.dialog_mode==2)
	assert(world.process_source_main_menu_confirmation(0x800000))
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	assert(world.process_source_load_menu(0,0x800000) and world.source_main_mode==9)
	assert(world.process_source_load_menu(0,0) and world.source_main_mode==5 and world.map_name=="MP100_02.MAP")
	assert(world.source_pickup_counts[3]==27 and world.source_menu_state.selected_index==12 and not world.source_load_screen.visible)
	assert(world.source_options_save_path==slots.slot_path(3))
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(slots.slot_path(3))==OK and DirAccess.remove_absolute(directory)==OK)
	print("PASS: title Load Game fade/entry/cancel/re-entry, deferred selected-slot load restores original island selector/progress")
	quit(0)
