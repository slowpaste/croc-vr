extends SceneTree
func _initialize() -> void:
	var gte = preload("res://source_gte_lighting.gd")
	var identity := [4096,0,0,0,4096,0,0,0,4096]
	assert(gte.nccs_rgb(Vector3i(4096,4096,4096),identity,identity,[0,0,0],[1,128,255]).rgb == [1,128,255])
	assert(gte.nccs_rgb(Vector3i.ZERO,identity,identity,[64,64,64],[255,255,255]).rgb == [63,63,63])
	var source := gte.nccs_rgb(Vector3i(0,4096,0),[0,4096,0,0,2048,3547,0,2048,-3547],[1024,4096,682,1024,4096,682,1024,2048,682],[64,64,64],[128,128,128])
	assert(source.light_ir == [4096,2048,2048] and source.color_ir == [4437,4437,3413] and source.rgb == [138,138,106])
	var maximum := [32767,32767,32767,32767,32767,32767,32767,32767,32767]
	var saturated: Dictionary = gte.nccs_rgb(Vector3i(32767,32767,32767),maximum,maximum,[255,255,255],[255,255,255])
	assert(saturated.light_ir == [32767,32767,32767] and saturated.rgb == [255,255,255])
	assert(gte.nccs_rgb(Vector3i(-4096,-4096,-4096),identity,identity,[0,0,0],[255,255,255]).rgb == [0,0,0])
	assert(gte.nccs_rgb(Vector3i.ZERO,[],[],[],[]).has("fault"))
	print("PASS: source NCCS RGB pipeline, ambient<<4,12-bit stages, signed normals and positive/RGB saturation")
	quit(0)
