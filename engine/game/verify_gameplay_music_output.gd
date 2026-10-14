extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var music: Node=world.source_gameplay_music;assert(is_instance_valid(music) and music.running)
	var bus_index := AudioServer.bus_count
	var bus_name := "CrocMusicCapture"+str(OS.get_process_id())
	AudioServer.add_bus();AudioServer.set_bus_name(bus_index,bus_name)
	var capture := AudioEffectCapture.new();capture.buffer_length=0.1
	AudioServer.add_bus_effect(bus_index,capture)
	music.transport.player.bus=bus_name
	var peak := 0.0;var captured := 0
	for tick in range(300):
		await create_timer(0.01).timeout
		assert(music.fault.is_empty(),music.fault)
		var frames := capture.get_frames_available()
		if frames>0:
			var pcm := capture.get_buffer(frames);captured+=pcm.size()
			for sample in pcm:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		if peak>0.0001 and captured>1000:break
	assert(captured>1000 and peak>0.0001,"Gameplay soundtrack produced no mixer signal")
	world.stop_imported_audio();world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	AudioServer.remove_bus(bus_index);assert(AudioServer.bus_count==bus_index)
	print("PASS: automatically started cue37 reaches audio mixer; captured_frames=",captured," peak=",peak,". This is local mixer output, not physical headset listening or native waveform parity")
	quit(0)
