extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
	var world=load("res://imported.tscn").instantiate()
	world.source_menu_state.selected_index=38
	root.add_child(world);await process_frame;world.set_physics_process(false)
	if not world.imported or world.source_player_actor==null:quit(1);return
	var chain: bool=OS.get_cmdline_user_args().has("--verify-chain")
	var valid: bool=not chain or world.map_name=="MP047_02.MAP"
	var phase_count:=0
	for phase in range(3 if chain else 1):
		if not valid:break
		valid=await run_phase(world)
		if valid:phase_count+=1
	if chain:print("DANTE_CHAIN: ",JSON.stringify({"phases":phase_count,"verified":valid and phase_count==3,"room":world.map_name,"transition":world.source_transition_state,"lives":world.source_pickup_counts[3],"scope":"continuous three-phase state with controlled positions; arena traversal and ending not simulated"}))
	if valid and (OS.get_cmdline_user_args().has("--verify-ending-entry") or OS.get_cmdline_user_args().has("--verify-ending")):
		var entered:=false
		for tick in range(1800):
			if not world.source_stage_stats_state.is_empty():world.advance_source_stage_stats(0x800200 if tick%60==30 else 0)
			if not world.process_source_exit():valid=false;break
			if is_instance_valid(world.source_cutscene_screen):entered=true;break
			if tick%30==0:await process_frame
		valid=valid and entered and int(world.source_ending_root)==15 and int(world.source_cutscene_progress.get("scene",-1))==15 and (int(world.source_menu_progress_flags.get(39,0))&0x8000)!=0 and int(world.source_pickup_counts[3])==3
		print("DANTE_EARNED_ENDING_ENTRY: ",JSON.stringify({"verified":valid,"root":world.source_ending_root,"scene":world.source_cutscene_progress.get("scene",-1),"progress_flag":world.source_menu_progress_flags.get(39,0),"lives":world.source_pickup_counts[3],"fault":world.source_transition_fault,"scope":"same fight world through native stats/fade into ending15; uninterrupted playback and credits not simulated"}))
	if valid and OS.get_cmdline_user_args().has("--verify-ending"):
		var completed_frames: Dictionary={}
		for tick in range(2800):
			if not is_instance_valid(world.source_cutscene_screen):break
			var display: Node3D=world.source_cutscene_screen
			var scene: int=int(world.source_cutscene_progress.scene)
			if not world.process_source_sad_cutscene(1.0/30.0):valid=false;break
			completed_frames[scene]=int(display.session.player.last_index)
			if tick%120==0:print("DANTE_ENDING_PROGRESS: ",JSON.stringify({"tick":tick,"scene":scene,"frame":completed_frames[scene]}))
			await process_frame
		valid=valid and completed_frames=={15:1006,19:1496} and world.source_main_mode==7 and is_instance_valid(world.source_credits_screen) and world.source_main_menu_credits_available
		if valid:
			for tick in range(10000):
				if not is_instance_valid(world.source_credits_screen):break
				if not world.process_source_credits(1.0/30.0):valid=false;break
				if tick%60==0:await process_frame
			valid=valid and world.source_main_mode==5 and not is_instance_valid(world.source_credits_screen) and world.terrain.visible and world.source_main_menu_credits_available
		print("DANTE_EARNED_ENDING_COMPLETE: ",JSON.stringify({"verified":valid,"completed_frames":completed_frames,"mode":world.source_main_mode,"room":world.map_name,"fault":world.source_transition_fault,"scope":"controlled combat followed by full native ending and credits steps; headset realtime and campaign travel not simulated"}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if valid else 1)
func run_phase(world, profile: Dictionary = {}) -> bool:
	var second_phase: bool=world.map_name=="MP047_03.MAP"
	var third_phase: bool=world.map_name=="MP047_04.MAP"
	if profile.is_empty() and world.map_name not in ["MP047_02.MAP","MP047_03.MAP","MP047_04.MAP"]:return false
	if not profile.is_empty() and world.map_name != str(profile.room):return false
	var boss_name: String="BossDantePart3" if third_phase else "BossDantePart2" if second_phase else "BossDante"
	var health_index: int=1 if third_phase else 23 if second_phase else 12
	var vulnerability_index: int=3 if third_phase else 27 if second_phase else 8
	var cooldown_index: int=5 if third_phase else 24 if second_phase else 13
	var destination: String="MP047_04.MAP" if second_phase else "MP047_03.MAP"
	if not profile.is_empty():
		boss_name=str(profile.name);health_index=int(profile.health);vulnerability_index=int(profile.vulnerability);cooldown_index=int(profile.cooldown)
	var initial_clips: Array=[]
	# The preceding transition check already stepped the next room60 ticks.
	# Avoid a second stationary wait in the live lightning encounter.
	var settle_ticks: int=0 if OS.get_cmdline_user_args().has("--verify-chain") and (second_phase or third_phase) else 60
	for tick in range(settle_ticks):
		world.sample_source_player_controls();world.tick_source_actors()
		if OS.get_cmdline_user_args().has("--trace-entry") and not initial_clips.has(world.source_player_actor.clip_name):
			initial_clips.append(world.source_player_actor.clip_name)
			print("DANTE_ENTRY: ",JSON.stringify({"tick":tick,"clip":world.source_player_actor.clip_name,"position":[world.source_player_actor.position.x,world.source_player_actor.position.y,world.source_player_actor.position.z],"ground":world.source_player_actor.source_ground,"flags":world.source_player_actor.primary_flags,"transition":world.source_transition_state,"lives":world.source_pickup_counts[3]}))
	var boss: Node3D=null
	for candidate in world.source_actors:
		if candidate.source_name==boss_name:boss=candidate;break
	if boss==null:return false
	var contact_actor: Node3D=boss
	if profile.has("contact_name"):
		contact_actor=null
		for candidate in world.source_actors:
			if candidate.source_name==str(profile.contact_name):contact_actor=candidate;break
		if contact_actor==null:return false
	var stomp_actor: Node3D=null
	if profile.has("stomp_contact"):
		for candidate in world.source_actors:
			if candidate.source_name==str(profile.stomp_contact):stomp_actor=candidate;break
		if stomp_actor==null:return false
	var player: Node3D=world.source_player_actor
	var safe_points: Array[Vector3]=[]
	for track in world.room_data.tracks:
		var point:=Vector3(float(track.position[0])*world.CELL_METERS,1,float(track.position[2])*world.CELL_METERS)
		var floor_sample: Dictionary=world.source_raw_floor_query(point)
		if int(floor_sample.get("tile",-1))>=0 and int(floor_sample.get("surface_type",-1))==0:
			point.y=float(floor_sample.height_units)*world.CELL_METERS/4096.0;safe_points.append(point)
	var initial_lives: int=world.source_pickup_counts[3]
	if third_phase or profile.has("avoid_prefix"):
		safe_points.clear()
		for x in range(5,20,2):
			for z in range(5,20,2):
				var point:=Vector3(x,1,z)
				var floor_sample: Dictionary=world.source_raw_floor_query(point)
				if int(floor_sample.get("tile",-1))>=0 and int(floor_sample.get("surface_type",-1))==0 and int(floor_sample.height_units)==0:
					point.y=float(floor_sample.height_units)*world.CELL_METERS/4096.0;safe_points.append(point)
	var health_words: Array=[];var attack_age: int=-1;var cooldown:=0;var attacks:=0;var contacts:=0
	var failure:="";var won:=false
	var last_player_clip: String = player.clip_name
	var contact_trace: Array=[]
	var stomping:=false
	if safe_points.is_empty():failure="No authored safe floor for controlled fixture"
	for tick in range(int(profile.get("ticks",6000))):
		if not failure.is_empty():break
		if not is_instance_valid(boss):
			boss=null
			if bool(profile.get("replace_boss",false)):
				for candidate in world.source_actors:
					if candidate.source_name==boss_name:boss=candidate;break
			if boss==null:
				failure="Boss actor retired without a matching next phase: "+str(world.source_actors.map(func(actor):return actor.source_name));break
			if not profile.has("contact_name"):contact_actor=boss
		var safe: Vector3=safe_points[0]
		for point in safe_points:
			if point.distance_squared_to(boss.position)>safe.distance_squared_to(boss.position):safe=point
		var approach_allowed: bool=not profile.has("approach_state_index") or int(boss.vm.globals.get(int(profile.get("approach_state_index",-1)),0))==(int(profile.get("approach_state",0))<<16)
		if profile.has("near_distance") and approach_allowed:
			var near: Vector3=boss.position+Vector3(0,0,float(profile.near_distance))
			var near_floor: Dictionary=world.source_raw_floor_query(near)
			if int(near_floor.get("tile",-1))>=0 and int(near_floor.get("surface_type",-1))==0:
				near.y=float(near_floor.height_units)*world.CELL_METERS/4096.0;safe=near
		if third_phase or profile.has("avoid_prefix"):
			var best_clearance := -1.0
			for point in safe_points:
				var clearance: float=point.distance_squared_to(boss.position)
				for hazard in world.source_actors:
					if hazard.source_name.begins_with(str(profile.get("avoid_prefix","Dante"))):clearance=minf(clearance,point.distance_squared_to(hazard.position))
				if clearance>best_clearance:best_clearance=clearance;safe=point
		var vulnerable: bool=int(boss.vm.globals.get(vulnerability_index,0))!=0 and int(boss.vm.globals.get(cooldown_index,0))==0
		var stomp_ready: bool=profile.has("stomp_state") and int(boss.vm.globals.get(0,0))==(int(profile.get("stomp_state",-1))<<16)
		if (vulnerable or stomp_ready) and attack_age<0 and cooldown==0:attack_age=0;attacks+=1;stomping=stomp_ready
		if attack_age>=0:
			if stomping:
				Input.action_release("attack")
				if attack_age<3 or attack_age in range(8,12):Input.action_press("jump")
				else:Input.action_release("jump")
			else:
				Input.action_release("jump")
				if attack_age<3:Input.action_press("attack")
				else:Input.action_release("attack")
			var active_contact: Node3D=stomp_actor if stomping else contact_actor
			var overlap: bool=attack_age in range(13,25) if stomping else attack_age in range(4,16)
			if overlap:player.position=Vector3(active_contact.source_render_position)*world.CELL_METERS/4096.0
			elif not stomping or attack_age==0 or attack_age>=25:player.position=safe
			attack_age+=1
			if attack_age==45:attack_age=-1;cooldown=30
		else:Input.action_release("attack");Input.action_release("jump");player.position=safe;cooldown=maxi(0,cooldown-1)
		var before_vulnerability: int=int(boss.vm.globals.get(vulnerability_index,0))
		player.refresh_source_render_pose();world.sample_source_player_controls();world.tick_source_actors()
		if bool(profile.get("trace_contact",false)) and attacks<=2 and attack_age>0 and attack_age<=18:
			contact_trace.append({"tick":tick,"age":attack_age,"before_vulnerability":before_vulnerability,"after_vulnerability":boss.vm.globals.get(vulnerability_index,0),"attack_kind":world.source_extended_globals.get(1,0),"contact_pc":contact_actor.vm.pc,"parent":contact_actor.source_parent_id,"boss":boss.source_pool_id,"contacts":world.source_player_contact_counts.get(contact_actor.source_pool_id,0)})
		if OS.get_cmdline_user_args().has("--trace-entry") and player.clip_name!=last_player_clip:
			last_player_clip=player.clip_name
			print("DANTE_COMBAT_POSE: ",JSON.stringify({"tick":tick,"clip":player.clip_name,"position":[player.position.x,player.position.y,player.position.z],"ground":player.source_ground,"actors":world.source_actors.map(func(actor):return {"name":actor.source_name,"contacts":world.source_player_contact_counts.get(actor.source_pool_id,0)})}))
		contacts=maxi(contacts,int(world.source_player_contact_counts.get(contact_actor.source_pool_id,0)))
		var health: int=int(world.source_extended_globals.get(health_index,0)) if bool(profile.get("extended_health",false)) else int(boss.vm.globals.get(health_index,0))
		if not health_words.has(health):health_words.append(health)
		for candidate in world.source_actors:
			if not candidate.vm.fault.is_empty():failure=candidate.source_name+": "+candidate.vm.fault;break
		if not failure.is_empty() or int(world.source_pickup_counts[3])!=initial_lives:break
		if third_phase and attacks==3 and world.source_transition_state in [3,4]:won=true;break
		if not profile.is_empty() and health==0 and world.source_transition_state==int(profile.end_state):won=true;break
		if not third_phase and health==0 and world.source_transition_state==2 and str(world.source_pending_exit.get("destination",""))==destination:won=true;break
		if tick%30==0:await process_frame
	Input.action_release("attack")
	Input.action_release("jump")
	if bool(profile.get("trace_contact",false)):print("BOSS_CONTACT_TRACE: ",JSON.stringify(contact_trace))
	var expected_health: Array=profile.get("expected_health",[196608,131072,65536] if third_phase else [196608,131072,65536,0])
	var actions_valid: bool=attacks>=6 if profile.has("stomp_state") else attacks==int(profile.get("expected_actions",3))
	won=won and health_words==expected_health and actions_valid and contacts>0
	print("DANTE_PHASE_FIGHT: ",JSON.stringify({"phase":3 if third_phase else 2 if second_phase else 1,"attacks":attacks,"contacts":contacts,"health_words":health_words,"lives":world.source_pickup_counts[3],"initial_lives":initial_lives,"transition":world.source_transition_state,"won":won,"failure":failure,"state":boss.vm.globals if is_instance_valid(boss) else {},"pc":boss.vm.pc if is_instance_valid(boss) else -1,"clip":boss.clip_name if is_instance_valid(boss) else "","player_clip":player.clip_name,"scope":"one phase with controlled positions and sampled attacks; arena travel and complete fight not simulated"}))
	if won and profile.is_empty() and not third_phase and (OS.get_cmdline_user_args().has("--verify-transition") or OS.get_cmdline_user_args().has("--verify-chain")):
		var entered:=false
		for tick in range(120):
			if not world.process_source_exit():failure=world.source_transition_fault;break
			if world.map_name==destination and world.source_fade_phase=="":entered=true;break
			await process_frame
		won=entered and failure.is_empty() and world.source_input_suppression_count==0 and world.source_player_actor!=null and world.source_controller_enabled and int(world.source_pickup_counts[3])==initial_lives
		if won:
			for tick in range(60):
				world.sample_source_player_controls();world.tick_source_actors()
				for candidate in world.source_actors:
					if not candidate.vm.fault.is_empty():failure=candidate.source_name+": "+candidate.vm.fault;won=false;break
				if not won:break
		print("DANTE_PHASE_RETURN: ",JSON.stringify({"room":world.map_name,"lives":world.source_pickup_counts[3],"suppression":world.source_input_suppression_count,"verified":won,"failure":failure}))
	return won and failure.is_empty()
