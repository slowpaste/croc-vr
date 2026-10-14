extends SceneTree
func _initialize() -> void: call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	# Controlled entry into Neptuna's original menu-table selection (index23).
	# Direct room loading alone retains the default first-stage selection.
	world.source_menu_state.selected_index=23
	root.add_child(world);await process_frame;world.set_physics_process(false)
	if not world.imported or world.source_player_actor == null:quit(1);return
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var boss: Node3D = null
	for candidate in world.source_actors:
		if candidate.source_name == "BossNeptuna":boss=candidate;break
	if boss == null:world.queue_free();await process_frame;quit(1);return
	var player: Node3D = world.source_player_actor
	var initial_lives: int = world.source_pickup_counts[3]
	var health_words: Array = []
	var attacks := 0;var attack_age := -1;var cooldown := 0
	var contacts := 0;var vulnerable_ticks := 0;var failure := "";var victory := false
	var attack_samples: Array = []
	for tick in range(3600):
		# Controlled positions only: all damage, vulnerability, health, animation
		# and exit commands remain the imported programs' responsibility.
		var away := Vector3(12,0,12)-Vector3(boss.position.x,0,boss.position.z)
		if away.length_squared()<0.001:away=Vector3.RIGHT
		var escape: Vector3 = boss.position+away.normalized()*3.0
		var vulnerable: bool = int(boss.vm.globals.get(14,0)) != 0 and int(boss.vm.globals.get(17,0)) == 0
		if vulnerable:vulnerable_ticks+=1
		if vulnerable and attack_age < 0 and cooldown == 0:attack_age=0;attacks+=1
		if attack_age >= 0:
			if attack_age < 3:Input.action_press("attack")
			else:Input.action_release("attack")
			player.position = boss.position if attack_age in range(4,16) else escape
			attack_age+=1
			if attack_age==45:attack_age=-1;cooldown=30
		else:
			Input.action_release("attack");player.position=escape;cooldown=maxi(0,cooldown-1)
		player.refresh_source_render_pose();world.sample_source_player_controls();world.tick_source_actors()
		if attack_age>0 and attack_age<=18:
			attack_samples.append({"tick":tick,"age":attack_age,"clip":player.clip_name,"attack_kind":world.source_extended_globals.get(1,0),"held":world.source_input_held_mask,"suppression":world.source_input_suppression_count,"boss_cooldown":boss.vm.globals.get(17,0)})
		contacts=maxi(contacts,int(world.source_player_contact_counts.get(boss.source_pool_id,0)))
		var health: int = int(boss.vm.globals.get(8,0))
		if not health_words.has(health):health_words.append(health)
		for candidate in world.source_actors:
			if not candidate.vm.fault.is_empty():failure=candidate.source_name+": "+candidate.vm.fault;break
		if not failure.is_empty() or int(world.source_pickup_counts[3]) != initial_lives:break
		if health==0 and world.source_transition_state==3:victory=true;break
		if tick%30==0:await process_frame
	Input.action_release("attack")
	victory = victory and health_words == [196608,131072,65536,0] and attacks == 3 and contacts > 0 and int(world.source_pickup_counts[3]) == initial_lives
	if OS.get_cmdline_user_args().has("--trace-attacks"):print("NEPTUNA_ATTACK_SAMPLES: ",JSON.stringify(attack_samples))
	print("NEPTUNA_FIGHT: ",JSON.stringify({"attacks":attacks,"vulnerable_ticks":vulnerable_ticks,"contacts":contacts,"health_words":health_words,"lives":world.source_pickup_counts[3],"initial_lives":initial_lives,"transition":world.source_transition_state,"victory":victory,"failure":failure,"boss_state":{"pc":boss.vm.pc,"globals":boss.vm.globals,"clip":boss.clip_name,"frame":boss.clip_frame,"playing":boss.clip_playing,"speed":boss.clip.get("speed",-1),"speed_offset":boss.clip_speed_offset,"flags":boss.primary_flags},"scope":"sampled swim attack with controlled positions; arena travel and full return not simulated"}))
	if victory and OS.get_cmdline_user_args().has("--verify-return"):
		var seen_frames := {};var expected_frames := -1;var last_scene := -1
		for tick in range(3000):
			if is_instance_valid(world.source_cutscene_screen):
				var display: Node3D = world.source_cutscene_screen
				last_scene=int(world.source_cutscene_progress.scene)
				expected_frames=display.session.player.frames.size()
				if not world.process_source_sad_cutscene(1.0/30.0):failure=world.source_transition_fault;break
				seen_frames[int(display.session.player.last_index)]=true
				await process_frame
			else:
				if not world.source_stage_stats_state.is_empty():world.advance_source_stage_stats(0x800200 if tick%60==30 else 0)
				if not world.process_source_exit():failure=world.source_transition_fault;break
				if world.source_main_mode==5 and world.source_fade_phase=="":break
				if tick%30==0:await process_frame
		seen_frames.erase(-1)
		victory=failure.is_empty() and last_scene==14 and expected_frames>0 and seen_frames.size()==expected_frames and world.source_main_mode==5 and world.map_name=="MP100_03.MAP" and int(world.source_menu_state.selected_index)==25 and int(world.source_pickup_counts[3])==initial_lives and (int(world.source_menu_progress_flags.get(24,0))&0x8000)!=0
		print("NEPTUNA_RETURN: ",JSON.stringify({"scene":last_scene,"frames_seen":seen_frames.size(),"expected_frames":expected_frames,"room":world.map_name,"mode":world.source_main_mode,"selected":world.source_menu_state.selected_index,"progress_flag":world.source_menu_progress_flags.get(24,0),"verified":victory,"failure":failure}))
		if victory and OS.get_cmdline_user_args().has("--verify-next-stage"):
			for tick in range(60):
				if not world.process_source_menu_confirmation(0x800000 if tick==0 else 0,int(world.source_menu_state.input_lock),int(world.source_menu_state.save_mode),int(world.source_menu_state.dialog_mode)):
					failure=world.source_transition_fault;break
				if world.source_main_mode==4 and world.source_fade_phase=="":break
				if tick%15==0:await process_frame
			victory=failure.is_empty() and world.source_main_mode==4 and world.map_name=="MP034_00.MAP" and world.source_player_actor!=null and world.source_controller_enabled and int(world.source_pickup_counts[3])==initial_lives
			if victory:
				for tick in range(60):
					world.sample_source_player_controls();world.tick_source_actors()
					for candidate in world.source_actors:
						if not candidate.vm.fault.is_empty():failure=candidate.source_name+": "+candidate.vm.fault;victory=false;break
					if not victory:break
			print("NEPTUNA_NEXT_STAGE: ",JSON.stringify({"room":world.map_name,"mode":world.source_main_mode,"lives":world.source_pickup_counts[3],"verified":victory,"failure":failure}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if victory and failure.is_empty() else 1)
