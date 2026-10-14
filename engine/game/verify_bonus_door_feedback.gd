extends SceneTree

func _initialize() -> void: call_deferred("verify")

func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for tick in range(30): await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.stop_imported_audio()
	var doors: Array = []
	var parent: Node3D
	for actor in world.source_actors:
		if actor.source_name == "BonusDoor": parent = actor
		if actor.source_name in ["BonusDoorL","BonusDoorR"]: doors.append(actor)
	if parent == null or doors.size() != 2:
		push_error("Missing bonus door actors"); quit(1); return
	world.actor.position = parent.position + Vector3(0,0,world.CELL_METERS*2)
	for mask in range(32):
		world.source_bonus_mask = mask
		for door in doors:
			door.refresh_bonus_door_feedback()
			if door.bonus_door_material == null or door.bonus_door_material.get_shader_parameter("collected_mask") != mask:
				push_error("Door mask mismatch"); quit(1); return
			var mesh: ArrayMesh = door.mesh_parts[0].mesh
			var indices: Array = []
			for uv in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]:
				if not indices.has(int(uv.y)): indices.append(int(uv.y))
			for index in [416 if door.source_name == "BonusDoorL" else 417,418 if door.source_name == "BonusDoorL" else 419,422,423,424,425,426,427,428,429,430,431]:
				if not indices.has(index): push_error("Missing gem surface mapping"); quit(1); return
	# Render every inventory combination; this catches atlas origin/color mistakes.
	var facing := Basis(Vector3.UP,float(parent.source_angles.y)*TAU/4096.0)
	world.camera.position = parent.position + facing*Vector3(0,world.CELL_METERS*0.45,world.CELL_METERS*1.2)
	world.camera.look_at(parent.position + Vector3(0,world.CELL_METERS*0.38,0))
	for mask in range(32):
		world.source_bonus_mask = mask
		for door in doors: door.refresh_bonus_door_feedback()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var points := [Vector2i(579,340),Vector2i(627,337),Vector2i(676,340),Vector2i(602,403),Vector2i(650,399)]
			for index in range(5):
				var color := image.get_pixelv(points[index])
				var chroma := maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
				if (chroma > 0.08) != ((mask & (1 << index)) != 0):
					push_error("Rendered gem color mismatch: mask %d gem %d chroma %f" % [mask,index,chroma]); quit(1); return
			# Bottom facets occupy additional authored surfaces420/421.
			for index in [3,4]:
				var color:=image.get_pixelv(Vector2i(615,424) if index==3 else Vector2i(659,424))
				var chroma:=maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
				if (chroma>0.08)!=((mask&(1<<index))!=0):push_error("Lower gem facet retained a missing color");quit(1);return
			if mask in [0,5,31]: image.save_png("res://../build/bonus-door-%s-mask-%d.png" % [world.map_name,mask])
	if DisplayServer.get_name() != "headless":
		for mask in [5,31]:
			world.source_bonus_mask = mask
			for door in doors: door.refresh_bonus_door_feedback()
			await process_frame; await RenderingServer.frame_post_draw
			var region := Rect2i(540,225,200,295)
			var initial := root.get_texture().get_image().get_region(region).get_data()
			var changed := false
			for tick in range(40):
				for animation in world.active_texture_animations.values(): animation.advance()
				await process_frame; await RenderingServer.frame_post_draw
				if initial != root.get_texture().get_image().get_region(region).get_data(): changed = true
			if changed != (mask == 31):
				push_error("Door flashing does not match completion"); quit(1); return
	# Original script gate stays closed for every incomplete combination.
	world.source_actors.assign([parent,doors[0],doors[1]])
	world.actor.position = parent.position
	world.source_player_actor.position = parent.position
	world.source_player_actor.refresh_source_render_pose()
	for mask in range(31):
		world.source_bonus_mask = mask
		for tick in range(10): world.tick_source_actors()
		if parent.vm.parameters[1] == 65536:
			push_error("Incomplete inventory opened the door"); quit(1); return
	world.source_bonus_mask = 31
	for tick in range(80): world.tick_source_actors()
	if parent.vm.parameters[1] != 65536 or doors[0].vm.parameters[1] != 131072 or doors[1].vm.parameters[1] != 131072:
		print("Gate states: ",parent.vm.parameters,doors[0].vm.parameters,doors[1].vm.parameters," faults ",parent.vm.fault,doors[0].vm.fault,doors[1].vm.fault)
		push_error("Complete inventory did not open both leaves"); quit(1); return
	world.source_bonus_mask = 0
	for door in doors:
		door.refresh_bonus_door_feedback()
		if door.bonus_door_material.get_shader_parameter("collected_mask") != 0:
			push_error("Door did not reset"); quit(1); return
	world.queue_free(); await process_frame
	print("PASS: rendered colors match all 32 masks; original gate rejects all incomplete masks and opens both leaves with all five; reset restores empty feedback")
	quit(0)
