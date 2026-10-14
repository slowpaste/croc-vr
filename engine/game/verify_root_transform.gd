extends SceneTree
const Rotation = preload("res://source_rotation.gd")

func _initialize() -> void:
	if Rotation.approach_angle(4090,10,5) != 4095 or Rotation.approach_angle(10,4090,5) != 5 or Rotation.approach_angle(0,2048,100) != 100 or Rotation.approach_angle(0,1024,2000) != 1024:
		quit(1)
		return
	var identity := [4096,0,0,0,4096,0,0,0,4096]
	var quarter_y := [0,0,4096,0,4096,0,-4096,0,0]
	if Rotation.actor_push_probe(quarter_y,Vector3i(4096,1024,0),Vector3i(8192,4096,4096),Vector3i(100,200,300),Vector2i(10,20)).position != Vector3i(90,1224,-3816):
		quit(1)
		return
	var origin := Vector3i(2147483647,10,-20)
	var models := [{"bounds":[[1,2,3]]},{"bounds":[[-1,0,0]]}]
	var bones := [[4096,0,0,0,4096,0,0,0,4096,123,-456,789]]
	if Rotation.model_contact_points(identity,Vector3i.ZERO,models).points != [Vector3i(4096,8192,12288),Vector3i(-4096,0,0)]:
		quit(1)
		return
	var animated := Rotation.model_contact_points(identity,Vector3i(10,20,30),models,{"vertexCount":1,"bones":[bones]},0)
	if animated.points != [Vector3i(10,20,30),Vector3i(133,-436,819)]:
		quit(1)
		return
	if not Rotation.model_contact_points(identity,Vector3i.ZERO,models,{"vertexCount":0,"bones":[bones]},0).has("fault"):
		quit(1)
		return
	if Rotation.contact_point(identity,origin,Vector3i(32768,-32769,65536),false).position != Vector3i(2147450879,32777,-20):
		quit(1)
		return
	if Rotation.contact_point(identity,origin,Vector3i(32768,-32769,65536),true).position != Vector3i(-2147450881,-32759,65516):
		quit(1)
		return
	if Rotation.contact_point(quarter_y,Vector3i(100,200,300),Vector3i(4096,1,8192),false).position != Vector3i(8292,201,-3796):
		quit(1)
		return
	var composed := Rotation.parent_pose(quarter_y,Vector3i(8192,1234,16384),identity,Vector3i(4096,0,0))
	if composed.position != Vector3i(8192,1234,12288) or composed.matrix != quarter_y:
		quit(1)
		return
	if Rotation.compose(quarter_y,quarter_y) != [-4096,0,0,0,4096,0,0,0,-4096]:
		quit(1)
		return
	if Rotation.compose(quarter_y,[4096,0,0,0,0,-4096,0,4096,0]) != [0,4096,0,0,0,-4096,-4096,0,0]:
		quit(1)
		return
	for point in [Vector3i(32768,-32769,1000000),Vector3i(-65536,12345,-1000000)]:
		if Rotation.transform_long(identity,point).position != point:
			quit(1)
			return
	if Rotation.frame_delta(quarter_y,Vector3i(1,-2,3)).position != Vector3i(3,-2,-1):
		quit(1)
		return
	if Rotation.scaled_matrix(identity,Vector3i(8192,-4096,4096)) != [8192,0,0,0,-4096,0,0,0,4096]:
		quit(1)
		return
	if Rotation.point_offset(quarter_y,Vector3i(4096,0,0),Vector3i(8192,4096,4096)).position != Vector3i(0,0,-4096):
		quit(1)
		return
	# Source long-vector transform retains IR halfword wrapping for large components.
	if Rotation.transform_long(identity,Vector3i(2147483647,0,0)).position.x != -1:
		quit(1)
		return
	# The sf=1 low pass shifts the full MAC accumulator, not a wrapped 32-bit sum.
	if Rotation.transform_long([32767,32767,32767,0,0,0,0,0,0],Vector3i(32767,32767,32767)).position.x != 786384:
		quit(1)
		return
	print("PASS: source long-vector split, signed transforms, quarter-turn frame movement and MAC/IR wrapping")
	quit(0)
