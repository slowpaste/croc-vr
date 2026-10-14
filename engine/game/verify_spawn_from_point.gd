extends SceneTree
func _initialize() -> void:
	var source = preload("res://source_spawn_from.gd")
	# Independent original-runtime observations, not parent/zero pose assumptions.
	assert(source.scratch_angles(0x80080f78,0x429b0) == Vector3i(3960,-32760,10672))
	assert(source.scratch_angles(0x80080f78,0x4fa70) == Vector3i(3960,-32760,-1424))
	assert(source.scratch_angles(0x80080f78,0x51160) == Vector3i(3960,-32760,4448))
	assert(source.scratch_angles(0x80080f78,0x04000000) == Vector3i(3960,-32760,0))
	var matrix := [4096,0,0,0,4096,0,0,0,4096]
	var origin := Vector3i(4096,8192,12288); var scale := Vector3i(2048,4096,8192)
	var models := [{"bounds":[[100.0/4096,200.0/4096,300.0/4096]]}]
	assert(source.point(matrix,origin,scale,models,{},0,17).position == origin+Vector3i(50,200,600))
	var bones := [[4096,0,0,0,4096,0,0,0,4096,100,200,300],[4096,0,0,0,4096,0,0,0,4096,-100,-200,-300]]
	assert(source.point(matrix,origin,scale,models,{"vertexCount":1,"bones":[bones]},0,0).position == origin)
	assert(source.point(matrix,origin,scale,models,{"vertexCount":1,"bones":[bones]},0,1).position == origin+Vector3i(50,200,600))
	assert(source.point(matrix,origin,scale,models,{"vertexCount":0,"bones":[bones]},0,1).position == origin-Vector3i(50,200,600))
	assert(source.point(matrix,origin,scale,models,{"vertexCount":1,"bones":[bones]},0,-1).has("fault"))
	assert(source.point([],origin,scale,models,{},0,0).has("fault"))
	print("PASS: SpawnFrom static/vertex/skeletal origins preserve source indexing, render translation and fixed-point scale")
	quit(0)
