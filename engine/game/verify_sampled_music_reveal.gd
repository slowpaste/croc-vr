extends SceneTree
func _initialize() -> void:call_deferred("verify")
func press(action: String) -> void:
	Input.action_press(action)
	for frame in range(4):await physics_frame
	Input.action_release(action)
	for frame in range(12):await physics_frame
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world)
	for frame in range(20):await physics_frame
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	world.source_main_menu_animation_state=preload("res://source_main_menu.gd").initialize(1,4)
	await press("jump")
	for frame in range(160):
		await physics_frame
		if world.source_main_mode==8 and world.source_fade_phase=="":break
	await press("move_back");await press("jump")
	assert(world.source_options_state.page==3 and not world.source_options_state.music_player_available)
	await press("source_select")
	assert(world.source_options_state.music_player_available and world.source_options_state.navigation.selected==4)
	await press("move_forward");await press("jump")
	assert(world.source_options_state.page==5 and world.source_transition_fault=="")
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: sampled desktop Select reveals Music Player, retains Back selection and normal navigation/confirm enters page5")
	quit(0)
