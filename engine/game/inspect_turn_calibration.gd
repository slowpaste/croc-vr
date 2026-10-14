extends SceneTree
func _initialize():call_deferred("inspect")
func inspect():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 for tick in range(12):
  var before: int=world.source_player_actor.source_angles.y
  Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
  print("TURN_SAMPLE: ",JSON.stringify({"tick":tick,"before":before,"after":world.source_player_actor.source_angles.y,"delta":wrapi(world.source_player_actor.source_angles.y-before,-2048,2048),"clip":world.source_player_actor.clip_name}))
 Input.action_release("move_right")
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit()
