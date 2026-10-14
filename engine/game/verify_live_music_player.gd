extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	assert(world.enter_source_title_options())
	world.source_options_state.navigation.selected=1
	assert(world.process_source_options(0,0x800000) and world.source_options_state.page==3)
	assert(world.process_source_options(0,0x400) and world.source_options_state.music_player_available)
	world.source_options_state.navigation.selected=3
	assert(world.process_source_options(0,0x800000) and world.source_options_state.page==5,world.source_transition_fault)
	assert(world.process_source_options(0,0x800000))
	assert(world.source_options_state.pending_action=="" and world.source_options_music_backend.playback_state==1)
	for frame in range(200):
		await process_frame
		if world.source_options_music_backend.transport.player.queued_frames>0:break
	assert(world.source_options_music_backend.transport.player.queued_frames>0)
	assert(world.process_source_options(0,0))
	assert(world.source_options_screen.panel.music_track.rendered_labels[0]=="TRACK 1")
	assert(world.source_options_screen.panel.legend.visible)
	for frame in range(5):await process_frame
	await RenderingServer.frame_post_draw
	var preview: Image=world.source_options_screen.panel.output_texture().get_image()
	print("MUSIC_MODEL_PIXEL: ",preview.get_pixel(245,95))
	assert(preview.get_pixel(245,95).r>0.5 and preview.get_pixel(245,95).a>0.1,"Pause model disappeared after redraw")
	assert(preview.save_png("res://../build/music-player-preview.png")==OK)
	assert(world.process_source_options(0,0x800000) and world.source_options_music_backend.playback_state==2)
	world.source_options_state.navigation.selected=2
	assert(world.process_source_options(0,0x800000) and world.source_options_state.track==2 and world.source_options_music_backend.playback_state==2)
	world.source_options_state.navigation.selected=0
	assert(world.process_source_options(0,0x800000) and world.source_options_music_backend.playback_state==1)
	world.source_options_state.navigation.selected=4
	assert(world.process_source_options(0,0x800000) and world.source_options_state.page==3 and world.source_options_state.pending_action=="")
	assert(world.source_options_music_backend.track==11 and world.source_options_music_backend.playback_state==1)
	assert(world.source_options_music_backend.transport.session.current.loop)
	var expected := preload("res://source_music_selection.gd").select(11,false,world.runtime_tables.musicCues.pairs,world.source_options_music_backend.transport.session.bootstrap_bounds)
	assert(world.source_options_music_backend.transport.session.current.stream.logical==expected.logical)
	world.source_options_state.navigation.selected=0
	assert(world.process_source_options(0,0x80000))
	assert(world.source_options_music_backend.transport.player.cd_mix==world.source_cd_mix_state.mix)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: live hidden Music Player renders, acknowledged commands produce XA frames and pause/next/resume/Return stay responsive")
	quit(0)
