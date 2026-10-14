extends RefCounted
const VM = preload("res://asl_vm.gd")
# Source516d4..51780: signed halfword option, division by8 toward zero.
static func restore(volume: int, stereo_flag: int) -> Dictionary:
	var level := volume&65535
	if level >= 32768: level -= 65536
	var decrement := (level+7 if level < 0 else level)>>3
	var byte := level&255
	return {"counter":level,"decrement":decrement,"mix":[byte,byte,byte if stereo_flag == 0 else 0,byte if stereo_flag == 0 else 0]}

# Source515b4..516c0: option adjustment clamps a signed halfword sum to0..127.
static func adjust(volume: int, delta: int, stereo_flag: int) -> Dictionary:
	var signed_volume := volume&65535
	if signed_volume >= 32768: signed_volume -= 65536
	var signed_delta := delta&65535
	if signed_delta >= 32768: signed_delta -= 65536
	var level := clampi(signed_volume+signed_delta,0,127)
	var result := restore(level,stereo_flag)
	result.volume = level
	return result
# Source51968..51a24; numerical CD mix update, hardware streaming is separate.
static func advance(counter: int, stereo_flag: int) -> Dictionary:
	if counter == 0:
		return {"counter":0,"changed":false}
	var remaining := VM.signed32(counter-1)
	if remaining <= 0:
		remaining = 0
	var byte := remaining&255
	return {"counter":remaining,"changed":true,"level":remaining,"mix":[byte,byte,byte if stereo_flag == 0 else 0,byte if stereo_flag == 0 else 0]}

# Source514dc..515a4: callback fade uses gp1536, not the title's unit step.
# The active word is set to3 only while the signed subtraction remains positive.
static func advance_callback(counter: int, decrement: int, stereo_flag: int, active: int) -> Dictionary:
	if counter == 0:
		return {"counter":0,"active":active,"changed":false}
	var remaining := VM.signed32(counter-decrement)
	if remaining > 0:
		active = 3
	else:
		remaining = 0
	var byte := remaining&255
	return {"counter":remaining,"active":active,"changed":true,"level":remaining,"mix":[byte,byte,byte if stereo_flag == 0 else 0,byte if stereo_flag == 0 else 0]}
