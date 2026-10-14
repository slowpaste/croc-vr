extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	assert(world.initialize_source_stage_stats())
	var music: Node=world.source_gameplay_music;music.automatic=false
	assert(music.running and music.transport.session.current.cue==64 and not music.transport.session.current.loop and music.transport.session.current.seek_mode==0)
	assert(world.load_room("MP090_00.MAP"));world.enter_source_main_menu()
	var menu: Node=world.source_options_music_backend;menu.set_process(false)
	assert(menu.playback_state==1 and menu.track==11 and menu.transport.session.current.loop and menu.transport.session.current.mode==1)
	var expected: Dictionary=preload("res://source_music_selection.gd").select(11,false,world.runtime_tables.musicCues.pairs,menu.transport.session.bootstrap_bounds)
	assert(menu.transport.session.current.logical==expected.logical)
	world.source_menu_state.dialog_mode=1;assert(world.enter_source_title_options())
	world.source_options_state.navigation.selected=1;assert(world.process_source_options(0,0x800000))
	assert(world.process_source_options(0,0x400));world.source_options_state.navigation.selected=3
	assert(world.process_source_options(0,0x800000) and int(world.source_options_state.page)==5 and menu.playback_state==0)
	assert(world.process_source_options(0,0x800000) and menu.playback_state==1 and menu.track==1)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: level results start original cue64 without loop/resume; main menu starts primary looping11; Music Player entry stops menu music and Play starts1")
	quit(0)
