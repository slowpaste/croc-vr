extends SceneTree
func _initialize() -> void:
	var mapper=preload("res://source_input.gd")
	var calibration={"lower_midpoint":Vector2i(64,64),"upper_midpoint":Vector2i(191,191)}
	var cases=[
		[Vector2i(128,0),Vector2i(64,191),4,0x10000,false],
		[Vector2i(128,0),Vector2i(192,128),4,0x40080000,true],
		[Vector2i(128,0),Vector2i(192,128),8,0x80000,true],
		[Vector2i(128,128),Vector2i(0,255),4,0x40060000,true],
		[Vector2i(64,191),Vector2i(128,128),4,0,false]]
	for row in cases:
		var result: Dictionary=mapper.analog_directions(row[0],row[1],calibration,row[2])
		if result.get("held",-1)!=row[3] or result.right_override!=row[4]:push_error("Original analog midpoint/override rule differs");quit(1);return
	if not mapper.analog_directions(Vector2i(-1,128),Vector2i(128,128),calibration,4).has("fault"):quit(1);return
	print("PASS: source-derived analog midpoint edges, right-stick override and mode4 modifier; full decoder/capture pending")
	quit(0)
