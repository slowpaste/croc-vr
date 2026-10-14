extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world)
	await process_frame;world.set_process(false);world.set_physics_process(false)
	var binding: Dictionary = world.material_for_texture("TK00_ENM.BIN")
	assert(binding.data.runtime_blend_material.get_shader_parameter("has_mask"))
	for file in ["resources/0152-MP010_02.WAD-131244.json","resources/0155-MP010_05.WAD-217184.json","resources/0150-MP010_00.WAD-62656.json"]:
		var model: Dictionary = world.read_json(file)
		var translucent := 0
		for part in model.models:
			var expected := 0
			for face in part.faces:
				if (int(face.flags)&32) != 0: expected += face.indices.size()*3-6
			var mesh: ArrayMesh = world.geometry(part,binding.data)
			for surface in range(mesh.get_surface_count()):
				if mesh.surface_get_material(surface) is ShaderMaterial:
					assert(mesh.surface_get_array_len(surface) == expected)
					translucent += expected
		print("TRANSPARENCY: ",file," blended vertices=",translucent)
	world.queue_free();await process_frame
	var viewport := SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLUE;viewport.add_child(env)
	var camera := Camera3D.new();viewport.add_child(camera)
	var panel := MeshInstance3D.new();var quad := QuadMesh.new();quad.size=Vector2(2,2);panel.mesh=quad;panel.position.z=-4;viewport.add_child(panel)
	var material := ShaderMaterial.new();material.shader=preload("res://source_gameplay_blend.gdshader");panel.material_override=material
	# Untextured source primitives blend their color independently of STP bits.
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var color := viewport.get_texture().get_image().get_pixel(128,128)
	assert(color.b > 0.8 and color.r > 0.3 and color.r < 0.9)
	print("PASS: actual gong shadow, balloon and jelly face materials plus visible framebuffer blending ",color)
	quit(0)
