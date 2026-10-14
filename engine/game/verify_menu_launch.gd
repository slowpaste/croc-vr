extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	if world.source_main_mode != 5:
		quit(1)
		return
	world.source_menu_state.selected_index = 0
	var change_during_fade := OS.get_cmdline_user_args().has("--change-during-fade")
	var expected_map := "MP011_00.MAP" if change_during_fade else "MP010_00.MAP"
	world.source_pickup_counts = {1:7,2:2,3:5}
	world.source_level_script_state = 1
	world.source_bonus_mask = 31
	world.source_player_movement_state.motion = Vector2i(100,-100)
	world.source_player_movement_state.magnitude = 200
	if not world.process_source_menu_confirmation(0,0,0,0) or not world.source_fade_phase.is_empty() or not world.process_source_menu_confirmation(0x800000,1,0,0) or not world.source_fade_phase.is_empty():
		push_error("Source menu confirm input/lock gates failed")
		quit(1)
		return
	if not world.process_source_menu_confirmation(0x800000,0,0,0) or world.source_fade_phase != "menu-out" or world.source_main_mode != 5:
		quit(1)
		return
	for tick in range(12):
		if tick == 5 and change_during_fade:
			world.source_menu_progress_flags[0] = 0x8000
			world.apply_source_menu_navigation(0x80000,0)
		if not world.process_source_menu_confirmation(0x800000,0,0,0) or world.map_name != "MP100_01.MAP":
			push_error("Stage changed before original fade readiness")
			quit(1)
			return
	var launched: bool = world.process_source_menu_confirmation(0,0,0,0)
	print("MENU_LAUNCH: ",JSON.stringify({"launched":launched,"map":world.map_name,"mode":world.source_main_mode,"fault":world.source_transition_fault,"player_fault":world.source_player_actor.vm.fault if world.source_player_actor != null else "missing","native":world.source_controller_enabled,"visible":world.visual.visible}))
	if not launched or world.map_name != expected_map or world.source_main_mode != 4 or world.source_player_actor == null or world.source_player_actor.source_name != "Croc" or world.source_player_actor.vm.fault != "" or not world.source_controller_enabled or world.visual.visible:
		push_error("Original selected-stage launch/controller route failed")
		quit(1)
		return
	if world.source_pickup_counts != {1:0,2:0,3:5} or world.source_bonus_mask != 0 or world.source_level_script_state != 0 or world.source_player_movement_state.motion != Vector2i.ZERO or world.source_player_movement_state.magnitude != 0:
		push_error("Original selector inventory/motion reset or lives retention failed")
		quit(1)
		return
	if world.source_pickup_display_timer != 240 or world.source_bonus_display_timer != 60 or world.source_transition_state != 0:
		push_error("Original gameplay entry timers/state were not initialized")
		quit(1)
		return
	var expected_crystals := 0
	for entity in world.room_data.entities:
		if entity.name == "Crystal": expected_crystals += 1
	var source_crystals: Array = []
	for candidate in world.source_actors:
		if candidate.source_name == "Crystal": source_crystals.append(candidate)
	if expected_crystals == 0 or source_crystals.size() != expected_crystals or not world.pickups.is_empty():
		push_error("Menu-launched level substituted provisional pickups for original crystal actors"); quit(1); return
	world.update_source_input(0,0)
	for tick in range(120):
		world.tick_source_actors()
		if not world.process_source_exit():
			quit(1)
			return
	if world.source_fade_phase != "" or world.source_audio_master_gain != 127:
		quit(1)
		return
	for actor in world.source_actors:
		if actor.vm.fault != "":
			push_error("Selected-stage actor fault: "+actor.source_name+" PC"+str(actor.vm.pc)+" "+str(actor.vm.fault))
			quit(1)
			return
	var crystal = source_crystals[0]
	var count_before := int(world.source_pickup_counts[1])
	world.source_player_actor.position = crystal.position
	world.source_player_actor.refresh_source_render_pose()
	for tick in range(3): world.tick_source_actors()
	if int(world.source_pickup_counts[1]) != count_before+1 or (int(world.source_map_entity_flags.get(world.map_name,{}).get(crystal.source_map_entity_index,0))&4) == 0:
		push_error("Menu-launched crystal did not execute original collection and persistence marking"); quit(1); return
	if not world.load_room("MP100_01.MAP"):
		quit(1)
		return
	world.source_menu_state.selected_index = 1 if change_during_fade else 0
	world.source_menu_state.save_mode=1;world.source_menu_state.dialog_mode=0
	if not world.process_source_menu_confirmation(0x200,0,1,0) or world.source_transition_fault != "" or world.source_fade_phase!="selector-options-out" or world.source_main_mode!=5 or world.map_name!="MP100_01.MAP":
		push_error("Other Options confirmation did not request its own transition without stage launch")
		quit(1)
		return
	world.source_fade_phase="";world.source_fade_state={};world.source_menu_state.save_mode=0;world.source_menu_state.dialog_mode=1
	if not world.process_source_menu_confirmation(0x200,0,0,1) or world.source_transition_fault != "" or not world.source_fade_phase.is_empty() or world.source_menu_state.save_mode!=1 or world.source_menu_state.dialog_mode!=0 or world.source_main_mode!=5 or world.map_name!="MP100_01.MAP":
		push_error("Options confirmation did not enter submenu without stage launch")
		quit(1)
		return
	world.source_transition_fault = ""
	world.source_menu_state.save_mode=0;world.source_menu_state.dialog_mode=0
	if not world.process_source_menu_confirmation(0x200,0,0,0) or world.source_fade_phase != "menu-out":
		push_error("Original Start confirmation was not accepted")
		quit(1)
		return
	for tick in range(13):
		if not world.process_source_menu_confirmation(0,0,0,0): quit(1); return
	var replay_crystals := 0
	for candidate in world.source_actors:
		if candidate.source_name == "Crystal": replay_crystals += 1
	if world.map_name != expected_map or replay_crystals != expected_crystals or not world.source_map_entity_flags.get(expected_map,{}).is_empty():
		push_error("Replaying a stage retained removed gems/rescues from the previous attempt"); quit(1); return
	world.queue_free()
	await process_frame
	print("PASS: normal menu confirm/lock, fade timing, selected-stage controller, resets, retained lives and120 stage ticks")
	quit(0)
