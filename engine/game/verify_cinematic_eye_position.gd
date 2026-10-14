extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.xr_active=true
	for height in [1.0,1.6,1.9]:
		for tilt in [-0.3,0.0,0.5]:
			world.head.position=Vector3(0.1,height,0.15)
			world.rig.transform=Transform3D(Basis.from_euler(Vector3(tilt,0.7,0)),Vector3(8,12,3))
			var before:Vector3=world.head.global_position
			world.capture_source_cinematic_view()
			assert(world.head.global_position.is_equal_approx(before),"Leveling the cinematic moved the tracked eye")
			assert(absf(world.rig.global_basis.z.y)<0.00001,"Cinematic retained virtual camera tilt")
			var screen=preload("res://source_sequence_screen.gd").new();root.add_child(screen)
			screen.viewer_camera=world.head;screen.viewer_distance=4.0;screen.reanchor()
			assert(is_equal_approx(screen.global_position.y,before.y-0.35))
			world.source_sequence_loading=true;world.source_main_mode=2
			world.actor.position=Vector3(0,-20,0);world.vr_camera_anchor=world.actor.position;world.vr_camera_anchor_initialized=true
			for frame in range(90):world.update_camera()
			assert(world.head.global_position.is_equal_approx(before),"Opening mode switched to gameplay eye height")
			assert(is_equal_approx(screen.global_position.y,world.head.global_position.y-0.35),"Viewport drifted above the viewer")
			world.head.position.x+=0.2
			assert(world.head.global_position.distance_to(before)>0.19,"Cinematic prevented physical head movement")
			world.source_sequence_loading=false;screen.queue_free()
	world.xr_active=false;world.queue_free();await process_frame
	print("PASS: seated/standing eye position preserved through cinematic mode changes; virtual tilt removed; viewport stays below eye level; physical head movement retained")
	quit(0)
