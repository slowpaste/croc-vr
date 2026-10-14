extends RefCounted
const Rotation = preload("res://source_rotation.gd")
# SPDX-License-Identifier: GPL-2.0-only
# Retail 0x8001b720: raw-texture semitransparent FT4, ENM polygon ShadowType.
# Geometry and materials are shared; a tick changes only an instance transform.
static func radius_units(model_radius: int, size_q16: int, height: int) -> int:
	var radius := ((((model_radius >> 2) + (model_radius >> 3)) * size_q16) & 0xffffffff) >> 16
	if height > 0:
		radius = (radius * maxi(4096-height,2048)) >> 12
	return radius

static func mesh(texture: Dictionary, shadow_type: int) -> ArrayMesh:
	var polygons: Array = texture.get("polygons",[])
	if shadow_type < 0 or shadow_type >= polygons.size():return null
	var uv: Array = polygons[shadow_type].uv
	if uv.size() != 4:return null
	var corners := [Vector3(-1,0,1),Vector3(1,0,1),Vector3(-1,0,-1),Vector3(1,0,-1)]
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,1,2,1,3,2]:
		builder.set_uv(Vector2(uv[index][0],uv[index][1]))
		builder.set_uv2(Vector2(1,int(polygons[shadow_type].get("blend",2))))
		builder.set_color(Color.WHITE) # Raw texture ignores the primitive's zero RGB.
		builder.set_normal(Vector3.UP)
		builder.add_vertex(corners[index])
	var result := builder.commit()
	var material: ShaderMaterial = texture.runtime_blend_material.duplicate()
	# Native command 0x2f blends every nonzero texel, including those without STP.
	material.set_shader_parameter("has_mask",false)
	result.surface_set_material(0,material)
	return result

static func update(actor: Node3D) -> void:
	var eligible: bool = (int(actor.primary_flags)&0x80020)==0x20 and not actor.model_data.is_empty() and int(actor.source_ground.get("mode",0)) != 0
	if not eligible:
		if is_instance_valid(actor.contact_shadow):actor.contact_shadow.hide()
		return
	var world: Node3D = actor.world
	var key := "%d:%d" % [int(world.room_data.style),int(actor.source_shadow_type)]
	if not world.source_shadow_meshes.has(key):
		world.source_shadow_meshes[key] = mesh(actor.model_texture,int(actor.source_shadow_type))
	var geometry: ArrayMesh = world.source_shadow_meshes[key]
	if geometry == null:return
	if not is_instance_valid(actor.contact_shadow):
		actor.contact_shadow = MeshInstance3D.new()
		actor.contact_shadow.name = "SourceContactShadow"
		actor.contact_shadow.top_level = true
		actor.contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.add_child(actor.contact_shadow)
	actor.contact_shadow.mesh = geometry
	var ground := int(actor.source_ground.height_units)
	var size := 65536 if actor.source_shadow_size == null else int(actor.source_shadow_size)
	var radius: float = radius_units(roundi(float(actor.model_data.models[0].radius)*4096.0),size,int(actor.source_render_position.y)-ground)*world.CELL_METERS/4096.0
	if radius <= 0:
		actor.contact_shadow.hide()
		return
	var matrix: Array = Rotation.matrix(Vector3i(0,actor.source_angles.y,0),world.runtime_tables.rotation.pairs)
	var basis := Basis(Vector3(matrix[0],matrix[3],matrix[6])/4096.0,Vector3.UP,Vector3(matrix[2],matrix[5],matrix[8])/4096.0).scaled(Vector3(radius,1,radius))
	var location: Vector3 = Vector3(actor.source_render_position)*world.CELL_METERS/4096.0
	location.y = ground*world.CELL_METERS/4096.0+0.002
	actor.contact_shadow.global_transform = Transform3D(basis,location)
	actor.contact_shadow.show()
