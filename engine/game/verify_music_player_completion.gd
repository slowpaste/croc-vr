extends SceneTree
func _initialize() -> void:call_deferred("verify")
func finish_track(backend: Node) -> void:
	var previous: int=backend.track
	backend.transport.session.current.start_sector=int(backend.transport.session.current.end_sector)-8
	var filter := preload("res://source_xa_zigzag.gd").new()
	assert(not backend.transport.seek_read([[0,0],[0,0]],filter.snapshot()).has("fault"))
	for frame in range(300):
		backend._process(0);assert(backend.fault.is_empty(),backend.fault);await process_frame
		if int(backend.track)!=previous:break
	assert(int(backend.track)!=previous,"Music Player did not advance at real cue boundary")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.enter_source_main_menu();world.source_menu_state.dialog_mode=1
	assert(world.enter_source_title_options())
	world.source_options_state.navigation.selected=1
	assert(world.process_source_options(0,0x800000))
	assert(world.process_source_options(0,0x400))
	world.source_options_state.navigation.selected=3
	assert(world.process_source_options(0,0x800000) and int(world.source_options_state.page)==5)
	world.source_options_state.track=64
	assert(world.process_source_options(0,0x800000))
	var backend: Node=world.source_options_music_backend;backend.set_process(false)
	await finish_track(backend)
	assert(backend.track==1 and backend.playback_state==1)
	assert(world.process_source_options(0,0) and world.source_options_state.track==1)
	assert(world.source_options_screen.panel.music_track.rendered_labels[0]=="TRACK 1")
	await finish_track(backend)
	assert(backend.track==2 and world.process_source_options(0,0) and world.source_options_state.track==2)
	assert(world.source_options_screen.panel.music_track.rendered_labels[0]=="TRACK 2")
	assert(not backend.pause_track().has("fault"))
	var cursor: int=backend.transport.session.current.cursor
	for frame in range(10):backend._process(0);await process_frame
	assert(backend.track==2 and backend.transport.session.current.cursor==cursor)
	assert(not backend.resume_track().has("fault"))
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: real final-packet receipt advances Music Player64→1→2 and refreshes rendered track label; pause freezes receipt callbacks. Controlled seek, hardware timing/history unqualified")
	quit(0)
