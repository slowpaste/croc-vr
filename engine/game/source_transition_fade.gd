extends RefCounted
const VM = preload("res://asl_vm.gd")
static func start(kind: int) -> Dictionary:
	# Dispatcher0x8003db60: profiles2/8 start at0; profile1 starts at288.
	# Profile2 uses the source additive-white presentation; its counter is separate.
	if kind not in [1,2,3,5,7,8,12,14,15]:
		return {"fault":"Unimplemented source transition profile"}
	var state := {"kind":kind,"counter":288 if kind == 1 else 0,"ready":false,"active":true,"level":255 if kind == 1 else 0}
	if kind in [3,7,15]:
		state.counter = 256
		state.level = 255
	if kind in [5,12]:
		state.rotation = 0
		state.render_scale = 0
	return state
static func advance(state: Dictionary, override_value: int) -> Dictionary:
	var result := state.duplicate(true)
	if not bool(result.active):
		return result
	var counter := VM.signed32(int(result.counter))
	if int(result.kind) in [5,12]:
		# Shared polygon handler3d544: rotation advances before override checking.
		result.rotation = (int(result.rotation)+113)&4095
		result.render_scale = counter>>4
		if override_value != 1:
			if counter == 0:
				result.counter = 1416
			elif counter > 0x67fff:
				result.ready = true
			else:
				result.counter = VM.signed32((counter>>8)*308)
		return result
	if int(result.kind) in [1,3,7,15] and counter < 0:
		counter = 0
		result.counter = 0
	result.level = 255 if counter >= 256 else counter&255
	if override_value == 1:
		return result
	if int(result.kind) in [2,8,14]:
		if counter < 288:
			result.counter = VM.signed32(counter+(32 if int(result.kind) == 2 else 24))
		else:
			result.ready = true # Source0x8003c250 keeps the black handler active.
	else:
		if counter > 0:
			result.counter = VM.signed32(counter-32)
		else:
			result.ready = true
			result.active = false # Source0x8003c23c also clears the handler.
	return result
