extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var owner = null
	for actor in world.source_actors:
		if actor.source_name == "FinalExit": owner = actor
	if owner == null: quit(1); return
	var player = world.source_player_actor
	player.position = owner.position+Vector3(world.CELL_METERS,0,0)
	player.primary_flags &= ~0x1000
	world.source_player_movement_state.motion = Vector2i.ZERO
	var source_position: Vector3 = owner.position
	var player_position: Vector3 = player.position
	var expression := [{"op":3,"index":63},{"op":18}]
	if owner.vm.evaluate(expression) != 1024<<16: push_error("Original player-relative angle query differs"); quit(1); return
	if owner.asl_command({"op":153,"args":[expression]},owner.vm) != "continue" or owner.position != source_position or world.source_player_movement_state.motion != Vector2i(245760,0): quit(1); return
	if not player.position.is_equal_approx(player_position+Vector3(60.0*world.CELL_METERS/4096.0,0,0)): quit(1); return
	player.primary_flags |= 0x1000
	player_position = player.position
	if owner.asl_command({"op":153,"args":[expression]},owner.vm) != "continue" or player.position != player_position: quit(1); return
	world.source_player_actor = null
	if owner.vm.evaluate(expression) != 0 or owner.asl_command({"op":153,"args":[[{"op":38}]]},owner.vm) != "continue": quit(1); return
	world.source_player_actor = player
	world.queue_free()
	await process_frame
	print("PASS: registered-player angle query/acceleration, caller pose retention, protected and missing-player no-op")
	quit(0)
