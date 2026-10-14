extends RefCounted
const VM = preload("res://asl_vm.gd")
static func terrain(flags: int, depths: Array) -> Dictionary:
	# Native1f7f0..1f848/20098..200ec: terrain always takes farthest SZ.
	if depths.size() not in [3,4]: return {"fault":"Invalid source terrain face"}
	var result := 0
	for depth in depths: result = maxi(result,clampi(int(depth),0,65535))
	if (flags&0x43) == 0x43: result = VM.signed32(result+64)
	return {"depth":result,"bucket":result>>6}
# Native19218..192fc/1948c..1951c/19a34..19ad4.
# Depth values are the GTE's saturated unsigned SZ outputs, not world Z.
static func face(flags: int, depths: Array, maximum_mode: bool = false, owner_flags: int = 0) -> Dictionary:
	if depths.size() not in [3,4]: return {"fault":"Invalid source depth face"}
	var values: Array = []
	var sum := 0
	for depth in depths:
		var value := clampi(int(depth),0,65535)
		values.append(value)
		sum = VM.signed32(sum+value)
	var result: int
	if maximum_mode:
		result = int(values.max())
		if depths.size() == 4 and (flags&0x41) == 0x41 and (flags&2) != 0 and (owner_flags&2) == 0: result = VM.signed32(result+64)
	elif depths.size() == 4:
		result = sum>>2 if (flags&0x40) != 0 else VM.signed32(int(values[0])+int(values[2]))>>1
	else:
		# Retail uses four arithmetic shifts, rather than division by three.
		result = VM.signed32((sum>>2)+(sum>>4)+(sum>>6)+(sum>>8))
	return {"depth":result,"bucket":result>>6}
