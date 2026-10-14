extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false); world.set_process(false)
	var asset: Dictionary = {}
	for entry in world.manifest.linkage.bootstrap:
		if entry.name == "DEATHFX": asset = entry; break
	world.source_transition_state = 0
	var slot: int = world.play_imported_sound_voice(asset,Vector3.ZERO,40.0,6144)
	if slot < 4:
		push_error("Zero pitch must allocate a dynamic voice"); quit(1); return
	var voice = world.source_voice_nodes[slot]
	var player = voice.player
	if world.source_voice_pool.pitch_registers[slot] != 0 or not player.zero_pitch or not player.stream_paused or player.pitch_scale <= 0:
		push_error("Zero pitch register/cursor state mismatch"); quit(1); return
	var position: float = player.get_playback_position()
	var cursor: int = player.cursor
	await create_timer(0.1).timeout
	if player.get_playback_position() != position or player.cursor != cursor:
		push_error("Zero pitch advanced the sample cursor"); quit(1); return
	if not world.shift_imported_sound_pitch(slot,2048) or player.stream_paused:
		push_error("Positive pitch must release the frozen cursor"); quit(1); return
	await create_timer(0.05).timeout
	if player.cursor <= cursor: push_error("Positive pitch did not advance the sample cursor");quit(1);return
	if not world.shift_imported_sound_pitch(slot,-2048) or not player.stream_paused:
		push_error("Pitch shift back to zero must freeze the cursor"); quit(1); return
	world.queue_free(); await process_frame
	var retirement := root.get_node("SourceSpuStreamRetirement")
	var deadline := Time.get_ticks_msec()+2000
	while not retirement.pending.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if not retirement.pending.is_empty():push_error("Zero-pitch voice remained alive after removal");quit(1);return
	print("PASS: original zero pitch allocates a voice, freezes its cursor and supports later pitch changes")
	quit(0)
