extends SceneTree
func _initialize() -> void:call_deferred("probe")
func release_controls() -> void:
	for action in ["move_left","move_right","move_forward","move_back","jump","attack"]:Input.action_release(action)
func walk_to(world: Node, target: Vector3, right_delta: int, jump_gaps: bool = false, target_actor: Node3D = null, jump_distance: float = 1.8, expected_room: String = "", turn_tolerance: int = 40,stop_when: Callable=Callable()) -> Dictionary:
	var jump_age := -100
	var jump_hold := 8
	var lives: int=world.source_pickup_counts[3]
	var prior_gems: int=world.source_pickup_counts[1]
	var origin_room: String=world.map_name
	for tick in range(900):
		release_controls()
		if stop_when.is_valid() and bool(stop_when.call()):return {"reached":true,"event":true}
		if not expected_room.is_empty() and world.map_name!=origin_room:
			if world.map_name!=expected_room:return {"fault":"Route entered unexpected room "+world.map_name}
			world.sample_source_player_controls();world.tick_source_actors()
			if not world.process_source_exit():return {"fault":world.source_transition_fault}
			if world.source_fade_phase=="":return {"reached":true,"room":world.map_name}
			await process_frame;continue
		var player: Node3D=world.source_player_actor
		if is_instance_valid(target_actor):
			var standing: Dictionary=world.source_contacts_at(target_actor.position,player)
			if standing.lower.is_empty():return {"fault":"Moving route target has no standing surface"}
			target=Vector3(target_actor.position.x,int(standing.lower.height_units)*world.CELL_METERS/4096.0,target_actor.position.z)
		var delta := target-player.position
		var distance := Vector2(delta.x,delta.z).length()
		if expected_room.is_empty() and distance<0.25 and absf(delta.y)<0.3 and (int(player.secondary_flags)&2)!=0:return {"reached":true}
		var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
		var difference := wrapi(desired-int(player.source_angles.y),-2048,2048)
		var movement_angle := 60 if world.map_name == "MP010_04.MAP" else 200
		if turn_tolerance>40:movement_angle=turn_tolerance*2
		if distance>0.2:
			if abs(difference)>turn_tolerance:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
			if abs(difference)<movement_angle:Input.action_press("move_forward")
		if distance<jump_distance and delta.y>0.3 and tick-jump_age>60 and (int(player.secondary_flags)&2)!=0:jump_age=tick;jump_hold=24 if world.map_name == "MP010_04.MAP" else 8
		if jump_gaps and distance>1.0 and abs(difference)<movement_angle and tick-jump_age>20 and (int(player.secondary_flags)&2)!=0:
			var direction:=Vector3(delta.x,0,delta.z).normalized()
			var ahead: Vector3=player.position+direction*0.25+Vector3.UP*3
			var ahead_floor: Dictionary=world.source_raw_floor_query(ahead)
			var ahead_contacts: Dictionary=world.source_contacts_at(ahead,player)
			var support_too_high: bool=not ahead_contacts.lower.is_empty() and float(ahead_contacts.lower.get("height_units",0))*world.CELL_METERS/4096.0>player.position.y+0.2
			if int(ahead_floor.get("surface_type",-1))==4 and (ahead_contacts.lower.is_empty() or support_too_high):jump_age=tick;jump_hold=16
		if tick-jump_age<jump_hold:Input.action_press("jump")
		if expected_room == "MP010_04.MAP" and distance < 1.8 and tick % 60 == 0:
			Input.action_press("attack")
		if expected_room == "MP010_04.MAP" and distance < 1.8 and tick % 90 < 16:
			Input.action_press("jump")
		if jump_gaps and OS.get_cmdline_user_args().has("--trace-gap-jumps") and player.position.z>7.0 and player.position.z<12.5:
			print("GAP_JUMP_INPUT: ",JSON.stringify({"tick":tick,"position":str(player.position),"grounded":(int(player.secondary_flags)&2)!=0,"jump_age":tick-jump_age,"jump":Input.is_action_pressed("jump"),"clip":player.clip_name,"gems":world.source_pickup_counts[1]}))
			if tick-jump_age in [0,24] or tick%30==0:print("GAP_PLATFORM_POSITIONS: ",JSON.stringify(world.source_actors.filter(func(actor):return actor.source_name.begins_with("Platform")).map(func(actor):return {"name":actor.source_name,"position":str(actor.position)})))
		if (world.map_name.begins_with("MP011_") or world.map_name.begins_with("MP012_") or world.map_name.begins_with("MP013_") or world.map_name.begins_with("MP014_") or world.map_name.begins_with("MP018_")) and OS.get_cmdline_user_args().has("--climb-ledges"):
			var state: int=int(world.source_extended_globals.get(0,0))>>16
			if world.map_name.begins_with("MP014_") and state==11:
				release_controls()
				Input.action_press("move_forward")
			if state==8:
				release_controls()
				if tick%2==0:Input.action_press("move_forward")
			elif state==9:release_controls()
		if (world.map_name.begins_with("MP011_") or world.map_name.begins_with("MP013_") or world.map_name.begins_with("MP018_")) and OS.get_cmdline_user_args().has("--attack-nearby") and tick%12<3 and not (world.map_name=="MP018_01.MAP" and OS.get_cmdline_user_args().has("--early-stage18-dantini") and (int(world.source_map_entity_flags.get("MP018_01.MAP",{}).get(9,0))&1)!=0):
			for actor in world.source_actors:
				if (actor.source_name.begins_with("Dantini") or (world.map_name.begins_with("MP018_") and OS.get_cmdline_user_args().has("--first-visit-fire-jumpers") and actor.source_name=="FireJumper")) and actor.position.distance_to(player.position)<2.2:Input.action_press("attack");break
		if world.map_name.begins_with("MP012_") and OS.get_cmdline_user_args().has("--attack-rats") and (int(world.source_map_entity_flags.get("MP012_01.MAP",{}).get(9,0))&5)!=0 and tick%12<3:
			for actor in world.source_actors:
				if actor.source_name=="BigRat" and actor.position.distance_to(player.position)<2.2:Input.action_press("attack");break
		if world.map_name=="MP018_04.MAP" and OS.get_cmdline_user_args().has("--attack-fire-jumpers") and (int(world.source_map_entity_flags.get("MP018_01.MAP",{}).get(11,0))&2)!=0 and not ((OS.get_cmdline_user_args().has("--dodge-stage18-revisit-fire") or OS.get_cmdline_user_args().has("--fight-stage18-revisit-fire")) and player.position.x<12):
			for actor in world.source_actors:
				if actor.source_name=="FireJumper" and actor.position.distance_to(player.position)<2.8:Input.action_press("attack");break
		if world.map_name=="MP018_01.MAP" and OS.get_cmdline_user_args().has("--early-stage18-dantini") and (int(world.source_map_entity_flags.get("MP018_01.MAP",{}).get(9,0))&1)!=0 and tick%8<2:
			for actor in world.source_actors:
				if actor.source_name.begins_with("Dantini") and actor.position.distance_to(player.position)<1.9:Input.action_press("attack");break
		world.sample_source_player_controls();world.tick_source_actors()
		if world.map_name=="MP018_01.MAP" and OS.get_cmdline_user_args().has("--trace-stage18-dantini") and (int(world.source_map_entity_flags.get("MP018_01.MAP",{}).get(9,0))&1)!=0 and tick%5==0:
			print("STAGE18_DANTINI_TRACE: ",JSON.stringify({"tick":tick,"player":str(player.position),"clip":player.clip_name,"attack":Input.is_action_pressed("attack"),"held":world.source_input_held_mask,"enemies":world.source_actors.filter(func(a):return a.source_name.begins_with("Dantini") and a.position.distance_to(player.position)<5).map(func(a):return {"position":str(a.position),"pc":a.vm.pc,"model":a.model_name,"globals":a.vm.globals})}))
		if not expected_room.is_empty():
			if not world.process_source_exit():release_controls();return {"fault":world.source_transition_fault}
			if world.map_name!=origin_room:continue
		if int(world.source_pickup_counts[1])!=prior_gems:
			print("WALK_PICKUP_CHANGE: ",JSON.stringify({"tick":tick,"before":prior_gems,"after":world.source_pickup_counts[1],"position":str(player.position),"clip":player.clip_name}))
			prior_gems=int(world.source_pickup_counts[1])
		if int(world.source_pickup_counts[3])<lives:release_controls();return {"fault":"Walking route lost a life"}
		lives=maxi(lives,int(world.source_pickup_counts[3]))
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty():
				print("ROUTE_ACTOR_FAULT: ",JSON.stringify({"name":actor.source_name,"pc":actor.vm.pc,"instruction":actor.vm.instructions.get(actor.vm.pc,{}),"globals":actor.vm.globals,"parameters":actor.vm.parameters,"fault":actor.vm.fault}))
				release_controls();return {"fault":actor.source_name+": "+actor.vm.fault}
		if tick%60==0:print("UNDERGROUND_ROUTE_STEP: ",JSON.stringify({"tick":tick,"position":str(player.position),"target":str(target),"clip":player.clip_name}));await process_frame
	print("WALK_BLOCKED_GEOMETRY: ",JSON.stringify({"floor":world.source_raw_floor_query(world.source_player_actor.position+Vector3.UP*3),"contacts":world.source_contacts_at(world.source_player_actor.position+Vector3.UP*3,world.source_player_actor),"nearby":world.source_actors.filter(func(a):return a.position.distance_to(world.source_player_actor.position)<3).map(func(a):return {"name":a.source_name,"position":str(a.position),"primary":a.primary_flags,"secondary":a.secondary_flags,"pc":a.vm.pc})}))
	release_controls();return {"fault":"Walking route did not reach target"}
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
	if OS.get_cmdline_user_args().has("--verify-second-well-only"):
		await probe_second_well(world)
		return
	var player: Node3D=world.source_player_actor
	var gobbo: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="Gobbo":gobbo=actor;break
	if player==null or gobbo==null:world.queue_free();await process_frame;quit(1);return
	var starting: Vector3=player.position
	var goal: Vector3=gobbo.position
	var lives: int=world.source_pickup_counts[3]
	var earned_gems := 0;var earned_bonus := 0
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var prior_yaw: int=player.source_angles.y
	Input.action_press("move_right")
	for tick in range(10):world.sample_source_player_controls();world.tick_source_actors()
	release_controls()
	var right_delta: int=wrapi(int(player.source_angles.y)-prior_yaw,-2048,2048)
	var succeeded:=false;var fault:="";var jump_age:=-100
	if right_delta==0:fault="Sampled right input did not turn Croc"
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-opening-loose"):
		for waypoint in [Vector3(9.06,0,12.11),Vector3(12,0,14),Vector3(11.46,0.75,16.5),Vector3(12,0.75,18),Vector3(12.46,0.75,19.51),Vector3(12,0,14),Vector3(9,0,9)]:
			var reached: Dictionary=await walk_to(world,waypoint,right_delta)
			fault=reached.get("fault","");release_controls()
			if not fault.is_empty():break
		for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
		for index in [0,1,2,13,15]:
			if (int(world.source_map_entity_flags.get(world.map_name,{}).get(index,0))&4)==0:fault="Missing opening crystal marker "+str(index)
		print("EARNED_OPENING_LOOSE: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts}))
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-opening-colors"):
		var red: Node3D=null
		var blue_box: Node3D=null
		for actor in world.source_actors:
			if actor.source_name=="Crystal_S":red=actor
			if actor.source_name=="SmashBlock":blue_box=actor
		if red==null or blue_box==null:fault="Opening colored-crystal actors missing"
		if fault.is_empty():
			for waypoint in [Vector3(9,0,4.5),Vector3(2.4,0,4.5),Vector3(red.position.x,0,red.position.z)]:
				if not fault.is_empty():break
				var reached: Dictionary=await walk_to(world,waypoint,right_delta)
				fault=str(reached.get("fault",""));release_controls()
		if fault.is_empty():
			for waypoint in [Vector3(2.4,0,4.5),Vector3(9,0,4.5),Vector3(9,0,9)]:
				if not fault.is_empty():break
				var reached: Dictionary=await walk_to(world,waypoint,right_delta)
				fault=str(reached.get("fault",""));release_controls()
		if fault.is_empty():
			var reached: Dictionary=await walk_to(world,blue_box.position,right_delta,true,blue_box)
			fault=str(reached.get("fault",""));release_controls()
		if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-opening-box"):
			var instance: int=blue_box.get_instance_id()
			var gems: int=world.source_pickup_counts[1]
			var expected: int=(int(blue_box.vm.parameters[3])>>16)-1
			for tick in range(180):
				release_controls()
				if tick in [12,13,14,15,22,23]:Input.action_press("jump")
				world.sample_source_player_controls();world.tick_source_actors()
				if tick%30==0:await process_frame
			release_controls()
			if world.source_actors.any(func(actor):return actor.get_instance_id()==instance):fault="Opening box did not break"
			if world.source_pickup_counts[1]!=gems+expected:fault="Opening box crystals not fully collected"
			print("OPENING_BOX_REWARDS: ",JSON.stringify({"fault":fault,"expected":expected,"inventory":world.source_pickup_counts}))
		if fault.is_empty() and (int(world.source_bonus_mask)&17)!=17:fault="Opening route did not collect both red and blue crystals"
		print("OPENING_COLOR_ROUTE: ",JSON.stringify({"fault":fault,"mask":world.source_bonus_mask,"position":str(player.position),"inventory":world.source_pickup_counts}))
	for tick in range(1500):
		if not fault.is_empty():break
		release_controls()
		var delta: Vector3=goal-player.position
		var distance := Vector2(delta.x,delta.z).length()
		var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
		var difference := wrapi(desired-int(player.source_angles.y),-2048,2048)
		if distance>0.3:
			if abs(difference)>40:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
			if abs(difference)<200:Input.action_press("move_forward")
		if distance<1.8 and player.position.y<goal.y-0.3 and tick-jump_age>60 and (int(player.secondary_flags)&2)!=0:jump_age=tick
		if tick-jump_age<8:Input.action_press("jump")
		world.sample_source_player_controls();world.tick_source_actors()
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;break
		if int(world.source_pickup_counts[3])<lives:fault="Route lost a life"
		if int(world.source_pickup_counts[2])>0:succeeded=true;break
		if tick%60==0:print("FIRST_ROOM_ROUTE_STEP: ",JSON.stringify({"tick":tick,"position":str(player.position),"target":str(goal),"distance":distance,"yaw":player.source_angles.y,"right_delta":right_delta,"clip":player.clip_name}));await process_frame
	release_controls()
	if succeeded and fault.is_empty():
		for tick in range(600):
			world.sample_source_player_controls();world.tick_source_actors()
			if tick%30==0:await process_frame
		if world.source_actors.any(func(actor):return actor.source_name=="Gobbo"):fault="Gobbo rescue animation did not retire its actor"
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-optional-room"):
		fault=await run_first_stage_optional(world)
		player=world.source_player_actor
		if fault.is_empty():
			var lid: Node3D=null
			for actor in world.source_actors:
				if actor.source_name=="SmashLid":lid=actor;break
			if lid==null:fault="Optional return lost well lid"
			else:
				var approach: Dictionary=await walk_to(world,lid.position,right_delta,false,lid)
				fault=approach.get("fault","");release_controls()
	if succeeded and fault.is_empty() and (OS.get_cmdline_user_args().has("--verify-well-entry") or OS.get_cmdline_user_args().has("--verify-well-return") or OS.get_cmdline_user_args().has("--verify-first-box") or OS.get_cmdline_user_args().has("--verify-underground-gobbo")):
		var entered:=false
		for tick in range(300):
			if tick==0 or tick==8:Input.action_press("jump")
			if tick==3 or tick==12:Input.action_release("jump")
			world.sample_source_player_controls();world.tick_source_actors()
			if not world.process_source_exit():fault=world.source_transition_fault;break
			if world.map_name=="MP010_03.MAP" and world.source_fade_phase=="":entered=true;break
			if tick%30==0:await process_frame
		release_controls()
		if not entered and fault.is_empty():fault="Sampled slam from reached well lid did not enter underground room"
		print("FIRST_ROOM_WELL_ENTRY: ",JSON.stringify({"verified":entered and fault.is_empty(),"room":world.map_name,"gobbos":world.source_pickup_counts[2],"fault":fault}))
	if succeeded and fault.is_empty() and (OS.get_cmdline_user_args().has("--verify-first-box") or OS.get_cmdline_user_args().has("--verify-underground-gobbo")):
		for tick in range(90):world.sample_source_player_controls();world.tick_source_actors()
		var box: Node3D=null
		for candidate in world.source_actors:
			if candidate.source_name=="SmashBlock":box=candidate;break
		if box==null:fault="Missing first underground box"
		else:
			var box_id: int=box.source_pool_id
			var box_instance: int=box.get_instance_id()
			var top: Dictionary=world.source_contacts_at(box.position,world.source_player_actor)
			if top.lower.is_empty() or int(top.lower.get("actor",-1))!=box_id:fault="Missing first box standing surface"
			else:
				var route: Dictionary=await walk_to(world,Vector3(box.position.x,int(top.lower.height_units)*world.CELL_METERS/4096.0,box.position.z),right_delta)
				fault=str(route.get("fault",""));release_controls()
				if fault.is_empty():
					for tick in range(180):
						if tick==0 or tick==8:Input.action_press("jump")
						if tick==3 or tick==12:Input.action_release("jump")
						world.sample_source_player_controls();world.tick_source_actors()
						if tick%30==0:await process_frame
					# Slots are reused by spawned rewards; track the actual box instance.
					if world.source_actors.any(func(actor):return actor.get_instance_id()==box_instance):fault="Reached first box did not break and retire"
			print("FIRST_UNDERGROUND_BOX_ROUTE: ",JSON.stringify({"verified":fault.is_empty(),"position":str(world.source_player_actor.position),"bonus_mask":world.source_bonus_mask,"inventory":world.source_pickup_counts,"fault":fault}))
			earned_gems=int(world.source_pickup_counts[1]);earned_bonus=int(world.source_bonus_mask)
		if OS.get_cmdline_user_args().has("--inspect-underground-floor"):
			var floor_path: Array=[]
			for step in range(42):
				var z:=3.0+float(step)*0.5
				var point:=Vector3(6,4,z)
				var sample: Dictionary=world.source_raw_floor_query(point)
				var contacts: Dictionary=world.source_contacts_at(point,world.source_player_actor)
				floor_path.append({"z":z,"surface":sample.get("surface_type",-1),"height":sample.get("height_units",0),"lower_actor":contacts.lower})
			print("UNDERGROUND_FLOOR_PATH: ",JSON.stringify(floor_path))
		release_controls()
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-underground-gobbo"):
		var approach: Dictionary=await walk_to(world,Vector3(6,0,16),right_delta,true)
		fault=str(approach.get("fault",""));release_controls()
		var crumbling: Array=[]
		for candidate in world.source_actors:
			if candidate.source_name=="PlatformCrumble":crumbling.append(candidate)
		crumbling.sort_custom(func(a,b):return a.position.z<b.position.z)
		for platform in crumbling:
			if not fault.is_empty():break
			var standing: Dictionary=world.source_contacts_at(platform.position,world.source_player_actor)
			if standing.lower.is_empty():fault="Missing crumbling platform standing surface";break
			var crossed: Dictionary=await walk_to(world,Vector3(platform.position.x,int(standing.lower.height_units)*world.CELL_METERS/4096.0,platform.position.z),right_delta,true)
			fault=str(crossed.get("fault",""));release_controls()
		var gobbo_box: Node3D=null
		for candidate in world.source_actors:
			if candidate.source_name=="SmashBlockGobbo":gobbo_box=candidate;break
		if gobbo_box==null:fault="Missing underground Gobbo box"
		elif fault.is_empty():
			var gobbo_box_instance: int=gobbo_box.get_instance_id()
			var top: Dictionary=world.source_contacts_at(gobbo_box.position,world.source_player_actor)
			if top.lower.is_empty():fault="Missing Gobbo box standing surface"
			else:
				var route: Dictionary=await walk_to(world,Vector3(gobbo_box.position.x,int(top.lower.height_units)*world.CELL_METERS/4096.0,gobbo_box.position.z),right_delta,true)
				fault=str(route.get("fault",""));release_controls()
				if fault.is_empty():
					for tick in range(600):
						if tick==0 or tick==8:Input.action_press("jump")
						if tick==3 or tick==12:Input.action_release("jump")
						world.sample_source_player_controls();world.tick_source_actors()
						if tick%30==0:await process_frame
					if int(world.source_pickup_counts[2])<2:fault="Reached underground Gobbo box did not award rescue"
					if int(world.source_pickup_counts[1])<8:fault="Underground rescue route lost earned gems"
					if is_instance_valid(gobbo_box) and gobbo_box.get_instance_id()==gobbo_box_instance and not gobbo_box.model_surface_candidates_at(gobbo_box.position,world.source_player_actor).is_empty():fault="Broken Gobbo box retained a solid standing surface"
		print("UNDERGROUND_GOBBO_INPUT_ROUTE: ",JSON.stringify({"verified":fault.is_empty(),"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position),"fault":fault}))
		release_controls()
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-well-return"):
		if OS.get_cmdline_user_args().has("--verify-underground-gobbo"):
			earned_gems=int(world.source_pickup_counts[1]);earned_bonus=int(world.source_bonus_mask);lives=int(world.source_pickup_counts[3])
			var platforms: Array=[];var moving: Node3D=null
			for candidate in world.source_actors:
				if candidate.source_name=="PlatformCrumble":platforms.append(candidate)
				if candidate.source_name=="PlatformNormal":moving=candidate
			platforms.sort_custom(func(a,b):return a.position.z>b.position.z)
			for platform in platforms:
				if not fault.is_empty():break
				var crossed: Dictionary=await walk_to(world,platform.position,right_delta,true,platform)
				fault=str(crossed.get("fault",""));release_controls()
			if fault.is_empty():
				var middle: Dictionary=await walk_to(world,Vector3(6,0,14),right_delta,true)
				fault=str(middle.get("fault",""));release_controls()
			if fault.is_empty() and moving!=null:
				var crossed: Dictionary=await walk_to(world,moving.position,right_delta,true,moving)
				fault=str(crossed.get("fault",""));release_controls()
			if fault.is_empty():
				var entrance: Dictionary=await walk_to(world,Vector3(6,0,7),right_delta,true)
				fault=str(entrance.get("fault",""));release_controls()
			print("UNDERGROUND_RETURN_WALK: ",JSON.stringify({"verified":fault.is_empty(),"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position),"fault":fault}))
		for tick in range(90):world.sample_source_player_controls();world.tick_source_actors()
		if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-entrance-crystals"):
			for waypoint in [Vector3(1.5,0,4.5),Vector3(10.5,0,4.5)]:
				var reached: Dictionary=await walk_to(world,waypoint,right_delta)
				fault=reached.get("fault","");release_controls()
				if not fault.is_empty():break
			for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
			for index in range(13,19):
				if (int(world.source_map_entity_flags.get(world.map_name,{}).get(index,0))&4)==0:fault="Missing entrance crystal marker "+str(index)
			print("EARNED_ENTRANCE_CRYSTALS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts}))
		var elevator: Node3D=null
		for candidate in world.source_actors:
			if candidate.source_name=="UpExit":elevator=candidate;break
		if elevator==null:fault="Missing elevator"
		var returned:=false
		for tick in range(1800):
			if not fault.is_empty():break
			release_controls()
			if world.map_name=="MP010_03.MAP" and world.source_input_suppression_count==0 and is_instance_valid(elevator):
				var current: Node3D=world.source_player_actor
				var delta: Vector3=elevator.position-current.position
				var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
				var difference := wrapi(desired-int(current.source_angles.y),-2048,2048)
				if Vector2(delta.x,delta.z).length()>0.2:
					if abs(difference)>40:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
					if abs(difference)<200:Input.action_press("move_forward")
			world.sample_source_player_controls();world.tick_source_actors()
			if not world.process_source_exit():fault=world.source_transition_fault;break
			if world.map_name=="MP010_00.MAP" and world.source_fade_phase=="":returned=true;break
			if tick%30==0:await process_frame
		release_controls()
		if not returned and fault.is_empty():fault="Walking to elevator did not complete ride"
		if returned:
			print("WELL_RETURN_INVENTORY_BOUNDARY: ",JSON.stringify({"inventory":world.source_pickup_counts,"bonus_mask":world.source_bonus_mask,"earned_gems":earned_gems,"earned_bonus":earned_bonus}))
			if int(world.source_pickup_counts[1])<earned_gems or (int(world.source_bonus_mask)&earned_bonus)!=earned_bonus:fault="Well transition discarded earned pickups"
			Input.action_press("move_forward");Input.action_press("jump")
			var prior_gems: int=world.source_pickup_counts[1]
			for tick in range(90):
				if tick==8:Input.action_release("jump")
				world.sample_source_player_controls();world.tick_source_actors()
				if int(world.source_pickup_counts[1])!=prior_gems:
					var contacts: Array=[]
					for candidate in world.source_actors:
						var count: int=world.source_player_contact_counts.get(candidate.source_pool_id,0)
						if count>0:contacts.append({"name":candidate.source_name,"count":count})
					print("POST_RETURN_PICKUP_CHANGE: ",JSON.stringify({"tick":tick,"before":prior_gems,"after":world.source_pickup_counts[1],"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"contacts":contacts}))
					prior_gems=int(world.source_pickup_counts[1])
				if not OS.get_cmdline_user_args().has("--trace-post-return") and tick>=8 and Vector2(world.source_player_actor.position.x-goal.x,world.source_player_actor.position.z-goal.z).length()>1.6:break
			release_controls()
			if world.source_input_suppression_count!=0 or Vector2(world.source_player_actor.position.x-goal.x,world.source_player_actor.position.z-goal.z).length()<1.5:fault="Returned Croc could not leave the well"
		print("FIRST_ROOM_WELL_RETURN: ",JSON.stringify({"verified":returned and fault.is_empty(),"room":world.map_name,"position":str(world.source_player_actor.position),"gobbos":world.source_pickup_counts[2],"suppression":world.source_input_suppression_count,"fault":fault}))
	if int(world.source_pickup_counts[3])<lives:fault="Route lost a life"
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-next-room"):
		if world.map_name!="MP010_00.MAP":fault="Next-room route requires return to main room"
		else:
			for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
			var crest: Dictionary=world.source_raw_floor_query(Vector3(12,4,18))
			for waypoint in [Vector3(12,int(crest.height_units)*world.CELL_METERS/4096.0,18),Vector3(12,0,21),Vector3(12,0,24)]:
				if not fault.is_empty():break
				var crossed: Dictionary=await walk_to(world,waypoint,right_delta,true,null,2.7)
				fault=str(crossed.get("fault",""));release_controls()
			var entered:=false
			for tick in range(180):
				if not fault.is_empty():break
				world.sample_source_player_controls();world.tick_source_actors()
				if not world.process_source_exit():fault=world.source_transition_fault;break
				if world.map_name=="MP010_01.MAP" and world.source_fade_phase=="":entered=true;break
				if tick%30==0:await process_frame
			if not entered and fault.is_empty():fault="Reached main-room door did not enter next room"
			print("FIRST_STAGE_NEXT_ROOM_ROUTE: ",JSON.stringify({"verified":entered and fault.is_empty(),"room":world.map_name,"inventory":world.source_pickup_counts,"fault":fault}))
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-third-gobbo"):
		if world.map_name!="MP010_01.MAP":fault="Third-Gobbo route requires normal room1 entry"
		else:
			for tick in range(90):world.sample_source_player_controls();world.tick_source_actors()
			for waypoint in [Vector3(3,0,9),Vector3(3,0,6)]:
				if not fault.is_empty():break
				var reached: Dictionary=await walk_to(world,waypoint,right_delta,true)
				fault=str(reached.get("fault",""));release_controls()
			var platforms: Array=[]
			for candidate in world.source_actors:
				if candidate.source_name in ["PlatformDead","PlatformCrumble"]:platforms.append(candidate)
			platforms.sort_custom(func(a,b):return a.position.x<b.position.x)
			for platform in platforms:
				if not fault.is_empty():break
				var reached: Dictionary=await walk_to(world,platform.position,right_delta,true,platform)
				fault=str(reached.get("fault",""));release_controls()
			var rescue: Node3D=null
			for candidate in world.source_actors:
				if candidate.source_name=="Gobbo":rescue=candidate;break
			if rescue==null and fault.is_empty():fault="Missing room1 Gobbo"
			if fault.is_empty():
				var reached: Dictionary=await walk_to(world,rescue.position,right_delta,true)
				fault=str(reached.get("fault",""));release_controls()
				for tick in range(600):
					world.sample_source_player_controls();world.tick_source_actors()
					if tick%30==0:await process_frame
				if int(world.source_pickup_counts[2])<3:fault="Room1 route did not rescue third Gobbo"
			print("THIRD_GOBBO_INPUT_ROUTE: ",JSON.stringify({"verified":fault.is_empty(),"room":world.map_name,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position),"fault":fault}))
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-third-gobbo-box"):
		fault=await collect_ordinary_boxes(world,right_delta)
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-room-two"):
		if world.map_name!="MP010_01.MAP":fault="Room2 route requires room1 traversal"
		else:
			var door: Dictionary=await walk_to(world,Vector3(24,0,6),right_delta,true)
			fault=str(door.get("fault",""));release_controls()
			var entered:=false
			for tick in range(180):
				if not fault.is_empty():break
				world.sample_source_player_controls();world.tick_source_actors()
				if not world.process_source_exit():fault=world.source_transition_fault;break
				if world.map_name=="MP010_02.MAP" and world.source_fade_phase=="":entered=true;break
				if tick%30==0:await process_frame
			if not entered and fault.is_empty():fault="Room1 exit did not enter room2"
			print("FIRST_STAGE_ROOM_TWO_ROUTE: ",JSON.stringify({"verified":entered and fault.is_empty(),"room":world.map_name,"inventory":world.source_pickup_counts,"bonus_mask":world.source_bonus_mask,"fault":fault}))
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-room-two-boxes"):
		for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
		fault=await collect_ordinary_boxes(world,right_delta)
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-fourth-gobbo"):
		if world.map_name!="MP010_02.MAP":fault="Fourth-Gobbo route requires normal room2 entry"
		else:
			for tick in range(90):world.sample_source_player_controls();world.tick_source_actors()
			for waypoint in [Vector3(9,0,6),Vector3(6,0,6),Vector3(6,0,13)]:
				if not fault.is_empty():break
				var crossed: Dictionary=await walk_to(world,waypoint,right_delta,true)
				fault=str(crossed.get("fault",""));release_controls()
			var rescue: Node3D=null
			for candidate in world.source_actors:
				if candidate.source_name=="Gobbo":rescue=candidate;break
			if rescue==null and fault.is_empty():fault="Missing room2 Gobbo"
			if fault.is_empty():
				var crossed: Dictionary=await walk_to(world,rescue.position,right_delta,true)
				fault=str(crossed.get("fault",""));release_controls()
				for tick in range(600):
					world.sample_source_player_controls();world.tick_source_actors()
					if tick%30==0:await process_frame
				if int(world.source_pickup_counts[2])<4:fault="Room2 route did not rescue fourth Gobbo"
			print("FOURTH_GOBBO_INPUT_ROUTE: ",JSON.stringify({"verified":fault.is_empty(),"room":world.map_name,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position),"fault":fault}))
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-worm-room"):
		if world.map_name!="MP010_02.MAP":fault="Worm entrance requires room2"
		else:
			for waypoint in [Vector3(6,0,14),Vector3(6,0,6),Vector3(14,0,8),Vector3(15,0,10)]:
				if not fault.is_empty():break
				var crossed: Dictionary=await walk_to(world,waypoint,right_delta,true)
				fault=str(crossed.get("fault",""));release_controls()
			if fault.is_empty():
				var entered: Dictionary=await walk_to(world,Vector3(15,0,12),right_delta,false,null,1.8,"MP010_04.MAP")
				fault=str(entered.get("fault",""));release_controls()
			print("WORM_ROOM_INPUT_ROUTE: ",JSON.stringify({"verified":fault.is_empty(),"room":world.map_name,"inventory":world.source_pickup_counts,"fault":fault}))
	if succeeded and fault.is_empty() and OS.get_cmdline_user_args().has("--verify-fifth-gobbo"):
		if world.map_name != "MP010_04.MAP" or int(world.source_pickup_counts[2]) != 4:
			fault = "Fifth Gobbo requires continuous four-Gobbo route into room4"
		else:
			await probe_second_well(world,true)
			return
	if OS.get_cmdline_user_args().has("--inspect-main-route") and world.map_name=="MP010_00.MAP":
		var rows: Array=[]
		for z in range(12,25):
			var samples: Array=[]
			for x in range(3,22,3):
				var sample: Dictionary=world.source_raw_floor_query(Vector3(x,4,z))
				samples.append([x,sample.get("surface_type",-1),sample.get("height_units",0),sample.get("tile",-1)])
			rows.append({"z":z,"samples":samples})
		print("MAIN_ROUTE_FLOOR_GRID: ",JSON.stringify(rows))
	print("FIRST_ROOM_ROUTE: ",JSON.stringify({"starting":str(starting),"ending":str(world.source_player_actor.position),"inventory":world.source_pickup_counts,"bonus_mask":world.source_bonus_mask,"fault":fault,"verified":succeeded and fault.is_empty(),"scope":"native room entry and sampled movement/jump inputs; no player teleport, angle/state writes or seeded pickups; selected opening/underground pickups and optional well return, full stage and collectible completeness not verified"}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if succeeded and fault.is_empty() else 1)
func probe_second_well(world: Node, continuous: bool = false) -> void:
	for tick in range(180): world.sample_source_player_controls();world.tick_source_actors()
	var box: Node3D = null
	for a in world.source_actors:
		if a.source_name == "SmashBlockFloatGobbo": box = a
	var fault := ""
	var initial_lives: int = world.source_pickup_counts[3]
	var initial_gobbos: int = world.source_pickup_counts[2]
	var id: int = box.source_pool_id if box != null else -1
	if box != null:
		print("FLOATING_BOX_COLLISION_RECORDS: ",JSON.stringify(box.model_data.models[0].get("collision",{})))
	print("PLAYER_LEDGE_TRIGGERS: ",JSON.stringify(world.source_player_actor.event_triggers))
	var prior: int = world.source_player_actor.source_angles.y
	Input.action_press("move_right")
	world.sample_source_player_controls();world.tick_source_actors();release_controls()
	var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
	var platforms: Array = world.source_actors.filter(func(a):return a.source_name == "PlatformCrumble" and absf(a.position.x-6.0)<0.1)
	platforms.sort_custom(func(a,b):return a.position.z<b.position.z)
	for platform in platforms:
		if not fault.is_empty():break
		var result: Dictionary = await walk_to(world,platform.position,right_delta,true,platform,1.8,"",40)
		fault = str(result.get("fault",""))
		if not fault.is_empty():break
	if fault.is_empty():
		var result: Dictionary = await walk_to(world,Vector3(6,0.4,12.2),right_delta,false,null,1.8,"",80 if OS.get_cmdline_user_args().has("--verify-second-well-crystals") else 40)
		fault = str(result.get("fault",""))
	if fault.is_empty():
		var stomp_age := -1
		for tick in range(240):
			release_controls()
			var player: Node3D = world.source_player_actor
			var delta := box.position-player.position
			var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
			var difference := wrapi(desired-int(player.source_angles.y),-2048,2048)
			if abs(difference)>(80 if OS.get_cmdline_user_args().has("--verify-second-well-crystals") else 40):Input.action_press("move_right" if difference*right_delta>0 else "move_left")
			if abs(difference)<200 and Vector2(delta.x,delta.z).length()>0.15:Input.action_press("move_forward")
			if tick%60<24 and (int(world.source_extended_globals.get(0,0))>>16) not in [5,7,11]:Input.action_press("jump")
			# Authored state 8 tests a NEW up press (ASL 9321), not held up.
			# Release for one sampled tick before asking Croc to climb the ledge.
			if (int(world.source_extended_globals.get(0,0))>>16) == 8:
				release_controls()
				if tick%2==0:Input.action_press("move_forward")
			if (int(world.source_extended_globals.get(0,0))>>16) == 9:
				release_controls()
			if stomp_age < 0 and (int(world.source_extended_globals.get(0,0))>>16) == 1 and int(player.source_ground.get("actor",-1)) == id and (player.secondary_flags&2)!=0:
				stomp_age = 0
			if stomp_age >= 0:
				release_controls()
				# Settle after climbing; jump, release, and jump again to stomp.
				if stomp_age in [12,13,14,15,22,23]:Input.action_press("jump")
				stomp_age += 1
			world.sample_source_player_controls();world.tick_source_actors()
			if not player.vm.fault.is_empty():
				fault=player.vm.fault
				print("CLIMB_SCRIPT_FAULT: ",JSON.stringify({"fault":fault,"pc":player.vm.pc,"instruction":player.vm.instructions.get(player.vm.pc,{})}))
				break
			if tick%20==0:print("LEDGE_CLIP_PROGRESS: ",JSON.stringify({"tick":tick,"state":int(world.source_extended_globals.get(0,0))>>16,"frame":player.clip_frame,"playing":player.clip_playing,"primary":player.primary_flags,"vm":player.vm.status,"fault":player.vm.fault}))
			if tick < 30:
				if player.source_movement_status == 2561:
					print("LEDGE_BRANCH_CONDITION: ",JSON.stringify({"tick":tick,"value":player.vm.evaluate(player.vm.instructions[5951].args[0]),"globals":player.vm.globals}))
				print("BOX_LEDGE_TRACE: ",JSON.stringify({"tick":tick,"state":int(world.source_extended_globals.get(0,0))>>16,"movement":player.source_movement_status,"ceiling":player.source_ceiling_type,"yaw":player.source_angles.y,"wall_angle":player.source_wall_angle,"falling":(player.primary_flags&0x400)!=0,"contacts":world.source_contacts_at(player.position,player),"pc":player.vm.pc}))
			if tick%5==0:
				print("FLOATING_BOX_INPUT: ",JSON.stringify({"tick":tick,"position":str(player.position),"clip":player.clip_name,"attack":world.source_extended_globals.get(1,0),"rise_remaining":player.source_rise_remaining,"vertical_speed":player.source_vertical_speed,"ground":player.source_ground,"box_flags":box.secondary_flags,"box_pc":box.vm.pc}))
				await process_frame
			if not world.source_pool.slots.has(id):break
		if fault.is_empty() and world.source_pool.slots.has(id):fault="Floating box survived sampled jump attack"
	release_controls()
	if fault.is_empty():
		for tick in range(90):
			if OS.get_cmdline_user_args().has("--verify-second-well-return"):
				if tick%24==0:Input.action_press("attack")
				if tick%24==4:Input.action_release("attack")
			world.sample_source_player_controls();world.tick_source_actors()
			if tick%30==0:await process_frame
		release_controls()
		print("POST_BOX_RESCUE: ",JSON.stringify({"position":str(world.source_player_actor.position),"inventory":world.source_pickup_counts,"nearby":world.source_actors.filter(func(a):return a.position.distance_to(world.source_player_actor.position)<4).map(func(a):return {"name":a.source_name,"position":str(a.position),"pc":a.vm.pc})}))
		if int(world.source_pickup_counts[2]) != initial_gobbos+1:fault="Floating box Gobbo was not rescued"
		if (world.source_bonus_mask&8)==0:fault="Floating box color crystal was not collected"
		if continuous and OS.get_cmdline_user_args().has("--verify-opening-colors") and world.source_bonus_mask!=31:fault="Continuous route did not retain all five colored crystals"
		if int(world.source_pickup_counts[3]) != initial_lives:fault="Floating box route lost a life"
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;break
	print("SECOND_WELL_BOX_ROUTE: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"bonus_mask":world.source_bonus_mask,"lives_preserved":int(world.source_pickup_counts[3])==initial_lives,"scope":"continuous opening route through fifth Gobbo" if continuous else "direct room entry and sampled traversal; not continuous opening route"}))
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-second-well-return"):
		var inventory_before: Dictionary=world.source_pickup_counts.duplicate()
		var colors_before: int=world.source_bonus_mask
		var crossed: Dictionary={}
		if OS.get_cmdline_user_args().has("--verify-second-well-crystals"):
			for waypoint in [Vector3(6,0.45,11.8125),Vector3(4.5,0.45,10.3125),Vector3(6,0.45,9.2625),Vector3(7.59,0.45,7.646),Vector3(6,0.45,6.65625)]:
				var result: Dictionary=await walk_to(world,waypoint,right_delta,true,null,1.8,"",80)
				fault=result.get("fault","");release_controls()
				if not fault.is_empty():break
			for index in [9,10]:
				if (int(world.source_map_entity_flags.get(world.map_name,{}).get(index,0))&4)==0:fault="Missing second-well crystal marker "+str(index)
			print("EARNED_SECOND_WELL_CRYSTALS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts}))
			platforms=[]
		platforms.sort_custom(func(a,b):return a.position.z>b.position.z)
		for platform in platforms:
			if not fault.is_empty():break
			crossed=await walk_to(world,platform.position,right_delta,true,platform,1.8,"",80)
			fault=str(crossed.get("fault",""));release_controls()
		if fault.is_empty():
			crossed=await walk_to(world,Vector3(6,0,4),right_delta,true,null,1.8,"",80)
			fault=str(crossed.get("fault",""));release_controls()
		if fault.is_empty():
			crossed=await walk_to(world,Vector3(6,0,0.7),right_delta,false,null,1.8,"MP010_02.MAP")
			fault=str(crossed.get("fault",""));release_controls()
		if fault.is_empty() and (world.source_input_suppression_count!=0 or world.source_pickup_counts[2]!=inventory_before[2] or world.source_bonus_mask!=colors_before):fault="Second-well return lost controls or collectibles"
		print("SECOND_WELL_RETURN_ROUTE: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"bonus_mask":world.source_bonus_mask,"position":str(world.source_player_actor.position)}))
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-crystal-door"):
		if world.map_name!="MP010_02.MAP" or world.source_bonus_mask!=31:fault="Crystal door route requires return with five earned crystals"
		if fault.is_empty():
			var crossed: Dictionary=await walk_to(world,Vector3(15,0,13.6),right_delta,true,null,2.7)
			fault=str(crossed.get("fault",""));release_controls()
		if fault.is_empty():
			var crossed: Dictionary=await walk_to(world,Vector3(15,0,18),right_delta,false,null,1.8,"MP010_05.MAP")
			fault=str(crossed.get("fault",""));release_controls()
		print("CRYSTAL_DOOR_INPUT_ROUTE: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"bonus_mask":world.source_bonus_mask,"position":str(world.source_player_actor.position)}))
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-sixth-gobbo"):
		if world.map_name!="MP010_05.MAP" or world.source_pickup_counts[2]!=5:fault="Sixth Gobbo requires continuous earned bonus entry"
		else:fault=await run_first_stage_bonus(world)
	if fault.is_empty() and "--from-earned-stage10" in OS.get_cmdline_user_args():fault=await continue_earned_stage(world)
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if fault.is_empty() else 1)

func run_first_stage_bonus(world: Node, direct_entry: bool = false) -> String:
	var initial_gobbos: int=world.source_pickup_counts[2]
	var initial_lives: int=world.source_pickup_counts[3]
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var fault := ""
	var prior: int=world.source_player_actor.source_angles.y
	Input.action_press("move_right")
	world.sample_source_player_controls();world.tick_source_actors();release_controls()
	var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
	var spring: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="Spring" and actor.position.x<6:spring=actor;break
	if spring==null:fault="Missing key spring"
	if fault.is_empty():
		var crossed: Dictionary=await walk_to(world,Vector3(4.2,3.45,4.8),right_delta)
		fault=str(crossed.get("fault",""));release_controls()
	if fault.is_empty():
		var jump_age := -100
		for tick in range(360):
			release_controls()
			var delta: Vector3=spring.position-world.source_player_actor.position
			var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
			var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
			var distance := Vector2(delta.x,delta.z).length()
			if (world.source_player_actor.secondary_flags&2)!=0 and tick-jump_age>40:
				if abs(difference)>80:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				else:jump_age=tick
			if tick-jump_age<8:Input.action_press("jump")
			if tick-jump_age<25 and distance>0.45:Input.action_press("move_forward")
			world.sample_source_player_controls();world.tick_source_actors()
			for actor in world.source_actors:
				if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;print("BONUS_ACTOR_FAULT: ",JSON.stringify({"name":actor.source_name,"instruction":actor.vm.instructions.get(actor.vm.pc,{}),"fault":actor.vm.fault}));break
			if not fault.is_empty():break
			if tick%20==0:
				for actor in world.source_actors:
					if actor.source_name=="KeyForCageFloat":print("KEY_ACTOR_TRACE: ",JSON.stringify({"position":str(actor.position),"pc":actor.vm.pc,"flags":actor.primary_flags,"secondary":actor.secondary_flags,"contact":world.source_player_contact_counts.get(actor.source_pool_id,0),"fault":actor.vm.fault}))
			if tick%20==0:print("KEY_SPRING_TRACE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"key":world.source_level_script_state,"clip":world.source_player_actor.clip_name}))
			if world.source_level_script_state!=0 and (not OS.get_cmdline_user_args().has("--verify-bonus-extras") or not world.source_actors.any(func(actor):return actor.source_name=="Crystal" and actor.position.x<6)):break
		release_controls()
		if fault.is_empty() and world.source_level_script_state==0:fault="Spring route did not collect cage key"
	print("BONUS_KEY_ROUTE: ",JSON.stringify({"fault":fault,"key":world.source_level_script_state,"scope":"direct bonus-room entry" if direct_entry else "continuous earned bonus-room entry"}))
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-bonus-extras"):
		for actor in world.source_actors:
			if actor.source_name=="Spring" and actor.position.x>6:spring=actor;break
		var crossed: Dictionary=await walk_to(world,Vector3(7.8,3.45,4.8),right_delta)
		fault=str(crossed.get("fault",""));release_controls()
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-bonus-extras"):
		var jump_age := -100
		for tick in range(360):
			release_controls()
			var delta: Vector3=spring.position-world.source_player_actor.position
			var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
			var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
			var distance := Vector2(delta.x,delta.z).length()
			if (world.source_player_actor.secondary_flags&2)!=0 and tick-jump_age>40:
				if abs(difference)>80:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				else:jump_age=tick
			if tick-jump_age<8:Input.action_press("jump")
			if tick-jump_age<25 and distance>0.45:Input.action_press("move_forward")
			world.sample_source_player_controls();world.tick_source_actors()
			for actor in world.source_actors:
				if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;print("BONUS_ACTOR_FAULT: ",JSON.stringify({"name":actor.source_name,"instruction":actor.vm.instructions.get(actor.vm.pc,{}),"fault":actor.vm.fault}));break
			if not fault.is_empty():break
			if tick%20==0:
				for actor in world.source_actors:
					if actor.source_name=="KeyForCageFloat":print("KEY_ACTOR_TRACE: ",JSON.stringify({"position":str(actor.position),"pc":actor.vm.pc,"flags":actor.primary_flags,"secondary":actor.secondary_flags,"contact":world.source_player_contact_counts.get(actor.source_pool_id,0),"fault":actor.vm.fault}))
			if tick%20==0:print("KEY_SPRING_TRACE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"key":world.source_level_script_state,"clip":world.source_player_actor.clip_name}))
			if not world.source_actors.any(func(actor):return actor.source_name=="Crystal" and actor.position.x>6):break
		release_controls()
		if fault.is_empty() and world.source_actors.any(func(actor):return actor.source_name=="Crystal" and actor.position.x>6):fault="Right spring crystals remain"
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-bonus-extras"):
		for waypoint in [Vector3(9,3.6,3),Vector3(6,3.6,3)]:
			var crossed: Dictionary=await walk_to(world,waypoint,right_delta)
			fault=str(crossed.get("fault",""));release_controls()
			if not fault.is_empty():break
	if fault.is_empty():
		var crossed: Dictionary=await walk_to(world,Vector3(6,3.6,8.2 if OS.get_cmdline_user_args().has("--verify-bonus-extras") else 7.5),right_delta)
		fault=str(crossed.get("fault",""));release_controls()
	if fault.is_empty():
		if OS.get_cmdline_user_args().has("--verify-bonus-extras"):
			for tick in range(30):world.sample_source_player_controls();world.tick_source_actors()
		var jump_tick := -100
		var rode := false
		for tick in range(600):
			release_controls()
			var player: Node3D=world.source_player_actor
			var delta:=Vector3(6.12 if OS.get_cmdline_user_args().has("--verify-bonus-extras") else 6,player.position.y,9.75)-player.position
			var desired:=roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
			var difference:=wrapi(desired-int(player.source_angles.y),-2048,2048)
			if int(world.source_extended_globals.get(6,0))==0 and not rode:
				if abs(difference)>80:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				elif tick-jump_tick>60:jump_tick=tick
				if tick-jump_tick<(16 if OS.get_cmdline_user_args().has("--verify-bonus-extras") else 8):Input.action_press("jump")
				if tick-jump_tick<25 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
			world.sample_source_player_controls();world.tick_source_actors()
			rode=rode or int(world.source_extended_globals.get(6,0))!=0
			for actor in world.source_actors:
				if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;print("BONUS_ACTOR_FAULT: ",JSON.stringify({"name":actor.source_name,"instruction":actor.vm.instructions.get(actor.vm.pc,{}),"fault":actor.vm.fault}));break
			if not fault.is_empty():break
			if tick%30==0 or (OS.get_cmdline_user_args().has("--trace-bonus-ride") and tick<90):print("BONUS_RIDE_TRACE: ",JSON.stringify({"tick":tick,"position":str(player.position),"ride":world.source_extended_globals.get(6,0),"state":world.source_extended_globals.get(0,0),"lives":world.source_pickup_counts[3],"pc":player.vm.pc,"secondary":player.secondary_flags,"ceiling":player.source_ceiling_type,"clip":player.clip_name}))
			if rode and player.position.z>15 and int(world.source_extended_globals.get(6,0))==0:break
		release_controls()
		if fault.is_empty() and (not rode or world.source_player_actor.position.z<15):fault="Balloon ride did not reach far platform"
	print("BONUS_RIDE_ROUTE: ",JSON.stringify({"fault":fault,"position":str(world.source_player_actor.position),"key":world.source_level_script_state}))
	if fault.is_empty():
		var crossed: Dictionary=await walk_to(world,Vector3(6,3.6,18.09375),right_delta)
		fault=str(crossed.get("fault",""));release_controls()
		for tick in range(180):
			world.sample_source_player_controls();world.tick_source_actors()
			if tick%30==0:await process_frame
		if fault.is_empty() and world.source_pickup_counts[2]!=initial_gobbos+1:fault="Cage route did not rescue Gobbo"
	print("BONUS_CAGE_ROUTE: ",JSON.stringify({"fault":fault,"position":str(world.source_player_actor.position),"inventory":world.source_pickup_counts,"key":world.source_level_script_state}))
	if fault.is_empty() and world.source_pickup_counts[3]!=initial_lives:fault="Bonus room route lost a life"
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-bonus-extras"):
		var seed: Node3D=null
		for actor in world.source_actors:
			if actor.source_name=="SeedRed":seed=actor;break
		if seed==null:fault="Missing bonus extra life"
		else:
			var crossed: Dictionary=await walk_to(world,Vector3(seed.position.x,3.6,seed.position.z),right_delta)
			fault=str(crossed.get("fault",""));release_controls()
			for tick in range(90):world.sample_source_player_controls();world.tick_source_actors()
			if fault.is_empty() and world.source_pickup_counts[3]!=initial_lives+1:fault="Bonus extra life was not collected"
		for index in range(5,12):
			if (int(world.source_map_entity_flags.get("MP010_05.MAP",{}).get(index,0))&4)==0:fault="Missing bonus crystal marker "+str(index)
		print("BONUS_EXTRAS_ROUTE: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts}))
	if fault.is_empty():print("STAGE_ENTITY_FLAGS: ",JSON.stringify(world.source_map_entity_flags))
	if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-gong-exit"):
		if OS.get_cmdline_user_args().has("--verify-bonus-extras"):
			for waypoint in [Vector3(6,3.6,18),Vector3(6,3.6,20)]:
				var approach: Dictionary=await walk_to(world,waypoint,right_delta)
				fault=approach.get("fault","");release_controls()
				if not fault.is_empty():break
		var crossed: Dictionary=await walk_to(world,Vector3(6,3.6,21.3),right_delta)
		fault=str(crossed.get("fault",""));release_controls()
		for tick in range(1200):
			if not fault.is_empty():break
			release_controls()
			if world.source_main_mode==4 and is_instance_valid(world.source_player_actor) and world.source_transition_state==0 and OS.get_cmdline_user_args().has("--verify-bonus-extras"):
				var delta: Vector3 = Vector3(6,3.6,21.8811)-world.source_player_actor.position
				var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
				var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
				if abs(difference)>60:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
				if abs(difference)<160:Input.action_press("move_forward")
			if tick%40<4:Input.action_press("attack")
			if world.source_transition_state==3 and tick%40<4:Input.action_press("jump")
			world.sample_source_player_controls();world.tick_source_actors()
			if not world.process_source_exit():fault=world.source_transition_fault;break
			for actor in world.source_actors:
				if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;break
			if world.source_main_mode==5 and world.source_fade_phase=="":break
			if tick%60==0:print("GONG_EXIT_TRACE: ",JSON.stringify({"tick":tick,"mode":world.source_main_mode,"transition":world.source_transition_state,"fade":world.source_fade_phase,"room":world.map_name}));await process_frame
		release_controls()
		if fault.is_empty() and (world.source_main_mode!=5 or world.map_name!="MP100_01.MAP"):fault="Gong did not return to island selector"
		print("GONG_EXIT_ROUTE: ",JSON.stringify({"fault":fault,"room":world.map_name,"mode":world.source_main_mode,"progress":world.source_menu_progress_flags,"selection":world.source_menu_state.selected_index,"inventory":world.source_pickup_counts}))
		if fault.is_empty() and int(world.source_menu_progress_flags.get(0,0))!=(0x8000|initial_gobbos+1):fault="Gong did not retain earned rescues/completion"
		if fault.is_empty() and OS.get_cmdline_user_args().has("--verify-earned-save"):
			fault=await verify_earned_campaign_roundtrip(world)
	return fault

func verify_earned_campaign_roundtrip(world: Node, expected_next_room: String = "MP011_00.MAP") -> String:
	var directory := "user://earned-route-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	world.source_options_save_path=slots.slot_path(0)
	var expected_lives: int=world.source_pickup_counts[3]
	var expected_flags: int=world.source_menu_progress_flags.get(0,0)
	var expected_campaign_flags: Dictionary=world.source_menu_progress_flags.duplicate(true)
	var expected_selection: int=world.source_menu_state.selected_index
	var fault := ""
	world.set_process(true);world.set_physics_process(true)
	for frame in range(30):await physics_frame
	for row in range(2):
		Input.action_press("move_back")
		for frame in range(4):await physics_frame
		Input.action_release("move_back")
		for frame in range(12):await physics_frame
	if world.source_menu_state.dialog_mode!=2:fault="Earned selector did not reach Save option"
	if fault.is_empty():
		Input.action_press("jump")
		for frame in range(4):await physics_frame
		Input.action_release("jump")
		for frame in range(180):
			await physics_frame
			if world.source_main_mode==11 and world.source_fade_phase=="":break
		if world.source_main_mode!=11:fault="Earned selector did not open Save screen"
	if fault.is_empty():
		Input.action_press("jump")
		for frame in range(4):await physics_frame
		Input.action_release("jump")
		for frame in range(180):
			await physics_frame
			if world.source_main_mode==5:break
		if world.source_main_mode!=5:fault="Saving earned campaign did not return to selector"
	world.set_process(false);world.set_physics_process(false);release_controls()
	var saved := preload("res://source_save_store.gd").new(slots.slot_path(1)).read_record()
	if fault.is_empty() and not saved.has("record"):fault="Earned campaign save missing"
	if fault.is_empty():
		var decoded := preload("res://source_campaign_save.gd").decode(saved.record)
		if decoded.get("flags",[]).size()!=46 or decoded.lives!=expected_lives or decoded.selection!=expected_selection:fault="Saved campaign differs from earned state"
		if fault.is_empty():
			for index in range(46):
				if decoded.flags[index]!=int(expected_campaign_flags.get(index,0)):fault="Saved campaign flag differs at "+str(index);break
	if fault.is_empty():
		var restored=load("res://imported.tscn").instantiate()
		restored.source_options_save_path=slots.slot_path(1)
		root.add_child(restored);await process_frame
		restored.set_process(false);restored.set_physics_process(false)
		if not restored.load_source_campaign():fault="Fresh world could not load earned campaign"
		elif restored.source_menu_progress_flags.get(0,0)!=expected_flags or restored.source_pickup_counts[3]!=expected_lives or restored.source_menu_state.selected_index!=expected_selection:fault="Fresh load lost earned progress"
		if fault.is_empty():
			for index in range(46):
				if int(restored.source_menu_progress_flags.get(index,0))!=int(expected_campaign_flags.get(index,0)):fault="Loaded campaign flag differs at "+str(index);break
		if fault.is_empty():
			restored.set_process(true);restored.set_physics_process(true)
			for frame in range(60):await physics_frame
			Input.action_press("jump")
			for frame in range(4):await physics_frame
			Input.action_release("jump")
			for frame in range(180):
				await physics_frame
				if restored.map_name==expected_next_room and restored.source_fade_phase=="":break
			if restored.map_name!=expected_next_room or restored.source_main_mode!=4:fault="Loaded campaign cannot enter earned next stage"
		print("EARNED_CAMPAIGN_RELOAD: ",JSON.stringify({"fault":fault,"room":restored.map_name,"progress":restored.source_menu_progress_flags,"lives":restored.source_pickup_counts[3]}))
		restored.stop_imported_audio();restored.queue_free();await process_frame
	if fault.is_empty() and expected_next_room=="MP018_00.MAP" and "--retain-earned-secret-save" in OS.get_cmdline_user_args():
		var bytes := FileAccess.get_file_as_bytes(slots.slot_path(1))
		var checkpoint_path := "res://../build/goal-earned-secret-checkpoint.save"
		var checkpoint := FileAccess.open(checkpoint_path,FileAccess.WRITE)
		if checkpoint==null:fault="Cannot preserve verified earned checkpoint"
		else:
			checkpoint.store_buffer(bytes);checkpoint.close()
			var digest := HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes)
			var proof := {"scope":"Unchanged bytes from sampled Save menu; all flags/lives/selection checked through fresh backend load and earned secret entry","path":ProjectSettings.globalize_path(checkpoint_path),"sha256":digest.finish().hex_encode(),"lives":expected_lives,"selection":expected_selection,"progress":expected_campaign_flags}
			var proof_file := FileAccess.open("res://../build/goal-earned-secret-checkpoint-proof.json",FileAccess.WRITE)
			if proof_file==null:fault="Cannot record earned checkpoint provenance"
			else:proof_file.store_string(JSON.stringify(proof));proof_file.close()
			print("EARNED_CHECKPOINT_PRESERVED: ",JSON.stringify(proof))
	for entry in slots.list_slots():
		if FileAccess.file_exists(entry.path):DirAccess.remove_absolute(entry.path)
	if DirAccess.dir_exists_absolute(directory):DirAccess.remove_absolute(directory)
	print("EARNED_CAMPAIGN_SAVE: ",JSON.stringify({"fault":fault,"expected_progress":expected_flags,"expected_lives":expected_lives,"expected_selection":expected_selection,"scope":"sampled Save menu, fresh-world backend load, sampled next-stage entry"}))
	return fault

func run_first_stage_optional(world: Node) -> String:
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var platform: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="PlatformCheat1":platform=actor
	if platform==null:return "Missing optional-entry platform"

	print("OPTIONAL_PLATFORM_STATE: ",JSON.stringify({"position":str(platform.position),"pc":platform.vm.pc,"parameters":platform.vm.parameters,"player":str(world.source_player_actor.position)}))
	var prior: int=world.source_player_actor.source_angles.y
	Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors();release_controls()
	var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
	var fault := ""
	for actor_name in ["SmashLid","PlatformDead","PlatformCheat1"]:
		var target: Node3D=null
		for actor in world.source_actors:
			if actor.source_name==actor_name:target=actor;break
		release_controls()
		for tick in range(20):world.sample_source_player_controls();world.tick_source_actors()
		for tick in range(120):
			release_controls()
			var delta: Vector3=target.position-world.source_player_actor.position
			var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
			var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
			if abs(difference)<60:break
			Input.action_press("move_right" if difference*right_delta>0 else "move_left")
			world.sample_source_player_controls();world.tick_source_actors()
		release_controls()
		if actor_name in ["PlatformCheat1","PlatformDead"]:
			for tick in range(60):
				release_controls()
				if tick<(16 if actor_name=="PlatformDead" else 8):Input.action_press("jump")
				var delta: Vector3=target.position-world.source_player_actor.position
				if tick<24 and Vector2(delta.x,delta.z).length()>0.45:Input.action_press("move_forward")
				world.sample_source_player_controls();world.tick_source_actors()
			release_controls()
			print("OPTIONAL_PLATFORM_LANDING: ",str(world.source_player_actor.position))
			continue
		var route: Dictionary=await walk_to(world,target.position,right_delta,false,target)
		fault=route.get("fault","")
		if not fault.is_empty():break
	for tick in range(600):
		if not fault.is_empty():break
		release_controls()
		if tick%80 in [12,13,14,15,22,23]:Input.action_press("jump")
		world.sample_source_player_controls();world.tick_source_actors()
		if not world.process_source_exit():fault=world.source_transition_fault;break
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;break
		if world.map_name=="MP010_06.MAP" and world.source_fade_phase=="":break
		if tick%40==0:print("OPTIONAL_TRIGGER_TRACE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"counter":platform.vm.parameters[7] if is_instance_valid(platform) else -1}));await process_frame
	release_controls()
	if fault.is_empty() and world.map_name!="MP010_06.MAP":fault="Three-stomp route did not enter optional room"
	print("OPTIONAL_ROOM_ROUTE: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
	var room_entry_counts: Dictionary=world.source_pickup_counts.duplicate()
	if fault.is_empty():
		for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
		print("OPTIONAL_ROOM_CONTENTS: ",JSON.stringify(world.source_actors.map(func(actor):return {"name":actor.source_name,"position":str(actor.position),"id":actor.get_instance_id()})))
		var crystals: Array=[]
		for actor in world.source_actors:
			if actor.source_name=="Crystal":crystals.append({"position":actor.position,"id":actor.get_instance_id()})
		for crystal in crystals:
			var contacts: Dictionary=world.source_raw_floor_query(crystal.position)
			if contacts.is_empty():fault="Crystal has no floor";break
			var target: Vector3=crystal.position
			target.y=int(contacts.height_units)*world.CELL_METERS/4096.0
			var result: Dictionary=await walk_to(world,target,right_delta)
			fault=result.get("fault","");release_controls()
			if not fault.is_empty():break
			for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
			if world.source_actors.any(func(actor):return actor.get_instance_id()==crystal.id):fault="Authored crystal was not collected";break
		print("OPTIONAL_CRYSTALS_ROUTE: ",JSON.stringify({"fault":fault,"authored":crystals.size(),"inventory":world.source_pickup_counts}))
	if fault.is_empty():
		var boxes: Array=world.source_actors.filter(func(actor):return actor.source_name=="SmashBlock_Red")
		for box in boxes:
			if box.position.x<10:
				var corner: Dictionary=await walk_to(world,Vector3(6,3.6,15),right_delta)
				fault=corner.get("fault","");release_controls()
				if not fault.is_empty():break
			var box_id: int=box.get_instance_id()
			var result: Dictionary=await walk_to(world,box.position,right_delta,false,box)
			fault=result.get("fault","");release_controls()
			if not fault.is_empty():break
			for tick in range(160):
				release_controls()
				if tick%80 in [12,13,14,15,22,23]:Input.action_press("jump")
				world.sample_source_player_controls();world.tick_source_actors()
				if tick%30==0:await process_frame
			release_controls()
			if world.source_actors.any(func(actor):return actor.get_instance_id()==box_id):fault="Red box not broken";break
		print("OPTIONAL_BOXES_ROUTE: ",JSON.stringify({"fault":fault,"boxes":boxes.size(),"inventory":world.source_pickup_counts,"actors":world.source_actors.map(func(actor):return {"name":actor.source_name,"position":str(actor.position)})}))
	if fault.is_empty():
		for waypoint in [Vector3(12,3.6,6),Vector3(15,3.6,6),Vector3(15,3.6,10.5)]:
			var result: Dictionary=await walk_to(world,waypoint,right_delta)
			fault=result.get("fault","");release_controls()
			if not fault.is_empty():break
		if fault.is_empty():
			var result: Dictionary=await walk_to(world,Vector3(18,3.6,10.5),right_delta,false,null,1.8,"MP010_00.MAP")
			fault=result.get("fault","");release_controls()
		if fault.is_empty() and (world.source_pickup_counts[1]!=room_entry_counts[1]+12 or world.source_pickup_counts[2]!=room_entry_counts[2] or world.source_pickup_counts[3]!=room_entry_counts[3]+3):fault="Optional rewards differ from twelve crystals and three extra lives"
		print("OPTIONAL_RETURN_ROUTE: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
	return fault



func collect_ordinary_boxes(world: Node, right_delta: int) -> String:
	var boxes: Array=world.source_actors.filter(func(actor):return actor.source_name=="SmashBlock")
	if world.map_name=="MP011_01.MAP":boxes.sort_custom(func(a,b):return a.position.y>b.position.y)
	var fault := ""
	for box in boxes:
		if world.map_name=="MP011_01.MAP" and box.position.y<2:
			var descent: Dictionary=await walk_to(world,Vector3(6,0,4.52),right_delta)
			fault=descent.get("fault","");release_controls()
			if not fault.is_empty():break
		var instance: int=box.get_instance_id()
		var gems: int=world.source_pickup_counts[1]
		var expected: int=(int(box.vm.parameters[3])>>16)-1
		var reached: Dictionary=await walk_to(world,box.position,right_delta,false,box)
		fault=reached.get("fault","");release_controls()
		if not fault.is_empty():break
		for tick in range(180):
			release_controls()
			if tick in [12,13,14,15,22,23]:Input.action_press("jump")
			world.sample_source_player_controls();world.tick_source_actors()
			if tick%30==0:await process_frame
		release_controls()
		if world.source_actors.any(func(actor):return actor.get_instance_id()==instance):fault="Box remains after stomp"
		if world.source_pickup_counts[1]!=gems+expected:fault="Spawned crystal count differs from box reward"
		print("ORDINARY_BOX_REWARD: ",JSON.stringify({"fault":fault,"expected":expected,"before":gems,"after":world.source_pickup_counts[1]}))
		if not fault.is_empty():break
	print("ORDINARY_BOX_ROUTE: ",JSON.stringify({"fault":fault,"boxes":boxes.size(),"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
	return fault

func continue_earned_stage(_world: Node) -> String:
	return "No earned-stage continuation provided"
