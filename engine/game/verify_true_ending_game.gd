extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--level")
	var level := int(args[option+1]) if option >= 0 else 54
	if level not in [47,54]: quit(1); return
	var normal := level == 47
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame; world.set_physics_process(false)
	if not world.imported: push_error("Ending test world did not import"); quit(1); return
	# Exercise the actual final return; this does not simulate the boss fight.
	world.map_name = "MP%03d_00.MAP"%level
	var boss_index: int = world.runtime_tables.menuLevels.values.find(float(level))
	world.source_menu_state.selected_index = boss_index+1
	world.source_pending_exit = {"source_level":level,"target_level":0}
	if not world.apply_source_next_level_return(): push_error(world.source_transition_fault); quit(1); return
	var completed_frames := {}
	for tick in range(2800):
		if not is_instance_valid(world.source_cutscene_screen): break
		var display: Node3D = world.source_cutscene_screen
		var scene := int(world.source_cutscene_progress.scene)
		if not world.process_source_sad_cutscene(1.0/30.0): push_error(world.source_transition_fault); quit(1); return
		completed_frames[scene] = int(display.session.player.last_index)
		if tick%120==0:
			print("ENDING_PROGRESS: tick=",tick," scene=",scene," frame=",completed_frames[scene])
			var progress := FileAccess.open("res://../build/ending-progress-"+str(OS.get_process_id())+".json",FileAccess.WRITE)
			if progress!=null:
				progress.store_string(JSON.stringify({"pid":OS.get_process_id(),"level":level,"tick":tick,"scene":scene,"frame":completed_frames[scene],"fault":world.source_transition_fault}));progress.close()
		await process_frame
	if world.source_main_mode != 7 or not is_instance_valid(world.source_credits_screen) or world.source_main_menu_credits_available != normal:
		push_error("Ending did not enter original credits/menu availability"); quit(1); return
	if completed_frames != ({15:1006,19:1496} if normal else {16:440}):
		push_error("Ending did not play every pose in its original sequence chain: "+str(completed_frames)); quit(1); return
	var first := ""
	for command in world.source_credits_screen.presenter.state.commands:
		if int(command.op) == 0: first = str(command.text); break
	if first != ("Fox Interactive" if normal else "CONGRATULATIONS"): push_error("Ending selected wrong credits resource"); quit(1); return
	for tick in range(10000):
		if not is_instance_valid(world.source_credits_screen): break
		if not world.process_source_credits(1.0/30.0): push_error(world.source_transition_fault); quit(1); return
		if tick%1000==0:print("ENDING_CREDITS_PROGRESS: tick=",tick," level=",level)
		if tick%60 == 0: await process_frame
	if world.source_main_mode != (5 if normal else 0) or is_instance_valid(world.source_credits_screen) or not world.terrain.visible or world.source_main_menu_credits_available != normal:
		push_error("Credits did not restore original selector/title destination"); quit(1); return
	world.queue_free(); await process_frame; await create_timer(0.25).timeout
	print("PASS: actual level",level," final return plays original sequence chain",completed_frames,", correct credits and title restoration; boss fight not simulated")
	quit(0)
