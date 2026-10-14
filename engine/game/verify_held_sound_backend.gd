extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var asset: Dictionary = {}
	for candidate in world.manifest.linkage.rooms[world.map_name].assets:
		if candidate.name == "MRFB" and candidate.get("audio",false): asset = candidate;break
	if asset.is_empty() or not world.read_json(asset.file).held:push_error("Missing actual held sound fixture");quit(1);return
	var near: Vector3 = world.to_local(world.camera.global_position)
	var far := near+Vector3(15*world.CELL_METERS,0,0)
	var slot: int = world.play_imported_sound_voice(asset,far,80,0,true)
	if slot < 0 or not world.source_voice_pool.reserved[slot] or world.source_voice_pool.volume_registers[slot]!=0 or world.source_voice_nodes[slot].player.channels!=Vector2i.ZERO:
		push_error("Inaudible held sample did not reserve a silent channel");quit(1);return
	if not world.update_imported_loop_sound(asset,slot,near) or world.source_voice_pool.volume_registers[slot]<=0 or world.source_voice_nodes[slot].player.channels==Vector2i.ZERO:
		push_error("Held loop failed to become audible on update");quit(1);return
	if not world.stop_imported_sound_voice(slot) or world.source_voice_pool.reserved[slot]:quit(1);return
	world.source_voice_pool.cursor=17
	var masked: int=world.play_imported_sound_voice(asset,far,80,0,true)
	if masked!=18 or not world.source_voice_pool.reserved[18]:push_error("Masked stop fixture did not allocate held channel18");quit(1);return
	if not world.stop_imported_sound_voice(78642) or world.source_voice_nodes.has(18) or not world.source_voice_pool.reserved[18]:push_error("Original low-five-bit keyoff or raw reservation ownership differs");quit(1);return
	if not world.stop_imported_sound_voice(18) or world.source_voice_pool.reserved[18] or not world.stop_imported_sound_voice(-1):quit(1);return
	world.source_effects_volume = 0
	var cursor: int = world.source_voice_pool.cursor
	if world.play_imported_sound_voice(asset,near,80,0,true)>=0 or world.source_voice_pool.cursor!=cursor:quit(1);return
	world.stop_imported_audio();world.queue_free();await process_frame
	var retirement := root.get_node("SourceSpuStreamRetirement")
	var deadline := Time.get_ticks_msec()+2000
	while not retirement.pending.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if not retirement.pending.is_empty():push_error("Held stream retirement did not release playback");quit(1);return
	print("PASS: actual held MRFB sound reserves silently, updates audibly, releases and rejects zero-product allocation")
	quit(0)
