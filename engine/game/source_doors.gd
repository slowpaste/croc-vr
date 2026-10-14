extends RefCounted
const VM = preload("res://asl_vm.gd")
static func transition_request(door: Dictionary, current_level: int, current_style: int, destination_style: int, entry_active: bool, counter: Variant) -> Dictionary:
	# Source0x8003bfe4..0x8003c1e4 orders delay before arrival/level gates.
	if (int(door.flags)&2) != 0 and destination_style == 1:
		if counter == null:
			return {"fault":"Unknown source swimming-entry delay counter"}
		if int(counter) != 10:
			return {"transition":false,"counter":VM.signed32(int(counter)+1)}
	else:
		counter = 0
	if (int(door.flags)&16) != 0:
		return {"transition":true,"state":3,"counter":counter,"capture_origin":false}
	if entry_active:
		return {"transition":false,"counter":counter}
	var state := 3 if int(door.level) != current_level else 2
	if state == 2 and ((current_style in [1,11]) != (destination_style in [1,11])):
		state = 5
	return {"transition":true,"state":state,"counter":counter,"capture_origin":true}
static func matching_exit(position: Vector3i, y_factor: int, secondary: int, doors: Array) -> Dictionary:
	# Source0x8003beac..0x8003bfdc: integer grid matching, not proximity.
	var divisor := VM.signed32(y_factor<<3)
	var numerator := VM.signed32(position.y+y_factor)
	if divisor == 0 or (numerator == -2147483648 and divisor == -1):
		return {"fault":"Invalid source door Y division"}
	var cell := Vector3i(VM.signed32(position.x+2048)>>12,int(float(numerator)/divisor),VM.signed32(position.z+2048)>>12)
	for index in range(doors.size()):
		var door: Dictionary = doors[index]
		if int(door.flags) == 8:
			continue
		var p: Array = door.position
		if cell != Vector3i(int(p[0]),int(p[1]),int(p[2])):
			continue
		# The first matching door requiring ground blocks further searching.
		if (int(door.flags)&2) != 0 and (secondary&2) == 0:
			return {"matched":false,"blocked":true,"index":index}
		return {"matched":true,"index":index,"door":door}
	return {"matched":false,"blocked":false}
