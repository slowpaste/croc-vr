extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var music: Node=world.source_gameplay_music;music.automatic=false
	var filter := preload("res://source_xa_zigzag.gd").new()
	# Controlled seek to the final real packet exercises completion without
	# waiting through the soundtrack; it does not qualify hardware seek history.
	music.transport.session.current.start_sector=int(music.transport.session.current.end_sector)-8
	assert(not music.transport.seek_read([[0,0],[0,0]],filter.snapshot()).has("fault"))
	for frame in range(300):
		assert(not music.pump().has("fault"));await process_frame
		if not music.running:break
	assert(not music.running and int(music.transport.session.current.completion_pending)==1)
	assert(int(music.transport.session.rooms[0].variant)==1 and music.completed_frame>=0)
	var completed: int=music.completed_frame;music.automatic=true
	world.source_frame_clock.counter=completed+1500;music._process(0)
	assert(not music.running,"Original replay delay is strict >1500")
	world.source_frame_clock.counter=completed+1501;music._process(0)
	assert(music.running and int(music.transport.session.current.variant)==1)
	assert(world.load_room("MP017_02.MAP"));assert(world.create_source_player()!=null)
	music.automatic=false;assert(music.transport.session.current.loop)
	music.transport.session.current.start_sector=int(music.transport.session.current.end_sector)-8
	assert(not music.transport.seek_read([[0,0],[0,0]],filter.snapshot()).has("fault"))
	var seeks: int=music.transport.session.current.seek_phase
	for frame in range(300):
		assert(not music.pump().has("fault"));await process_frame
		if int(music.transport.session.current.seek_phase)>seeks:break
	assert(music.running and int(music.transport.session.current.seek_phase)>seeks and music.completed_frame<0)
	world.hide_source_cinematic_world();assert(not music.running and music.transport.player.playback==null)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: real final XA packet produces non-loop completion/variant change and strict1500-frame replay delay; authored boss-room loop seeks again; cinematic entry stops music. Controlled seek/clock, hardware timing/history unqualified")
	quit(0)
