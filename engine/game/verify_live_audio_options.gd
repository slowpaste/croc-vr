extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	if not world.enter_source_title_options():push_error(world.source_transition_fault);quit(1);return
	world.source_options_state.navigation=preload("res://source_main_menu.gd").initialize(1,3)
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=3 or world.source_options_pose.slot!=1280:push_error("Audio entry did not retain selected preview");quit(1);return
	world.source_options_state.navigation.selected=0
	var voices_before: int=world.sound_voices.size()
	if not world.process_source_options(0,0x80000) or world.source_music_volume!=88:push_error("Live Audio music option did not change");quit(1);return
	if world.sound_voices.size()!=voices_before+1:push_error("Audio adjustment did not start native SELECT feedback");quit(1);return
	var feedback=world.sound_voices.back()
	var expected_feedback := preload("res://source_audio_math.gd").one_shot_volume(80,127,0,false)
	if feedback.player.pitch_register!=4088 or feedback.player.channels!=Vector2i(int(expected_feedback.volume),int(expected_feedback.volume)):push_error("SELECT feedback pitch or centered channels differ");quit(1);return
	for tick in range(2):
		if not world.process_source_options(0,0):quit(1);return
	if world.source_options_pose.slot!=1256:push_error("Music preview slot differs");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/audio-options-panel.png")!=OK:quit(1);return
	for step in range(11):
		if not world.process_source_options(0,0x20000):quit(1);return
	if world.source_music_volume!=0 or not world.source_options_screen.panel.mute.visible:push_error("Music zero volume did not display MUTE");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var muted_image: Image = world.source_options_screen.panel.output_texture().get_image()
	var white_pixels := 0
	for y in range(147,160):
		for x in range(236,276):
			var pixel := muted_image.get_pixel(x,y)
			if pixel.g>0.8 and pixel.b>0.8:white_pixels+=1
	if white_pixels<10:push_error("Enabled MUTE label was obscured in the rendered panel");quit(1);return
	if muted_image.save_png("res://../build/audio-mute-panel.png")!=OK:quit(1);return
	for step in range(11):
		if not world.process_source_options(0,0x80000):quit(1);return
	if world.source_music_volume!=88 or world.source_options_screen.panel.mute.visible:push_error("Music volume restore retained MUTE");quit(1);return
	world.source_options_state.navigation.selected=1
	if not world.process_source_options(0,0x20000) or world.source_effects_volume!=120 or world.source_audio_master_maximum!=119:push_error("Live effects helper/display levels differ");quit(1);return
	for tick in range(2):
		if not world.process_source_options(0,0):quit(1);return
	if world.source_options_pose.slot!=1276:push_error("Effects preview slot differs");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/audio-effects-panel.png")!=OK:quit(1);return
	world.source_options_state.navigation.selected=2
	for mode in [1,2,0]:
		if world.source_cd_stereo_flag!=mode:
			if not world.process_source_options(0,0x80000):quit(1);return
		for tick in range(2):
			if not world.process_source_options(0,0):quit(1);return
		if world.source_options_pose.slot!=[1288,1292,1300][mode]:push_error("Audio mode preview does not match live mode");quit(1);return
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/audio-mode-%d.png"%mode)!=OK:quit(1);return
	world.stop_imported_audio()
	if not world.process_source_options(0,0xa0000) or world.source_cd_stereo_flag!=0 or world.source_effects_volume!=120:push_error("Combined mode adjustment changed final options");quit(1);return
	if world.sound_voices.size()!=2:push_error("Combined adjustment did not emit two ordered SELECT voices");quit(1);return
	var level := int(preload("res://source_audio_math.gd").one_shot_volume(80,120,0,false).volume)
	if world.sound_voices[0].player.channels!=Vector2i(level>>1,level>>1) or world.sound_voices[1].player.channels!=Vector2i(level,level):push_error("Combined feedback lost mode2 then mode0 routing");quit(1);return
	world.source_options_state.navigation.selected=3
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=1 or world.source_effects_restore_volume!=120:push_error("Audio Back did not retain effects restore option");quit(1);return
	if not world.process_source_options(0,0x100000) or world.source_main_mode!=1 or world.source_music_volume!=88 or world.source_effects_volume!=120:quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: live Audio entry preview, music/effects adjustments, native119/display120, Back restore snapshot and retained options after title return")
	quit(0)
