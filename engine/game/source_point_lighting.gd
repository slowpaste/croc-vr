extends RefCounted
const VM = preload("res://asl_vm.gd")
const Rotation = preload("res://source_rotation.gd")
const Collision = preload("res://source_collision.gd")
static func decode(records: Array) -> Dictionary:
	var lights: Array = []
	for record in records:
		if record.size() != 24: return {"fault":"Invalid source point-light record"}
		var bytes := PackedByteArray(record)
		lights.append({"position":Vector3i(bytes.decode_s32(0)>>4,bytes.decode_s32(4)>>4,bytes.decode_s32(8)>>4),"rgb":[int(bytes[12]),int(bytes[13]),int(bytes[14])],"inner":bytes.decode_s32(16)>>4,"outer":bytes.decode_s32(20)>>4})
	return {"lights":lights}
static func contribution(position: Vector3i, normal: Vector3i, matrix: Array, base: Array, light: Dictionary, roots: Array) -> Dictionary:
	if matrix.size() != 9 or base.size() != 3 or roots.size() != 192: return {"fault":"Missing source point-light inputs"}
	var delta := Vector3i(VM.signed32(position.x-light.position.x),VM.signed32(position.y-light.position.y),VM.signed32(position.z-light.position.z))
	var distance := Collision.distance_root(Collision.square_ir(delta.x)+Collision.square_ir(delta.y)+Collision.square_ir(delta.z),roots)
	if distance >= int(light.outer): return {"rgb":[0,0,0],"distance":distance,"ir0":4096}
	var direction: Array = []
	for axis in range(3):
		var value := 0 if distance <= 0 else int(float(VM.signed32(delta[axis]<<12))/float(distance))
		direction.append(Rotation.halfword(-Rotation.halfword(value)))
	var attenuation := 0
	if int(light.inner) < distance:
		attenuation = int(float(VM.signed32((distance-int(light.inner))<<12))/float(int(light.outer)-int(light.inner)))
	var light_matrix := Rotation.compose([direction[0],direction[1],direction[2],0,0,0,0,0,0],matrix)
	var color := [int(light.rgb[0])<<4,0,0,int(light.rgb[1])<<4,0,0,int(light.rgb[2])<<4,0,0]
	var gte = preload("res://source_gte_lighting.gd")
	var light_ir: Array = gte.positive_stage(light_matrix,[normal.x,normal.y,normal.z],[0,0,0])
	var color_ir: Array = gte.positive_stage(color,light_ir,[0,0,0])
	var rgb: Array = []
	for channel in range(3):
		var modulation: int = ((int(base[channel])&255)*int(color_ir[channel]))<<4
		var difference := clampi((-modulation)>>12,-32768,32767)
		var mac: int = (modulation+attenuation*difference)>>12
		rgb.append(clampi(mac>>4,0,255))
	return {"rgb":rgb,"distance":distance,"ir0":attenuation}
static func face_rgb(face: Dictionary, vertex: int, model: Dictionary, position: Vector3i, matrix: Array, atlas: Dictionary, lighting: Dictionary, original: Array) -> Dictionary:
	var result := original.duplicate()
	var flags := int(face.flags)
	if (flags&1) != 0 and int(atlas.polygons[int(face.material)].blend) == 3: return {"rgb":result}
	var values: Array = face.sourceHeader if (flags&0x40) != 0 else model.sourceNormals[vertex]
	var normal := Vector3i(int(values[0]),int(values[1]),int(values[2]))
	var base: Array = lighting.textureBase if (flags&1) != 0 else face.color
	for light in lighting.pointLights:
		var value := contribution(position,normal,matrix,base,light,lighting.distanceRoot)
		if value.has("fault"): return value
		for channel in range(3): result[channel] = mini(255,int(result[channel])+int(value.rgb[channel]))
	return {"rgb":result}
