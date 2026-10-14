extends RefCounted
const VM = preload("res://asl_vm.gd")
var counter := 0
var fractional_frames := 0.0
# Virtual NTSC display cadence for this supported US backup; independent of XR Hz.
func advance(delta: float) -> int:
	fractional_frames += maxf(delta,0.0)*60.0
	var frames := floori(fractional_frames+0.000000001)
	fractional_frames -= frames
	counter = VM.signed32(counter+frames)
	return counter
