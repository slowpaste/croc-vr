extends SceneTree
const Progress = preload("res://source_menu_progress.gd")
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var world = World.new()
	var actor = Actor.new()
	world.add_child(actor)
	actor.world = world
	world.source_pickup_counts[2] = 6
	if actor.asl_command({"op":159,"args":[]},actor.vm) != "continue" or world.source_menu_progress_flags.get(0) != 0x8006 or world.source_transition_state != 4 or world.process_source_exit() or world.source_transition_fault != "Missing source transition camera":
		quit(1)
		return
	world.free()
	var recording := {0:0x8005,3:12,4:0xffff}
	if Progress.record_completion(0,2,recording)[0] != 0x8005 or Progress.record_completion(0,6,recording)[0] != 0x8006 or recording[0] != 0x8005:
		quit(1)
		return
	var secret := Progress.record_completion(3,6,recording)
	if secret[3] != 12 or secret[4] != 0x8000 or Progress.record_completion(40,6,{}).get(40) != 0xc006 or Progress.record_completion(45,6,recording) != recording:
		push_error("Native stage result redirect/overwrite/index40/sentinel differs")
		quit(1)
		return
	if Progress.record_completion(0,-1,{}).get(0) != 65535:
		quit(1)
		return
	var original := {0:0x8006,1:6,2:6,4:0x8000,5:6,6:6,7:6,9:0x8000}
	var result := Progress.update_unlocks(0,original)
	if result.bits != 3 or result.flags[3] != 0x8000 or result.flags[8] != 0x8000 or original.has(3):
		quit(1)
		return
	original[0] = 7
	original[3] = 0xffff
	result = Progress.update_unlocks(0,original)
	if result.bits != 2 or result.flags[3] != 0:
		push_error("Native rescue total used >=18 or retained old unlock bits")
		quit(1)
		return
	original[4] = 0
	result = Progress.update_unlocks(0,original)
	if result.flags[3] != 0xffff:
		push_error("Missing boss gate changed the untouched unlock word")
		quit(1)
		return
	if Progress.update_unlocks(40,original).bits != 0 or Progress.update_unlocks(40,original).flags != original:
		quit(1)
		return
	var history: Array = [0,0,0,0,0,0,0,0]
	var both := {0:6,1:6,2:6,4:0x8000,5:6,6:6,7:6,9:0x8000}
	result = Progress.enter_selector(0,both,history)
	if result.selected_index != 4 or result.return_mode != 1 or result.secret_return != 2 or result.history[0] != 1 or history[0] != 0:
		quit(1)
		return
	result = Progress.enter_selector(1,both,result.history)
	if result.selected_index != 1 or result.return_mode != 2 or result.secret_return != 2:
		quit(1)
		return
	result = Progress.enter_selector(5,both,history)
	if result.selected_index != 9 or result.return_mode != 2 or result.secret_return != 1 or result.history[1] != 1:
		quit(1)
		return
	result = Progress.enter_selector(40,both,history)
	if result.selected_index != 40 or result.return_mode != 0 or result.secret_return != 0 or result.history != history:
		quit(1)
		return
	if not Progress.enter_selector(0,both,[]).has("fault"):
		quit(1)
		return
	print("PASS: original boss/rescue unlocks, selector announcement history, redirects and return modes")
	quit(0)
