extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();world.source_menu_state.selected_index = 23
	root.add_child(world);await process_frame;world.set_physics_process(false)
	for tick in range(60): world.tick_source_actors()
	var parent: Node3D = null
	for actor in world.source_actors:
		if actor.source_name == "BossNeptuna": parent = actor;break
	if parent == null: quit(1);return
	var command: Dictionary = parent.vm.instructions[276]
	# Unknown-state refusal is a controlled fixture; live movement/sound can now
	# populate both words during these initial ticks.
	world.source_spawn_scratch = preload("res://source_spawn_scratch.gd").new()
	var count: int = world.source_actors.size()
	assert(parent.asl_command(command,parent.vm) == "unsupported")
	assert(parent.vm.fault == "Unknown SpawnFrom scratch word" and world.source_actors.size() == count)
	parent.vm.status = "yielded";parent.vm.fault = ""
	# Test input comes from independent native observations; no live fallback.
	world.source_spawn_scratch.evaluator_frame(88,0x20000000,0x04000000)
	world.source_spawn_scratch.sound_header(0x429b0)
	world.source_spawn_scratch.camera_query(0x80080f78)
	var expected: Dictionary = preload("res://source_spawn_from.gd").point(parent.source_render_matrix,parent.source_render_position,parent.source_scale,parent.model_data.models,parent.clip,parent.clip_frame,1)
	assert(not expected.has("fault"))
	assert(parent.asl_command(command,parent.vm) == "continue")
	var child: Node3D = world.source_actors[0]
	assert(child.source_name == "BangBubble" and child.source_parent_id == parent.source_pool_id)
	assert(child.vm.parameters == [29491,0,0,0,0,0,0,0])
	assert(child.source_angles == Vector3i(3960,-32760,10672))
	assert((int(child.primary_flags)&0x04000000) == 0)
	assert(child.refresh_source_render_pose() and child.source_render_position == expected.position)
	assert(child.source_waypoints == parent.source_waypoints)
	if parent.source_waypoint_chain.nodes.size() > 0:
		parent.source_waypoint_chain.nodes[0].next = -1
		assert(child.source_waypoint_chain.nodes[0].next == -1)
	var available: Array = world.source_pool.free_slots.duplicate()
	world.source_pool.free_slots.clear();count = world.source_actors.size()
	assert(parent.asl_command(command,parent.vm) == "continue" and world.source_actors.size() == count)
	world.source_pool.free_slots.assign(available)
	world.stop_imported_audio();world.queue_free();await process_frame;await create_timer(0.25).timeout
	print("PASS: authored SpawnFrom consumes origin separately, copies eight child parameters, retained owner/shared waypoints and independent pose; unknown scratch refuses without allocation")
	quit(0)
