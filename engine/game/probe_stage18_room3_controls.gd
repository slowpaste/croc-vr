extends "res://probe_secret_stage_route.gd"
func probe() -> void:
	var world=load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
	if world.map_name!="MP018_03.MAP":push_error("Expected direct room3 debugging fixture");quit(1);return
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var prior: int=world.source_player_actor.source_angles.y
	for tick in range(12):Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
	release_controls()
	var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
	var fault := "" if right_delta!=0 else "Room3 turn calibration failed"
	var helper=preload("res://probe_stage18_room3_loot.gd")
	if fault.is_empty():fault=await helper.left_shore(self,world,right_delta)
	if fault.is_empty():fault=await helper.right_shore(self,world,right_delta)
	if fault.is_empty():fault=await helper.first_spin(self,world,right_delta)
	if fault.is_empty():fault=await helper.second_spin(self,world,right_delta)
	if fault.is_empty() and ("--verify-stage18-room3-third-spin" in OS.get_cmdline_user_args() or "--verify-stage18-room3-top-spin" in OS.get_cmdline_user_args()):fault=await helper.second_spin(self,world,right_delta,1,2)
	if fault.is_empty() and "--verify-stage18-room3-top-spin" in OS.get_cmdline_user_args():fault=await helper.climb_top(self,world,right_delta)
	if fault.is_empty() and "--verify-stage18-room3-high-life" in OS.get_cmdline_user_args():fault=await helper.high_life(self,world,right_delta,27,28)
	if fault.is_empty() and "--verify-stage18-room3-both-high-lives" in OS.get_cmdline_user_args():
		fault=await helper.return_top(self,world,right_delta)
		if fault.is_empty():fault=await helper.high_life(self,world,right_delta,25,26)
	if fault.is_empty() and "--verify-stage18-room3-high-exit" in OS.get_cmdline_user_args():fault=await helper.leave_high_lives(self,world,right_delta)
	if fault.is_empty() and "--verify-stage18-room3-return-door" in OS.get_cmdline_user_args():fault=await helper.return_room5(self,world,right_delta)
	if fault.is_empty() and "--verify-stage18-jigsaw-contact" in OS.get_cmdline_user_args():fault=await helper.collect_jigsaw(self,world,right_delta)
	print("STAGE18_ROOM3_CONTROL_CHECK: ",JSON.stringify({"fault":fault,"scope":"Direct room3 normal-input debugging only; no earned entry, goldkey/wheels/fullstage/Jigsaw/save/headset proof","inventory":world.source_pickup_counts}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if fault.is_empty() else 1)
