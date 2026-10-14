extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var player = world.create_source_player()
	player.position = Vector3(1.5,2.25,3)
	player.source_angles = Vector3i(100,200,300)
	player.source_waypoints = [{"runtime_position":Vector3i(1,2,3)}]
	var original_count: int = world.source_actors.size()
	for count in [0,7,99]:
		world.source_pickup_counts[1] = count
		var previous: Array = world.source_actors.duplicate()
		if player.asl_command({"op":123,"args":[]},player.vm) != "continue" or world.source_pickup_counts[1] != 0:
			push_error("LosePickups did not clear the full crystal count")
			quit(1)
			return
		var spawned: Array = []
		for candidate in world.source_actors:
			if not previous.has(candidate):
				spawned.append(candidate)
		if spawned.size() != mini(count,10):
			push_error("LosePickups scatter count/cap differs from source")
			quit(1)
			return
		spawned.reverse() # Source prepends each successive allocation.
		for index in range(spawned.size()):
			var piece = spawned[index]
			if piece.source_name != "PickUpScatter" or piece.position != player.position or piece.source_angles != Vector3i(0,index*int(4096/spawned.size()),0) or piece.source_parent_id != -1 or not piece.source_waypoints.is_empty() or piece.vm.parameters != [0,0,0,0,0,0,0,0] or piece.vm.pc != 37 or piece.vm.status != "ready":
				push_error("LosePickups detached pose, angle spacing or deferred entry differs from source")
				quit(1)
				return
	if world.source_actors.size() != original_count+17:
		quit(1)
		return
	var observer = world.source_actors[0]
	observer.position = Vector3(0,2.25,3)
	observer.source_angles = Vector3i(10,0,20)
	world.source_actor_references.refresh(world.source_actors)
	observer.vm.program.references = [{"kind":0,"name":player.source_name}]
	# Replacing the fixture program requires registering its new reference;
	# native cached references do not lazily resolve a different program.
	world.register_source_actor_references(observer)
	world.source_actor_references.refresh(world.source_actors)
	if observer.asl_command({"op":7,"args":[0,[{"op":4,"value":2097152},{"op":18}]]},observer.vm) != "continue" or observer.source_angles != Vector3i(10,32,20) or observer.source_reference_slots[0] != player.source_pool_id:
		push_error("TurnTowardY source actor-reference yaw step failed")
		quit(1)
		return
	observer.source_angles.y = 4090
	if observer.asl_command({"op":7,"args":[0,[{"op":4,"value":2097152},{"op":18}]]},observer.vm) != "continue" or observer.source_angles.y != 26:
		push_error("TurnTowardY source yaw wrapping failed")
		quit(1)
		return
	world.queue_free()
	await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: source crystal scatter cap, spacing, detached pose and deferred scripts; referenced yaw turning")
	quit(0)
