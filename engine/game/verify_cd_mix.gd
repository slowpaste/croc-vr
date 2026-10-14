extends SceneTree
const Mix = preload("res://source_cd_mix.gd")
func _initialize() -> void:
	var cases := [
		[1234,-2345,[128,128,0,0],Vector2(1234,-2345)],
		[1000,3000,[64,64,64,64],Vector2(2000,2000)],
		[1000,3000,[0,0,128,128],Vector2(3000,1000)],
		[32767,32767,[255,255,255,255],Vector2(32767,32767)],
		[-32768,-32768,[255,255,255,255],Vector2(-32768,-32768)],
		[-1,-1,[1,1,1,1],Vector2(-2,-2)],
		[32767,-32768,[0,0,0,0],Vector2.ZERO]
	]
	for sample in cases:
		if Mix.frame(sample[0],sample[1],sample[2])*32768.0 != sample[3]:
			push_error("CD routing/gain/rounding/saturation differs")
			quit(1)
			return
	print("PASS: CD gain, stereo/mono/cross routing, per-product rounding, saturation and mute")
	quit(0)
