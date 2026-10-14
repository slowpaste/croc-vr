extends SceneTree
func _initialize() -> void: call_deferred("verify")
func check_actor_ticks(world: Node, count: int) -> bool:
	world.update_source_input(0,0)
	for tick in range(count):
		world.tick_source_actors()
		if not world.source_transition_fault.is_empty():
			push_error("Opening live camera/actor fault: "+world.source_transition_fault);return false
		for actor in world.source_actors:
			if not actor.vm.fault.is_empty(): push_error(actor.source_name+": "+actor.vm.fault);return false
	return true
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var deadline:=Time.get_ticks_msec()+60000
	while world.source_sequence_loading and Time.get_ticks_msec()<deadline:await process_frame
	if not world.imported or world.source_main_mode != 2 or not is_instance_valid(world.source_cutscene_screen) or int(world.source_cutscene_progress.scene) != 0:
		push_error("Original-start launch did not enter INTRO0: "+str(world.source_transition_fault)); quit(1); return
	if world.terrain.visible or world.source_controller_enabled or world.source_fade_overlay.visible:
		push_error("Opening retained gameplay/title geometry or inherited overlay"); quit(1); return
	var skipped := false
	for tick in range(100):
		var result: Dictionary = world.source_cutscene_screen.advance(33334,0x800000,1)
		if result.has("fault"): push_error(str(result.fault)); quit(1); return
		await process_frame
		if bool(result.complete): skipped = true; break
	if not skipped or not world.process_source_sad_cutscene(1.0/30.0):
		push_error("Opening skip did not finish through game dispatch"); quit(1); return
	if world.source_main_mode != 0 or world.source_title_scene_index not in [0,1,2,3] or world.map_name != "MP%03d_00.MAP"%(90+world.source_title_scene_index) or is_instance_valid(world.source_cutscene_screen) or not world.terrain.visible or not world.source_transition_fault.is_empty():
		push_error("Opening completion did not restore original title scene"); quit(1); return
	if not check_actor_ticks(world,20): quit(1);return
	if not world.process_source_title_confirmation(0x800000) or world.source_main_mode != 1:
		push_error("Opening title did not accept main-menu confirmation"); quit(1); return
	if not world.process_source_main_menu_confirmation(0x800000): push_error(world.source_transition_fault); quit(1); return
	for tick in range(100):
		if world.source_main_mode == 5: break
		if not world.advance_source_transition(): push_error(world.source_transition_fault); quit(1); return
	if world.source_main_mode != 5 or world.map_name != "MP100_01.MAP": push_error("New Game did not enter first island"); quit(1); return
	if not check_actor_ticks(world,40): quit(1);return
	for tick in range(20):
		if world.source_fade_phase.is_empty(): break
		if not world.advance_source_transition(): push_error(world.source_transition_fault); quit(1); return
	if not world.process_source_menu_confirmation(0x800000,0,0,0): push_error(world.source_transition_fault); quit(1); return
	for tick in range(30):
		if world.source_main_mode == 4: break
		if not world.advance_source_transition(): push_error(world.source_transition_fault); quit(1); return
	if world.source_main_mode != 4 or world.map_name != "MP010_00.MAP" or not world.source_controller_enabled or not is_instance_valid(world.source_player_actor) or not world.source_player_actor.vm.fault.is_empty():
		push_error("Original opening/New Game path did not launch playable Croc in stage1"); quit(1); return
	if not check_actor_ticks(world,60): quit(1);return
	world.queue_free(); await process_frame; await create_timer(0.25).timeout
	print("PASS: actual INTRO0 startup/skip -> title -> New Game -> first island -> stage1 with original Croc controller")
	quit(0)
