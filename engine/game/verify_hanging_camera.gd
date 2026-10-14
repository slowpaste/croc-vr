extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame
	world.set_process(false); world.set_physics_process(false)
	world.xr_active = true
	world.actor.position = Vector3(300,10,300)
	world.source_player_actor.position = world.actor.position
	world.yaw = 0
	var roof := StaticBody3D.new()
	roof.position = world.actor.position+Vector3(0,0.8,0)
	var collision := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(12,0.3,12); collision.shape = box; roof.add_child(collision); world.add_child(roof)
	await physics_frame
	for mode in [7,8,9]:
		world.source_extended_globals[0] = mode<<16
		for head_height in [1.0,1.6,1.9]:
			world.head.position = Vector3(0,head_height,0)
			world.vr_camera_anchor_initialized = false
			world.vr_traversal_view_blend = 0
			for frame in range(60):
				world.update_vr_camera_anchor(1.0/90.0)
				world.update_camera()
				if world.head.global_position.distance_to(world.actor.position)<=4.5:
					print("CAMERA_TRANSITION: ",mode," height ",head_height," frame ",frame," eye ",world.head.global_position," anchor ",world.vr_camera_anchor," blend ",world.vr_traversal_view_blend)
					push_error("Grab transition collapsed the orbit");quit(1);return
			world.update_camera()
			assert(world.head.global_position.distance_to(world.actor.position)>4.5,"Overhang collapsed the camera onto hanging Croc")
			assert(world.head.global_position.y<10.3,"Hanging camera remained above the safe ceiling envelope")
	var wall := StaticBody3D.new(); wall.position = world.actor.position+Vector3(0,0.5,2)
	var side := CollisionShape3D.new(); var side_box := BoxShape3D.new()
	side_box.size = Vector3(12,8,0.3); side.shape=side_box; wall.add_child(side); world.add_child(wall)
	await physics_frame
	world.update_camera()
	assert(world.head.global_position.z-world.actor.position.z<1.5,"Hanging camera ignored a real wall")
	world.queue_free(); await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: ledge and ceiling camera preserve orbit distance under an overhang at three tracked heights, while still respecting walls")
	quit(0)
