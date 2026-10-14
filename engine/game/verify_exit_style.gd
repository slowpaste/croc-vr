extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var player = world.source_player_actor
	player.position = Vector3(9,0,6)
	player.source_ground.surface_type = 128 # Controlled classification, not physical completion.
	world.source_player_entry_state.present = false
	world.room_data.doors = [{"position":[3,0,2],"level":0,"room":0,"flags":1,"id":0}]
	var result: Dictionary = world.source_exit_request(player)
	if result.has("fault") or result.state != 3 or not result.transition or result.destination != "MP000_00.MAP":
		push_error("Cross-level classification incorrectly required a future-level room bank")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: source current-chapter room style lookup classifies cross-level return state3")
	quit(0)
