extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world)
	await process_frame;world.set_process(false);world.set_physics_process(false)
	assert(world.source_player_actor != null and world.source_player_actor.source_name=="Croc")
	world.xr_active=true;world.source_main_mode=4
	world.actor.position=Vector3(3,3,4);world.vr_camera_anchor_initialized=false
	world.update_vr_camera_anchor(1.0/60.0)
	world.source_player_actor.primary_flags |= 0x200
	world.source_player_actor.secondary_flags &= ~2
	world.actor.position=Vector3(5,4.4,4)
	for frame in range(60):world.update_vr_camera_anchor(1.0/60.0)
	assert(is_equal_approx(world.vr_camera_anchor.y,3.0))
	assert(world.vr_camera_anchor.x>4.9)
	world.source_camera_hold_counter=1
	var held_x:float=world.vr_camera_anchor.x
	world.actor.position.x=8
	world.update_vr_camera_anchor(0.1)
	assert(world.vr_camera_anchor.x==held_x and is_equal_approx(world.vr_camera_anchor.y,3.0))
	world.source_camera_hold_counter=0
	world.source_player_actor.primary_flags &= ~0x600
	world.source_player_actor.secondary_flags |= 2
	world.actor.position.y=4.0
	for frame in range(240):world.update_vr_camera_anchor(1.0/60.0)
	assert(world.vr_camera_anchor.y>3.8 and world.vr_camera_anchor.y<=4.0)
	world.xr_active=false;world.actor.position.y=7
	world.update_vr_camera_anchor(0.1)
	assert(world.vr_camera_anchor.y>5.0)
	world.queue_free();await process_frame
	print("PASS: real Croc jump flags select steady XR height, horizontal/hold behavior, landing recovery and desktop follow")
	quit(0)
