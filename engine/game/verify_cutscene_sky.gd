extends SceneTree
func _initialize() -> void:
	var sky = preload("res://source_cutscene_sky.gd")
	var first: Dictionary = sky.frame({"position":[6274,620,11862]},1)
	assert(first.parts.size() == 1 and first.parts[0].position == [6274,-1893,11862])
	assert(first.parts[0].matrix == [8192,0,0,0,8192,0,0,0,8192])
	assert(sky.frame({"position":[1,-1,2]},1).parts[0].position == [1,-2049,2])
	assert(sky.frame({},1).has("fault"))
	print("PASS: SAD26 dome camera-follow position, signed quarterY offset and original double-scale matrix")
	quit(0)
