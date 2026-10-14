extends RefCounted
static func build(frame: Dictionary, models: Array, view: Dictionary, atlas: Dictionary, lighting: Dictionary = {}, projection: Dictionary = {}) -> Dictionary:
	if not frame.has("parts") or not atlas.has("polygons"): return {"fault":"Missing cutscene mesh resources"}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gpu_color := bool(projection.get("gpu_color",false))
	if gpu_color: surface.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
	var count := 0
	var culled := 0
	var ordering := bool(projection.get("ordering",false))
	var primitives: Array = []
	for part in frame.parts:
		var id := int(part.id)
		if id < 0 or id >= models.size(): return {"fault":"Invalid cutscene model index"}
		var model: Dictionary = models[id]
		var facing_image := bool(projection.get("facing_images",false)) and preload("res://source_sprite_facing.gd").is_image_quad(model)
		var posed := preload("res://source_cutscene_transform.gd").vertices(part,model,view,bool(projection.get("facing_images",false)))
		if posed.has("fault"): return posed
		var screen_points: Array[Vector2i] = []
		if projection.has("h") or projection.has("offset"):
			if not projection.has_all(["h","offset"]): return {"fault":"Missing original cutscene projection"}
			for point in posed.vertices:
				screen_points.append(preload("res://source_gte_projection.gd").screen(Vector2i(point.x,point.y),point.z,int(projection.h),projection.offset))
		var light: Dictionary = {}
		var point_vertices: Array = []
		if not lighting.get("pointLights",[]).is_empty():
			var world := preload("res://source_cutscene_transform.gd").vertices(part,model,{"matrix":[4096,0,0,0,4096,0,0,0,4096],"position":[0,0,0]})
			if world.has("fault"): return world
			point_vertices = world.vertices
		var color_cache := {}
		if not lighting.is_empty():
			light = preload("res://source_cutscene_lighting.gd").part_light_matrix(part,view,lighting)
			if light.has("fault"): return light
		for face in model.faces:
			var ids: Array = face.indices
			if ids.size() not in [3,4]: return {"fault":"Invalid cutscene face"}
			if not screen_points.is_empty() and not facing_image:
				for vertex in ids:
					if int(vertex) < 0 or int(vertex) >= screen_points.size(): return {"fault":"Invalid projected face index"}
				var cull = preload("res://source_cutscene_culling.gd")
				var area := cull.nclip(screen_points[int(ids[0])],screen_points[int(ids[1])],screen_points[int(ids[2])])
				var accepted: bool = cull.triangle(int(face.flags),area) if ids.size() == 3 else cull.quad(int(face.flags),area,cull.nclip(screen_points[int(ids[3])],screen_points[int(ids[1])],screen_points[int(ids[2])]))
				if not accepted:
					culled += 1
					continue
			var textured: bool = (int(face.flags)&1) != 0
			var uvs: Array = []
			if textured:
				var material := int(face.material)
				if material < 0 or material >= atlas.polygons.size(): return {"fault":"Missing original cutscene sprite"}
				uvs = atlas.polygons[material].uv
			var uv_order := [0,1,2,3] if int(face.flags)&16 else [1,0,3,2]
			if ids.size() == 3: uv_order = [0,2,3]
			var corners: Array = []
			for corner in ([0,1,2,1,3,2] if ids.size() == 4 else [0,1,2]):
				var vertex := int(ids[corner])
				if vertex < 0 or vertex >= posed.vertices.size(): return {"fault":"Invalid cutscene face vertex"}
				var point: Vector3i = posed.vertices[vertex]
				var rgb: Array = [128,128,128] if textured else face.color
				if not lighting.is_empty():
					var normal_key := str(face.sourceHeader) if int(face.flags)&0x40 else str(vertex)
					var key := str(int(face.flags)&0x61)+":"+str(rgb)+":"+normal_key
					if not point_vertices.is_empty(): key += ":point-vertex:"+str(vertex)
					if not color_cache.has(key):
						var shade := preload("res://source_cutscene_lighting.gd").face_rgb(face,vertex,model,light.matrix,lighting)
						if shade.has("fault"): return shade
						if not point_vertices.is_empty():
							shade = preload("res://source_point_lighting.gd").face_rgb(face,vertex,model,point_vertices[vertex],part.matrix,atlas,lighting,shade.rgb)
							if shade.has("fault"): return shade
						color_cache[key] = shade.rgb
					rgb = color_cache[key]
				var color := Color(float(rgb[0])/255.0,float(rgb[1])/255.0,float(rgb[2])/255.0,0.0 if textured else 1.0)
				var uv := Vector2(0.5/float(atlas.width),0.5/float(atlas.height))
				if textured: uv = Vector2(float(uvs[uv_order[corner]][0]),float(uvs[uv_order[corner]][1]))
				# Native view has down-positiveY/front-positiveZ; Godot's camera is opposite.
				var position := Vector3(point.x,-point.y,-point.z)/4096.0
				if ordering: corners.append({"position":position,"color":color,"uv":uv,"flags":int(face.flags)&0x61})
				else:
					if gpu_color: surface.set_custom(0,Color(float(int(face.flags)&0x61),0,0,0))
					surface.set_color(color); surface.set_uv(uv); surface.add_vertex(position)
				count += 1
			if ordering:
				var depths: Array = []
				for vertex in ids: depths.append(posed.vertices[int(vertex)].z)
				var maximum_mode := int(model.get("collision",{}).get("counts",[0,0])[0]) != 0
				var depth_math = preload("res://source_cutscene_depth.gd")
				var depth: Dictionary = depth_math.terrain(int(face.flags),depths) if bool(projection.get("terrain",false)) else depth_math.face(int(face.flags),depths,maximum_mode)
				if depth.has("fault") or int(depth.bucket) < 0 or int(depth.bucket) >= 1024: return {"fault":"Invalid original cutscene ordering bucket"}
				primitives.append({"bucket":int(depth.bucket),"serial":primitives.size(),"vertices":corners,"flags":int(face.flags),"blend":int(atlas.polygons[int(face.material)].get("blend",0)) if textured else 0})
	if ordering:
		var tie_base := int(projection.get("tie_base",0))
		if tie_base < 0 or primitives.size()+tie_base > 8192: return {"fault":"Source ordering tie range exceeded"}
		primitives.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.bucket) > int(b.bucket) if a.bucket != b.bucket else int(a.serial) > int(b.serial))
		for primitive in primitives:
			for vertex in primitive.vertices:
				if gpu_color: surface.set_custom(0,Color(float(vertex.flags),0,0,0))
				surface.set_color(vertex.color); surface.set_uv(vertex.uv)
				surface.set_uv2(Vector2(float(primitive.bucket),float(primitives.size()-int(primitive.serial)+tie_base))); surface.add_vertex(vertex.position)
	surface.generate_normals()
	var result := {"mesh":surface.commit(),"vertices":count,"culled_faces":culled,"primitive_count":primitives.size()}
	if bool(projection.get("commands",false)): result.commands = primitives
	return result
