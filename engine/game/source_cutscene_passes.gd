extends RefCounted
# Original terrain is emitted before actor parts; the OT prepends within buckets.
static func plan(room: Array, actors: Array) -> Dictionary:
	var commands: Array = []
	for command in room:
		var item: Dictionary = command.duplicate(true)
		item.source = str(command.get("source","room"))
		item.global_serial = int(item.serial)
		commands.append(item)
	for command in actors:
		var item: Dictionary = command.duplicate(true)
		item.source = "actor"
		item.global_serial = room.size()+int(item.serial)
		commands.append(item)
	commands.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.bucket) > int(b.bucket) if a.bucket != b.bucket else int(a.global_serial) > int(b.global_serial))
	var passes: Array = []
	var opaque: Array = []
	var blended := 0
	for command in commands:
		if (int(command.flags)&0x20) != 0:
			if not opaque.is_empty(): passes.append({"kind":"opaque","commands":opaque}); opaque = []
			passes.append({"kind":"blend","command":command,"mode":int(command.blend)})
			blended += 1
		else: opaque.append(command)
	if not opaque.is_empty(): passes.append({"kind":"opaque","commands":opaque})
	return {"passes":passes,"commands":commands.size(),"blended":blended}

static func mesh(commands: Array, total: int) -> ArrayMesh:
	var count := 0
	for command in commands: count += command.vertices.size()
	if count == 0: return null
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
	for command in commands:
		for vertex in command.vertices:
			surface.set_color(vertex.color); surface.set_uv(vertex.uv)
			surface.set_uv2(Vector2(float(command.bucket),float(total-int(command.global_serial))))
			surface.set_custom(0,Color(float(int(command.flags)&0x61),0,0,0))
			surface.add_vertex(vertex.position)
	return surface.commit()
