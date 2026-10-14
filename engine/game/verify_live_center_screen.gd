extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	assert(world.enter_source_title_options())
	world.source_options_state.navigation.selected=2
	assert(world.process_source_options(0,0x800000))
	world.source_options_state.navigation.selected=3
	assert(world.process_source_options(0,0x800000) and world.source_options_state.page==7)
	assert(world.source_options_screen.panel.text.rendered_labels[0]=="Use directional buttons")
	for tick in range(30):assert(world.process_source_options(0xa0000,0))
	assert(world.source_options_state.screen_offset==Vector2i.ZERO)
	for tick in range(40):assert(world.process_source_options(0xc0000,0))
	assert(world.source_options_state.screen_offset==Vector2i(24,24))
	assert(world.process_source_options(0,0x800000) and world.source_options_state.page==4 and world.source_options_state.navigation.selected==3)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: Center Screen page/instructions/native held offset limits/Return remain responsive; global display shift not qualified")
	quit(0)
