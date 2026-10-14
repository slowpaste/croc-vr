extends RefCounted
# Physical display plane: 44 degrees wide, with the original 512x240 layout.
const DISTANCE := 4.0
const SIZE := Vector2(3.2,1.5)
static func configure_sprite(sprite: MeshInstance3D, enabled: bool) -> void:
	sprite.text_material.set_shader_parameter("physical_panel",enabled)
	sprite.position = Vector3(0,0,-DISTANCE) if enabled else Vector3.ZERO
	sprite.scale = Vector3(SIZE.x/2.0,SIZE.y/2.0,1.0) if enabled else Vector3.ONE
