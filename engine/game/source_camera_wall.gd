extends RefCounted
const VM = preload("res://asl_vm.gd")
const Collision = preload("res://source_collision.gd")
const Rotation = preload("res://source_rotation.gd")
static func miss_accumulated_push(record: Dictionary, point: Vector2i, tile_angle: int, quarter: Array) -> Dictionary:
	# Native36594..3686c: enabled old edges with strictly negative distance,
	# distance+distance>>8, and old cache restored only after nonzero movement.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22 or quarter.size() != 1025: return {"fault":"Missing no-hit camera geometry"}
	var delta := Vector2i.ZERO
	var blocked := false
	for edge in range(4 if (int(h[0])&4) else 3):
		if ((int(h[1])>>(edge+8))&1) == 0: continue
		var contact := edge_push(record,point,edge,8)
		if contact.has("fault"): return contact
		if int(contact.distance) >= 0: continue
		blocked = true
		delta = Vector2i(Rotation.halfword(delta.x+contact.delta.x),Rotation.halfword(delta.y+contact.delta.y))
	return {"blocked":blocked,"world_delta":Collision.local_point(delta,-tile_angle,quarter)}
static func lower_route(previous_tile: int, cache_match: int) -> int:
	# Native369ec..36a34: a missing previous tile or matched cached plane
	# selects route2; an unmatched prior plane selects route3.
	return 2 if previous_tile < 0 or (cache_match&65535) != 0 else 3
static func fresh_edge_push(record: Dictionary, center: Vector2i, probe: Vector2i, edge: int) -> Dictionary:
	# Native374b4..3764c: center outside an enabled plane; correction uses
	# probe distance plus distance>>6, rather than cached route's>>2.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22 or edge < 0 or edge >= (4 if (int(h[0])&4) else 3): return {"fault":"Invalid fresh camera edge"}
	var a := int(h[2+edge*4]);var b := int(h[3+edge*4])
	var constant := Collision.word(h,4+edge*4)
	var center_distance := VM.signed32((VM.signed32(VM.signed32(a*center.x)-VM.signed32(b*center.y))>>12)+constant)
	if center_distance > 0 or (int(h[1])&(17<<edge)) == 0: return {"delta":Vector2i.ZERO}
	var distance := VM.signed32((VM.signed32(VM.signed32(a*probe.x)-VM.signed32(b*probe.y))>>12)+constant)
	var denominator := Collision.square_ir(a)+Collision.square_ir(b)
	if denominator == 0: return {"delta":Vector2i.ZERO}
	var margin := VM.signed32(distance+(distance>>6))
	return {"delta":Vector2i(int(float(VM.signed32(-VM.signed32(margin*a)))/denominator),int(float(VM.signed32(margin*b))/denominator))}
static func fresh_accumulated_push(record: Dictionary, center: Vector2i, probe: Vector2i, tile_angle: int, quarter: Array) -> Dictionary:
	var h: Array = record.get("halfwords",[])
	if h.size() != 22 or quarter.size() != 1025: return {"fault":"Missing fresh camera geometry"}
	var delta := Vector2i.ZERO
	for edge in range(4 if (int(h[0])&4) else 3):
		var contact := fresh_edge_push(record,center,probe,edge)
		if contact.has("fault"): return contact
		delta = Vector2i(Rotation.halfword(delta.x+contact.delta.x),Rotation.halfword(delta.y+contact.delta.y))
	return {"local_delta":delta,"world_delta":Collision.local_point(delta,-tile_angle,quarter)}
static func accumulated_probe_pushes(record: Dictionary, points: Array[Vector3i], tile_origin: Vector2i, tile_angle: int, quarter: Array) -> Dictionary:
	var total := Vector2i.ZERO
	var responses: Array[Vector2i] = []
	for point in points:
		var relative := Vector2i(VM.signed32(point.x+total.x-tile_origin.x),VM.signed32(point.z+total.y-tile_origin.y))
		var local := Collision.local_point(relative,tile_angle,quarter)
		var response := accumulated_edge_push(record,local,tile_angle,quarter)
		if response.has("fault"): return response
		var delta: Vector2i = response.world_delta
		responses.append(delta)
		total = Vector2i(VM.signed32(total.x+delta.x),VM.signed32(total.y+delta.y))
	return {"delta":total,"responses":responses}
static func accumulated_edge_push(record: Dictionary, point: Vector2i, tile_angle: int, quarter: Array) -> Dictionary:
	var h: Array = record.get("halfwords",[])
	if h.size() != 22 or quarter.size() != 1025: return {"fault":"Missing camera wall geometry"}
	var delta := Vector2i.ZERO
	for edge in range(4 if (int(h[0])&4) else 3):
		var contact := edge_push(record,point,edge)
		if contact.has("fault"): return contact
		# Native248/256(sp) accumulators are signed halfwords; all edges use
		# the same original local point before the final world rotation.
		delta.x = Rotation.halfword(delta.x+contact.delta.x)
		delta.y = Rotation.halfword(delta.y+contact.delta.y)
	return {"local_delta":delta,"world_delta":Collision.local_point(delta,-tile_angle,quarter)}
static func edge_push(record: Dictionary, point: Vector2i, edge: int, margin_shift: int = 2) -> Dictionary:
	# Native370e0..37234: camera edge correction uses distance+distance/4.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22 or edge < 0 or edge >= (4 if (int(h[0])&4) else 3):
		return {"fault":"Invalid camera wall edge"}
	var a := int(h[2+edge*4]);var b := int(h[3+edge*4])
	var distance := VM.signed32((VM.signed32(VM.signed32(a*point.x)-VM.signed32(b*point.y))>>12)+Collision.word(h,4+edge*4))
	if distance > 0: return {"delta":Vector2i.ZERO,"distance":distance}
	var denominator := Collision.square_ir(a)+Collision.square_ir(b)
	if denominator == 0: return {"delta":Vector2i.ZERO,"distance":distance}
	var margin := VM.signed32(distance+(distance>>margin_shift))
	var x := int(float(VM.signed32(-VM.signed32(margin*a)))/float(denominator))
	var z := int(float(VM.signed32(margin*b))/float(denominator))
	return {"delta":Vector2i(x,z),"distance":distance}
