extends SceneTree
const Clock = preload("res://source_frame_clock.gd")
func _initialize() -> void:
	for refresh in [60,72,90,144]:
		var clock := Clock.new()
		for frame in range(refresh):
			clock.advance(1.0/refresh)
		if clock.counter != 60 or absf(clock.fractional_frames) > 0.000001:
			push_error("Virtual source display counter depended on headset refresh")
			quit(1)
			return
	var clock := Clock.new()
	clock.counter = 2147483646
	clock.advance(1.0/30.0)
	if clock.counter != -2147483648:
		quit(1)
		return
	clock = Clock.new()
	clock.advance(1.0/120.0)
	if clock.counter != 0:
		quit(1)
		return
	clock.advance(1.0/120.0)
	if clock.counter != 1:
		quit(1)
		return
	print("PASS: independent virtual display counter at60/72/90/144Hz, fractional cadence and source signed wrap")
	quit(0)
