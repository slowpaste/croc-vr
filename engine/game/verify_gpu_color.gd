extends SceneTree
func _initialize() -> void:
	var color = preload("res://source_gpu_color.gd")
	for texture in range(32):
		assert(color.channel(texture,128,true,true,0) == texture)
		assert(color.channel(texture,0,true,false,-4) == texture)
	assert(color.channel(31,255,true,true,0) == 31)
	assert(color.channel(1,127,true,true,0) == 0)
	assert(color.channel(1,128,true,true,0) == 1)
	assert(color.channel(0,8,false,false,0) == 1)
	assert(color.channel(0,8,false,false,-4) == 0)
	assert(color.channel(0,255,false,false,3) == 31)
	assert(color.channel(0,0,false,false,-4) == 0)
	var sum := 0
	for y in range(4):
		for x in range(4):
			sum += color.dither_at(x,y)
			assert(color.dither_at(x+4,y+4) == color.dither_at(x,y))
	assert(sum == -8)
	assert(color.blend(31,31,0) == 31)
	assert(color.blend(5,3,0) == 4)
	assert(color.blend(30,8,1) == 31)
	assert(color.blend(4,9,2) == 0 and color.blend(20,7,2) == 13)
	assert(color.blend(10,7,3) == 11)
	assert(color.blend(0,0,4) == -1)
	print("PASS: integer5-bit color modulation, unity128, raw texture, saturation and4x4 dither phase")
	quit(0)
