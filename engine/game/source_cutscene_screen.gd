extends Node3D
var viewport := SubViewport.new()
var session := preload("res://source_cutscene_session.gd").new()
var screen := MeshInstance3D.new()
var uses_portal := false
func _init() -> void:
	add_child(preload("res://source_cinematic_surround.gd").new())
	viewport.size = Vector2i(512,240)
	viewport.own_world_3d = true
	viewport.use_xr = false
	# Preserve dark source color levels before the VR screen samples this texture.
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)
	viewport.add_child(session)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	viewport.add_child(environment)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.67,2.67*240.0/512.0)
	screen.mesh = quad
	add_child(screen)
	visible = false

func setup_sad(content: String, manifest: Dictionary, tables: Dictionary, cd_state: Dictionary, viewer: Camera3D, distance: float = 2.5) -> bool:
	if viewer == null or not is_inside_tree() or distance < 0.5: return false
	uses_portal=get_viewport().use_xr or OS.get_cmdline_user_args().has("--portal-preview")
	if uses_portal:
		viewport.remove_child(session);session.free()
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		session=preload("res://source_sad_portal_session.gd").new();add_child(session)
		distance=4.0
	if not session.setup_sad(content,manifest,tables,cd_state): return false
	# Snapshot the viewer once; subsequent head motion never moves this screen.
	global_transform = preload("res://source_horizon_anchor.gd").transform(viewer.global_transform,distance)
	global_position.y-=0.35
	if not uses_portal:
		var material := ShaderMaterial.new()
		material.shader = preload("res://source_cutscene_screen_material.gdshader")
		material.set_shader_parameter("source_texture",session.compositor.output.get_texture())
		screen.material_override = material
	screen.visible=not uses_portal
	if uses_portal:
		session.portal.black_level=int(session.player.fade.get("level",255));session.portal.update_anchor()
	visible = true
	return true

func advance(microseconds: int, held: int, budget: int = 1) -> Dictionary:
	var result := session.advance(microseconds,held,budget)
	if uses_portal:
		session.portal.black_level=int(session.player.fade.get("level",255));session.portal.update_anchor()
	if not result.has("fault") and screen.material_override != null: screen.material_override.set_shader_parameter("source_black_level",int(session.player.fade.get("level",255)))
	return result

func set_paused(value: bool) -> void:
	session.set_paused(value)
