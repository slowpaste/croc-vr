extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	if not world.enter_source_title_options():quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=2:quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0) or not world.source_options_screen.panel.controller_status.visible:push_error("Unavailable analog controller status missing");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/controller-status-panel.png")!=OK:quit(1);return
	world.stop_imported_audio()
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=2 or world.sound_voices.size()!=1:push_error("Unavailable calibration feedback did not play");quit(1);return
	var feedback=world.sound_voices.back()
	var volume := int(preload("res://source_audio_math.gd").one_shot_volume(15,127,0,false).volume)
	if feedback.player.pitch_register!=2048 or feedback.player.channels!=Vector2i(volume,volume):push_error("Native calibration beep parameters differ");quit(1);return
	if not world.process_source_options(0,0) or world.sound_voices.size()!=1:push_error("Calibration error feedback repeated on idle frame");quit(1);return
	world.source_options_state.navigation.selected=1
	if not world.process_source_options(0,0x80000) or world.source_options_state.scheme!=1:quit(1);return
	if not world.source_options_screen.panel.controller_scheme.visible or world.source_options_screen.panel.controller_status.visible:push_error("Configuration/status visibility differs");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/controller-scheme-panel.png")!=OK:quit(1);return
	world.source_options_state.pad_kind=2
	if not world.process_source_options(0,0) or not world.source_options_screen.panel.controller_status.visible or world.source_options_screen.panel.controller_directions.visible:push_error("Method B analog-unavailable layout differs");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/controller-analog-unavailable.png")!=OK:quit(1);return
	for scheme in [2,0]:
		if not world.process_source_options(0,0x80000) or world.source_options_state.scheme!=scheme or not world.source_options_screen.panel.controller_directions.visible or world.source_options_screen.panel.controller_status.visible:push_error("Analog A/C instructions differ");quit(1);return
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/controller-analog-%d.png"%scheme)!=OK:quit(1);return
	world.source_options_state.scheme=1
	world.source_options_state.pad_kind=1
	for scheme in [2,0,1]:
		if not world.process_source_options(0,0x80000) or world.source_options_state.scheme!=scheme:quit(1);return
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/controller-method-%d.png"%scheme)!=OK:quit(1);return
	world.source_options_state.screen_offset=Vector2i(-3,12)
	world.source_options_state.saved_game_selection=7
	var calibration: Dictionary=world.source_options_state.calibration.duplicate(true)
	world.source_options_state.navigation.selected=2
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=1:quit(1);return
	if not world.process_source_options(0,0x100000):quit(1);return
	if not world.enter_source_title_options():quit(1);return
	if world.source_options_state.scheme!=1 or world.source_options_state.screen_offset!=Vector2i(-3,12) or world.source_options_state.saved_game_selection!=7 or world.source_options_state.calibration!=calibration:push_error("Reopening Options discarded settings");quit(1);return
	if world.source_options_state.page!=1 or world.source_options_state.navigation.selected!=0:push_error("Reopening retained stale submenu navigation");quit(1);return
	if not world.process_source_options(0,0x100000):quit(1);return
	world.source_menu_state.selected_index=0
	if not world.apply_source_menu_launch({}) or world.map_name!="MP010_00.MAP" or world.source_options_state.scheme!=1:push_error("Stage entry discarded controller option");quit(1);return
	world.vr_controls.layout="classic";world.update_source_input(0,0)
	Input.action_press("jump");world.sample_source_player_controls();Input.action_release("jump")
	var expected: int=preload("res://source_input.gd").digital_pad(65535&~0x4000,1,4)
	if world.source_input_held_mask!=expected:push_error("Retained menu scheme did not reach stage input");quit(1);return
	var start_position: Vector3=world.source_player_actor.position
	for tick in range(45):world.tick_source_actors()
	var movement: Vector3=world.source_player_actor.position-start_position
	if not world.source_player_actor.vm.fault.is_empty() or Vector2(movement.x,movement.z).length()<0.1:push_error("Retained scheme did not move original Croc horizontally in stage1");quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: controller scheme survives actual menu change/exit/reopen; screen/calibration/save metadata retained while navigation resets")
	quit(0)
