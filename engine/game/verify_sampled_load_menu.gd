extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var directory := "user://sampled-load-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../reference/original-campaign-save.json")))
	for index in range(2):
		var record := PackedByteArray();record.resize(256)
		for word in range(64):record.encode_u32(word*4,int(capture.rows[index].words[word]))
		assert(preload("res://source_save_store.gd").new(slots.slot_path(3 if index==0 else 9)).write_copies(record+record).written)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	root.add_child(world)
	for frame in range(20):await physics_frame
	world.source_main_mode=1;world.source_menu_state.dialog_mode=2
	world.source_main_menu_animation_state=preload("res://source_main_menu.gd").initialize(2,4)
	Input.action_press("jump")
	for frame in range(4):await physics_frame
	Input.action_release("jump")
	for frame in range(180):
		await physics_frame
		if world.source_main_mode==9 and world.source_fade_phase=="":break
	assert(world.source_main_mode==9 and world.source_load_screen.visible)
	Input.action_press("move_right")
	for frame in range(4):await physics_frame
	Input.action_release("move_right")
	for frame in range(4):await physics_frame
	assert(world.source_load_state.slot==1)
	Input.action_press("jump")
	for frame in range(4):await physics_frame
	Input.action_release("jump")
	for frame in range(30):
		await physics_frame
		if world.source_main_mode==5:break
	assert(world.source_main_mode==5 and world.map_name=="MP100_05.MAP" and world.source_menu_state.selected_index==44)
	assert(world.source_pickup_counts[3]==27 and world.source_transition_fault=="")
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	for slot in [3,9]:assert(DirAccess.remove_absolute(slots.slot_path(slot))==OK)
	assert(DirAccess.remove_absolute(directory)==OK)
	print("PASS: sampled title confirm, Load right-slot navigation and confirm restore second saved campaign selector; seeded fixture only")
	quit(0)
