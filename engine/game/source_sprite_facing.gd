extends RefCounted
# Camera-facing image quads within imported actor models. Solid meshes and
# non-XY planes (for example animated bee wings) retain their source transforms.
static func is_image_quad(model: Dictionary) -> bool:
	var vertices: Array = model.get("vertices",[])
	var faces: Array = model.get("faces",[])
	if vertices.size() != 4 or faces.size() != 1 or (int(faces[0].flags)&9) != 9 or faces[0].indices.size() != 4:
		return false
	for count in model.get("collision",{}).get("counts",[0,0]):
		if int(count) != 0:
			return false
	var xs: Dictionary = {}
	var ys: Dictionary = {}
	var corners: Dictionary = {}
	for point in vertices:
		if float(point[2]) != float(vertices[0][2]):
			return false
		xs[point[0]] = true
		ys[point[1]] = true
		corners[Vector2(point[0],point[1])] = true
	return xs.size() == 2 and ys.size() == 2 and corners.size() == 4
static func is_actor_sprite(pack:Dictionary, model_index:int, model_name:String="") -> bool:
	# Flat wings/eyes beside a solid body belong to its rig. Sprite-only effect
	# packs may contain several independent images, which still face the camera.
	var models:Array=pack.get("models",[])
	if model_index<0 or model_index>=models.size():return false
	# MrFrBall has two solid parts and a separate camera-facing flame image.
	if model_name=="MRFRBALL.MOD" and model_index==2:return is_image_quad(models[model_index])
	# Gobbo's two authored image parts coexist with solid animated limbs.
	# Preserve the explicit sprite exception when excluding mixed-pack wings.
	if model_name=="GOBBO.MOD" and model_index in [8,9]:return is_image_quad(models[model_index])
	for part in models:
		if not is_image_quad(part):return false
	return true

static func facing_basis(origin: Vector3, camera_position: Vector3, source_scale: Vector3) -> Basis:
	var forward := camera_position-origin
	if forward.length_squared() < 0.000001:
		return Basis()
	forward = forward.normalized()
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := forward.cross(right).normalized()
	return Basis(right*source_scale.x,up*source_scale.y,forward*source_scale.z)
