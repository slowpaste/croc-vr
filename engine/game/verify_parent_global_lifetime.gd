extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false)
 var parent=world.source_actors[0]
 var slot: int=parent.source_pool_id
 parent.vm.globals[4]=65536
 var child=preload("res://asl_actor.gd").new()
 child.world=world;child.source_parent_id=slot
 var stack: Array=[]
 child.asl_expression({"op":1,"index":4},stack,child.vm)
 var fault := ""
 if stack!=[65536]:fault="Live parent read differs"
 if not world.remove_source_actor(parent):fault="Parent retirement failed"
 stack.clear();child.asl_expression({"op":1,"index":4},stack,child.vm)
 if stack!=[65536]:fault="Retired parent read differs"
 var result: String=child.asl_command({"op":55,"args":[4,[{"op":4,"value":131072},{"op":18}]]},child.vm)
 if result!="continue":fault="Retired parent write rejected"
 stack.clear();child.asl_expression({"op":1,"index":4},stack,child.vm)
 if stack!=[131072]:fault="Retired parent write did not persist"
 var replacement=preload("res://asl_actor.gd").new()
 replacement.vm.globals[4]=196608
 var reused: int=world.source_pool.allocate({"node":replacement})
 if reused!=slot:fault="Expected native slot reuse differs"
 stack.clear();child.asl_expression({"op":1,"index":4},stack,child.vm)
 if stack!=[196608]:fault="Parent pointer did not follow reused slot"
 if not child.vm.fault.is_empty():fault=child.vm.fault
 print("PARENT_GLOBAL_LIFETIME: ",fault if not fault.is_empty() else "PASS live/retired reads, retained write, reused slot")
 child.free();replacement.free()
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)
