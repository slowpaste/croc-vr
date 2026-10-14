extends SceneTree
func _initialize() -> void:call_deferred("verify")
func press(action: String) -> void:
	Input.action_press(action)
	for frame in range(4):await physics_frame
	Input.action_release(action)
	for frame in range(12):await physics_frame
func verify() -> void:
	var directory := "user://sampled-delete-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var settings := {"scheme":0,"music":80,"effects":127,"mode":1,"center_x":128,"center_y":128,"minimum_x":0,"minimum_y":0,"maximum_x":255,"maximum_y":255,"screen_x":0,"screen_y":0}
	for slot in [1,2]:assert(preload("res://source_save_store.gd").new(slots.slot_path(slot)).write_options(settings).written)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	root.add_child(world)
	for frame in range(20):await physics_frame
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	world.source_main_menu_animation_state=preload("res://source_main_menu.gd").initialize(1,4)
	await press("jump")
	for frame in range(160):
		await physics_frame
		if world.source_main_mode==8 and world.source_fade_phase=="":break
	assert(world.source_main_mode==8)
	await press("move_back");await press("move_back");await press("jump")
	assert(world.source_options_state.page==4)
	# Misc initially selects its final Return row; move to first Delete row.
	for row in range(4):await press("move_forward")
	await press("jump");assert(world.source_main_mode==10)
	await press("move_forward");await press("jump")
	assert(world.source_delete_state.overwrite and FileAccess.file_exists(slots.slot_path(1)))
	await press("jump") # Default NO: keep the record.
	assert(not world.source_delete_state.overwrite and FileAccess.file_exists(slots.slot_path(1)))
	await press("move_forward");await press("jump");await press("move_forward");await press("jump")
	assert(not FileAccess.file_exists(slots.slot_path(1)) and FileAccess.file_exists(slots.slot_path(2)))
	await press("jump") # Default Return after deletion.
	assert(world.source_main_mode==8 and world.source_options_state.pending_action=="" and world.source_transition_fault=="")
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(slots.slot_path(2))==OK and DirAccess.remove_absolute(directory)==OK)
	print("PASS: sampled title/Options/Misc/Delete path, NO preserves selected save, explicit YES deletes only it and Return remains responsive")
	quit(0)
