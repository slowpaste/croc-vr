extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.update_source_input(0,0)
	world.source_menu_progress_flags = {0:6,1:6,2:6,4:0x8000,5:6,6:6,7:6,9:0x8000}
	for selected in [0,1,5,6]:
		world.source_menu_state.selected_index = selected
		if not world.load_room("MP100_01.MAP"):
			quit(1)
			return
		var expected: int = 4 if selected == 0 else 9 if selected == 5 else selected
		if world.source_menu_state.selected_index != expected:
			push_error("Loaded selector did not apply source announcement redirect")
			quit(1)
			return
		var fountain_seen := false
		var spray_seen := false
		var grew := false
		var secret = null
		var secret_name := "Secret1" if selected < 5 else "Secret2"
		for tick in range(600):
			world.tick_source_actors()
			for actor in world.source_actors:
				fountain_seen = fountain_seen or actor.source_name == "SecretFountain"
				spray_seen = spray_seen or actor.source_name == "SecretFount"
				if actor.source_name == secret_name:
					secret = actor
					grew = grew or actor.source_scale.x < 4096
		if selected in [0,5] and (not fountain_seen or not spray_seen or not grew or secret == null or secret.vm.pc != 171 or secret.source_scale != Vector3i(4096,4096,4096) or not secret.visible or int(secret.vm.parameters[7]) != 65536):
			push_error("Original secret-stage fountain/growth sequence did not complete: "+secret_name+" "+str({"fountain":fountain_seen,"spray":spray_seen,"growth":grew,"pc":secret.vm.pc if secret != null else -1,"scale":secret.source_scale if secret != null else Vector3i.ZERO}))
			quit(1)
			return
		for actor in world.source_actors:
			if actor.vm.fault != "":
				push_error("Selector announcement actor failed: "+actor.source_name+" "+actor.vm.fault)
				quit(1)
				return
	if world.source_menu_announcement_history != [1,1,0,0,0,0,0,0]:
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: loaded selector one-time announcements, both original fountain/growth sequences and repeat visits")
	quit(0)
