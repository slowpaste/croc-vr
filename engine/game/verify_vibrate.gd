extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var player = world.source_player_actor
	var position: Vector3 = player.position
	var camera: Vector3 = world.camera.position
	var hold: int = world.source_camera_hold_counter
	var draws: int = world.source_random.draws
	var expression := [{"op":4,"value":655360},{"op":25},{"op":18}]
	if player.asl_command({"op":185,"args":[expression]},player.vm) != "continue" or world.source_random.draws != draws+2:
		push_error("Original Vibrate skipped argument evaluation")
		quit(1)
		return
	if player.position != position or world.camera.position != camera or world.source_camera_hold_counter != hold:
		push_error("Supported executable Vibrate gained a non-source pose/camera effect")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: original Vibrate argument evaluation without invented pose/camera/rumble effects")
	quit(0)
