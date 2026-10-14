extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=4
	world.source_pickup_counts[3]=7;world.source_menu_progress_flags={0:0x8006}
	assert(world.process_source_main_menu_confirmation(0x800000) and world.source_fade_phase=="show-intro-out" and world.source_fade_state.kind==5)
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	var deadline:=Time.get_ticks_msec()+60000
	while world.source_sequence_loading and Time.get_ticks_msec()<deadline:
		world._process(0)
		await process_frame
	assert(not world.source_sequence_loading,"Intro preparation did not complete")
	assert(world.source_main_mode==2 and world.source_cutscene_progress.scene==0 and is_instance_valid(world.source_cutscene_screen))
	assert(world.source_pickup_counts[3]==7 and world.source_menu_progress_flags[0]==0x8006)
	assert(not is_instance_valid(world.source_options_music_backend) or world.source_options_music_backend.playback_state==0,"Menu audio overlapped intro")
	Input.action_press("jump")
	for tick in range(100):
		if world.source_main_mode!=2:break
		assert(world.process_source_sad_cutscene(1.0/30.0),world.source_transition_fault)
		await process_frame
	Input.action_release("jump")
	assert(world.source_main_mode==0 and not is_instance_valid(world.source_cutscene_screen) and world.terrain.visible and world.source_transition_fault=="")
	assert(world.source_pickup_counts[3]==7 and world.source_menu_progress_flags[0]==0x8006)
	assert(not world.source_opening_preparation.is_empty())
	var replay_started:=Time.get_ticks_msec()
	assert(world.enter_source_opening())
	assert(not world.source_sequence_loading and is_instance_valid(world.source_cutscene_screen),"Replay repeated the opening preparation delay")
	assert(Time.get_ticks_msec()-replay_started<2500,"Prepared opening replay still blocked the display")
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: title Show Intro enters original scene0, sampled confirm skips through live cinematic dispatch and restores title without resetting campaign")
	quit(0)
