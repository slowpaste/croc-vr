extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var backend=preload("res://source_options_music_backend.gd").new();root.add_child(backend)
	backend.set_process(false)
	assert(not backend.execute(world,1,["play"]).has("fault"))
	var player=backend.transport.player
	for frame in range(120):
		await process_frame
		if player.get_playback_position()>0.05:break
	assert(player.queued_frames==0 and player.get_playback_position()>0.05)
	assert(player.playback.get_skips()>0)
	backend.stop_track();backend.queue_free();world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: runtime generator position advances during silent underrun with zero queued XA frames; unsuitable as source CD cursor")
	quit(0)
