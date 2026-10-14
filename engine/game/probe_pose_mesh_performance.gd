extends Node3D
func _ready() -> void:call_deferred("visual_check" if OS.get_cmdline_user_args().has("--visual-check") else "profile")
func visual_check() -> void:
	var world=load("res://imported.tscn").instantiate();get_tree().root.add_child(world);await get_tree().process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.tick_source_actors()
	var butterfly:Node=null
	for actor in world.source_actors:
		if actor.source_name=="SceneryButterfly":butterfly=actor;break
	if butterfly==null or not butterfly.sprite_parts.is_empty():get_tree().quit(2);return
	butterfly.apply_pose();var pose:Array=[]
	for part in butterfly.mesh_parts:pose.append(part.transform)
	world.camera.position+=Vector3(5,3,4);butterfly._process(1.0/60.0)
	for i in range(pose.size()):
		if not pose[i].is_equal_approx(butterfly.mesh_parts[i].transform):get_tree().quit(3);return
	var player=world.active_texture_animations.get("TK05_TRK.BIN")
	if player==null:get_tree().quit(4);return
	var initial:PackedByteArray=player.bitmap.get_data();var started:=Time.get_ticks_usec()
	for tick in range(60):player.advance()
	var result:Dictionary={"butterfly_rig":true,"palette_changed":initial!=player.bitmap.get_data(),"palette_ticks":60,"palette_total_us":Time.get_ticks_usec()-started,"scope":"CPU/headless; texture GPU upload time excluded"}
	var file:=FileAccess.open("user://visual-repairs-check.json",FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("VISUAL_REPAIRS: ",JSON.stringify(result))
	world.queue_free();await get_tree().process_frame;get_tree().quit(0 if result.palette_changed else 5)
func profile() -> void:
	var world=load("res://imported.tscn").instantiate();get_tree().root.add_child(world);await get_tree().process_frame
	world.set_process(false);world.set_physics_process(false)
	var actor=world.source_player_actor
	if not is_instance_valid(actor) or actor.model_data.is_empty() or actor.model_data.models[0].vertices.size()<99:
		push_error("Pose performance probe did not load Croc's source model");get_tree().quit(6);return
	var model:Dictionary=actor.model_data.models[0]
	var template:ArrayMesh=world.geometry(model,actor.model_texture)
	var builder=preload("res://source_pose_mesh_builder.gd").new();builder.setup(template,model)
	var points:Array[Vector3]=[]
	for point in model.vertices:points.append(Vector3(point[0],point[1],point[2])*world.CELL_METERS)
	# Exercise changing positions, including a foot deformation, not an idle cache hit.
	var poses:Array=[]
	for frame in range(100):
		var pose:Array[Vector3]=points.duplicate()
		for index in range(41,95):pose[index]+=Vector3(0.01*sin(frame*0.1),0.01*cos(frame*0.1),0)
		poses.append(pose)
	var started:=Time.get_ticks_usec()
	var expected:Array=[]
	for pose in poses:
		var posed:Dictionary=model.duplicate();posed.vertices=[]
		for point in pose:posed.vertices.append([point.x/world.CELL_METERS,point.y/world.CELL_METERS,point.z/world.CELL_METERS])
		expected.append(world.geometry(posed,actor.model_texture))
	var old_us:=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec()
	var actual:Array=[]
	for pose in poses:actual.append(builder.build(pose))
	var new_us:=Time.get_ticks_usec()-started
	for i in range(poses.size()):
		for surface in range(actual[i].get_surface_count()):
			var a:Array=actual[i].surface_get_arrays(surface);var b:Array=expected[i].surface_get_arrays(surface)
			for attribute in [Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_INDEX]:
				if a[attribute]!=b[attribute]:push_error("Pose mesh attribute changed: "+str(attribute));get_tree().quit(2);return
			for point in range(a[Mesh.ARRAY_VERTEX].size()):
				if a[Mesh.ARRAY_VERTEX][point].distance_to(b[Mesh.ARRAY_VERTEX][point])>0.000001 or a[Mesh.ARRAY_NORMAL][point].distance_to(b[Mesh.ARRAY_NORMAL][point])>0.0001:
					push_error("Pose mesh position or normal changed");get_tree().quit(3);return
	var result:Dictionary={"poses":100,"full_rebuild_us":old_us,"reused_attributes_us":new_us,"equivalent":true}
	var file:=FileAccess.open("user://pose-mesh-performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("POSE_MESH_PERFORMANCE: ",JSON.stringify(result))
	world.queue_free();await get_tree().process_frame;get_tree().quit(0)
