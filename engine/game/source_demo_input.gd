extends RefCounted
const VM = preload("res://asl_vm.gd")
static func sample(frames: Array, tick: int, previous: int) -> Dictionary:
	if frames.size() != 900 or tick < 0:
		return {"fault":"Missing original900-frame demo recording or invalid tick"}
	# Main15e14..15ea0, playback sets pad mode1 and uses the ordinary edge updater.
	var held := VM.signed32(int(frames[tick])) if tick < 900 else 0
	return {"held":held,"pressed":VM.signed32((~previous)&held),"released":VM.signed32((~held)&previous),"pad_mode":1}
