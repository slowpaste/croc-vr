extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.update_source_input(0,0)
	for island in range(4):
		var base := island*10
		world.source_menu_progress_flags.clear()
		for offset in [0,1,2,5,6,7]:
			world.source_menu_progress_flags[base+offset] = 6
		for offset in [4,9]:
			world.source_menu_progress_flags[base+offset] = 0x8000
		for half in range(2):
			world.source_menu_state.selected_index = base+half*5
			if not world.load_room("MP100_%02d.MAP" % (island+1)):
				quit(1)
				return
			var name := "Secret%d" % (island*2+half+1)
			var fountain_seen := false
			var shown := false
			var hidden := false
			for tick in range(600):
				world.tick_source_actors()
				for actor in world.source_actors:
					fountain_seen = fountain_seen or actor.source_name == "SecretFountain"
					if actor.source_name == name:
						shown = shown or actor.visible
						hidden = hidden or not actor.visible
			var found := false
			for actor in world.source_actors:
				if actor.vm.fault != "":
					push_error(world.map_name+" "+actor.source_name+" "+actor.vm.fault)
					quit(1)
					return
				if actor.source_name == name:
					found = true
					if int(actor.vm.instructions.get(actor.vm.pc,{}).get("op",-1)) != 66 or actor.visible != (island < 3):
						push_error("Reveal variant did not finish its original visibility/holding state: "+name+" "+actor.vm.status)
						quit(1)
						return
			if not found or not shown or not hidden or (island < 3 and not fountain_seen):
				push_error("Reveal variant did not exercise its original animation: "+name)
				quit(1)
				return
	if world.source_menu_announcement_history != [1,1,1,1,1,1,1,1]:
		quit(1)
		return
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Selector variant audio did not retire");quit(1);return
	print("PASS: all eight island reveal variants, fountain/blink branches, final visibility and announcement history")
	quit(0)
