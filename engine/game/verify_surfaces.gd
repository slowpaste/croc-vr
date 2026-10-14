extends SceneTree
const Collision = preload("res://source_collision.gd")
var failures := 0

func check(condition: bool) -> void:
	if not condition:
		failures += 1
		push_error("Source collision surface check failed")

func _initialize() -> void:
	check(Collision.terrain_query_state({"tile":4,"record":77,"height_units":123},{},"query_field_6",0) == {"tile":-1,"record":77,"height_units":123,"query_field_6":0})
	check(not Collision.terrain_query_state({}, {},"query_field_6",0).has("record"))
	var upper := [{"height_units":100,"group":0,"flags":8,"tile":0},{"height_units":50,"group":0,"flags":8,"tile":1},{"height_units":-10,"group":0,"flags":8,"tile":2}]
	check(Collision.select_ceiling(upper,0).height_units == 50)
	check(Collision.select_ceiling(upper,100).height_units == 100)
	check(Collision.select_ceiling(upper,50).height_units == 100)
	check(Collision.select_ceiling([],0).is_empty())
	var ceiling_plane: Array = []
	ceiling_plane.resize(22)
	ceiling_plane.fill(0)
	ceiling_plane[0] = 8
	check(Collision.surface({"halfwords":ceiling_plane},Vector2i.ZERO,true,true).is_empty())
	for edge in range(3):
		ceiling_plane[4+edge*4] = -1
		ceiling_plane[5+edge*4] = -1
	check(not Collision.surface({"halfwords":ceiling_plane},Vector2i.ZERO,true,true).is_empty())
	var candidates: Array = []
	for height in [2000,3000,1000,900,1100]:
		candidates.append({"height_units":height,"group":0,"flags":4,"surface_type":0})
	check(Collision.select_floor(candidates,0).height_units == 1000)
	check(Collision.select_floor(candidates.slice(0,2),0).height_units == 2000)
	candidates.append({"height_units":1024,"group":0,"flags":4,"surface_type":17})
	check(Collision.select_floor(candidates,0).height_units == 1024)
	check(Collision.select_floor(candidates,0,true).height_units == 1000)
	candidates.append({"height_units":1023,"group":1,"flags":4,"surface_type":0})
	candidates.append({"height_units":1022,"group":0,"flags":12,"surface_type":0})
	check(Collision.select_floor(candidates,0,true).height_units == 1000)
	check(Collision.select_floor([],0).is_empty())
	var cached := {"height_units":1024,"group":0,"flags":4,"surface_type":0,"tile":99,"query_field_6":1}
	check(Collision.select_floor(candidates,0,false,cached).tile == 99)
	check(Collision.select_floor([],0,false,cached) == cached)
	var ties := [{"height_units":1000,"group":0,"flags":4,"surface_type":0,"tile":0},{"height_units":1000,"group":0,"flags":4,"surface_type":0,"tile":1}]
	check(Collision.select_floor(ties,0).tile == 0)
	var overflow := [{"height_units":-2147483000,"group":0,"flags":4,"surface_type":0},{"height_units":0,"group":0,"flags":4,"surface_type":0}]
	check(Collision.select_floor(overflow,2147483647).height_units == -2147483000)
	# Four inward halfplanes bound [-128,128] in both axes. Border is inclusive.
	var record := {"halfwords":[4 | (17 << 8),0,4096,0,128,0,-4096,0,128,0,0,4096,128,0,0,-4096,128,0,0,0,1177,0]}
	check(Collision.surface(record,Vector2i.ZERO).height_units == 1177)
	check(Collision.surface(record,Vector2i(128,-128)).surface_type == 17)
	check(Collision.surface(record,Vector2i(129,0)).is_empty())
	check(Collision.surface(record,Vector2i(0,-129)).is_empty())
	# Triangles use three planes, irrespective of the fourth record's contents.
	record.halfwords[0] = 0
	check(not Collision.surface(record,Vector2i(0,-1000)).is_empty())
	# Sloped surfaces preserve the original >>8 conversion and signed height word.
	record.halfwords[0] = 2
	record.halfwords[18] = 256
	record.halfwords[19] = -128
	record.halfwords[20] = -1
	record.halfwords[21] = -1
	check(Collision.surface(record,Vector2i(64,32)).height_units == 47)
	# PS-X signed overflow is observable before the arithmetic right shift.
	record.halfwords[18] = -32768
	record.halfwords[19] = 0
	for offset in [2,6,10,14]:
		record.halfwords[offset] = 0
		record.halfwords[offset + 1] = 0
	check(Collision.surface(record,Vector2i(-65536,0)).get("height_units",0) == -8388609)
	check(Collision.surface({"halfwords":[]},Vector2i.ZERO).is_empty())
	if failures == 0:
		print("PASS: source halfplane inclusion, triangle/quad edges, slope height, surface type and signed overflow")
	quit(1 if failures else 0)
