extends SceneTree
var world
var out := ""
var shot := ""
var number := 0
var dry := false
var trace: Array = []
var camera_offset := Vector3(0,2.1,4.0)
func _initialize() -> void:call_deferred("run")
func controls(stick:Vector2,jump:=false) -> void:
	for a in ["move_left","move_right","move_forward","move_back","jump","attack","precision_move"]:
		if InputMap.has_action(a):Input.action_release(a)
	if absf(stick.x)>0:Input.action_press("move_right" if stick.x>0 else "move_left",absf(stick.x))
	if absf(stick.y)>0:Input.action_press("move_back" if stick.y>0 else "move_forward",absf(stick.y))
	if jump:Input.action_press("jump")
func aimed(target:Vector3,strength:float,jump:=false) -> void:
	var delta:Vector3=target-world.source_player_actor.position
	var forward:Vector3=-world.camera.global_basis.z;forward.y=0;forward=forward.normalized()
	var right:Vector3=forward.cross(Vector3.UP)
	var direction:=Vector3(delta.x,0,delta.z).normalized()
	controls(Vector2(direction.dot(right),-direction.dot(forward))*strength,jump)
func camera_frame() -> void:
	var focus:Vector3=world.source_player_actor.position
	world.camera.position=focus+camera_offset
	var exclude:Array[RID]=[world.actor.get_rid()]
	for body in world.source_player_actor.camera_bodies:
		if is_instance_valid(body):exclude.append(body.get_rid())
	var ray:=PhysicsRayQueryParameters3D.create(focus+Vector3(0,.6,0),world.camera.position,257,exclude)
	var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():world.camera.position=Vector3(hit.position)+Vector3(hit.normal)*.18
	world.camera.look_at(focus+Vector3(0,0.45,0))
func step() -> void:
	world.sample_source_player_controls();world.tick_source_actors()
	world.actor.position=world.source_player_actor.position
	world.source_player_actor.apply_pose();world.source_player_actor.refresh_source_render_pose()
	world.source_player_actor.modern_blend_alpha=1
	world.source_player_actor.modern_pose.apply(world.source_player_actor,1.0/30.0)
	camera_frame()
