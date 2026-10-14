extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var parent = null
	for actor in world.source_actors:
		if actor.source_name == "RunningPlatform":
			parent = actor
			break
	if parent == null:
		quit(1)
		return
	for index in range(1,5): parent.source_reference_slots[index] = parent.source_pool_id
	if parent.asl_command({"op":119,"args":[2,"RunSwitch",[{"op":4,"value":65536},{"op":18}]]},parent.vm) != "continue":
		quit(1)
		return
	var child = world.source_pool.slots[parent.source_child_id].node
	for index in range(4):
		if parent.source_reference_slots.has(index): assert(child.source_reference_slots[index] == parent.source_reference_slots[index])
	assert(not child.source_reference_slots.has(4))
	if child.position != Vector3.ZERO or child.source_angles != Vector3i.ZERO or (int(child.primary_flags)&0x04000000) == 0 or child.source_parent_id != parent.source_pool_id or child.vm.parameters != [65536,0,0,0,0,0,0,0]:
		push_error("Original SpawnChild local pose, flags, parent or parameters differ")
		quit(1)
		return
	if not child.refresh_source_render_pose() or child.source_render_position != Vector3i(roundi(parent.position.x/world.CELL_METERS*4096),roundi(parent.position.y/world.CELL_METERS*4096),roundi(parent.position.z/world.CELL_METERS*4096)):
		push_error("Attached child did not compose the original parent transform")
		quit(1)
		return
	if parent.source_waypoints.size() > 1:
		parent.source_waypoint_chain.nodes[0].next = -1
		if child.source_waypoint_chain.nodes[0].next != -1:
			push_error("SpawnChild did not share source waypoint links")
			quit(1)
			return
	var effect = world.spawn_source_actor(parent,"DeathFX",[],{"position":Vector3i(4096,8192,12288),"angles":Vector3i(123,456,789),"retain_parent":true})
	if effect == null or effect.source_parent_id != parent.source_pool_id or (int(effect.primary_flags)&0x04000000) != 0 or effect.source_angles != Vector3i(123,456,789):
		push_error("Independent effect pose/retained owner differs");quit(1);return
	if not effect.refresh_source_render_pose() or effect.source_render_position != Vector3i(4096,8192,12288) or not effect.source_waypoints.is_empty():
		push_error("Independent effect incorrectly inherited parent transform/waypoints");quit(1);return
	var previous_ids := {}
	for candidate in world.source_actors: previous_ids[candidate.source_pool_id] = true
	var voices_before: int = world.sound_voices.size()
	# CreateDeath's audible sound allocation is qualified with a nearby listener.
	world.camera.global_position = parent.global_position
	parent.source_angles = Vector3i(123,456,789);parent.vm.parameters = [42,11,22,33,44,55,66,77]
	var flags_before: int = parent.primary_flags
	if parent.asl_command({"op":165,"args":[]},parent.vm) != "continue": quit(1);return
	var effects := []
	for candidate in world.source_actors:
		if not previous_ids.has(candidate.source_pool_id): effects.append(candidate)
	if effects.size() != 8 or parent.vm.parameters != [0,11,22,33,44,55,66,77] or parent.primary_flags != (flags_before|0x80040) or world.sound_voices.size() != voices_before+1:
		push_error("CreateDeath effect count, sound, counter or flags differ");quit(1);return
	var yaws := []
	for candidate in effects:
		if candidate.source_name != "DeathFX" or candidate.source_parent_id != parent.source_pool_id or candidate.source_angles.x != 123 or candidate.source_angles.z != 789 or not candidate.position.is_equal_approx(parent.position):
			push_error("CreateDeath copied pose or owner differs");quit(1);return
		yaws.append(candidate.source_angles.y)
	yaws.sort()
	if yaws != [456,968,1480,1992,2504,3016,3528,4040]: push_error("CreateDeath eight original yaw directions differ");quit(1);return
	world.stop_imported_audio()
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Death-effect audio did not retire");quit(1);return
	print("PASS: original attached child zero pose, parameter bank, flag, parent link, composed rendering and shared waypoints")
	quit(0)
