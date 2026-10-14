extends RefCounted
const Rotation = preload("res://source_rotation.gd")
const VM = preload("res://asl_vm.gd")
# Native50618..50728: background camera uses the room's first entity anchor.
# Position must already be converted to original runtime units by the room loader.
static func anchored_camera(camera: Dictionary, position: Vector3i, yaw: int, pairs: Array) -> Dictionary:
	if not camera.has_all(["position","angles"]) or camera.position.size() != 3 or camera.angles.size() != 3 or pairs.size() != 4096: return {"fault":"Invalid cutscene room camera"}
	var trig := Rotation.trig(yaw,pairs)
	var x := int(camera.position[0])
	var z := int(camera.position[2])
	var rotated_x := VM.signed32(VM.signed32(trig.x*z)+VM.signed32(trig.y*x))>>12
	var rotated_z := VM.signed32(VM.signed32(trig.y*z)-VM.signed32(trig.x*x))>>12
	var result := camera.duplicate(true)
	result.position = [VM.signed32(rotated_x+position.x),VM.signed32(int(camera.position[1])+position.y),VM.signed32(rotated_z+position.z)]
	result.angles[1] = Rotation.halfword(int(camera.angles[1])+yaw)
	return result
# Native5506c..552f4; differs from actor builder552fc in mixed-axis order.
static func matrix(angles: Vector3i, pairs: Array) -> Array:
	if pairs.size() != 4096: return []
	var x := Rotation.trig(angles.x,pairs)
	var y := Rotation.trig(angles.y,pairs)
	var z := Rotation.trig(angles.z,pairs)
	var a := Rotation.multiply(z.y,-y.x)
	var b := Rotation.multiply(z.x,-y.x)
	var values := [Rotation.multiply(z.y,y.y),Rotation.multiply(-z.x,y.y),y.x,Rotation.multiply(z.x,x.y)-Rotation.multiply(a,x.x),Rotation.multiply(z.y,x.y)+Rotation.multiply(b,x.x),Rotation.multiply(-y.y,x.x),Rotation.multiply(a,x.y)+Rotation.multiply(z.x,x.x),Rotation.multiply(z.y,x.x)-Rotation.multiply(b,x.y),Rotation.multiply(y.y,x.y)]
	for index in range(9): values[index] = Rotation.halfword(int(values[index]))
	return values

static func camera_view(camera: Dictionary, pairs: Array) -> Dictionary:
	if not camera.has_all(["position","angles"]) or camera.position.size() != 3 or camera.angles.size() != 3: return {"fault":"Invalid source cutscene camera"}
	var rotation := matrix(Vector3i(int(camera.angles[0]),int(camera.angles[1]),int(camera.angles[2])),pairs)
	if rotation.is_empty(): return {"fault":"Missing source cutscene camera trig table"}
	var position := Vector3i(int(camera.position[0]),int(camera.position[1]),int(camera.position[2]))
	var translated := Rotation.transform_long(rotation,-position)
	return {"matrix":rotation,"position":[translated.position.x,translated.position.y,translated.position.z]}

static func parts_view(camera: Dictionary, pairs: Array) -> Dictionary:
	# Main507a0 resets camera position to the zero default vector before4fab0.
	var data := camera.duplicate(true)
	data.position = [0,0,0]
	return camera_view(data,pairs)
