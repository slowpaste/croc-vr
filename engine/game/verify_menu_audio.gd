extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.enter_source_main_menu()
	var samples: Dictionary = {}
	for asset in world.manifest.linkage.bootstrap:
		if int(asset.kind) == 3 and asset.name in ["SELECT","START"]:
			samples[asset.name] = asset.file
	world.advance_source_main_menu_navigation(0x40000,0x40000)
	var selected_voice := int(world.source_voice_pool.cursor)
	if int(world.source_sample_volumes.get(samples.SELECT,0)) != 80 or world.source_voice_pool.pitch_registers.get(selected_voice,0) != 4088:
		push_error("Source menu SELECT volume/pitch differs")
		quit(1)
		return
	world.advance_source_main_menu_navigation(0,0)
	if world.source_voice_pool.cursor != selected_voice:
		push_error("Idle menu frame emitted a selection sound")
		quit(1)
		return
	world.advance_source_main_menu_navigation(0x10000,0x10000)
	if not world.process_source_main_menu_confirmation(0x200):
		quit(1)
		return
	var start_voice := int(world.source_voice_pool.cursor)
	if int(world.source_sample_volumes.get(samples.START,0)) != 80 or world.source_voice_pool.pitch_registers.get(start_voice,0) != 4088 or world.source_voice_nodes[start_voice].get_parent() != world.camera or world.source_voice_nodes[start_voice].position != Vector3.ZERO:
		push_error("Source menu START sample, volume, pitch or listener position differs")
		quit(1)
		return
	world.camera.position += Vector3(1,0,0)
	if world.source_voice_nodes[start_voice].global_position != world.camera.global_position:
		push_error("Menu sound moved away from the listener after tracked head movement")
		quit(1)
		return
	world.stop_imported_audio()
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Menu sound playback did not retire");quit(1);return
	print("PASS: original SELECT/START samples, volume80, pitch24/register4088 and idle suppression")
	quit(0)
