extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();world.source_menu_state.selected_index=33
	root.add_child(world);await process_frame;world.set_physics_process(false)
	if not world.imported or world.source_player_actor==null:quit(1);return
	var entry_args:=OS.get_cmdline_user_args();var settle_option:=entry_args.find("--initial-ticks")
	var settle_ticks: int=int(entry_args[settle_option+1]) if settle_option>=0 else 60
	if settle_ticks<1 or settle_ticks>120:world.queue_free();await process_frame;quit(1);return
	for tick in range(settle_ticks):
		if entry_args.has("--protect-triggers"):world.source_player_actor.primary_flags|=0x40
		world.sample_source_player_controls();world.tick_source_actors()
	var boss: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="BalloonBoss":boss=actor;break
	if boss==null:world.queue_free();await process_frame;quit(1);return
	var player: Node3D=world.source_player_actor
	var safe: Vector3=player.position
	var safe_points: Array[Vector3]=[]
	for x in range(5,20,2):
		for z in range(5,24,2):
			var point:=Vector3(x,1,z)
			var floor_sample: Dictionary=world.source_raw_floor_query(point)
			if int(floor_sample.get("tile",-1))>=0 and int(floor_sample.get("surface_type",-1))==0 and int(floor_sample.height_units)==0:safe_points.append(Vector3(x,0,z))
	var lives: int=world.source_pickup_counts[3]
	var target: Node3D=null;var age:=0;var attacks:=0;var cooldown:=0
	var health_words: Array=[];var failure:="";var won:=false
	var attack_samples: Array=[]
	var signal_samples: Array=[];var prior_signals: Array=[]
	var args:=OS.get_cmdline_user_args();var ticks_option:=args.find("--probe-ticks")
	var spring_wait: Vector3=safe
	var trajectory_option:=args.find("--trajectory")
	var trajectory_every_option:=args.find("--trajectory-every")
	var trajectory_every: int=int(args[trajectory_every_option+1]) if trajectory_every_option>=0 else 5
	if trajectory_every<1 or trajectory_every>30:world.queue_free();await process_frame;quit(1);return
	var trajectory: Array=[]
	var last_player_clip: String=player.clip_name
	if args.has("--stand-spring"):
		for spring in world.source_actors:
			if spring.source_name!="BALNSPRG":continue
			var standing: Vector3=spring.position
			if args.has("--spring-edge"):standing+=(boss.position-spring.position).normalized()*0.8
			var contacts: Dictionary=world.source_contacts_at(standing+Vector3.UP*3,player)
			print("BALLOON_SPRING_CONTACT: ",JSON.stringify({"position":[spring.position.x,spring.position.y,spring.position.z],"contacts":contacts}))
			if int(contacts.lower.get("actor",-1))!=spring.source_pool_id:world.queue_free();await process_frame;quit(1);return
			safe=Vector3(standing.x,int(contacts.lower.height_units)*world.CELL_METERS/4096.0,standing.z);spring_wait=safe
			if not args.has("--spring-bait") and not args.has("--lure-across"):safe_points.clear()
	var ticks_limit: int=int(args[ticks_option+1]) if ticks_option>=0 else 6000
	if ticks_limit<1 or ticks_limit>6000:world.queue_free();await process_frame;quit(1);return
	for tick in range(ticks_limit):
		if args.has("--protect-triggers"):player.primary_flags|=0x40
		var best_clearance := -1.0
		for point in safe_points:
			var clearance: float=point.distance_squared_to(boss.position)
			for hazard in world.source_actors:
				if hazard.source_name=="FuseDude":clearance=minf(clearance,point.distance_squared_to(hazard.position))
			if clearance>best_clearance:best_clearance=clearance;safe=point
		if args.has("--spring-bait"):
			var launched:=false
			for enemy in world.source_actors:
				if enemy.source_name=="FuseDude" and ((enemy.primary_flags&0x600)!=0 or enemy.vm.pc>1483):launched=true;break
			if not launched:safe=spring_wait
		if args.has("--spring-timed"):
			var approaching:=false
			for enemy in world.source_actors:
				if enemy.source_name=="FuseDude" and (enemy.primary_flags&0x400)!=0 and Vector2(enemy.position.x-spring_wait.x,enemy.position.z-spring_wait.z).length()<3.0:approaching=true;break
			safe=spring_wait if approaching else spring_wait+Vector3.UP*3.0
		if args.has("--lure-across"):
			var toward_boss:=Vector3(boss.position.x-spring_wait.x,0,boss.position.z-spring_wait.z).normalized()
			var chasing:=false
			for enemy in world.source_actors:
				if enemy.source_name=="FuseDude" and (enemy.primary_flags&0x600)==0 and int(enemy.vm.globals.get(5,0)) in [65536,131072,327680]:chasing=true;break
			safe=spring_wait-toward_boss*3.0 if chasing else spring_wait+toward_boss*3.0
			if not safe_points.is_empty():
				var requested: Vector3=safe
				safe=safe_points[0]
				for point in safe_points:
					if point.distance_squared_to(requested)<safe.distance_squared_to(requested):safe=point
		if target==null and cooldown==0 and not args.has("--no-attack"):
			for actor in world.source_actors:
				if actor.source_name=="FuseDude" and (actor.primary_flags&0x80000)==0 and (actor.secondary_flags&2)!=0 and int(actor.vm.globals.get(23,0))==0:
					target=actor;age=0;attacks+=1;break
		if is_instance_valid(target):
			if age<3:Input.action_press("attack")
			else:Input.action_release("attack")
			player.position=target.position if age in range(4,16) else safe
			age+=1
			if age==45:target=null;cooldown=60
		else:
			Input.action_release("attack")
			if not args.has("--natural-spring") or tick==0:player.position=safe
			target=null;cooldown=maxi(0,cooldown-1)
		player.refresh_source_render_pose();world.sample_source_player_controls();world.tick_source_actors()
		if args.has("--trace-player") and player.clip_name!=last_player_clip:
			last_player_clip=player.clip_name
			print("BALLOON_PLAYER_POSE: ",JSON.stringify({"tick":tick,"clip":player.clip_name,"position":[player.position.x,player.position.y,player.position.z],"ground":player.source_ground,"actors":world.source_actors.map(func(actor):return {"name":actor.source_name,"contacts":world.source_player_contact_counts.get(actor.source_pool_id,0)})}))
		if trajectory_option>=0 and tick%trajectory_every==0:
			for enemy in world.source_actors:
				if enemy.source_name!="FuseDude":continue
				trajectory.append({"tick":tick,"id":enemy.get_instance_id(),"pc":enemy.vm.pc,"position":[enemy.position.x,enemy.position.y,enemy.position.z],"ground":enemy.source_ground.duplicate(true),"primary":enemy.primary_flags,"secondary":enemy.secondary_flags,"state":enemy.vm.globals.duplicate(),"parameters":enemy.vm.parameters.duplicate(),"player_ground":player.source_ground.duplicate(true),"player_flags":player.primary_flags,"signal71":world.source_extended_globals.get(71,0),"springs":world.source_actors.filter(func(actor):return actor.source_name=="BALNSPRG").map(func(actor):return {"position":[actor.position.x,actor.position.y,actor.position.z],"primary":actor.primary_flags,"secondary":actor.secondary_flags,"pc":actor.vm.pc})})
		var signals: Array=[]
		for index in range(14,19):signals.append(world.source_extended_globals.get(index,0))
		if signals!=prior_signals:
			prior_signals=signals.duplicate();signal_samples.append({"tick":tick,"signals":signals,"boss_parameters":boss.vm.parameters.duplicate(),"boss_state":boss.vm.globals.duplicate()})
		if is_instance_valid(target) and age<=18:
			attack_samples.append({"tick":tick,"age":age,"player_clip":player.clip_name,"attack_kind":world.source_extended_globals.get(1,0),"enemy_pc":target.vm.pc,"enemy_flags":target.primary_flags,"contacts":world.source_player_contact_counts.get(target.source_pool_id,0)})
		var health: int=int(boss.vm.globals.get(9,0))
		if not health_words.has(health):health_words.append(health)
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty():failure=actor.source_name+": "+actor.vm.fault;break
		if not failure.is_empty() or int(world.source_pickup_counts[3])!=lives:break
		if health==0 and world.source_transition_state!=0:won=true;break
		if tick%30==0:await process_frame
	Input.action_release("attack")
	if trajectory_option>=0:
		var output:=FileAccess.open(str(args[trajectory_option+1]),FileAccess.WRITE)
		if output==null:failure="Cannot write trajectory"
		else:output.store_string(JSON.stringify(trajectory));output.close()
	if OS.get_cmdline_user_args().has("--trace-attacks"):print("BALLOON_ATTACK_SAMPLES: ",JSON.stringify(attack_samples))
	if OS.get_cmdline_user_args().has("--trace-attacks"):print("BALLOON_SIGNAL_SAMPLES: ",JSON.stringify(signal_samples))
	print("BALLOON_FIGHT: ",JSON.stringify({"attacks":attacks,"health_words":health_words,"won":won,"lives":world.source_pickup_counts[3],"initial_lives":lives,"transition":world.source_transition_state,"failure":failure,"boss_pc":boss.vm.pc,"scope":"controlled positions and sampled attacks on authored FuseDude; arena travel and return not simulated"}))
	var valid: bool=won and failure.is_empty() and health_words==[196608,131072,65536,0] and int(world.source_pickup_counts[3])==lives and (int(world.source_menu_progress_flags.get(34,0))&0x8000)!=0
	if valid and OS.get_cmdline_user_args().has("--verify-return"):
		var seen_frames := {};var expected_frames := -1;var scene := -1
		for tick in range(3000):
			if is_instance_valid(world.source_cutscene_screen):
				var display: Node3D=world.source_cutscene_screen
				scene=int(world.source_cutscene_progress.scene);expected_frames=display.session.player.frames.size()
				if not world.process_source_sad_cutscene(1.0/30.0):valid=false;break
				seen_frames[int(display.session.player.last_index)]=true
				await process_frame
			else:
				if not world.source_stage_stats_state.is_empty():world.advance_source_stage_stats(0x800200 if tick%60==30 else 0)
				if not world.process_source_exit():valid=false;break
				if world.source_main_mode==5 and world.source_fade_phase=="":break
				if tick%30==0:await process_frame
		seen_frames.erase(-1)
		valid=valid and scene==13 and expected_frames>0 and seen_frames.size()==expected_frames and world.source_main_mode==5 and world.map_name=="MP100_04.MAP" and int(world.source_menu_state.selected_index)==35 and int(world.source_pickup_counts[3])==3
		print("BALLOON_RETURN: ",JSON.stringify({"verified":valid,"scene":scene,"frames_seen":seen_frames.size(),"expected_frames":expected_frames,"room":world.map_name,"selected":world.source_menu_state.selected_index,"fault":world.source_transition_fault}))
		if valid and OS.get_cmdline_user_args().has("--verify-next-stage"):
			for tick in range(60):
				if not world.process_source_menu_confirmation(0x800000 if tick==0 else 0,int(world.source_menu_state.input_lock),int(world.source_menu_state.save_mode),int(world.source_menu_state.dialog_mode)):valid=false;break
				if world.source_main_mode==4 and world.source_fade_phase=="":break
				if tick%15==0:await process_frame
			valid=valid and world.map_name=="MP044_00.MAP" and world.source_main_mode==4 and world.source_player_actor!=null and world.source_controller_enabled and int(world.source_pickup_counts[3])==3
			if valid:
				for tick in range(60):
					world.sample_source_player_controls();world.tick_source_actors()
					for actor in world.source_actors:
						if not actor.vm.fault.is_empty():valid=false;break
					if not valid:break
			print("BALLOON_NEXT_STAGE: ",JSON.stringify({"verified":valid,"room":world.map_name,"mode":world.source_main_mode,"lives":world.source_pickup_counts[3],"fault":world.source_transition_fault}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if valid else 1)
