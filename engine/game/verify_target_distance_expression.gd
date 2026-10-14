extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false)
 var actor=world.source_player_actor
 var fault := ""
 var cases=0
 for placement in [Vector3(3,0,6),Vector3(-6,9,3)]:
  actor.position=placement
  var origin := Vector3i(roundi(placement.x/3*4096),roundi(placement.y/3*4096),roundi(placement.z/3*4096))
  for data in [[Vector3i.ZERO,0],[Vector3i(4096,0,0),65536],[Vector3i(0,-4096,0),65536],[Vector3i(0,0,4096),65536]]:
   var point: Vector3i=origin+data[0]
   var stack: Array=[point.x,point.y,point.z]
   var machine=preload("res://asl_vm.gd").new()
   actor.asl_expression({"op":34},stack,machine)
   if not machine.fault.is_empty() or stack!=[data[1]]:fault="Distance differs for "+str(point)+": "+str(stack)
   cases+=1
 var invalid=preload("res://asl_vm.gd").new()
 actor.asl_expression({"op":34},[0,0],invalid)
 if invalid.fault.is_empty():fault="Operand underflow was accepted"
 print("TARGET_DISTANCE34: ",JSON.stringify({"fault":fault,"cases":cases}))
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)
