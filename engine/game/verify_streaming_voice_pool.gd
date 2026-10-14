extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.camera.global_transform = Transform3D.IDENTITY
	world.source_cd_stereo_flag = 1
	var right: Dictionary = world.source_sound_channels(Vector3(world.CELL_METERS,0,0),1000)
	var left: Dictionary = world.source_sound_channels(Vector3(-world.CELL_METERS,0,0),1000)
	if right.left!=0 or right.right!=2000 or left.left!=2000 or left.right!=0:push_error("Listener orientation reversed source stereo sides");quit(1);return
	world.source_cd_stereo_flag = 0
	var mono: Dictionary = world.source_sound_channels(Vector3(world.CELL_METERS,0,0),1000)
	if mono.left!=1000 or mono.right!=1000:quit(1);return
	world.source_cd_stereo_flag = 2
	var rear: Dictionary = world.source_sound_channels(Vector3(0,0,world.CELL_METERS),1000)
	if rear.left!=250 or rear.right!=-250 or rear.flags!=2:quit(1);return
	var wav := AudioStreamWAV.load_from_file(world.content_root.path_join("audio/0279-MP033_02.WAD-311512.wav"))
	var voice = preload("res://source_spu_voice_node.gd").new();world.add_child(voice)
	var slot: int = world.source_voice_pool.allocate(true)
	world.source_voice_nodes[slot] = voice;world.sound_voices.append(voice)
	world.source_voice_pool.set_pitch(slot,4096)
	voice.finished.connect(world.retire_imported_voice.bind(voice))
	if not voice.start_voice(wav,1000,-1000,4096):quit(1);return
	var asset: Dictionary = {}
	for candidate in world.manifest.linkage.rooms[world.map_name].assets:
		if candidate.name=="NEPTTAIL":asset=candidate;break
	world.source_sample_volumes[asset.file] = 80
	if not world.update_imported_loop_sound(asset,slot,Vector3(0,0,world.CELL_METERS)) or voice.player.channels.x<=0 or voice.player.channels.y>=0:push_error("Loop update lost rear signed panning");quit(1);return
	if not world.shift_imported_sound_pitch(slot,-4096) or not voice.player.zero_pitch:quit(1);return
	if not world.shift_imported_sound_pitch(slot,4096) or voice.player.zero_pitch:quit(1);return
	if not world.stop_imported_sound_voice(slot) or world.source_voice_nodes.has(slot) or world.source_voice_pool.reserved[slot]:
		push_error("Streaming voice pool stop left allocation/node");quit(1);return
	await process_frame
	var second = preload("res://source_spu_voice_node.gd").new();world.add_child(second)
	slot = world.source_voice_pool.allocate(false)
	world.source_voice_nodes[slot] = second;world.sound_voices.append(second)
	second.finished.connect(world.retire_imported_voice.bind(second))
	if not second.start_voice(wav,1000,1000,4096):quit(1);return
	var start := Time.get_ticks_usec()
	while world.source_voice_nodes.has(slot) and Time.get_ticks_usec()-start<2000000:await create_timer(0.005).timeout
	if world.source_voice_nodes.has(slot) or not world.sound_voices.is_empty():push_error("Streaming completion retained world voice");quit(1);return
	world.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: actual world voice pool handles streaming pitch, stop and natural retirement")
	quit(0)
