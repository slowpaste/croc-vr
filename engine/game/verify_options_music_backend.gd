extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var backend=preload("res://source_options_music_backend.gd").new();root.add_child(backend)
	var result := backend.execute(world,1,["play"])
	assert(not result.has("fault") and backend.playback_state==1)
	assert(backend.transport.session.current.stream.logical==world.runtime_tables.musicCues.mode8.channels[1])
	for frame in range(200):
		await process_frame
		if backend.transport.player.queued_frames>0:break
	assert(backend.transport.player.queued_frames>0 and backend.transport.player.stream_fault=="")
	assert(backend.execute(world,1,["pause"]).state==2 and backend.transport.player.stream_paused)
	assert(backend.execute(world,1,["resume"]).state==1 and not backend.transport.player.stream_paused)
	assert(backend.execute(world,64,["stop","play","pause"]).state==2 and backend.track==64)
	assert(backend.transport.session.current.stream.logical==world.runtime_tables.musicCues.mode8.channels[64])
	assert(backend.execute(world,64,["stop"]).state==0)
	assert(backend.execute(world,0,["play"]).has("fault"))
	assert(backend.execute(world,1,["invalid"]).has("fault"))
	backend.queue_free();world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: Music Player backend uses original mode8 XA mapping, real accepted stream, pause/resume/stop and paused track changes")
	quit(0)
