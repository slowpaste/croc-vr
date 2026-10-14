extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false); world.set_process(false)
	world.source_pickup_counts[3] = 0
	assert(world.enter_source_game_over())
	world.update_source_input(0x40000,0)
	assert(world.process_source_game_over() and world.source_menu_state.dialog_mode == 1)
	world.update_source_input(0x800000,0x800000)
	assert(world.process_source_game_over() and world.source_fade_phase == "game-over-out")
	for tick in range(13): assert(world.advance_source_transition())
	assert(world.source_main_mode == 6 and world.source_fade_phase == "" and world.source_cutscene_screen.session.player.fade.kind == 1)
	var display = world.source_cutscene_screen
	assert(display.session.audio.stream.cd_mix == [80,80,0,0])
	var before: int = world.source_tick_count
	for tick in range(6): world._physics_process(1.0/60.0)
	var sector: int = display.session.timeline.clock.clock.cursor
	var frame: int = display.session.player.last_index
	assert(display.session.audio.started)
	assert(world.source_audio_master_gain > 0 and display.session.audio.stream.cd_mix == [80,80,0,0])
	world.vr_settings.toggle()
	world._physics_process(1.0)
	assert(display.session.timeline.clock.clock.cursor == sector and display.session.player.last_index == frame and display.session.audio.stream.stream_paused)
	assert(world.source_cutscene_progress.paused and world.source_cutscene_progress.presented_index == frame)
	world.vr_settings.toggle()
	for tick in range(700):
		assert(world.process_source_sad_cutscene(1.0/60.0))
		if world.source_main_mode != 6: break
	assert(world.source_main_mode == 0 and world.map_name == "MP090_00.MAP" and world.source_cutscene_screen == null)
	assert(world.source_cutscene_progress.complete and world.source_cutscene_progress.presented_index == 290)
	assert(world.source_pickup_counts[3] == 0 and world.source_tick_count == before)
	assert(world.source_fade_phase == "in" and world.source_fade_state.kind == 7)
	assert(world.enter_source_game_over())
	world.update_source_input(0x40000,0)
	assert(world.process_source_game_over())
	world.update_source_input(0x800000,0x800000)
	assert(world.process_source_game_over())
	for tick in range(13): assert(world.advance_source_transition())
	display = world.source_cutscene_screen
	Input.action_press("jump")
	for tick in range(6): assert(world.process_source_sad_cutscene(1.0/60.0))
	assert(not display.session.player.flow.ending and world.source_main_mode == 6)
	var skip_frames := 0
	for tick in range(100):
		assert(world.process_source_sad_cutscene(1.0/60.0))
		if world.source_main_mode != 6: break
		skip_frames = display.session.player.last_index
	Input.action_release("jump")
	assert(world.source_main_mode == 0 and skip_frames < 100)
	world.queue_free(); await process_frame
	await create_timer(0.1).timeout
	print("PASS: Continue NO enters SAD20 with original mix, pauses gameplay actors and returns title0/incoming7 without life reset")
	quit(0)
