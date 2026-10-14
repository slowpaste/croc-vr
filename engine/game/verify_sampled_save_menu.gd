extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var directory := "user://sampled-save-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	world.source_menu_state.selected_index=12
	root.add_child(world)
	for frame in range(20):await physics_frame
	world.source_menu_state.selected_index=12;world.source_pickup_counts[3]=7
	world.source_menu_progress_flags={0:0x8006,4:0x8000}
	for row in range(2):
		Input.action_press("move_back")
		for frame in range(4):await physics_frame
		Input.action_release("move_back")
		for frame in range(12):await physics_frame
	assert(world.source_menu_state.dialog_mode==2 and world.source_main_menu_text.visible,"Selector state "+str(world.source_menu_state)+" action="+str(world.source_selector_action_state)+" mode="+str(world.source_main_mode))
	Input.action_press("jump")
	for frame in range(4):await physics_frame
	Input.action_release("jump")
	for frame in range(180):
		await physics_frame
		if world.source_main_mode==11 and world.source_fade_phase=="":break
	assert(world.source_main_mode==11 and world.source_load_screen.visible)
	Input.action_press("jump")
	for frame in range(4):await physics_frame
	Input.action_release("jump")
	for frame in range(180):
		await physics_frame
		if world.source_main_mode==5:break
	assert(world.source_main_mode==5 and world.map_name=="MP100_02.MAP" and world.source_transition_fault=="")
	var saved := preload("res://source_save_store.gd").new(slots.slot_path(1)).read_record()
	assert(saved.has("record"))
	var state := preload("res://source_campaign_save.gd").decode(saved.record)
	assert(state.lives==7 and state.selection==12 and state.flags[0]==0x8006 and state.level==22 and state.room==0)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(slots.slot_path(1))==OK and DirAccess.remove_absolute(directory)==OK)
	print("PASS: sampled selector down/down/confirm opens Save, confirm persists new campaign and automatically returns to selector")
	quit(0)
