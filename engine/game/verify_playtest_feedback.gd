extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_pickup_counts[3]=7;world.source_menu_progress_flags={0:0x8006}
	assert(world.enter_source_title_options(1,4))
	world.source_options_state.navigation.selected=3
	assert(world.process_source_options(0,0x800000))
	assert(world.source_main_mode==0 and not world.source_controller_enabled and world.map_name=="MP090_00.MAP","Return to Main Menu resumed the level")
	assert(world.source_pickup_counts[3]==7 and world.source_menu_progress_flags[0]==0x8006,"Returning erased campaign progress")
	world.source_main_mode=4
	assert(world.enter_source_title_options(1,4))
	assert(world.process_source_options(0,0x100000) and world.source_main_mode==4 and world.source_controller_enabled,"Back failed to resume gameplay")
	world.xr_active=true;world.source_main_mode=5;world.source_menu_state.selected_index=0;world.source_menu_state.dialog_mode=0;world.source_menu_state.save_mode=0
	assert(world.advance_source_selector_actions(0,0))
	world.update_source_level_title(0)
	assert(world.source_level_title.position.is_equal_approx(world.source_main_menu_text.position))
	assert(world.source_level_title.scale.is_equal_approx(world.source_main_menu_text.scale),"Selector title and actions have different physical planes")
	world.xr_active=false
	world.source_main_mode=2;world.hide_source_cinematic_world()
	world.update_source_level_title(0);world.update_source_gameplay_hud()
	world.camera.rotation=Vector3.ZERO
	var movie=preload("res://source_startup_movie.gd").new();root.add_child(movie)
	var done:Dictionary={"finished":false};movie.finished.connect(func():done.finished=true)
	movie.setup(world.camera,80)
	assert(movie.video.stream is VideoStreamTheora)
	var deadline:=Time.get_ticks_msec()+15000
	var captured:=false
	while not done.finished and Time.get_ticks_msec()<deadline:
		await process_frame
		if not captured and movie.video.stream_position>4.0 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var image:Image=movie.video.get_video_texture().get_image()
			assert(not image.is_empty() and image.get_width()==320)
			image.save_png("res://../build/argonaut-movie-frame.png")
			root.get_texture().get_image().save_png("res://../build/argonaut-movie-preview.png")
			captured=true
	assert(done.finished,"Original Argonaut movie did not complete")
	assert(movie.video.get_video_texture().get_width()==320)
	movie.queue_free();world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: pause confirm returns to title without erasing progress; Back resumes; selector title/actions share a plane; original 320x240 Argonaut movie plays to completion")
	quit(0)
