extends SceneTree
const Pose=preload("res://modern_character_pose.gd")
const Anchor=preload("res://source_horizon_anchor.gd")
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	for angles in [Vector3(0.6,1.2,0.3),Vector3(-1.5,-2,-0.7),Vector3(PI/2,0.9,0.4)]:
		var view:=Transform3D(Basis.from_euler(angles),Vector3(3,1.7,8))
		var level:=Anchor.transform(view,4)
		assert(level.basis.y.is_equal_approx(Vector3.UP) and is_equal_approx(level.origin.y,view.origin.y))
		assert(is_equal_approx(level.origin.distance_to(view.origin),4))
	var h:Array=[];h.resize(22);h.fill(0);h[0]=2;h[18]=128;h[19]=-64
	var normal:=Pose.record_normal({"halfwords":h},0)
	assert(normal.is_equal_approx(Vector3(-0.5,1,0.25).normalized()))
	assert((Pose.foot_tilt(normal,1)*Vector3.UP).is_equal_approx(normal))
	assert((Pose.foot_tilt(normal,0)*Vector3.UP).is_equal_approx(Vector3.UP))
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for room in ["MP010_00.MAP","MP100_01.MAP","MP100_02.MAP","MP100_03.MAP","MP100_04.MAP","MP100_05.MAP"]:
		assert(world.load_room(room))
		var sky:Node3D=null
		for child in world.terrain.get_children():
			if child.get_script()==preload("res://source_gameplay_sky.gd"):sky=child
		assert(sky!=null and sky.get_child_count()>0)
		world.camera.position=Vector3(2,3,4);sky._process(0)
		assert(is_equal_approx(sky.global_position.y,world.camera.global_position.y*0.25-world.CELL_METERS*0.5))
	assert(world.load_room("MP093_00.MAP"))
	for tick in range(40):world.tick_source_actors()
	var flames:=0
	for actor in world.source_actors:
		if actor.model_name=="MRFRBALL.MOD":
			assert(actor.sprite_parts.size()==1)
			world.camera.position=actor.position+Vector3(3,1,2);actor._process(0.016)
			var part:MeshInstance3D=actor.sprite_parts[0]
			assert(part.global_basis.z.normalized().dot((world.camera.global_position-part.global_position).normalized())>0.999)
			flames+=1
	assert(flames==4)
	world.queue_free();await process_frame
	print("PASS: horizon anchor; slope tilt; all five level-selector skies; four title flame sprites")
	quit(0)
