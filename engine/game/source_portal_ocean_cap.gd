extends RefCounted
static func build(part:Dictionary, index:int) -> ArrayMesh:
	# TB43's original dome has an open bottom, hidden by the flat game's
	# viewing window. VR head motion exposes it. Close that rim using its
	# existing blue ocean texels, leaving the rainbow/sky geometry untouched.
	var camera:Dictionary=part.data.frames[index].camera
	var pairs:Array=part.tables.rotation.pairs
	var anchored:=preload("res://source_cutscene_view.gd").anchored_camera(camera,part.anchor.position,int(part.anchor.yaw),pairs)
	var view:=preload("res://source_cutscene_view.gd").camera_view(anchored,pairs)
	var sky:=preload("res://source_cutscene_sky.gd").frame(anchored,part.sky_models.models.size(),roundi(float(part.room.startRotation)*4096.0),pairs)
	var raw:=SurfaceTool.new();raw.begin(Mesh.PRIMITIVE_TRIANGLES);raw.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
	for model_index in range(part.sky_models.models.size()):
		var model:Dictionary=part.sky_models.models[model_index]
		var bottom:=INF
		for vertex in model.vertices:bottom=minf(bottom,float(vertex[1]))
		var expanded:Dictionary=model.duplicate();expanded.vertices=model.vertices.duplicate();expanded.vertices.append([0,bottom,0])
		var posed:=preload("res://source_cutscene_transform.gd").vertices(sky.parts[model_index],expanded,view)
		for face in model.faces:
			if (int(face.flags)&1)==0:continue
			var rim:Array=[];var uvs:Array=[]
			var mapping:Array=[0,1,2,3] if (int(face.flags)&16)!=0 else [1,0,3,2]
			for corner in range(face.indices.size()):
				var id:int=face.indices[corner]
				if is_equal_approx(float(model.vertices[id][1]),bottom):
					rim.append(posed.vertices[id])
					var values:Array=part.sky_atlas.polygons[int(face.material)].uv[mapping[corner]]
					uvs.append(Vector2(values[0],values[1]))
			if rim.size()!=2:continue
			var points:Array=[posed.vertices.back(),rim[0],rim[1]]
			var coordinates:Array=[(uvs[0]+uvs[1])*0.5,uvs[0],uvs[1]]
			for corner in range(3):
				var point:Vector3i=points[corner]
				raw.set_color(Color(128.0/255.0,128.0/255.0,128.0/255.0,0));raw.set_uv(coordinates[corner]);raw.set_uv2(Vector2(1022,0));raw.set_custom(0,Color(1,0,0,0));raw.add_vertex(Vector3(point.x,-point.y,-point.z)/4096.0)
	var clipped:=SurfaceTool.new();clipped.begin(Mesh.PRIMITIVE_TRIANGLES);clipped.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
	if preload("res://source_portal_geometry.gd").append(clipped,raw.commit())==0:return null
	return clipped.commit()
