extends Node
# Experimental only: scene playback continues to use the qualified 3D graph.
var output := SubViewport.new()
var fault := ""
var vertex_texture: ImageTexture = null
func _init() -> void:
	output.size = Vector2i(512,240); output.use_hdr_2d = true
	output.transparent_bg = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(output)
func mesh(commands: Array, h: int) -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var attributes: Array = []
	for command in commands:
		var source := int({"actor":0,"room":1,"sky":2}.get(str(command.source),-1))
		if source < 0: fault = "Unknown canvas primitive source"; return null
		var metadata := (int(command.flags)&97)|(source<<2)
		for vertex in preload("res://source_sequence_canvas_clip.gd").triangles(command.vertices,h):
			var point: Vector3 = vertex.position
			if -point.z <= 0: fault = "Invalid clipped canvas depth"; return null
			var screen := Vector2(point.x,-point.y)*float(h)/(-point.z)+Vector2(256,192)
			var tint: Color = vertex.color
			attributes.append({"color":tint,"uv":vertex.uv,"metadata":metadata,"screen":screen})
	var width := mini(4096,maxi(1,attributes.size()))
	var height := maxi(2,2*int(ceil(float(attributes.size())/width)))
	var data := Image.create(width,height,false,Image.FORMAT_RGBAF)
	for index in range(attributes.size()):
		var item: Dictionary = attributes[index]
		var x := index%width; var y := 2*int(index/width)
		data.set_pixel(x,y,Color(item.color.r,item.color.g,item.color.b,item.uv.x))
		data.set_pixel(x,y+1,Color(item.uv.y,float(item.metadata),0,0))
		surface.set_color(Color.WHITE); surface.set_uv(Vector2(x,y))
		surface.add_vertex(Vector3(item.screen.x,item.screen.y,0))
	vertex_texture = ImageTexture.create_from_image(data)
	if attributes.is_empty(): return ArrayMesh.new()
	return surface.commit()
func setup(plan: Dictionary, h: int, textures: Dictionary, masks: Dictionary) -> bool:
	if h <= 0 or not output.get_children().is_empty(): return false
	for pass_data in plan.passes:
		var commands: Array = pass_data.commands if pass_data.kind == "opaque" else [pass_data.command]
		var geometry := mesh(commands,h)
		if geometry == null: return false
		if pass_data.kind == "blend":
			var copy := BackBufferCopy.new(); copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			output.add_child(copy)
		var material := ShaderMaterial.new(); material.shader = preload("res://source_sequence_canvas_material.gdshader")
		material.set_shader_parameter("use_vertex_data",true)
		material.set_shader_parameter("vertex_data",vertex_texture)
		for source in ["actor","room","sky"]:
			if textures.has(source): material.set_shader_parameter(source+"_texture",textures[source])
			if masks.has(source): material.set_shader_parameter(source+"_mask",masks[source])
		material.set_shader_parameter("apply_blend",pass_data.kind == "blend")
		if pass_data.kind == "blend": material.set_shader_parameter("blend_mode",int(pass_data.mode))
		var node := MeshInstance2D.new(); node.mesh = geometry; node.material = material
		output.add_child(node)
	return true
