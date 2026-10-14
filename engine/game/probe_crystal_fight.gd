extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();world.source_menu_state.selected_index=44
	root.add_child(world);await process_frame;world.set_physics_process(false)
	if not world.imported or world.source_player_actor==null:quit(1);return
	for tick in range(30):world.sample_source_player_controls();world.tick_source_actors()
	var player: Node3D=world.source_player_actor
	var safe: Vector3=player.position
	var gongs: Array=[]
	for actor in world.source_actors:
		if actor.source_name=="CrysGong":gongs.append(actor)
	var lives: int=world.source_pickup_counts[3]
	var peak_active:=0;var contacts:=0;var won:=false;var failure:=""
	var target: Node3D=null;var age:=0;var attacks:=0
	for tick in range(1800):
		if target==null or age>=24:
			target=null;age=0
			for gong in gongs:
				if int(gong.vm.parameters[3])==0:target=gong;break
			if target!=null:attacks+=1
		if target!=null:
			if age<3:Input.action_press("attack")
			else:Input.action_release("attack")
			player.position=target.position if age in range(4,16) else safe
			age+=1
		else:Input.action_release("attack");player.position=safe
		player.refresh_source_render_pose();world.sample_source_player_controls();world.tick_source_actors()
		peak_active=maxi(peak_active,int(world.source_extended_globals.get(21,0))>>16)
		for gong in gongs:contacts=maxi(contacts,int(world.source_player_contact_counts.get(gong.source_pool_id,0)))
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty():failure=actor.source_name+": "+actor.vm.fault;break
		if not failure.is_empty() or int(world.source_pickup_counts[3])!=lives:break
		if world.source_transition_state==4:won=true;break
		if tick%30==0:await process_frame
	Input.action_release("attack")
	won=won and gongs.size()==4 and peak_active>=4 and contacts>0
	print("CRYSTAL_FIGHT: ",JSON.stringify({"gongs":gongs.size(),"attacks":attacks,"peak_active":peak_active,"contacts":contacts,"lives":world.source_pickup_counts[3],"initial_lives":lives,"transition":world.source_transition_state,"won":won,"failure":failure,"gong_states":gongs.map(func(gong):return {"pc":gong.vm.pc,"parameters":gong.vm.parameters}),"scope":"controlled positions with sampled attacks on authored gongs; arena travel and ending not simulated"}))
	if won and OS.get_cmdline_user_args().has("--verify-ending"):
		var entered:=false
		for tick in range(1800):
			if not world.source_stage_stats_state.is_empty():world.advance_source_stage_stats(0x800200 if tick%60==30 else 0)
			if not world.process_source_exit():failure=world.source_transition_fault;break
			if is_instance_valid(world.source_cutscene_screen):entered=true;break
			if tick%30==0:await process_frame
		won=entered and failure.is_empty() and int(world.source_ending_root)==16 and (int(world.source_menu_progress_flags.get(44,0))&0x8000)!=0
		var seen_frames := {}
		if won:
			for tick in range(600):
				if not is_instance_valid(world.source_cutscene_screen):break
				var display: Node3D=world.source_cutscene_screen
				if not world.process_source_sad_cutscene(1.0/30.0):failure=world.source_transition_fault;break
				seen_frames[int(display.session.player.last_index)]=true
				await process_frame
			seen_frames.erase(-1)
			won=failure.is_empty() and seen_frames.size()==441 and seen_frames.has(440) and world.source_main_mode==7 and is_instance_valid(world.source_credits_screen) and not world.source_main_menu_credits_available
		if won:
			var first := ""
			for command in world.source_credits_screen.presenter.state.commands:
				if int(command.op)==0:first=str(command.text);break
			won=first=="CONGRATULATIONS"
			for tick in range(10000):
				if not is_instance_valid(world.source_credits_screen):break
				if not world.process_source_credits(1.0/30.0):failure=world.source_transition_fault;break
				if tick%60==0:await process_frame
			won=won and failure.is_empty() and world.source_main_mode==0 and not is_instance_valid(world.source_credits_screen) and world.terrain.visible and int(world.source_pickup_counts[3])==lives
		print("CRYSTAL_EARNED_ENDING: ",JSON.stringify({"verified":won,"frames_seen":seen_frames.size(),"mode":world.source_main_mode,"room":world.map_name,"completion_flag44":world.source_menu_progress_flags.get(44,0),"percentage_flag45":world.source_menu_progress_flags.get(45,0),"failure":failure,"scope":"controlled gong attacks through secret ending/credits/title; campaign collection and headset performance not simulated"}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if won and failure.is_empty() else 1)
