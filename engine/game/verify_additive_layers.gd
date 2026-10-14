extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(32,32);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
	viewport.add_child(environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;viewport.add_child(camera)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color(0.3,0,0,1))
	var material:=ShaderMaterial.new();material.shader=preload("res://source_gameplay_additive.gdshader")
	material.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(image))
	var nodes:Array=[]
	for layer in range(2):
		var node:=MeshInstance3D.new();viewport.add_child(node);nodes.append(node)
		var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [Vector3(-1,-1,-2),Vector3(1,-1,-2),Vector3(1,1,-2),Vector3(-1,-1,-2),Vector3(1,1,-2),Vector3(-1,1,-2)]:
			builder.set_uv(Vector2(0.5,0.5));builder.set_uv2(Vector2(1,1));builder.set_color(Color.WHITE);builder.add_vertex(point)
		node.mesh=builder.commit();node.material_override=material;node.position.z=-float(layer)*0.01
	nodes[1].hide()
	for frame in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var single:=viewport.get_texture().get_image().get_pixel(16,16)
	nodes[1].show()
	for frame in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var layered:=viewport.get_texture().get_image().get_pixel(16,16)
	assert(single.r>0.1 and layered.r>single.r+0.05,"Additive layer replaced earlier contribution")
	print("PASS: additive surfaces accumulate; single=",single," two=",layered)
	viewport.queue_free();await process_frame;quit(0)