func record() -> void:
	trace.append({"shot":shot,"frame":number,"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"ground":(int(world.source_player_actor.secondary_flags)&2)!=0,"gems":world.source_pickup_counts[1],"lives":world.source_pickup_counts[3]})
	if not dry:
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(out.path_join("%s-%04d.png"%[shot,number]))==OK)
	number+=1
func new_world(map:String,start:Vector3,heading:int) -> void:
	controls(Vector2.ZERO)
	if is_instance_valid(world):world.stop_imported_audio();world.queue_free();await process_frame
	world=load("res://imported.tscn").instantiate();world.map_name=map;root.add_child(world)
	world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="modern"
	world.stop_imported_audio()
	for a in world.source_actors:a.set_process(false)
	world.hud.hide()
	if is_instance_valid(world.source_gameplay_hud):world.source_gameplay_hud.hide()
	world.camera.fov=52
	camera_frame()
	for i in range(60):step()
	world.source_player_actor.position=start;world.source_player_actor.source_angles.y=heading
	world.source_player_actor.refresh_source_render_pose()
	for i in range(30):step()
	print("DIRECTOR_START ",map," ",world.source_player_actor.position)
func hold(count:int) -> void:
	for i in range(count):controls(Vector2.ZERO);step();await record()
func walk(target:Vector3,strength:=0.8,max_ticks:=100) -> bool:
	for i in range(max_ticks):
		var p:Vector3=world.source_player_actor.position
		var distance:=Vector2(target.x-p.x,target.z-p.z).length()
		if distance<0.12: return true
		aimed(target,minf(strength,maxf(.2,distance*1.5)));step();await record()
	return false
func leap(target:Vector3) -> bool:
	var airborne:=false
	for i in range(80):
		var p:Vector3=world.source_player_actor.position
		var distance:=Vector2(target.x-p.x,target.z-p.z).length()
		var grounded:bool=(int(world.source_player_actor.secondary_flags)&2)!=0
		if not grounded:airborne=true
		if airborne and grounded:
			print("DIRECTOR_LANDING ",p," target ",target," distance ",distance," lives ",world.source_pickup_counts[3])
			return distance<1.0 and absf(p.y-target.y)<.75
		aimed(target,minf(1.0,distance*2),i<12);step();await record()
		if world.source_pickup_counts[3]<3:return false
	return false
func platform_shot() -> void:
	shot="platforms";number=0;camera_offset=Vector3(-1,1.65,2.5)
	await new_world("MP010_01.MAP",Vector3(6.1,0,6),1024)
	await hold(8)
	for target in [Vector3(9,0.56,6),Vector3(10.5,1.16,6),Vector3(12,0.56,6),Vector3(15,0.56,6),Vector3(16.5,1.16,6),Vector3(18,0.56,6)]:
		if not await leap(target):print("DIRECTOR_PLATFORM_FAILED ",target);return
		await hold(2)
	# Facing is preserved by gentle lateral and backward intent before the last jump.
	for i in range(10):controls(Vector2(0,.3));step();await record()
	for i in range(10):controls(Vector2(.28,0));step();await record()
	await hold(5)
	if not await leap(Vector3(21,0,6)):print("DIRECTOR_FINAL_JUMP_FAILED");return
	await hold(10)
	print("DIRECTOR_PLATFORMS_SUCCESS frames ",number)
func gem_shot() -> void:
	shot="gems";number=0;camera_offset=Vector3(-.4,1.9,3.5)
	await new_world("MP010_03.MAP",Vector3(6,0,4.5),1024)
	var start_gems:int=world.source_pickup_counts[1]
	await walk(Vector3(10.5,0,4.5),1,100)
	for i in range(4):aimed(Vector3(11,0,4.5),1);step();await record()
	# A rapid opposite stick gesture triggers the native flip turn.
	for i in range(45):aimed(Vector3(1.5,0,4.5),1);step();await record()
	await walk(Vector3(1.5,0,4.5),1,100)
	await hold(8)
	print("DIRECTOR_GEMS_SUCCESS collected ",world.source_pickup_counts[1]-start_gems," frames ",number)
func slope_shot() -> void:
	shot="slope";number=0;camera_offset=Vector3(1.1,.75,1.4)
	await new_world("MP010_00.MAP",Vector3(3.5,.602,6.5),0)
	for i in range(65):
		aimed(Vector3(3.5,.5,6.8),.18 if i<12 else 0);step();await record()
	print("DIRECTOR_SLOPE_COMPLETE")
func door_shot() -> void:
	shot="door";number=0
	await new_world("MP010_02.MAP",Vector3(15,0,15),0)
	var parent
	var leaves:Array=[]
	for a in world.source_actors:
		if a.source_name=="BonusDoor":parent=a
		if a.source_name in ["BonusDoorL","BonusDoorR"]:leaves.append(a)
	assert(parent!=null and leaves.size()==2)
	# Staged inventory montage, using the real shader and original opening scripts.
	world.source_player_actor.position=parent.position;world.actor.position=parent.position
	world.source_player_actor.primary_flags|=0x20;world.source_player_actor.refresh_source_render_pose()
	world.source_actors.assign([parent,leaves[0],leaves[1]])
	var facing:=Basis(Vector3.UP,float(parent.source_angles.y)*TAU/4096)
	for i in range(155):
		world.source_bonus_mask=0 if i<12 else 1 if i<35 else 3 if i<57 else 7 if i<65 else 15 if i<73 else 31
		world.tick_source_actors()
		for leaf in leaves:leaf.refresh_bonus_door_feedback()
		world.camera.position=parent.position+facing*Vector3(.25*sin(float(i)/155*PI),1.25,3.65)
		world.camera.look_at(parent.position+Vector3(0,1.05,0))
		await record()
	print("DIRECTOR_DOOR_OPEN ",parent.vm.parameters," leaves ",leaves[0].vm.parameters,leaves[1].vm.parameters)
func run() -> void:
	var args:=OS.get_cmdline_user_args();dry=args.has("--dry")
	out=args[args.find("--out")+1];root.size=Vector2i(1280,720)
	var selection:String=args[args.find("--shot")+1] if args.has("--shot") else "all"
	if selection in ["all","platforms"]:await platform_shot()
	if selection in ["all","gems"]:await gem_shot()
	if selection in ["all","slope"]:await slope_shot()
	if selection in ["all","door"]:await door_shot()
	var f:=FileAccess.open(out.path_join("trace-%s.json"%selection),FileAccess.WRITE);f.store_string(JSON.stringify(trace))
	quit(0)
