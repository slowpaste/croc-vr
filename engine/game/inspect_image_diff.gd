extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1);return
	var expected := Image.load_from_file(args[0]);var actual := Image.load_from_file(args[1])
	if expected == null or actual == null or expected.get_size() != actual.get_size(): quit(1);return
	var differences := []
	for y in range(expected.get_height()):
		for x in range(expected.get_width()):
			var a := expected.get_pixel(x,y);var b := actual.get_pixel(x,y)
			if a != b: differences.append({"x":x,"y":y,"expected":[roundi(a.r*255),roundi(a.g*255),roundi(a.b*255)],"actual":[roundi(b.r*255),roundi(b.g*255),roundi(b.b*255)]})
	print(JSON.stringify({"different_pixels":differences.size(),"pixels":differences.slice(0,64)}))
	quit(0)
