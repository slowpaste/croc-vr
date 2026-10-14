extends RefCounted
# Visual-only secondary motion. Croc's feet/legs deform inside body mesh 0;
# the ten rigid parts are the head, arms/hands, eyes and backpack.
var feet: Dictionary = {}
var lean := Vector2.ZERO
var lean_velocity := Vector2.ZERO
var previous_velocity := Vector3.ZERO
var clip_name := ""
var stance_heights: Dictionary = {}
var last_mesh_key := ""
var last_mesh: ArrayMesh
var last_points: Array[Vector3] = []
var pose_mesh_builder=preload("res://source_pose_mesh_builder.gd").new()
var pose_mesh_model:Dictionary={}

func reset() -> void:
	feet.clear()
	lean = Vector2.ZERO
	lean_velocity = Vector2.ZERO
	previous_velocity = Vector3.ZERO
	clip_name = ""
	last_mesh_key = ""
	last_mesh = null
	last_points.clear()

static func gait(name: String) -> bool:
	return preload("res://modern_motion_palette.gd").LOOPS.has(name)

static func foot_indices(side: int) -> Array:
	var indices: Array = range(41,66) if side == 0 else range(66,91)
	indices.append_array(range(91,95) if side == 0 else range(95,99))
	return indices

static func decode_vertices(packed_vertices: Array, meters: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for packed_value in packed_vertices:
		var packed := int(packed_value)
		var point := Vector3.ZERO
		for axis in range(3):
			var value := (packed>>(axis*10))&1023
			if value >= 512: value -= 1024
			point[axis] = float(value)*meters/1024.0
		points.append(point)
	return points

static func sole(points: Array[Vector3], side: int) -> Vector3:
	var minimum := INF
	var center := Vector3.ZERO
	var count := 0
	for index in foot_indices(side): minimum = minf(minimum,points[index].y)
	for index in foot_indices(side):
		if points[index].y <= minimum+0.015:
			center += points[index]
			count += 1
	center /= maxi(count,1)
	center.y = minimum
	return center

static func record_normal(record:Dictionary,yaw:float,scale:Vector3=Vector3.ONE) -> Vector3:
	var h:Array=record.get("halfwords",[])
	if absf(scale.x)<0.000001 or absf(scale.y)<0.000001 or absf(scale.z)<0.000001:return Vector3.UP
	if h.size()!=22 or (int(h[0])&2)==0:return Vector3.UP
	var normal:=Vector3(-float(h[18])/256.0/scale.x,1.0/scale.y,-float(h[19])/256.0/scale.z).normalized()
	return Basis(Vector3.UP,yaw)*normal

static func floor_normal(world:Node3D,hit:Dictionary) -> Vector3:
	var index:=int(hit.get("record",-1))
	if index<0:return Vector3.UP
	if hit.has("actor"):
		var owner_id:=int(hit.actor)
		if not world.source_pool.slots.has(owner_id):return Vector3.UP
		var owner=world.source_pool.slots[owner_id].node
		if not is_instance_valid(owner) or owner.model_data.is_empty():return Vector3.UP
		for group in owner.model_data.models[0].get("collision",{}).get("groups",[]):
			if index<group.size():return record_normal(group[index],float(owner.source_rotation_y)*TAU/4096.0,Vector3(owner.source_scale)/4096.0)
			index-=group.size()
	elif hit.has("tile"):
		var tile:Dictionary=world.room_data.tracks[int(hit.tile)]
		var records:Array=world.terrain_models[int(tile.index)].collision.groups[int(hit.get("group",0))]
		if index<records.size():return record_normal(records[index],float(tile.rotation)*TAU)
	return Vector3.UP

static func foot_tilt(normal:Vector3,weight:float) -> Quaternion:
	var angle:=acos(clampf(Vector3.UP.dot(normal.normalized()),-1,1))
	var axis:=Vector3.UP.cross(normal)
	if axis.length_squared()<0.000001:return Quaternion.IDENTITY
	return Quaternion(axis.normalized(),minf(angle,deg_to_rad(40.0))*weight)

func apply(actor: Node3D, delta: float) -> void:
	if actor.mesh_parts.size() != 11 or int(actor.clip.get("vertexCount",0)) != 100 or not is_instance_valid(actor.visual_root):
		reset()
		return
	if absf(actor.visual_root.global_basis.determinant())<0.000001 or absf(actor.mesh_parts[0].basis.determinant())<0.000001:
		reset()
		return
	var grounded: bool = (actor.secondary_flags&2) != 0
	if not grounded or not (gait(actor.clip_name) or actor.clip_name.begins_with("CROCWA") or actor.clip_name in ["CROCLEFT.ANI","CROCRGHT.ANI"]):
		reset()
		return
	if clip_name != actor.clip_name:
		feet.clear()
		clip_name = actor.clip_name
	var dt := minf(delta,1.0/30.0)
	var local_velocity: Vector3 = actor.visual_root.global_basis.inverse()*actor.modern_velocity
	var acceleration := (local_velocity-previous_velocity)/maxf(dt,0.001)
	previous_velocity = local_velocity
	var target := Vector2(clampf(-local_velocity.z*0.035-acceleration.z*0.001,-0.12,0.12),clampf(local_velocity.x*0.035+acceleration.x*0.001,-0.12,0.12))
	lean_velocity += ((target-lean)*100.0-lean_velocity*20.0)*dt
	lean += lean_velocity*dt
	actor.visual_root.global_basis = actor.visual_root.global_basis*Basis.from_euler(Vector3(lean.x,0,lean.y))
	var points := decode_vertices(actor.clip.vertices[actor.clip_frame],actor.world.CELL_METERS)
	var fraction := float(actor.clip_fraction)/256.0
	if actor.clip_playing and actor.clip_frame+1<int(actor.clip.frameCount):
		var following := decode_vertices(actor.clip.vertices[actor.clip_frame+1],actor.world.CELL_METERS)
		for index in range(points.size()): points[index] = points[index].lerp(following[index],fraction)
	if actor.modern_blend_alpha<1.0 and actor.modern_blend_points.size()==points.size():
		for index in range(points.size()): points[index] = Vector3(actor.modern_blend_points[index]).lerp(points[index],actor.modern_blend_alpha)
	var body: MeshInstance3D = actor.mesh_parts[0]
	var mesh_key := clip_name+":"+str(actor.clip_frame)+":"+str(roundi(fraction*32.0))+":"+str(roundi(actor.modern_blend_alpha*32.0))
	for side in [0,1]:
		var local_sole := sole(points,side)
		var world_sole: Vector3 = body.global_transform*local_sole
		var hit: Dictionary = actor.world.source_cached_floor_at(world_sole,{})
		var contacts: Dictionary = actor.world.source_contacts_at(world_sole,actor)
		if not contacts.lower.is_empty() and (hit.is_empty() or int(contacts.lower.height_units)>int(hit.height_units)): hit = contacts.lower
		if hit.is_empty():
			feet.erase(side)
			continue
		var floor_y: float = float(hit.height_units)*actor.world.CELL_METERS/4096.0
		if absf(floor_y-actor.global_position.y)>0.3:
			feet.erase(side)
			continue # Never bridge an edge or pull a foot down a cliff.
		var key := clip_name+":"+str(side)
		if not stance_heights.has(key):
			var minimum := INF
			for frame in actor.clip.vertices: minimum = minf(minimum,sole(decode_vertices(frame,actor.world.CELL_METERS),side).y)
			stance_heights[key] = minimum
		var weight := 1.0-smoothstep(0.015,0.09,local_sole.y-float(stance_heights[key]))
		if not feet.has(side): feet[side] = {"offset":Vector3.ZERO,"tilt":Quaternion.IDENTITY,"anchor":world_sole,"planted":false,"owner":-1}
		var foot: Dictionary = feet[side]
		var owner := int(hit.get("actor",-1))
		var owner_node: Node3D = null
		if owner >= 0 and actor.world.source_pool.slots.has(owner): owner_node = actor.world.source_pool.slots[owner].node
		if weight>0.7:
			if not foot.planted or foot.owner != owner:
				foot.anchor = Vector3(world_sole.x,floor_y,world_sole.z)
				foot.owner = owner
				if is_instance_valid(owner_node): foot.owner_local = owner_node.to_local(foot.anchor)
				foot.planted = true
			if is_instance_valid(owner_node) and foot.has("owner_local"): foot.anchor = owner_node.to_global(foot.owner_local)
		else:
			foot.planted = false
		var desired := Vector3(world_sole.x,lerpf(world_sole.y,floor_y,weight),world_sole.z)
		if foot.planted:
			var horizontal := Vector3(foot.anchor.x-world_sole.x,0,foot.anchor.z-world_sole.z).limit_length(0.08)
			desired += horizontal*weight
		var correction: Vector3 = body.global_basis.inverse()*(desired-world_sole)
		correction = correction.limit_length(0.12)
		foot.offset = Vector3(foot.offset).lerp(correction,1.0-exp(-25.0*dt))
		var normal:Vector3=(body.global_basis.transposed()*floor_normal(actor.world,hit)).normalized()
		foot.tilt=Quaternion(foot.tilt).slerp(foot_tilt(normal,weight),1.0-exp(-25.0*dt))
		mesh_key += ":"+str(Vector3(foot.offset).snapped(Vector3.ONE*0.001))
		mesh_key += ":"+str(Quaternion(foot.tilt).get_euler().snapped(Vector3.ONE*0.002))
		for index in foot_indices(side):
			var rest_y: float = float(actor.model_data.models[0].vertices[index][1])*actor.world.CELL_METERS
			var influence := 1.0-smoothstep(0.06,0.24,rest_y)
			var relative:=points[index]-local_sole
			points[index] += (Quaternion(foot.tilt)*relative-relative+Vector3(foot.offset))*influence
	if last_mesh == null or last_mesh_key != mesh_key:
		var started:=Time.get_ticks_usec()
		var model:Dictionary=actor.model_data.models[0]
		if not is_same(pose_mesh_model,model):
			pose_mesh_builder.setup(actor.world.geometry(model,actor.model_texture),model)
			pose_mesh_model=model
		last_mesh = pose_mesh_builder.build(points)
		if actor.world.has_method("record_runtime_cost"):actor.world.record_runtime_cost("modern_mesh_build",Time.get_ticks_usec()-started)
		last_mesh_key = mesh_key
		last_points = points
	body.mesh = last_mesh
