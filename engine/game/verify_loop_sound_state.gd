extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame
	world.set_physics_process(false); world.set_process(false)
	var asset: Dictionary = {}
	for entry in world.manifest.linkage.bootstrap:
		if entry.name == "CRYS": asset = entry; break
	if asset.is_empty(): push_error("Missing original loop-sound fixture"); quit(1); return
	world.source_sample_volumes.erase(asset.file)
	var location: Vector3 = world.to_local(world.camera.global_position)
	if not world.update_imported_loop_sound(asset,0,location) or int(world.source_voice_pool.volume_registers.get(0,-1)) != 1024 or world.source_voice_nodes.has(0):
		push_error("Unplayed LoopSound must update the native channel register without starting audio"); quit(1); return
	world.source_audio_muted = true
	if not world.update_imported_loop_sound(asset,0,location) or int(world.source_voice_pool.volume_registers[0]) != 0:
		push_error("Muted LoopSound did not clear its channel volume"); quit(1); return
	if not world.update_imported_loop_sound(asset,-1,location) or world.update_imported_loop_sound(asset,24,location):
		push_error("LoopSound voice bounds differ from source"); quit(1); return
	world.queue_free(); await process_frame
	print("PASS: LoopSound updates unplayed/muted channel registers, preserves silence and rejects invalid voices")
	quit(0)
