extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false)
 var actor=world.source_player_actor
 var fault := ""
 for step in [[-1,0],[78,65536],[79,0]]:
  if step[0]>=0:
   if actor.asl_command({"op":step[0],"args":[]},actor.vm)!="continue":fault="Key command failed"
  var stack: Array=[]
  actor.asl_expression({"op":3,"index":57},stack,actor.vm)
  if stack!=[step[1]]:fault="Key query differs after command "+str(step[0])
 if not actor.vm.fault.is_empty():fault=actor.vm.fault
 print("COLLECTED_KEY_QUERY: ",fault if not fault.is_empty() else "PASS absent/collected/consumed")
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)
