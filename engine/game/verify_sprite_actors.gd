extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var room = load("res://imported.tscn").instantiate()
	root.add_child(room)
	for frame in range(90):
		await physics_frame
	room.set_physics_process(false)
	room.set_process(false)
	var checked: Dictionary = {}
	for actor in room.source_actors:
		actor.set_process(false)
		if actor.sprite_parts.is_empty():
			continue
		var actor_origin: Vector3 = actor.position
		var actor_angles: Vector3i = actor.source_angles
		for part in actor.sprite_parts:
			var origin: Vector3 = part.global_position
			var scale_before: Vector3 = part.global_basis.get_scale()
			for xr in [false,true]:
				room.xr_active=xr
				var view:Camera3D=room.head if xr else room.camera
				for offset in [Vector3(3,0,0),Vector3(0,2,3),Vector3(-3,1,0),Vector3(0,0,-3)]:
					view.global_position = origin + offset
					actor._process(0.0)
					if part.global_basis.z.normalized().dot(offset.normalized()) < 0.9999 or not part.global_position.is_equal_approx(origin) or not part.global_basis.get_scale().is_equal_approx(scale_before) or actor.position != actor_origin or actor.source_angles != actor_angles:
						push_error("Sprite orbit changed facing, scale, attachment or physics: " + actor.source_name)
						quit(1)
						return
			room.xr_active=false
		checked[actor.source_name] = true
		var root_pose: Transform3D = actor.visual_root.global_transform
		actor.visual_root.basis = Basis.from_scale(Vector3.ZERO)
		actor._process(0.0)
		if actor.visual_root.global_basis != Basis.from_scale(Vector3.ZERO):
			push_error("Sprite update changed a collapsed effect pose")
			quit(1)
			return
		actor.visual_root.global_transform = root_pose
	if not checked.has("Gobbo") or not checked.has("LavaBlubsActual"):
		push_error("Imported sprite fixture did not exercise Gobbo and lava parts")
		quit(1)
		return
	for actor in room.source_actors:
		if actor.source_name == "Gobbo" and (actor.sprite_parts.size() != 2 or actor.mesh_parts.size() != 12):
			push_error("Gobbo's solid limbs were incorrectly converted into sprites")
			quit(1)
			return
	print("PASS: imported sprite orbit, stable source physics/attachment/scale, Gobbo solid limbs: ",checked.keys())
	room.queue_free()
	await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	quit(0)
