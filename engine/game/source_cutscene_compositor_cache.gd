extends RefCounted
static func mesh(content: String, entry: Dictionary) -> ArrayMesh:
	if not entry.has_all(["file","sha256"]): return null
	var path := content.path_join(str(entry.file))
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(entry.sha256): return null
	var resource = load(path)
	if not resource is ArrayMesh or resource.get_surface_count() != 1: return null
	return resource
static func frames(content: String, descriptor: Dictionary) -> Dictionary:
	if not descriptor.has("frames"): return {"fault":"Missing compositor frame cache"}
	var result: Array = []
	for entry in descriptor.frames:
		var frame: Dictionary = entry.duplicate(true)
		if frame.has("meshes"):
			for key in frame.meshes:
				var prepared := mesh(content,frame.meshes[key])
				if prepared == null:return {"fault":"Invalid prepared portal mesh"}
				frame.meshes[key]=prepared
			result.append(frame)
			continue
		for pass_data in frame.passes:
			if pass_data.kind == "opaque":
				for source in pass_data.meshes:
					var resource := mesh(content,pass_data.meshes[source])
					if resource == null: return {"fault":"Invalid cached opaque stage mesh"}
					pass_data.meshes[source] = resource
			else:
				var resource := mesh(content,pass_data.mesh)
				if resource == null: return {"fault":"Invalid cached blend stage mesh"}
				pass_data.mesh = resource
		result.append(frame)
	return {"frames":result}
