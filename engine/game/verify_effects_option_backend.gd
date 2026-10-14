extends SceneTree
const StreamingVoice = preload("res://source_spu_voice_node.gd")
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var boss = world.source_actors[0]
	var handle: int = boss.asl_asset({"kind":4,"name":"NEPTTAIL"},boss.vm)>>16
	if handle <= 0:quit(1);return
	var asset: Dictionary = boss.handles[handle]
	var location: Vector3 = world.to_local(world.camera.global_position)
	var slot: int = world.play_imported_sound_voice(asset,location,80,0)
	if slot < 0:push_error("Effects backend voice fixture unavailable");quit(1);return
	var info: Dictionary = world.read_json(asset.file)
	var shot := preload("res://source_audio_math.gd").one_shot_volume(80,127,0,false)
	var initial := 0 if bool(info.held) else int(shot.volume)
	if world.source_voice_pool.volume_registers[slot]!=initial or not world.source_voice_nodes[slot] is StreamingVoice:
		push_error("One-shot source volume did not reach actual voice");quit(1);return
	var initial_channels: Dictionary = world.source_sound_channels(location,initial)
	if world.source_voice_nodes[slot].player.channels!=Vector2i(int(initial_channels.left),int(initial_channels.right)):quit(1);return
	if not bool(info.held):
		var cursor: int = world.source_voice_pool.cursor
		if world.play_imported_sound_voice(asset,location+Vector3(15*world.CELL_METERS,0,0),80,0)>=0 or world.source_voice_pool.cursor!=cursor:
			push_error("Inaudible unheld one-shot consumed a voice");quit(1);return
		if not world.play_imported_sound(asset,location+Vector3(15*world.CELL_METERS,0,0),80,0) or world.source_voice_pool.cursor!=cursor or not world.source_sound_request_fault.is_empty():
			push_error("Inaudible void PlaySound halted an actor or consumed a voice");quit(1);return
	var state := {"audio":{"effects":80},"effects_restore_volume":127,"effects_maximum":80,"effects_step":10}
	if not world.apply_source_effects_option_state(state) or not world.update_imported_loop_sound(asset,slot,location):quit(1);return
	if world.source_audio_master_gain!=80 or world.source_effects_restore_volume!=127:quit(1);return
	var expected := preload("res://source_audio_math.gd").loop_volume(80,80,0,false)
	var expected_channels: Dictionary = world.source_sound_channels(location,expected)
	if world.source_voice_pool.volume_registers[slot]!=expected or world.source_voice_nodes[slot].player.channels!=Vector2i(int(expected_channels.left),int(expected_channels.right)):
		push_error("Original effects option did not reach live loop voice");quit(1);return
	state.effects_step = 9
	if world.apply_source_effects_option_state(state) or world.source_effects_volume!=80:quit(1);return
	world.source_audio_master_gain = 0
	if world.source_effects_volume!=0 or world.play_imported_sound_voice(asset,location,80,0)>=0:quit(1);return
	world.stop_imported_audio();world.queue_free();await process_frame
	var retirement := root.get_node("SourceSpuStreamRetirement")
	var deadline := Time.get_ticks_msec()+2000
	while not retirement.pending.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if not retirement.pending.is_empty():push_error("Effects option voices did not retire");quit(1);return
	print("PASS: validated effects state reaches actual imported loop voice using option, not fade gain")
	quit(0)

