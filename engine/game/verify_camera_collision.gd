extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0,2,2)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10,8,0.3)
	collision.shape = box
	wall.add_child(collision)
	world.add_child(wall)
	await physics_frame
	world.actor.position = Vector3.ZERO
	world.yaw = 0
	world.update_camera()
	if world.camera.global_position.z >= 1.9:
		push_error("Camera swept sphere passed through a wall")
		quit(1)
		return
	print("CAMERA_SAFE_POSITION: ",world.camera.global_position)
	world.xr_active = true
	world.head.position = Vector3(0,1.6,0)
	world.vr_camera_anchor_initialized = false
	world.vr_head_collision_overlay = preload("res://source_fade_overlay.gd").new()
	world.head.add_child(world.vr_head_collision_overlay)
	world.update_camera()
	var neutral_rig: Vector3 = world.rig.global_position
	if 1.85-world.head.global_position.z<0.36 or world.vr_head_collision_overlapping:
		push_error("Centered HMD did not retain wall clearance");quit(1);return
	world.head.position.z=0.25
	world.update_camera()
	if world.vr_head_collision_overlapping or not world.rig.global_position.is_equal_approx(neutral_rig):
		push_error("Comfortable head lean caused a blackout or moved the rig");quit(1);return
	world.head.position.z = 0.6
	world.update_camera()
	if not world.rig.global_position.is_equal_approx(neutral_rig) or not world.vr_head_collision_overlapping or world.vr_head_collision_fade != 255.0 or not world.vr_head_collision_overlay.visible:
		push_error("Tracked head lean moved the virtual rig or did not fade near geometry")
		quit(1)
		return
	world.head.position.z = 0
	world.update_camera()
	if world.vr_head_collision_overlapping:
		push_error("Head overlap persisted after retreat")
		quit(1)
		return
	var controls = preload("res://vr_controls.gd")
	for rate in [60,72,144]:
		var fade := 255.0
		for frame in range(rate/4):
			fade = controls.collision_fade(fade,false,1.0/rate)
		if fade > 0.001:
			push_error("Head fade recovery depends on refresh rate")
			quit(1)
			return
	world.head.position.z=0
	for distance in [1.2,2.0,4.0]:
		wall.position.z=distance;await physics_frame
		world.update_camera()
		if distance-0.15-world.head.global_position.z<0.36 or world.vr_head_collision_overlapping:
			push_error("Wall clearance changed with arm length");quit(1);return
	wall.position.z=2.0;world.actor.position.z=1.65;await physics_frame
	world.update_camera()
	if world.head.global_position.z>1.49 or world.vr_head_collision_overlapping:
		push_error("Starting inside the outer sweep envelope bypassed the wall");quit(1);return
	var corner:=StaticBody3D.new();corner.position=Vector3(2,2,0)
	var side:=CollisionShape3D.new();var side_box:=BoxShape3D.new();side_box.size=Vector3(0.3,8,10)
	side.shape=side_box;corner.add_child(side);world.add_child(corner)
	world.actor.position.x=1.65;world.yaw=PI/4.0;await physics_frame
	world.update_camera()
	if world.head.global_position.x>1.49 or world.head.global_position.z>1.49 or world.vr_head_collision_overlapping:
		push_error("Centered head retained a wall overlap at a corner");quit(1);return
	world.queue_free()
	await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: camera arm collision remains in front of wall with clearance")
	quit(0)
