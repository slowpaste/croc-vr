extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world)
	for frame in range(20):await physics_frame
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	world.source_main_menu_animation_state=preload("res://source_main_menu.gd").initialize(1,4)
	Input.action_press("jump")
	for frame in range(4):await physics_frame
	Input.action_release("jump")
	for frame in range(160):
		await physics_frame
		if world.source_main_mode==8 and world.source_fade_phase=="":break
	if world.source_main_mode!=8 or not world.source_options_screen.visible:push_error("Sampled confirm did not enter Options");quit(1);return
	for row in range(3):
		Input.action_press("move_back")
		for frame in range(10):await physics_frame
		Input.action_release("move_back")
		for frame in range(10):await physics_frame
	if world.source_options_state.navigation.selected!=3:push_error("Sampled Options navigation did not reach Return");quit(1);return
	Input.action_press("jump")
	for frame in range(4):await physics_frame
	Input.action_release("jump")
	if world.source_main_mode!=1 or world.source_menu_state.dialog_mode!=1 or not world.source_transition_fault.is_empty():push_error("Sampled Return did not restore title menu");quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: sampled confirm enters Options, three down presses select Return, confirm restores main-menu Options selection")
	quit(0)
