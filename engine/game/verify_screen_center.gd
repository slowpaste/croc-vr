extends SceneTree
const Center = preload("res://source_screen_center.gd")
func _initialize() -> void:
	var cases := [
		[Vector2i.ZERO,0,Vector2i.ZERO,0],
		[Vector2i.ZERO,0x20000,Vector2i(-1,0),1],
		[Vector2i.ZERO,0x80000,Vector2i(1,0),1],
		[Vector2i.ZERO,0x10000,Vector2i(0,-1),1],
		[Vector2i.ZERO,0x40000,Vector2i(0,1),1],
		[Vector2i(-8,-8),0x30000,Vector2i(-8,-8),2],
		[Vector2i(24,24),0xc0000,Vector2i(24,24),2],
		[Vector2i(24,-8),0xf0000,Vector2i(24,-8),4]
	]
	for sample in cases:
		var result := Center.advance(sample[0],sample[1],0)
		if result.offset!=sample[2] or result.moves!=sample[3] or result.apply_display!=(sample[3]!=0):
			push_error("Original screen-center source-derived boundary mismatch");quit(1);return
	for pressed in [0x100000,0x800000,0x900000]:
		var result := Center.advance(Vector2i(2,3),0,pressed)
		if not result.back or result.parent_page!=4 or result.parent_selection!=3: quit(1);return
	print("PASS: source-derived screen-center directions, limits, opposite input and return; runtime oracle pending")
	quit(0)
