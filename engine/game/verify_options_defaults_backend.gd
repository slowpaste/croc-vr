extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	if not world.enter_source_title_options():quit(1);return
	world.source_options_state.navigation.selected=2
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=4:quit(1);return
	world.source_options_state.scheme=2;world.source_options_state.screen_offset=Vector2i(12,-3)
	world.source_options_state.saved_game_selection=7
	world.source_music_volume=0;world.source_effects_volume=0;world.source_cd_stereo_flag=2
	world.source_options_state.navigation.selected=2
	if not world.process_source_options(0,0x800000):push_error(world.source_transition_fault);quit(1);return
	var state: Dictionary=world.source_options_state
	if state.pending_action!="" or state.reset_notice_ticks!=30 or state.scheme!=0 or state.screen_offset!=Vector2i.ZERO or state.saved_game_selection!=0 or world.source_music_volume!=80 or world.source_effects_volume!=127 or world.source_cd_stereo_flag!=1 or world.source_cd_mix_state.mix!=[80,80,0,0]:push_error("Live defaults reset left stale values or pending action");quit(1);return
	if not world.process_source_options(0,0) or world.source_options_state.reset_notice_ticks!=29:quit(1);return
	if not world.source_options_screen.panel.notice.visible:push_error("Reset notice was not rendered");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/options-reset-notice.png")!=OK:quit(1);return
	for tick in range(29):
		if not world.process_source_options(0,0) or not world.source_options_screen.panel.notice.visible:push_error("Reset notice ended before30 native ticks");quit(1);return
	if world.source_options_state.reset_notice_ticks!=0:push_error("Reset notice counter did not reach zero");quit(1);return
	if not world.process_source_options(0,0) or world.source_options_screen.panel.notice.visible:push_error("Reset notice remained beyond30 native ticks");quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: actual Misc defaults action applies original audio/controller/screen values, clears pending request and advances notice")
	quit(0)
