extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var room = load("res://imported.tscn").instantiate()
	root.add_child(room)
	for frame in range(30):
		await process_frame
	room.set_physics_process(false)
	room.set_process(false)
	room.board.hide()
	room.hud.hide()
	var args := OS.get_cmdline_user_args()
	var target_name := "LavaBlubsActual"
	var option := args.find("--probe-sprite")
	if option >= 0 and option + 1 < args.size():
		target_name = args[option + 1]
	var target: MeshInstance3D = null
	for actor in room.source_actors:
		actor.set_process(false)
		actor.apply_pose()
		if actor.clip.is_empty():
			for part in actor.sprite_parts:
				part.basis = Basis.IDENTITY
		if actor.source_name == target_name and not actor.sprite_parts.is_empty():
			target = actor.sprite_parts[0]
	if target == null:
		push_error("No camera-facing quad found for " + target_name)
		quit(1)
		return
	var center := target.global_transform * target.get_aabb().get_center()
	room.camera.position = center + Vector3(1,0,0)
	room.camera.look_at(center)
	if args.has("--probe-isolate"):
		var isolated := MeshInstance3D.new()
		isolated.mesh = target.mesh
		isolated.material_override = target.material_override
		root.add_child(isolated)
		isolated.global_transform = target.global_transform
		isolated.global_position -= center
		room.terrain.hide()
		room.visual.hide()
		room.camera.position = Vector3(1,0,0)
		room.camera.look_at(Vector3.ZERO)
		if not args.has("--probe-legacy-facing"):
			isolated.global_basis = preload("res://source_sprite_facing.gd").facing_basis(isolated.global_position,room.camera.global_position,isolated.global_basis.get_scale())
	if not args.has("--probe-legacy-facing"):
		for actor in room.source_actors:
			actor._process(0.0)
	await RenderingServer.frame_post_draw
	var suffix := "legacy" if args.has("--probe-legacy-facing") else "corrected"
	var result := root.get_texture().get_image().save_png("res://../build/sprite-facing-" + target_name.to_lower() + "-" + suffix + ".png")
	room.queue_free()
	await process_frame
	quit(result)
