extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	if not world.enter_source_title_options(2):quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0x800000):quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=6:quit(1);return
	if not world.process_source_options(0,0x800000,Vector2i(128,128)) or world.source_options_state.capture.phase!=1:quit(1);return
	for point in [Vector2i(0,128),Vector2i(255,128),Vector2i(128,0),Vector2i(128,255)]:
		if not world.process_source_options(0,0,point):quit(1);return
	if not world.process_source_options(0,0x800000,Vector2i(128,128)) or world.source_options_state.page!=2:quit(1);return
	var calibration: Dictionary=world.source_options_state.calibration.duplicate(true)
	if not world.process_source_options(0,0,Vector2i(128,128)) or not world.source_options_screen.panel.notice.visible:push_error("Calibration success notice missing");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/calibration-success.png")!=OK:quit(1);return
	if calibration.center!=Vector2i(128,128) or calibration.minimum!=Vector2i.ZERO or calibration.maximum!=Vector2i(255,255):push_error("Committed original calibration differs");quit(1);return
	Input.action_press("move_left")
	var left_sample: Vector2i=world.source_options_pad_sample();Input.action_release("move_left")
	Input.action_press("move_right")
	var right_sample: Vector2i=world.source_options_pad_sample();Input.action_release("move_right")
	if left_sample!=Vector2i(0,128) or right_sample!=Vector2i(255,128) or world.source_options_pad_sample()!=Vector2i(128,128):push_error("Virtual pad-byte endpoints differ");quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0x800000):quit(1);return
	if not world.process_source_options(0,0x100000,Vector2i(0,0)) or world.source_options_state.page!=2 or world.source_options_state.calibration!=calibration:push_error("Calibration cancel changed committed values");quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0x800000):quit(1);return
	if not world.process_source_options(0,0x800000,Vector2i(128,128)) or not world.process_source_options(0,0x800000,Vector2i(128,128)):quit(1);return
	if int(world.source_options_state.calibration.status)!=-1 or world.source_options_state.calibration.minimum!=Vector2i.ZERO or world.source_options_state.calibration.maximum!=Vector2i(255,255):push_error("Failed calibration did not restore original defaults");quit(1);return
	if not world.process_source_options(0,0) or not world.source_options_screen.panel.notice.visible:quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/calibration-failure.png")!=OK:quit(1);return
	for tick in range(149):
		if not world.process_source_options(0,0) or not world.source_options_screen.panel.notice.visible:push_error("Failure notice ended before150 controller ticks");quit(1);return
	if world.source_options_state.calibration_notice_counter!=0:push_error("Failure notice counter did not expire");quit(1);return
	if not world.process_source_options(0,0) or world.source_options_screen.panel.notice.visible:push_error("Expired calibration notice remained visible");quit(1);return
	world.source_options_state.calibration_notice_counter=1
	world.source_options_state.navigation.selected=1
	if not world.process_source_options(0,0) or world.source_options_state.calibration_notice_counter!=0 or not world.source_options_screen.panel.notice.visible:push_error("Configuration did not clear notice after its last draw");quit(1);return
	if not world.process_source_options(0,0) or world.source_options_screen.panel.notice.visible:quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: live calibration route captures center/extrema, commits original normalization and cancels without altering prior calibration")
	quit(0)
