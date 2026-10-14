extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var music: Node=world.source_gameplay_music;assert(is_instance_valid(music));music.automatic=false
	assert(world.map_name=="MP010_00.MAP")
	var started: Dictionary=music.start_room(world)
	assert(started.playing and started.cue==37 and started.seek_mode==128 and not started.loop,"Original first-room request differs")
	var receipts := 0
	for frame in range(30):
		var pumped: Dictionary=music.pump();assert(not pumped.has("fault"));receipts+=pumped.get("packet_receipts",[]).size();await process_frame
	assert(music.transport.player.queued_frames>0 and music.transport.player.playback!=null)
	assert(music.transport.session.current.cursor==music.transport.session.current.start_sector+receipts*8,"Cursor must advance only from explicit local packet receipt callbacks")
	music.stop_room();assert(not music.running and music.transport.player.playback==null)
	var bookmark: int=music.transport.session.rooms[0].start
	assert(bookmark>0)
	world.source_transition_state=2
	assert(world.load_room("MP010_03.MAP"))
	assert(world.create_source_player()!=null)
	assert(music.running and music.transport.session.current.cue==14 and music.transport.session.current.seek_mode==128)
	for frame in range(30):
		assert(not music.pump().has("fault"));await process_frame
	assert(music.transport.player.queued_frames>0)
	assert(world.load_room("MP010_00.MAP") and world.create_source_player()!=null)
	assert(music.transport.session.current.start_sector==bookmark,"Same-level return must preserve the room bookmark")
	world.source_transition_state=0
	assert(world.load_room("MP011_00.MAP") and world.create_source_player()!=null)
	assert(music.transport.session.rooms.is_empty() and music.transport.session.current.start_sector==music.transport.session.current.pack_start,"Fresh-level load must reset native room music state")
	world.stop_imported_audio();assert(not music.running and music.transport.player.playback==null);world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: world player creation starts first-room cue37/resume128 and underground cue14; local packet receipts advance eight-sector callbacks, audio teardown stops playback; hardware CD timing/history parity remains pending")
	quit(0)
