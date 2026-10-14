extends "res://probe_dante_fight.gd"
func _initialize() -> void:call_deferred("flibby")
func flibby() -> void:
	var world=load("res://imported.tscn").instantiate();world.source_menu_state.selected_index=8
	root.add_child(world);await process_frame;world.set_physics_process(false)
	if not world.imported or world.source_player_actor==null:quit(1);return
	# Belly contact3283 checks tail attack and parent vulnerability20;
	# the parent animation/state path decrements health2 at2840.
	var valid: bool=await run_phase(world,{"room":"MP017_02.MAP","name":"BossFlibby","contact_name":"FlibbyBelly","stomp_contact":"FlibbyCollision","stomp_state":17,"health":2,"vulnerability":20,"cooldown":18,"end_state":4,"near_distance":2.0,"trace_contact":true})
	valid=valid and (int(world.source_menu_progress_flags.get(9,0))&0x8000)!=0
	print("FLIBBY_FIGHT: ",JSON.stringify({"verified":valid,"completion_flag":world.source_menu_progress_flags.get(9,0),"transition":world.source_transition_state,"fault":world.source_transition_fault,"scope":"controlled positions and sampled tail/stomp combinations; arena travel and return not simulated"}))
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
		valid=valid and scene==10 and expected_frames>0 and seen_frames.size()==expected_frames and world.source_main_mode==5 and world.map_name=="MP100_02.MAP" and int(world.source_menu_state.selected_index)==10 and int(world.source_pickup_counts[3])==3
		print("FLIBBY_RETURN: ",JSON.stringify({"verified":valid,"scene":scene,"frames_seen":seen_frames.size(),"expected_frames":expected_frames,"room":world.map_name,"selected":world.source_menu_state.selected_index,"fault":world.source_transition_fault}))
		if valid and OS.get_cmdline_user_args().has("--verify-next-stage"):
			for tick in range(60):
				if not world.process_source_menu_confirmation(0x800000 if tick==0 else 0,int(world.source_menu_state.input_lock),int(world.source_menu_state.save_mode),int(world.source_menu_state.dialog_mode)):valid=false;break
				if world.source_main_mode==4 and world.source_fade_phase=="":break
				if tick%15==0:await process_frame
			valid=valid and world.map_name=="MP020_00.MAP" and world.source_main_mode==4 and world.source_player_actor!=null and world.source_controller_enabled and int(world.source_pickup_counts[3])==3
			if valid:
				for tick in range(60):
					world.sample_source_player_controls();world.tick_source_actors()
					for actor in world.source_actors:
						if not actor.vm.fault.is_empty():valid=false;break
					if not valid:break
			print("FLIBBY_NEXT_STAGE: ",JSON.stringify({"verified":valid,"room":world.map_name,"mode":world.source_main_mode,"lives":world.source_pickup_counts[3],"fault":world.source_transition_fault}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if valid else 1)
