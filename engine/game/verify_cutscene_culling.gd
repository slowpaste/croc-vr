extends SceneTree
func _initialize() -> void:
	var cull = preload("res://source_cutscene_culling.gd")
	assert(cull.nclip(Vector2i(0,0),Vector2i(10,0),Vector2i(0,10)) == 100)
	assert(cull.nclip(Vector2i(0,0),Vector2i(0,10),Vector2i(10,0)) == -100)
	assert(cull.nclip(Vector2i(0,0),Vector2i(1,1),Vector2i(2,2)) == 0)
	assert(cull.triangle(0,0) and cull.triangle(0,100) and not cull.triangle(0,-100))
	assert(cull.triangle(4,-100) and not cull.triangle(0,0xffffffff))
	assert(cull.quad(0,100,100) and cull.quad(0,-100,-100) and not cull.quad(0,-100,100))
	assert(cull.quad(0,-100,0) and not cull.quad(0x80,-100,-100))
	assert(cull.quad(0x84,-100,100))
	print("PASS: original triangle/quad projected winding, signed MAC0, double-sided and0x80 branch semantics")
	quit(0)
