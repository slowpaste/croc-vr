extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 var before: Vector3=world.source_player_actor.position
 for tick in range(120):
  Input.action_press("precision_move");Input.action_press("move_right")
  if "--jump-side" in OS.get_cmdline_user_args() and tick<8:Input.action_press("jump")
  else:Input.action_release("jump")
  world.sample_source_player_controls();world.tick_source_actors()
  if tick%10==0:print("SIDE_CYCLE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"yaw":world.source_player_actor.source_angles.y,"clip":world.source_player_actor.clip_name}))
 Input.action_release("precision_move");Input.action_release("move_right");Input.action_release("jump")
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 print("SIDESTEP_MOVEMENT: ",JSON.stringify({"before":str(before),"after":str(world.source_player_actor.position),"yaw":world.source_player_actor.source_angles.y,"clip":world.source_player_actor.clip_name,"held":world.source_input_held_mask,"mode":world.source_player_movement_state}))
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit()
