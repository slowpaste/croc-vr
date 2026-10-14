extends SceneTree
func _initialize() -> void:
	var lighting = preload("res://source_cutscene_lighting.gd")
	var identity := [4096,0,0,0,4096,0,0,0,4096]
	var quarter := [0,0,4096,0,4096,0,-4096,0,0]
	var source := {"lightMatrix":[0,4096,0,0,2048,3547,0,2048,-3547]}
	var part := {"matrix":identity,"position":[0,0,0],"scale":4096}
	assert(lighting.part_light_matrix(part,{"matrix":identity,"position":[0,0,0]},source).matrix == source.lightMatrix)
	assert(lighting.part_light_matrix(part,{"matrix":quarter,"position":[0,0,0]},source).matrix == source.lightMatrix)
	part.matrix = quarter
	assert(lighting.part_light_matrix(part,{"matrix":identity,"position":[0,0,0]},source).matrix == [0,4096,0,-3547,2048,0,3547,2048,0])
	part.matrix = [2048,0,0,0,2048,0,0,0,2048]; part.scale = 2048
	assert(lighting.part_light_matrix(part,{"matrix":identity,"position":[0,0,0]},source).matrix == [0,4096,0,0,2048,3546,0,2048,-3548])
	print("PASS: native light/view/part composition and separate normal-scale reciprocal preserve signed rounding")
	quit(0)
