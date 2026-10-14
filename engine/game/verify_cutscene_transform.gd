extends SceneTree
func _initialize() -> void:
	var transform = preload("res://source_cutscene_transform.gd")
	var identity := [4096,0,0,0,4096,0,0,0,4096]
	var quarter := [0,0,4096,0,4096,0,-4096,0,0]
	var part := {"matrix":identity,"position":[100,200,300],"scale":4096}
	var composed: Dictionary = transform.compose_view(part,{"matrix":quarter,"position":[10,20,30]})
	assert(composed.matrix == quarter and composed.position == Vector3i(310,220,-70) and composed.scale == 4096)
	part.scale = 65535
	assert(transform.compose_view(part,{"matrix":identity,"position":[0,0,0]}).scale == -1)
	assert(transform.compose_view({},{}).has("fault"))
	assert(transform.normal_scale(0) == 0 and transform.normal_scale(4092) == 4092 and transform.normal_scale(4100) == 4100)
	assert(transform.normal_scale(2048) == 8192 and transform.normal_scale(-2048) == -8192)
	part.scale = 2048
	part.matrix = [2048,0,0,0,2048,0,0,0,2048]
	var model := {"vertices":[[100.0/4096,200.0/4096,300.0/4096]]}
	var geometry: Dictionary = transform.vertices(part,model,{"matrix":identity,"position":[0,0,0]})
	assert(geometry.vertices == [Vector3i(150,300,450)] and geometry.normal_scale == 8192)
	part.vertices = [[10,20,30,99]]
	assert(transform.vertices(part,model,{"matrix":identity,"position":[0,0,0]}).vertices == [Vector3i(105,210,315)])
	part.vertices = []
	assert(transform.vertices(part,model,{"matrix":identity,"position":[0,0,0]}).has("fault"))
	print("PASS: native cutscene view/part matrix composition, translation and separate signed scale")
	quit(0)
