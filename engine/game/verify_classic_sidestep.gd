extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 var fault := ""
 for side in ["move_left","move_right"]:
  Input.action_press("precision_move");Input.action_press(side)
  world.sample_source_player_controls()
  var held: int=world.source_input_held_mask
  var expected := 0x80 if side=="move_left" else 0x100
  if (held&expected)==0 or (held&(0x20000|0x80000))!=0:fault="Classic precision emitted incorrect lateral actions: "+str(held)
  Input.action_release(side);Input.action_release("precision_move")
 print("CLASSIC_SIDESTEP: ",fault if not fault.is_empty() else "PASS left/right shoulders without turns")
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)
