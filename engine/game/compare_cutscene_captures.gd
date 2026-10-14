extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gl := Image.load_from_file(args[0] if args.size() >= 2 else "res://../build/cutscene-SAD-first-gl.png")
	var mobile := Image.load_from_file(args[1] if args.size() >= 2 else "res://../build/cutscene-SAD-first.png")
	if gl == null or mobile == null or gl.get_size() != mobile.get_size(): quit(1); return
	var maximum := 0
	var changed := 0
	var samples: Array = []
	var signed_total := Vector3i.ZERO
	for y in range(gl.get_height()):
		for x in range(gl.get_width()):
			var first := gl.get_pixel(x,y)
			var second := mobile.get_pixel(x,y)
			var delta := maxi(absi(first.r8-second.r8),maxi(absi(first.g8-second.g8),absi(first.b8-second.b8)))
			maximum = maxi(maximum,delta)
			if delta >= 8 and samples.size() < 8: samples.append({"position":Vector2i(x,y),"gl":[first.r8,first.g8,first.b8],"mobile":[second.r8,second.g8,second.b8]})
			signed_total += Vector3i(second.r8-first.r8,second.g8-first.g8,second.b8-first.b8)
			if delta != 0: changed += 1
	print("CUTSCENE_RENDERER_DIFFERENCE: ",{"changed_pixels":changed,"maximum_rgb_byte_delta":maximum})
	print("CUTSCENE_COLOR_SAMPLES: ",{"samples":samples,"signed_total":signed_total})
	quit(0)
