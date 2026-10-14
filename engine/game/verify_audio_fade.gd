extends SceneTree
const AudioMath = preload("res://source_audio_math.gd")
func _initialize() -> void:
	if AudioMath.fade_step(100) != 12 or AudioMath.fade_step(65527) != -1 or AudioMath.fade_half_up(90,15,100) != 100 or AudioMath.fade_half_up(20,12,100) != 32 or AudioMath.fade_half_up(65535,0,100) != 100 or AudioMath.fade_half_up(65535,1,100) != 0:
		quit(1)
		return
	if AudioMath.fade_half_down(5,4) != 0 or AudioMath.fade_half_down(6,4) != 2 or AudioMath.fade_half_down(0,1) != 0 or AudioMath.should_fade_out(1,2,4,1) or AudioMath.should_fade_out(2,3,8,0) or not AudioMath.should_fade_out(1,0,4,0):
		quit(1)
		return
	print("PASS: source audio fade halfword arithmetic, caps, zero threshold and skip gates")
	quit(0)
