extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	for scene in ["res://main.tscn", "res://imported.tscn"]:
		var room = load(scene).instantiate()
		root.add_child(room)
		await physics_frame
		var initial: Vector3 = room.actor.position
		Input.action_press("move_forward")
		Input.action_press("jump")
		for i in range(10): await physics_frame
		Input.action_release("move_forward")
		Input.action_release("jump")
		if room.actor.position != initial or room.missing_data_label.text != "Game data isn't imported." or not room.missing_data_label.visible or room.board.text != room.missing_data_label.text or room.board.visible or not room.pickups.is_empty():
			push_error("Missing-data scene must show only the message and stay idle")
			quit(1)
			return
		for child in room.get_children():
			if child is StaticBody3D or child is MeshInstance3D:
				push_error("Missing-data scene must not contain procedural scenery")
				quit(1)
				return
		room.queue_free()
		await process_frame
	print("PASS: both missing-data scenes show the message without gameplay")
	quit(0)
