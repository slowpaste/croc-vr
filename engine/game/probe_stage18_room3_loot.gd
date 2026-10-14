extends RefCounted
static func left_shore(route: SceneTree,world: Node,right_delta: int) -> String:
	if world.map_name!="MP018_03.MAP":return "Room3 loot requires normal locked-room entry"
	var targets: Dictionary={}
	for actor in world.source_actors:
		if actor.source_name=="Crystal" and actor.source_map_entity_index>=7 and actor.source_map_entity_index<=16:targets[actor.source_map_entity_index]=actor.position
	if targets.size()!=10:return "Room3 left-shore crystal inventory incomplete"
	var reached: Dictionary=await route.walk_to(world,Vector3(3,0,9),right_delta)
	var fault: String=reached.get("fault","");route.release_controls()
	for index in [11,10,9,8,7,12,13,14,15,16]:
		if not fault.is_empty():break
		if (int(world.source_map_entity_flags.get("MP018_03.MAP",{}).get(index,0))&4)!=0:continue
		reached=await route.walk_to(world,targets[index],right_delta,false,null,1.8,"",40,func():return (int(world.source_map_entity_flags.get("MP018_03.MAP",{}).get(index,0))&4)!=0)
		fault=reached.get("fault","");route.release_controls()
		if world.map_name!="MP018_03.MAP":fault="Left-shore route left original room3";break
	if fault.is_empty():
		for index in range(7,17):
			if (int(world.source_map_entity_flags.get("MP018_03.MAP",{}).get(index,0))&4)==0:fault="Room3 left crystal marker missing: "+str(index);break
	print("STAGE18_ROOM3_LEFT_CRYSTALS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags,"player":str(world.source_player_actor.position)}))
	return fault

static func return_top(route: SceneTree,world: Node,right_delta: int) -> String:
	var target: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="PlatformSpin" and actor.source_map_entity_index==6:target=actor;break
	if target==null:return "Top spinner missing on elevated return"
	var lives: int=world.source_pickup_counts[3]
	var aim := Vector3.ZERO
	var ready := false
	for tick in range(400):
		route.release_controls()
		var angle: float=float(int(target.source_angles.y)&4095)*TAU/4096.0
		var center: Vector3=target.position-Vector3(sin(angle)*3,0,cos(angle)*3)
		aim=center+Vector3(sin(angle-20*15*TAU/4096.0)*3,0,cos(angle-20*15*TAU/4096.0)*3)
		var delta: Vector3=aim-world.source_player_actor.position
		var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
		var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
		if Vector2(delta.x,delta.z).length()<2.5 and abs(difference)<80:ready=true;break
		if abs(difference)>40:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
		world.sample_source_player_controls();world.tick_source_actors()
		if world.source_pickup_counts[3]<lives:return "Elevated return preparation lost a life"
	if not ready:return "Elevated return close approach missing"
	var supported := func():return int(world.source_player_actor.source_ground.get("actor",-1))==target.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
	var reached: Dictionary=await route.jump_to_actor(world,target,right_delta,30,0,18,supported,supported,aim)
	var fault: String=reached.get("fault","")
	route.release_controls()
	if fault.is_empty() and not supported.call():fault="Elevated return top standing missing"
	print("STAGE18_ROOM3_HIGH_RETURN: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"ground":world.source_player_actor.source_ground,"player":str(world.source_player_actor.position)}))
	return fault

static func right_shore(route: SceneTree,world: Node,right_delta: int) -> String:
	if world.map_name!="MP018_03.MAP":return "Right-shore loot requires normal room3 entry"
	var targets: Dictionary={}
	for actor in world.source_actors:
		if actor.source_name=="Crystal" and (actor.source_map_entity_index in [17,18,19,20,21,22,23,24,29,30]):targets[actor.source_map_entity_index]=actor.position
	if targets.size()!=10:return "Room3 right-shore crystal inventory incomplete"
	var fault := ""
	for point in [Vector3(6,0,7),Vector3(16.5,0,7)]:
		var reached: Dictionary=await route.walk_to(world,point,right_delta)
		fault=reached.get("fault","");route.release_controls()
		if not fault.is_empty():break
	for index in [17,18,19,20,29,30,21,22,23,24]:
		if not fault.is_empty():break
		if (int(world.source_map_entity_flags.get("MP018_03.MAP",{}).get(index,0))&4)!=0:continue
		var reached: Dictionary=await route.walk_to(world,targets[index],right_delta,false,null,1.8,"",40,func():return (int(world.source_map_entity_flags.get("MP018_03.MAP",{}).get(index,0))&4)!=0)
		fault=reached.get("fault","");route.release_controls()
		if world.map_name!="MP018_03.MAP":fault="Right-shore route left original room3";break
	if fault.is_empty():
		for index in [17,18,19,20,21,22,23,24,29,30]:
			if (int(world.source_map_entity_flags.get("MP018_03.MAP",{}).get(index,0))&4)==0:fault="Room3 right crystal marker missing: "+str(index);break
	print("STAGE18_ROOM3_RIGHT_CRYSTALS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags,"player":str(world.source_player_actor.position)}))
	return fault

static func first_spin(route: SceneTree,world: Node,right_delta: int) -> String:
	if world.map_name!="MP018_03.MAP":return "High platform route requires normal room3 entry"
	var fault := ""
	for point in [Vector3(16.5,0,7),Vector3(6.5,0,7),Vector3(6.5,0,9)]:
		var reached: Dictionary=await route.walk_to(world,point,right_delta)
		fault=reached.get("fault","");route.release_controls()
		if not fault.is_empty():break
	var platform: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="PlatformSpin" and actor.source_map_entity_index==0:platform=actor;break
	if platform==null:return "Room3 first spinning platform missing"
	if fault.is_empty():fault=await route.board_stage18_spinner(world,[platform],right_delta,Vector3(5.93628,1.499268,9.24316),3320,16,65)
	print("STAGE18_ROOM3_FIRST_SPIN: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"platforms":world.source_actors.filter(func(a):return a.source_name=="PlatformSpin").map(func(a):return {"index":a.source_map_entity_index,"position":str(a.position),"angle":a.source_angles.y,"pc":a.vm.pc})}))
	return fault

static func second_spin(route: SceneTree,world: Node,right_delta: int,current_index: int=0,target_index: int=1) -> String:
	var target: Node3D=null
	var current: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="PlatformSpin" and actor.source_map_entity_index==target_index:target=actor;break
	if target==null:return "Room3 second spinning platform missing"
	for actor in world.source_actors:
		if actor.source_name=="PlatformSpin" and actor.source_map_entity_index==current_index:current=actor;break
	if current==null:return "Room3 current platform missing"
	var centered: Dictionary=await route.walk_to(world,current.position,right_delta,false,current,3.0)
	route.release_controls()
	if not centered.get("fault","").is_empty():return centered.fault
	if int(world.source_player_actor.source_ground.get("actor",-1))!=current.source_pool_id or int(world.source_player_actor.source_ground.get("mode",0))!=2 or (int(world.source_player_actor.secondary_flags)&2)==0:return "Centering lost current platform support"
	var lives: int=world.source_pickup_counts[3]
	var aim := Vector3.ZERO
	var forward_budget := 0
	var ready := false
	for tick in range(800):
		route.release_controls()
		var angle: float=float(int(target.source_angles.y)&4095)*TAU/4096.0
		var center: Vector3=target.position-Vector3(sin(angle)*3,0,cos(angle)*3)
		var future_angle := angle-20*15*TAU/4096.0
		aim=center+Vector3(sin(future_angle)*3,0,cos(future_angle)*3)
		var inherited: Vector3=current.position-Vector3(current.previous_source_position)*world.CELL_METERS/4096.0
		aim-=Vector3(inherited.x,0,inherited.z)*10.0
		var delta: Vector3=aim-world.source_player_actor.position
		var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
		var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
		var actual: Vector3=target.position-world.source_player_actor.position
		var turn_difference := difference
		if Vector2(actual.x,actual.z).length()>2.0:
			var current_angle: float=float(int(current.source_angles.y)&4095)*TAU/4096.0
			var current_center: Vector3=current.position-Vector3(sin(current_angle)*3,0,cos(current_angle)*3)
			var future_origin: Vector3=current_center+Vector3(sin(current_angle-20*15*TAU/4096.0)*3,0,cos(current_angle-20*15*TAU/4096.0)*3)
			var later_target: Vector3=center+Vector3(sin(angle-40*15*TAU/4096.0)*3,0,cos(angle-40*15*TAU/4096.0)*3)
			var anticipated: Vector3=later_target-future_origin
			var turn_desired := roundi(atan2(anticipated.x,anticipated.z)*4096.0/TAU)&4095
			turn_difference=wrapi(turn_desired-int(world.source_player_actor.source_angles.y),-2048,2048)
		if tick%10==0:print("STAGE18_TRANSFER_PREP: ",JSON.stringify({"tick":tick,"player":str(world.source_player_actor.position),"current":str(current.position),"target":str(target.position),"aim":str(aim),"actual_gap":Vector2(actual.x,actual.z).length(),"predicted_gap":Vector2(delta.x,delta.z).length(),"difference":difference,"ground":world.source_player_actor.source_ground,"clip":world.source_player_actor.clip_name,"inherit":str(inherited)}))
		if int(world.source_player_actor.source_ground.get("actor",-1))!=current.source_pool_id or int(world.source_player_actor.source_ground.get("mode",0))!=2 or (int(world.source_player_actor.secondary_flags)&2)==0:return "Transfer preparation lost current platform support"
		if abs(difference)<(120 if current_index>=1 and current_index!=5 else 80) and Vector2(actual.x,actual.z).length()<(2.6 if current_index in [3,5] else (2.3 if current_index%2==1 else 1.7)) and Vector2(delta.x,delta.z).length()<(1.6 if current_index>=2 and current_index%2==0 else 1.2):
			forward_budget=clampi(roundi(Vector2(delta.x,delta.z).length()/0.1),4,18)
			ready=true;break
		if abs(turn_difference)>40:Input.action_press("move_right" if turn_difference*right_delta>0 else "move_left")
		world.sample_source_player_controls();world.tick_source_actors()
		if world.source_pickup_counts[3]<lives:return "Higher platform preparation lost a life"
	if not ready:return "Higher platform close approach missing"
	print("STAGE18_ROOM3_SECOND_SPIN_START: ",JSON.stringify({"player":str(world.source_player_actor.position),"target":str(target.position),"aim":str(aim),"angle":target.source_angles.y,"forward_ticks":forward_budget}))
	var supported := func():return int(world.source_player_actor.source_ground.get("actor",-1))==target.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
	var reached: Dictionary=await route.jump_to_actor(world,target,right_delta,30,0,forward_budget,supported,supported,aim)
	var fault: String=reached.get("fault","");route.release_controls()
	if fault.is_empty() and not supported.call():fault="Room3 second platform standing support missing"
	print("STAGE18_ROOM3_SECOND_SPIN: ",JSON.stringify({"fault":fault,"from_index":current_index,"to_index":target_index,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts}))
	return fault

static func climb_top(route: SceneTree,world: Node,right_delta: int) -> String:
	var fault := ""
	for index in range(2,6):
		fault=await second_spin(route,world,right_delta,index,index+1)
		if not fault.is_empty():break
	print("STAGE18_ROOM3_TOP_SPIN: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"scope":"Actual standing on indexed staircase; highlife pickups still separate"}))
	return fault

static func high_life(route: SceneTree,world: Node,right_delta: int,platform_index: int,seed_index: int) -> String:
	var platform: Node3D=null
	var seed: Node3D=null
	for actor in world.source_actors:
		if actor.source_map_entity_index==platform_index:platform=actor
		if actor.source_map_entity_index==seed_index:seed=actor
	if platform==null or seed==null:return "Elevated life actors missing"
	var before: int=world.source_pickup_counts[3]
	var close := false
	for tick in range(400):
		route.release_controls()
		var delta: Vector3=platform.position-world.source_player_actor.position
		var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
		var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
		if tick%20==0:print("STAGE18_HIGH_LIFE_PREP: ",JSON.stringify({"tick":tick,"gap":Vector2(delta.x,delta.z).length(),"difference":difference,"player":str(world.source_player_actor.position),"platform":str(platform.position)}))
		if Vector2(delta.x,delta.z).length()<2.6 and abs(difference)<80:close=true;break
		if abs(difference)>40:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
		world.sample_source_player_controls();world.tick_source_actors()
		if world.source_pickup_counts[3]<before:return "Elevated life preparation lost a life"
	if not close:return "Elevated life platform approach missing"
	var supported := func():return int(world.source_player_actor.source_ground.get("actor",-1))==platform.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
	var reached: Dictionary=await route.jump_to_actor(world,platform,right_delta,30,0,18,supported,supported)
	var fault: String=reached.get("fault","")
	if fault.is_empty() and not supported.call():fault="Elevated life platform standing missing"
	if fault.is_empty():
		var pickup: Dictionary=await route.walk_to(world,seed.position,right_delta,false,null,0.3,"",40,func():return world.source_pickup_counts[3]==before+1)
		fault=pickup.get("fault","")
	route.release_controls()
	if fault.is_empty() and world.source_pickup_counts[3]!=before+1:fault="Elevated seed life award missing"
	print("STAGE18_ROOM3_HIGH_LIFE: ",JSON.stringify({"fault":fault,"platform_index":platform_index,"seed_index":seed_index,"before_lives":before,"inventory":world.source_pickup_counts,"ground":world.source_player_actor.source_ground,"player":str(world.source_player_actor.position)}))
	return fault

static func leave_high_lives(route: SceneTree,world: Node,right_delta: int) -> String:
	var lives: int=world.source_pickup_counts[3]
	var landed := func():return int(world.source_player_actor.source_ground.get("mode",0))==1 and (int(world.source_player_actor.secondary_flags)&2)!=0 and world.source_player_actor.position.y<1.0
	var reached: Dictionary=await route.jump_to_actor(world,Vector3(17,0,11),right_delta,100,0,45,landed,landed)
	var fault: String=reached.get("fault","")
	route.release_controls()
	if fault.is_empty() and not landed.call():fault="Elevated exit ground landing missing"
	if world.source_pickup_counts[3]<lives:fault="Elevated exit lost a life"
	print("STAGE18_ROOM3_HIGH_EXIT: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"ground":world.source_player_actor.source_ground,"player":str(world.source_player_actor.position)}))
	return fault

static func return_room5(route: SceneTree,world: Node,right_delta: int) -> String:
	var fault := ""
	for waypoint in [Vector3(16.5,0,7),Vector3(6.5,0,7),Vector3(3,0,9)]:
		var reached: Dictionary=await route.walk_to(world,waypoint,right_delta)
		fault=reached.get("fault","");route.release_controls()
		if not fault.is_empty():break
	if fault.is_empty():
		var returned: Dictionary=await route.walk_to(world,Vector3(0,0,8.977),right_delta,false,null,1.8,"MP018_05.MAP")
		fault=returned.get("fault","");route.release_controls()
	print("STAGE18_ROOM3_RETURN_DOOR: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"player":str(world.source_player_actor.position)}))
	return fault

static func collect_jigsaw(route: SceneTree,world: Node,right_delta: int) -> String:
	if world.map_name!="MP018_05.MAP":return "Jigsaw route requires normal return to room5"
	var jigsaw: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="Jigsaw" and actor.source_map_entity_index==22:jigsaw=actor;break
	if jigsaw==null:return "Original room5 Jigsaw missing"
	var before: int=world.source_extended_globals.get(28,0)
	print("STAGE18_JIGSAW_APPROACH: ",JSON.stringify({"player":str(world.source_player_actor.position),"jigsaw":str(jigsaw.position),"completion_signal":before}))
	var corridor: Dictionary=await route.walk_to(world,Vector3(29.4,5.25,10.5),right_delta)
	route.release_controls()
	if not corridor.get("fault","").is_empty():return corridor.fault
	var reached: Dictionary=await route.walk_to(world,jigsaw.position,right_delta,false,null,1.8,"",40,func():return int(world.source_extended_globals.get(28,0))!=before)
	var fault: String=reached.get("fault","");route.release_controls()
	if fault.is_empty() and int(world.source_extended_globals.get(28,0))==before:fault="Jigsaw completion signal missing"
	print("STAGE18_JIGSAW_CONTACT: ",JSON.stringify({"fault":fault,"completion_signal":world.source_extended_globals.get(28,0),"transition_state":world.source_transition_state,"flags":world.source_map_entity_flags,"inventory":world.source_pickup_counts,"scope":"Normal contact and original completion signal only; earned selector credit/save unverified"}))
	return fault

static func finish_jigsaw(route: SceneTree,world: Node) -> String:
	var fault := ""
	var saw_victory: bool=world.source_transition_state==3
	for tick in range(1500):
		route.release_controls()
		if world.source_transition_state==3:
			saw_victory=true
			if tick%60<4:Input.action_press("jump")
		world.sample_source_player_controls();world.tick_source_actors()
		if not world.process_source_exit():fault=world.source_transition_fault;break
		if world.source_main_mode==5 and world.source_fade_phase=="":break
		if tick%30==0:await route.process_frame
	route.release_controls()
	if fault.is_empty() and (not saw_victory or world.source_main_mode!=5 or world.map_name!="MP100_01.MAP" or world.source_fade_phase!=""):fault="Jigsaw victory/results/selector sequence incomplete"
	print("STAGE18_JIGSAW_RETURN: ",JSON.stringify({"fault":fault,"saw_victory":saw_victory,"room":world.map_name,"mode":world.source_main_mode,"progress":world.source_menu_progress_flags,"selection":world.source_menu_state.selected_index,"inventory":world.source_pickup_counts,"scope":"Normal victory/results/menu return; campaign credit requires earned entry"}))
	return fault
