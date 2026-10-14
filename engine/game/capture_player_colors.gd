extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false); world.set_physics_process(false)
	for tick in range(30): world.tick_source_actors()
	var player: Node3D = world.source_player_actor
	assert(player != null and player.mesh_parts.size() > 0)
	for node in world.find_children("*", "Label", true, false): node.hide()
	world.camera.global_position = player.global_position + Vector3(1.1,0.7,1.2)
	world.camera.look_at(player.global_position + Vector3(0,0.35,0))
	for corrected in [false,true]:
		for binding in world.source_material_bindings.values():
			binding.material.vertex_color_is_srgb = corrected
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/player-colors-%s.png" % ("corrected" if corrected else "before"))
	world.queue_free(); await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	quit()
