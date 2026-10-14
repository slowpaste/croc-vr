extends "res://probe_first_room_route.gd"
var route_starting_lives: int=3
func probe() -> void:
	if "--from-earned-stage10" in OS.get_cmdline_user_args():
		await super.probe();return
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	var fault: String=await run_stage11(world)
	if is_instance_valid(world):
		world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if fault.is_empty() else 1)

func continue_earned_stage(world: Node) -> String:
	world.set_process(true);world.set_physics_process(true)
	for frame in range(60):await physics_frame
	Input.action_press("jump")
	for frame in range(4):await physics_frame
	Input.action_release("jump")
	for frame in range(180):
		await physics_frame
		if world.map_name=="MP011_00.MAP" and world.source_fade_phase=="":break
	if world.map_name!="MP011_00.MAP" or world.source_menu_state.selected_index!=1:return "Earned selector did not enter stage11"
	print("STAGE11_EARNED_ENTRY: ",JSON.stringify({"progress":world.source_menu_progress_flags,"lives":world.source_pickup_counts[3]}))
	return await run_stage11(world)

func run_stage11(world: Node) -> String:
	world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
	route_starting_lives=int(world.source_pickup_counts[3])
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var prior: int=world.source_player_actor.source_angles.y
	Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors();release_controls()
	var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
	var fault := ""
	if "--inspect-opening" in OS.get_cmdline_user_args():
		print("STAGE11_OPENING_ACTORS: ",JSON.stringify(world.source_actors.map(func(a):return {"name":a.source_name,"position":str(a.position)})))
		for z in range(3,22,3):
			var row: Array=[]
			for x in range(3,16,3):row.append({"x":x,"z":z,"floor":world.source_raw_floor_query(Vector3(x,12,z))})
			print("STAGE11_OPENING_FLOORS: ",JSON.stringify(row))
		world.stop_imported_audio();world.queue_free();await process_frame
		await preload("res://source_spu_stream_retirement.gd").drain(self)
		quit();return ""
	if "--verify-opening-boxes" in OS.get_cmdline_user_args():fault=await collect_ordinary_boxes(world,right_delta)
	var upper_well: bool="--verify-upper-well" in OS.get_cmdline_user_args()
	if "--verify-opening-blue" in OS.get_cmdline_user_args() or upper_well:
		var reached: Dictionary=await walk_to(world,Vector3(6,0,12),right_delta)
		fault=reached.get("fault","");release_controls()
		if fault.is_empty():
			reached=await walk_to(world,Vector3(3,3.433,12),right_delta)
			fault=reached.get("fault","");release_controls()
		if fault.is_empty() and "--verify-perimeter-extras" in OS.get_cmdline_user_args():
			for waypoint in [Vector3(3,3.433,18),Vector3(3,3.6,21),Vector3(6,3.433,21),Vector3(12,3.433,21),Vector3(15,3.6,21),Vector3(15,3.433,15),Vector3(15,3.6,21),Vector3(3,3.6,21),Vector3(3,3.433,12)]:
				reached=await walk_to(world,waypoint,right_delta)
				fault=reached.get("fault","");release_controls()
				if not fault.is_empty():break
			for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
			if fault.is_empty():
				for index in [4,7,8,9,10,18,19,20,21,25,26,27]:
					if (int(world.source_map_entity_flags.get("MP011_00.MAP",{}).get(index,0))&5)==0:fault="Perimeter crystal remains at index "+str(index);break
			print("STAGE11_PERIMETER_EXTRAS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts}))
		if fault.is_empty():
			for waypoint in [Vector3(3,3.433,6),Vector3(3,3.6,3),Vector3(6,3.433,3),Vector3(12,3.433,3)]:
				reached=await walk_to(world,waypoint,right_delta)
				fault=reached.get("fault","");release_controls()
				if not fault.is_empty():break
		for tick in range(1):world.sample_source_player_controls();world.tick_source_actors()
		if fault.is_empty() and world.source_bonus_mask==0:fault="Opening blue crystal was not collected"
		print("STAGE11_OPENING_BLUE: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts}))
	if upper_well and fault.is_empty():
		var corner: Dictionary=await jump_to_point(world,Vector3(15,3.6,3),right_delta)
		fault=corner.get("fault","");release_controls()
	if upper_well and fault.is_empty():
		for waypoint in [Vector3(15,3.433,6),Vector3(15,3.433,9)]:
			var reached: Dictionary=await walk_to(world,waypoint,right_delta)
			fault=reached.get("fault","");release_controls()
			if not fault.is_empty():break
	var lid: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="SmashLid" and (actor.position.y>2 if upper_well else actor.position.y<2):lid=actor;break
	if lid==null:fault="Missing selected well lid"
	var expected_well_room := "MP011_03.MAP" if upper_well else "MP011_01.MAP"
	if fault.is_empty():
		var reached: Dictionary=await walk_to(world,lid.position,right_delta,false,lid)
		fault=reached.get("fault","");release_controls()
	if fault.is_empty():
		for tick in range(360):
			release_controls()
			if tick in [12,13,14,15,22,23]:Input.action_press("jump")
			world.sample_source_player_controls();world.tick_source_actors()
			if not world.process_source_exit():fault=world.source_transition_fault;break
			if world.map_name==expected_well_room and world.source_fade_phase=="":break
			if tick%30==0:await process_frame
		release_controls()
		if world.map_name!=expected_well_room:fault="Selected well did not enter "+expected_well_room
	print("STAGE11_WELL_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
	if upper_well:
		if fault.is_empty() and "--verify-spring-loot" in OS.get_cmdline_user_args():
			for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
			var box: Node3D=null
			var floating: Node3D=null
			for actor in world.source_actors:
				if actor.source_name=="SmashBlock":box=actor
				if actor.source_name=="SmashBlockFloat" and actor.position.z<6:floating=actor
			if box==null or floating==null:fault="Missing spring-room near boxes"
			else:
				var reached: Dictionary=await walk_to(world,box.position,right_delta,false,box)
				fault=reached.get("fault","");release_controls()
				if fault.is_empty():
					var contacts: Dictionary=world.source_contacts_at(floating.position,world.source_player_actor)
					if contacts.lower.is_empty():fault="Floating box has no standing surface"
					else:
						var target: Vector3=floating.position
						target.y=int(contacts.lower.height_units)*world.CELL_METERS/4096.0
						reached=await jump_to_point(world,target,right_delta)
						fault=reached.get("fault","");release_controls()
						for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
						if fault.is_empty() and world.source_bonus_mask==1:fault="Near floating box color was not collected"
						if fault.is_empty() and "--verify-spring-boxes" in OS.get_cmdline_user_args():fault=await stomp_reward_box(world,floating)
			if fault.is_empty() and "--verify-spring-boxes" in OS.get_cmdline_user_args():fault=await collect_ordinary_boxes(world,right_delta)
			if fault.is_empty():fault=await collect_spring_far(world,right_delta)
			print("STAGE11_SPRING_LOOT: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
		if fault.is_empty() and "--verify-spring-exit" in OS.get_cmdline_user_args():
			for waypoint in [Vector3(9,0,12),Vector3(9,0,6),Vector3(15,0,6),Vector3(15,0,9)]:
				var reached: Dictionary=await walk_to(world,waypoint,right_delta)
				fault=reached.get("fault","");release_controls()
				if not fault.is_empty():break
			if fault.is_empty():
				var reached: Dictionary=await walk_to(world,Vector3(19.5,0,9),right_delta,false,null,1.8,"MP011_01.MAP")
				fault=reached.get("fault","");release_controls()
			if fault.is_empty() and (world.source_bonus_mask!=25 or world.source_pickup_counts[2]!=1):fault="Spring exit lost collected inventory"
			print("STAGE11_SPRING_EXIT: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
		if fault.is_empty() and "--verify-balloon-descent" in OS.get_cmdline_user_args():
			for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
			var reached: Dictionary=await walk_to(world,Vector3(9.2,5.25,6.1875),right_delta)
			fault=reached.get("fault","");release_controls()
			if fault.is_empty():
				for tick in range(120):
					release_controls()
					var difference := wrapi(3072-int(world.source_player_actor.source_angles.y),-2048,2048)
					if abs(difference)<80:break
					Input.action_press("move_right" if difference*right_delta>0 else "move_left")
					world.sample_source_player_controls();world.tick_source_actors()
				var rode := false
				var attached := false
				for tick in range(600):
					release_controls()
					if tick<16:Input.action_press("jump")
					if tick<10:Input.action_press("move_forward")
					world.sample_source_player_controls();world.tick_source_actors()
					if (int(world.source_extended_globals.get(0,0))>>16)==7:attached=true
					if tick%30==0:print("STAGE11_BALLOON_STEP: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"state":int(world.source_extended_globals.get(0,0))>>16,"clip":world.source_player_actor.clip_name}))
					if world.source_player_actor.position.y<1 and (int(world.source_player_actor.secondary_flags)&2)!=0:rode=true;break
				release_controls()
				if not rode or not attached:fault="Balloon approach did not attach and reach lower floor"
				print("STAGE11_BALLOON_RESULT: ",JSON.stringify({"fault":fault,"attached":attached,"landed":rode,"position":str(world.source_player_actor.position)}))
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
		if world.source_pickup_counts[3]!=route_starting_lives:fault="Upper well route lost a life"
		print("STAGE11_UPPER_WELL_CHECK: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"room":world.map_name,"inventory":world.source_pickup_counts}))
		if not "--join-stage11-route" in OS.get_cmdline_user_args() or not fault.is_empty():
			world.stop_imported_audio();world.queue_free();await process_frame
			await preload("res://source_spu_stream_retirement.gd").drain(self)
			quit(0 if fault.is_empty() else 1);return fault
	var carried_gobbos: int=world.source_pickup_counts[2]
	if "--join-stage11-route" in OS.get_cmdline_user_args() and (world.map_name!="MP011_01.MAP" or carried_gobbos!=1 or world.source_bonus_mask!=25):fault="Joined route lacks spring-room inventory or arrival"
	if fault.is_empty():
		for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
		var box: Node3D=null
		for actor in world.source_actors:
			if actor.source_name=="SmashBlockGobbo":box=actor;break
		if box==null:fault="Missing boxed Gobbo"
		else:
			var reached: Dictionary=await walk_to(world,box.position,right_delta,false,box)
			fault=reached.get("fault","");release_controls()
			if fault.is_empty():
				for tick in range(240):
					release_controls()
					if tick in [12,13,14,15,22,23]:Input.action_press("jump")
					world.sample_source_player_controls();world.tick_source_actors()
					if tick%30==0:await process_frame
				release_controls()
				if world.source_pickup_counts[2]!=carried_gobbos+1:fault="Box route did not rescue first Gobbo"
	for actor in world.source_actors:
		if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
	if world.source_pickup_counts[3]!=route_starting_lives:fault="Opening second-stage route lost a life"
	print("STAGE11_FIRST_GOBBO: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
	if fault.is_empty():fault=await climb_key_platforms(world,right_delta,true)
	if fault.is_empty() and "--verify-keyroom-boxes" in OS.get_cmdline_user_args():fault=await collect_ordinary_boxes(world,right_delta)
	if fault.is_empty():
		var reached: Dictionary=await walk_to(world,Vector3(6,0,4.52),right_delta)
		fault=reached.get("fault","");release_controls()
		for tick in range(180):world.sample_source_player_controls();world.tick_source_actors()
		if fault.is_empty() and world.source_pickup_counts[2]!=carried_gobbos+2:fault="Cage route did not rescue second Gobbo"
		print("STAGE11_CAGE_ROUTE: ",JSON.stringify({"fault":fault,"key":world.source_level_script_state,"inventory":world.source_pickup_counts}))
	if fault.is_empty():fault=await climb_key_platforms(world,right_delta,false)
	if fault.is_empty() and "--inspect-spring-approach" in OS.get_cmdline_user_args():
		for z in [6,9,12,15,18,21,24,27]:
			var row: Array=[]
			for x in [4.5,6,8.25,10.5]:row.append({"x":x,"z":z,"floor":world.source_raw_floor_query(Vector3(x,12,z))})
			print("SPRING_APPROACH_FLOORS: ",JSON.stringify(row))
		print("SPRING_APPROACH_ACTORS: ",JSON.stringify(world.source_actors.filter(func(a):return a.source_name in ["DeathSlide","NormalDoor"]).map(func(a):return {"name":a.source_name,"position":str(a.position),"parameters":a.vm.parameters})))
		world.stop_imported_audio();world.queue_free();await process_frame
		await preload("res://source_spu_stream_retirement.gd").drain(self)
		quit();return ""
	if fault.is_empty() and "--verify-upper-color" in OS.get_cmdline_user_args():
		var box: Node3D=null
		for actor in world.source_actors:
			if actor.source_name=="SmashBlockBonus":box=actor;break
		if box==null:fault="Missing upper bonus box"
		else:
			var before: int=world.source_bonus_mask
			var approach: Dictionary=await walk_to(world,Vector3(4.5,5.25,25.5),right_delta)
			fault=approach.get("fault","");release_controls()
			for tick in range(20):world.sample_source_player_controls();world.tick_source_actors()
			for tick in range(120):
				release_controls()
				var delta: Vector3=box.position-world.source_player_actor.position
				var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
				var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
				if abs(difference)<80:break
				Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				world.sample_source_player_controls();world.tick_source_actors()
			for tick in range(60) if fault.is_empty() else []:
				release_controls()
				if tick<16:Input.action_press("jump")
				var delta: Vector3=box.position-world.source_player_actor.position
				if tick<35 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
				world.sample_source_player_controls();world.tick_source_actors()
			release_controls()
			var reached: Dictionary=await walk_to(world,box.position,right_delta,false,box)
			fault=reached.get("fault","");release_controls()
			if fault.is_empty():
				for tick in range(240):
					release_controls()
					if tick in [12,13,14,15,22,23]:Input.action_press("jump")
					world.sample_source_player_controls();world.tick_source_actors()
				release_controls()
				if world.source_bonus_mask==before:fault="Upper bonus box did not yield a colored crystal"
		print("STAGE11_UPPER_COLOR: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts}))
	if fault.is_empty():
		for waypoint in [Vector3(4.5,5.25,25.5),Vector3(6,5.25,27)]:
			var approach: Dictionary=await walk_to(world,waypoint,right_delta)
			fault=approach.get("fault","");release_controls()
			if not fault.is_empty():break
		if fault.is_empty():
			var reached: Dictionary=await walk_to(world,Vector3(10.5,5.25,27),right_delta,false,null,1.8,"MP011_02.MAP")
			fault=reached.get("fault","");release_controls()
		print("STAGE11_ROOM2_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
	if fault.is_empty():
		for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
		var clear_door: Dictionary=await walk_to(world,Vector3(6,0,4.5),right_delta)
		fault=clear_door.get("fault","");release_controls()
		var rescue_platform: Node3D=null
		for actor in world.source_actors:
			if actor.source_name=="PlatformDead" and actor.position.x>6:rescue_platform=actor;break
		if rescue_platform==null:fault="Missing room2 Gobbo platform"
		else:
			for tick in range(120):
				release_controls()
				var delta: Vector3=rescue_platform.position-world.source_player_actor.position
				var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
				var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
				if abs(difference)<80:break
				Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				world.sample_source_player_controls();world.tick_source_actors()
			for tick in range(60):
				release_controls()
				if tick<16:Input.action_press("jump")
				var delta: Vector3=rescue_platform.position-world.source_player_actor.position
				if tick<35 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
				world.sample_source_player_controls();world.tick_source_actors()
			release_controls()
			var reached: Dictionary=await walk_to(world,rescue_platform.position,right_delta,true,rescue_platform)
			fault=reached.get("fault","");release_controls()
			for tick in range(180):world.sample_source_player_controls();world.tick_source_actors()
			if fault.is_empty() and world.source_pickup_counts[2]!=carried_gobbos+3:fault="Raised platform did not yield third Gobbo"
		print("STAGE11_THIRD_GOBBO: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
	if fault.is_empty() and "--verify-room2-color" in OS.get_cmdline_user_args():
		var reached: Dictionary=await jump_to_point(world,Vector3(6,0,4.5),right_delta)
		fault=reached.get("fault","");release_controls()
		var platform: Node3D=null
		for actor in world.source_actors:
			if actor.source_name=="PlatformDead" and actor.position.x<6:platform=actor;break
		if platform==null:fault="Missing room2 colored-crystal platform"
		if fault.is_empty():
			for tick in range(20):world.sample_source_player_controls();world.tick_source_actors()
			for tick in range(120):
				release_controls()
				var delta: Vector3=platform.position-world.source_player_actor.position
				var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
				var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
				if abs(difference)<80:break
				Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				world.sample_source_player_controls();world.tick_source_actors()
			for tick in range(60):
				release_controls()
				if tick<16:Input.action_press("jump")
				var delta: Vector3=platform.position-world.source_player_actor.position
				if tick<35 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
				world.sample_source_player_controls();world.tick_source_actors()
			release_controls()
			reached=await walk_to(world,platform.position,right_delta,true,platform)
			fault=reached.get("fault","");release_controls()
			for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
			if fault.is_empty() and (world.source_bonus_mask&4)==0:fault="Room2 colored crystal was not collected"
		print("STAGE11_ROOM2_COLOR: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts}))
	if fault.is_empty() and "--verify-fourth-gobbo" in OS.get_cmdline_user_args():
		for waypoint in [Vector3(6,0,4.5),Vector3(6,0,9)]:
			var reached: Dictionary=await walk_to(world,waypoint,right_delta,true)
			fault=reached.get("fault","");release_controls()
			if not fault.is_empty():break
		if fault.is_empty():
			var platforms: Array=world.source_actors.filter(func(actor):return actor.source_name=="PlatformSpin")
			if platforms.is_empty():fault="Missing rotating platforms"
			else:
				var reached: Dictionary=await walk_to(world,Vector3(6,0,9.8),right_delta)
				fault=reached.get("fault","");release_controls()
				if fault.is_empty():
					for tick in range(120):
						release_controls()
						var difference := wrapi(-int(world.source_player_actor.source_angles.y),-2048,2048)
						if abs(difference)<80:break
						Input.action_press("move_right" if difference*right_delta>0 else "move_left")
						world.sample_source_player_controls();world.tick_source_actors()
					release_controls()
					var intercept_ready := false
					for tick in range(600):
						release_controls()
						var difference := wrapi(-int(world.source_player_actor.source_angles.y),-2048,2048)
						if abs(difference)>80:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
						world.sample_source_player_controls();world.tick_source_actors()
						if abs(wrapi(-int(world.source_player_actor.source_angles.y),-2048,2048))<100 and platforms.any(func(a):return a.position.x>5.25 and a.position.x<5.35 and a.position.z<12):intercept_ready=true;break
					print("STAGE11_INTERCEPT_READY: ",intercept_ready," angle=",world.source_player_actor.source_angles.y)
					if not intercept_ready:fault="Near rotating-platform intercept did not align"
					for tick in range(30) if fault.is_empty() else []:
						if tick%5==0:print("STAGE11_SPIN_JUMP: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"angle":world.source_player_actor.source_angles.y,"clip":world.source_player_actor.clip_name,"platforms":platforms.map(func(a):return str(a.position))}))
						release_controls()
						if tick<16:Input.action_press("jump")
						if world.source_player_actor.position.z<11.65:Input.action_press("move_forward")
						world.sample_source_player_controls();world.tick_source_actors()
					release_controls()
					print("STAGE11_SPIN_LANDING: ",JSON.stringify({"position":str(world.source_player_actor.position),"inventory":world.source_pickup_counts,"contacts":world.source_contacts_at(world.source_player_actor.position+Vector3.UP,world.source_player_actor)}))
					if world.source_pickup_counts[3]!=route_starting_lives:fault="Timed rotating-platform jump lost a life"
		if fault.is_empty():
			var center: Node3D=null
			for actor in world.source_actors:
				if actor.source_name=="PlatformStepStone":center=actor;break
			if center==null:fault="Missing central stepping stone"
			else:
				for tick in range(120):
					release_controls()
					var delta: Vector3=center.position-world.source_player_actor.position
					var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
					var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
					if abs(difference)<100:break
					Input.action_press("move_right" if difference*right_delta>0 else "move_left")
					world.sample_source_player_controls();world.tick_source_actors()
				for tick in range(30):
					release_controls()
					if tick<16:Input.action_press("jump")
					var delta: Vector3=center.position-world.source_player_actor.position
					if Vector2(delta.x,delta.z).length()>0.3:Input.action_press("move_forward")
					world.sample_source_player_controls();world.tick_source_actors()
				release_controls()
				var reached: Dictionary=await walk_to(world,center.position,right_delta,true,center)
				fault=reached.get("fault","");release_controls()
		if fault.is_empty():
			var platforms: Array=world.source_actors.filter(func(actor):return actor.source_name=="PlatformSpin")
			var ready := false
			for tick in range(600):
				release_controls()
				var difference := wrapi(-int(world.source_player_actor.source_angles.y),-2048,2048)
				if abs(difference)>80:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				world.sample_source_player_controls();world.tick_source_actors()
				if abs(wrapi(-int(world.source_player_actor.source_angles.y),-2048,2048))<100 and platforms.any(func(a):return a.position.x>6.65 and a.position.x<6.75 and a.position.z>15):ready=true;break
			if not ready:fault="Far rotating-platform intercept did not align"
			else:
				for tick in range(30):
					release_controls()
					if tick<16:Input.action_press("jump")
					if world.source_player_actor.position.z<15.15:Input.action_press("move_forward")
					world.sample_source_player_controls();world.tick_source_actors()
				release_controls()
				print("STAGE11_FAR_SPIN_LANDING: ",JSON.stringify({"position":str(world.source_player_actor.position),"inventory":world.source_pickup_counts,"contacts":world.source_contacts_at(world.source_player_actor.position+Vector3.UP,world.source_player_actor)}))
				for tick in range(35):
					release_controls()
					if tick<16:Input.action_press("jump")
					if world.source_player_actor.position.z<18:Input.action_press("move_forward")
					world.sample_source_player_controls();world.tick_source_actors()
				release_controls()
				if world.source_pickup_counts[3]!=route_starting_lives:fault="Far rotating-platform crossing lost a life"
		if fault.is_empty():
			var reached: Dictionary=await walk_to(world,Vector3(6,0,18),right_delta,true)
			fault=reached.get("fault","");release_controls()
		if fault.is_empty():
			var box: Node3D=null
			for actor in world.source_actors:
				if actor.source_name=="SmashBlockGobbo":box=actor;break
			if box==null:fault="Missing fourth Gobbo box"
			else:
				var reached: Dictionary=await walk_to(world,box.position,right_delta,true,box)
				fault=reached.get("fault","");release_controls()
				if fault.is_empty():
					for tick in range(240):
						release_controls()
						if tick in [12,13,14,15,22,23]:Input.action_press("jump")
						world.sample_source_player_controls();world.tick_source_actors()
					release_controls()
					if world.source_pickup_counts[2]!=carried_gobbos+4:fault="Box route did not rescue fourth Gobbo"
		print("STAGE11_FOURTH_GOBBO: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
	if fault.is_empty() and "--verify-stage11-bonus-door" in OS.get_cmdline_user_args():
		if world.source_bonus_mask!=31 or world.source_pickup_counts[2]!=5:fault="Bonus entry requires earned five colors and five Gobbos"
		if fault.is_empty():
			for waypoint in [Vector3(6,0,18),Vector3(9,0,18)]:
				var reached: Dictionary=await walk_to(world,waypoint,right_delta)
				fault=reached.get("fault","");release_controls()
				if not fault.is_empty():break
		if fault.is_empty():
			var reached: Dictionary=await walk_to(world,Vector3(13.5,0,18),right_delta,false,null,1.8,"MP011_04.MAP")
			fault=reached.get("fault","");release_controls()
		if fault.is_empty() and (world.source_bonus_mask!=31 or world.source_pickup_counts[2]!=5):fault="Bonus door transition lost earned inventory"
		print("STAGE11_BONUS_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts}))
	if fault.is_empty() and "--verify-bonus-spring" in OS.get_cmdline_user_args():
		for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
		print("STAGE11_BONUS_ACTORS: ",JSON.stringify(world.source_actors.map(func(a):return {"name":a.source_name,"position":str(a.position)})))
		var reached: Dictionary=await walk_to(world,Vector3(7.8,0,10.5),right_delta)
		fault=reached.get("fault","");release_controls()
		if fault.is_empty():
			for tick in range(120):
				release_controls()
				var difference := wrapi(3072-int(world.source_player_actor.source_angles.y),-2048,2048)
				if abs(difference)<80:break
				Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				world.sample_source_player_controls();world.tick_source_actors()
			var peak := 0.0
			var reached_bars := false
			for tick in range(240):
				release_controls()
				if tick<16:Input.action_press("jump")
				if tick<20 and world.source_player_actor.position.x>6.6:Input.action_press("move_forward")
				if tick>=20 and world.source_player_actor.position.y>1.8 and world.source_player_actor.position.x>4.2:Input.action_press("move_forward")
				var traversal_state: int=int(world.source_extended_globals.get(0,0))>>16
				if traversal_state==8:
					release_controls()
					if tick%2==0:Input.action_press("move_forward")
				elif traversal_state==9:release_controls()
				world.sample_source_player_controls();world.tick_source_actors()
				peak=maxf(peak,world.source_player_actor.position.y)
				if world.source_player_actor.position.x<4.7 and world.source_player_actor.position.y>2.4:reached_bars=true
				if tick%20==0:print("STAGE11_BONUS_SPRING_TRACE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"state":int(world.source_extended_globals.get(0,0))>>16}))
			release_controls()
			if not reached_bars:fault="First bonus spring did not reach monkey-bar end"
			print("STAGE11_BONUS_SPRING: ",JSON.stringify({"fault":fault,"peak":peak,"position":str(world.source_player_actor.position)}))
	if fault.is_empty() and "--verify-bonus-upper-spring" in OS.get_cmdline_user_args():
		for waypoint in [Vector3(3.09,2.698,10.5)]:
			var reached: Dictionary=await walk_to(world,waypoint,right_delta)
			fault=reached.get("fault","");release_controls()
			if not fault.is_empty():break
		if fault.is_empty():
			for tick in range(120):
				release_controls()
				var difference := wrapi(2048-int(world.source_player_actor.source_angles.y),-2048,2048)
				if abs(difference)<80:break
				Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				world.sample_source_player_controls();world.tick_source_actors()
			var reached_ledge := false
			for tick in range(360):
				release_controls()
				if tick<8:Input.action_press("jump")
				if tick<20 and world.source_player_actor.position.z>9.37:Input.action_press("move_forward")
				if tick>=20 and world.source_player_actor.position.y>4.2 and world.source_player_actor.position.z>4.5:Input.action_press("move_forward")
				var state: int=int(world.source_extended_globals.get(0,0))>>16
				if state==8:
					release_controls()
					if tick%2==0:Input.action_press("move_forward")
				elif state==9:release_controls()
				world.sample_source_player_controls();world.tick_source_actors()
				if tick%30==0:print("STAGE11_UPPER_SPRING_TRACE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"state":state,"clip":world.source_player_actor.clip_name}))
				if world.source_player_actor.position.y>5 and world.source_player_actor.position.z<5.5 and (int(world.source_player_actor.secondary_flags)&2)!=0:reached_ledge=true;break
			release_controls()
			if not reached_ledge:fault="Upper bonus spring did not reach high ledge"
			print("STAGE11_UPPER_SPRING: ",JSON.stringify({"fault":fault,"position":str(world.source_player_actor.position)}))
	if fault.is_empty() and "--verify-sixth-gobbo" in OS.get_cmdline_user_args():
		for waypoint in [Vector3(3,5.25,4.5),Vector3(6,5.25,4.5),Vector3(6,5.25,5.5)]:
			var reached: Dictionary=await walk_to(world,waypoint,right_delta)
			fault=reached.get("fault","");release_controls()
			if not fault.is_empty():break
		if fault.is_empty():
			var reached: Dictionary=await jump_to_point(world,Vector3(7.5,5.427,7.402),right_delta)
			fault=reached.get("fault","");release_controls()
		if fault.is_empty():
			for tick in range(300):
				release_controls()
				if tick in [12,13,14,15] or tick>=22:Input.action_press("jump")
				world.sample_source_player_controls();world.tick_source_actors()
			release_controls()
			if world.source_pickup_counts[2]!=6:fault="Bonus tower did not yield sixth Gobbo"
		print("STAGE11_SIXTH_GOBBO: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
	if fault.is_empty() and "--audit-stage11-pickups" in OS.get_cmdline_user_args():print("STAGE_ENTITY_FLAGS: ",JSON.stringify(world.source_map_entity_flags))
	if fault.is_empty() and "--verify-stage11-gong" in OS.get_cmdline_user_args():
		var reached: Dictionary=await walk_to(world,Vector3(3,0,10.5),right_delta)
		fault=reached.get("fault","");release_controls()
		if fault.is_empty():
			for tick in range(1200):
				release_controls()
				if world.source_main_mode==4 and world.source_transition_state==0:
					var delta: Vector3=Vector3(3,0,9.6)-world.source_player_actor.position
					var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
					var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
					if abs(difference)>60:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
					if abs(difference)<160:Input.action_press("move_forward")
				if tick%40<4:Input.action_press("attack")
				if world.source_transition_state==3 and tick%40<4:Input.action_press("jump")
				world.sample_source_player_controls();world.tick_source_actors()
				if not world.process_source_exit():fault=world.source_transition_fault;break
				if world.source_main_mode==5 and world.source_fade_phase=="":break
				if tick%60==0:await process_frame
			release_controls()
			if world.source_main_mode!=5 or world.map_name!="MP100_01.MAP":fault="Stage11 gong did not return to selector"
			if int(world.source_menu_progress_flags.get(1,0))!=0x8006:fault="Stage11 completion was not credited to stage11"
			print("STAGE11_GONG_RESULT: ",JSON.stringify({"fault":fault,"room":world.map_name,"progress":world.source_menu_progress_flags,"selection":world.source_menu_state.selected_index}))
			if fault.is_empty() and "--verify-stage11-save" in OS.get_cmdline_user_args():fault=await verify_earned_campaign_roundtrip(world,"MP012_00.MAP")
	for actor in world.source_actors:
		if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
	if world.source_pickup_counts[3]!=route_starting_lives:fault="Stage11 route lost a life"
	print("STAGE11_FINAL_CHECK: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"room":world.map_name}))
	return fault

func collect_spring_far(world: Node,right_delta: int) -> String:
	var box: Node3D=null
	var floating: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="SmashBlockGobbo":box=actor
		if actor.source_name=="SmashBlockFloat" and actor.position.z>6:floating=actor
	if box==null or floating==null:return "Missing spring-room far boxes"
	for waypoint in [Vector3(9,0,6),Vector3(9,0,12)]:
		var approach: Dictionary=await walk_to(world,waypoint,right_delta)
		release_controls()
		if approach.has("fault"):return approach.fault
	var reached: Dictionary=await jump_to_point(world,Vector3(box.position.x,0.928711,box.position.z),right_delta)
	release_controls()
	if reached.has("fault"):return reached.fault
	var contacts: Dictionary=world.source_contacts_at(floating.position,world.source_player_actor)
	if contacts.lower.is_empty():return "Far floating box has no standing surface"
	var target: Vector3=floating.position
	target.y=int(contacts.lower.height_units)*world.CELL_METERS/4096.0
	reached=await jump_to_point(world,target,right_delta);release_controls()
	if reached.has("fault"):return reached.fault
	for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
	if world.source_bonus_mask!=25:return "Spring-room colors did not produce mask25"
	if "--verify-spring-boxes" in OS.get_cmdline_user_args():
		var reward_fault: String=await stomp_reward_box(world,floating)
		if not reward_fault.is_empty():return reward_fault
	reached=await walk_to(world,box.position,right_delta,false,box);release_controls()
	if reached.has("fault"):return reached.fault
	if "--verify-spring-extra-life" in OS.get_cmdline_user_args():
		var platform: Node3D=null
		for actor in world.source_actors:
			if actor.source_name=="PlatformDead":platform=actor;break
		if platform==null:return "Missing extra-life platform"
		var lives_before: int=world.source_pickup_counts[3]
		var support: Dictionary=world.source_contacts_at(platform.position,world.source_player_actor)
		if support.lower.is_empty():return "Extra-life platform has no standing surface"
		var life_target: Vector3=platform.position
		life_target.y=int(support.lower.height_units)*world.CELL_METERS/4096.0
		reached=await jump_to_point(world,life_target,right_delta);release_controls()
		if reached.has("fault"):return reached.fault
		for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
		if world.source_pickup_counts[3]!=lives_before+1:return "Spring-room extra life did not increment lives"
		route_starting_lives=lives_before+1
		print("STAGE11_EXTRA_LIFE: ",JSON.stringify({"before":lives_before,"after":world.source_pickup_counts[3],"position":str(world.source_player_actor.position)}))
		reached=await jump_to_point(world,Vector3(box.position.x,0.928711,box.position.z),right_delta);release_controls()
		if reached.has("fault"):return reached.fault
	for tick in range(240):
		release_controls()
		if tick in [12,13,14,15,22,23]:Input.action_press("jump")
		world.sample_source_player_controls();world.tick_source_actors()
	release_controls()
	if world.source_pickup_counts[2]!=1:return "Spring-room box did not rescue Gobbo"
	return ""

func stomp_reward_box(world: Node,box: Node3D) -> String:
	var identity: int=box.get_instance_id()
	var expected: int=(int(box.vm.parameters[4 if box.source_name=="SmashBlockFloat" else 3])>>16)-1
	var before: int=world.source_pickup_counts[1]
	var name: String=box.source_name
	var spawned: Dictionary={}
	var prior: int=before
	var lives_before: int=world.source_pickup_counts[3]
	for tick in range(240):
		release_controls()
		if tick in [12,13,14,15] or (tick>=22 and tick<100):Input.action_press("jump")
		world.sample_source_player_controls();world.tick_source_actors()
		for actor in world.source_actors:
			if actor.source_name=="CrystalFall":spawned[actor.get_instance_id()]={"position":str(actor.position),"pc":actor.vm.pc}
		if world.source_pickup_counts[1]!=prior:
			print("STAGE11_REWARD_CHANGE: ",JSON.stringify({"tick":tick,"before":prior,"after":world.source_pickup_counts[1],"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name}))
			prior=int(world.source_pickup_counts[1])
	release_controls()
	var fault := ""
	if name=="SmashBlockFloat" and world.source_pickup_counts[1]<before+expected:
		var yaw_before: int=world.source_player_actor.source_angles.y
		for tick in range(12):
			Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
		release_controls()
		var direction_delta := wrapi(int(world.source_player_actor.source_angles.y)-yaw_before,-2048,2048)
		for attempt in range(expected):
			var remaining: Array=world.source_actors.filter(func(a):return a.source_name=="CrystalFall" and spawned.has(a.get_instance_id()) and a.vm.pc!=34)
			if remaining.is_empty():break
			remaining.sort_custom(func(a,b):return a.position.distance_squared_to(world.source_player_actor.position)<b.position.distance_squared_to(world.source_player_actor.position))
			var reached: Dictionary=await walk_to(world,remaining[0].position,direction_delta)
			fault=reached.get("fault","");release_controls()
			if not fault.is_empty():break
	if world.source_pickup_counts[3]<lives_before:fault="Held box stomp lost a life"
	if world.source_actors.any(func(a):return a.get_instance_id()==identity):fault="Reward box remains after stomp"
	if name=="SmashBlockFloat":
		var uncollected: Array=world.source_actors.filter(func(a):return a.source_name=="CrystalFall" and spawned.has(a.get_instance_id()) and a.vm.pc!=34)
		if spawned.size()!=expected or (spawned.values().any(func(record):return int(record.pc)!=34) and (world.source_pickup_counts[1]!=before+expected or not uncollected.is_empty())):fault="Floating rewards lack pickup-trigger or complete gathered-count proof"
	elif world.source_pickup_counts[1]!=before+expected:fault="Reward box crystal delta differs"
	print("STAGE11_REWARD_ACTORS: ",JSON.stringify({"spawned":spawned,"remaining":world.source_actors.filter(func(a):return a.source_name.begins_with("Crystal")).map(func(a):return {"name":a.source_name,"id":a.get_instance_id(),"position":str(a.position),"pc":a.vm.pc})}))
	print("STAGE11_BOX_REWARD: ",JSON.stringify({"fault":fault,"name":name,"expected":expected,"before":before,"after":world.source_pickup_counts[1]}))
	return fault

func jump_to_point(world: Node,target: Vector3,right_delta: int) -> Dictionary:
	release_controls()
	for tick in range(20):world.sample_source_player_controls();world.tick_source_actors()
	for tick in range(120):
		release_controls()
		var delta: Vector3=target-world.source_player_actor.position
		var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
		var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
		if abs(difference)<80:break
		Input.action_press("move_right" if difference*right_delta>0 else "move_left")
		world.sample_source_player_controls();world.tick_source_actors()
	if target.x==15 and world.map_name=="MP011_00.MAP":
		for tick in range(5):
			release_controls();Input.action_press("move_forward")
			world.sample_source_player_controls();world.tick_source_actors()
	for tick in range(60):
		if "--trace-platform-jump" in OS.get_cmdline_user_args() and tick%5==0:print("PLATFORM_JUMP_TRACE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"angle":world.source_player_actor.source_angles.y,"state":int(world.source_extended_globals.get(0,0))>>16,"clip":world.source_player_actor.clip_name}))
		release_controls()
		if tick<16:Input.action_press("jump")
		if "--stomp-worms" in OS.get_cmdline_user_args() and world.map_name=="MP012_06.MAP" and tick in [22,23]:
			for actor in world.source_actors:
				if actor.source_name=="Worm" and actor.position.distance_to(world.source_player_actor.position)<2.3:Input.action_press("jump");break
		if "--attack-nearby" in OS.get_cmdline_user_args() and tick%12<3:
			for actor in world.source_actors:
				if actor.source_name.begins_with("Dantini") and actor.position.distance_to(world.source_player_actor.position)<2.2:Input.action_press("attack");break
		var delta: Vector3=target-world.source_player_actor.position
		if tick<35 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
		world.sample_source_player_controls();world.tick_source_actors()
	release_controls()
	if world.source_pickup_counts[3]<route_starting_lives:return {"fault":"Explicit platform jump lost a life"}
	return await walk_to(world,target,right_delta)

func climb_key_platforms(world: Node,right_delta: int,require_key: bool) -> String:
	var fault := ""
	var platforms: Array=world.source_actors.filter(func(actor):return actor.source_name=="PlatformDead")
	platforms.sort_custom(func(a,b):return a.position.z<b.position.z)
	for platform in platforms:
		if platform.position.z>20 and not require_key and "--verify-keyroom-boxes" in OS.get_cmdline_user_args():break
		if platform==platforms[0] and not require_key and "--join-stage11-route" in OS.get_cmdline_user_args():
			var approach: Dictionary=await walk_to(world,Vector3(4.53,0,6.2),right_delta)
			fault=approach.get("fault","");release_controls()
			if not fault.is_empty():break
		if platform.position.z>20:
			for tick in range(100):
				release_controls()
				if tick%30<5:Input.action_press("attack")
				world.sample_source_player_controls();world.tick_source_actors()
			release_controls()
			var upper_box: Node3D=null
			for actor in world.source_actors:
				if actor.source_name=="SmashBlock" and actor.position.z>20:upper_box=actor;break
			if upper_box==null:fault="Missing key approach box";break
			var approach: Dictionary=await walk_to(world,upper_box.position,right_delta,false,upper_box)
			fault=approach.get("fault","");release_controls()
			if not fault.is_empty():break
		release_controls()
		for tick in range(20):world.sample_source_player_controls();world.tick_source_actors()
		for tick in range(120):
			release_controls()
			var delta: Vector3=platform.position-world.source_player_actor.position
			var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
			var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
			if abs(difference)<80:break
			Input.action_press("move_right" if difference*right_delta>0 else "move_left")
			world.sample_source_player_controls();world.tick_source_actors()
		release_controls()
		if platform!=platforms[0] or "--join-stage11-route" in OS.get_cmdline_user_args():
			for tick in range(60):
				release_controls()
				if tick<16:Input.action_press("jump")
				var delta: Vector3=platform.position-world.source_player_actor.position
				if tick<25 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
				world.sample_source_player_controls();world.tick_source_actors()
			release_controls()
		var reached: Dictionary=await walk_to(world,platform.position,right_delta,false,platform)
		fault=reached.get("fault","");release_controls()
		if not fault.is_empty():break
	if require_key and fault.is_empty() and world.source_level_script_state==0:fault="Platform route did not collect cage key"
	print("STAGE11_KEY_ROUTE: ",JSON.stringify({"fault":fault,"key":world.source_level_script_state,"position":str(world.source_player_actor.position)}))
	return fault


