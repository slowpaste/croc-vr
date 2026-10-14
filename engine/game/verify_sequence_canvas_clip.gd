extends SceneTree
func _initialize() -> void:
	var clip = preload("res://source_sequence_canvas_clip.gd")
	var input := [{"position":Vector3(-1,1,-1),"uv":Vector2.ZERO,"color":Color.RED},{"position":Vector3(-1,-1,-1),"uv":Vector2(0,1),"color":Color.BLUE},{"position":Vector3(1,1,-1),"uv":Vector2(1,0),"color":Color.GREEN}]
	var output: Array = clip.triangles(input,120)
	assert(output.size() == 6)
	var found := false
	for vertex in output:
		for plane in range(5): assert(clip.distance(vertex,plane,120) >= -0.000001)
		if vertex.position.distance_to(Vector3(-1,-0.4,-1)) < 0.000001:
			assert(vertex.uv.distance_to(Vector2(0,0.7)) < 0.000001)
			assert(absf(vertex.color.r-0.3) < 0.000001 and absf(vertex.color.b-0.7) < 0.000001)
			found = true
	assert(found)
	var a := {"position":Vector3(0,0,-1),"uv":Vector2.ZERO,"color":Color.RED}
	var b := {"position":Vector3(1,0,-3),"uv":Vector2.ONE,"color":Color.BLUE}
	var middle: Dictionary = clip.intersection(a,b,0.5)
	assert(middle.uv.distance_to(Vector2(0.75,0.75)) < 0.000001)
	assert(absf(middle.color.r-0.25) < 0.000001 and absf(middle.color.b-0.75) < 0.000001)
	print("PASS: canvas viewport clipping triangulates the boundary and preserves homogeneous color/UV without RGB8 requantization")
	quit(0)
