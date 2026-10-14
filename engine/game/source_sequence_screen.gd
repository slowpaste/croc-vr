extends Node3D
var viewport := SubViewport.new()
var session := preload("res://source_sequence_session.gd").new()
var screen := MeshInstance3D.new()
var viewer_camera: Camera3D
var viewer_distance := 2.5
var awaiting_tracked_view := false
var uses_portal := false
func _init() -> void:
	add_child(preload("res://source_cinematic_surround.gd").new())
	viewport.size = Vector2i(512,240); viewport.own_world_3d = true
	viewport.use_xr = false; viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport); viewport.add_child(session)
	var quad := QuadMesh.new(); quad.size = Vector2(2.67,2.67*3.0/4.0)
	screen.mesh = quad; add_child(screen); visible = false
func setup(content: String, manifest: Dictionary, tables: Dictionary, scene_id: int, cd_state: Dictionary, viewer: Camera3D, distance: float = 2.5) -> bool:
	if viewer == null or not is_inside_tree() or distance < 0.5: return false
	uses_portal = get_viewport().use_xr or OS.get_cmdline_user_args().has("--portal-preview")
	viewer_camera = viewer
	if uses_portal:
		viewport.remove_child(session);session.free()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		session = preload("res://source_sequence_portal_session.gd").new();add_child(session)
		viewer_distance = 4.0;reanchor()
		if not session.setup(content,manifest,tables,scene_id,cd_state):return false
		session.player.camera.current=false
	var image_entry: Dictionary = {}
	for entry in manifest.get("cutsceneSequenceImages",[]):
		if scene_id == 0 and int(entry.get("sky_orientation_revision",0)) != 1: continue
		if int(entry.get("scene_id",-1)) == scene_id: image_entry = entry;break
	if uses_portal: pass
	elif not image_entry.is_empty():
		viewport.remove_child(session);session.free()
		session = preload("res://source_sequence_image_session.gd").new();viewport.add_child(session)
		if not session.setup_images(content.path_join(str(image_entry.file)).get_base_dir(),content,manifest,tables,scene_id,cd_state): return false
	elif not session.setup(content,manifest,tables,scene_id,cd_state): return false
	viewer_camera = viewer
	if not uses_portal:viewer_distance = distance
	reanchor()
	awaiting_tracked_view = get_viewport().use_xr
	if not XRServer.reference_frame_changed.is_connected(reanchor):
		XRServer.reference_frame_changed.connect(reanchor,CONNECT_DEFERRED)
	var interface := XRServer.find_interface("OpenXR")
	if interface != null and interface.has_signal("pose_recentered") and not interface.is_connected("pose_recentered",reanchor):
		interface.connect("pose_recentered",reanchor,CONNECT_DEFERRED)
	if not uses_portal:
		var material := ShaderMaterial.new(); material.shader = preload("res://source_cutscene_screen_material.gdshader")
		material.set_shader_parameter("source_texture",session.output_texture())
		screen.material_override = material
	screen.visible = not uses_portal
	apply_fade(); visible = true; return true
func advance(microseconds: int, held: int, budget: int = 1) -> Dictionary:
	var result := session.advance(microseconds,held,budget)
	if not result.has("fault") and screen.material_override != null:
		screen.material_override.set_shader_parameter("source_texture",session.output_texture())
		apply_fade()
	if uses_portal:apply_fade()
	return result
func apply_fade() -> void:
	var white := int(session.player.fade.get("kind",1)) == 3
	var level := int(session.player.fade.get("level",255))
	if uses_portal:
		session.portal.black_level=0 if white else level
		session.portal.white_level=level if white else 0
		session.portal.update_anchor();return
	screen.material_override.set_shader_parameter("source_black_level",0 if white else level)
	screen.material_override.set_shader_parameter("source_white_level",level if white else 0)
func set_paused(value: bool) -> void: session.set_paused(value)
func reanchor() -> void:
	if not is_instance_valid(viewer_camera): return
	global_transform = preload("res://source_horizon_anchor.gd").transform(viewer_camera.global_transform,viewer_distance)
	global_position.y-=0.35
func _process(_delta: float) -> void:
	if not awaiting_tracked_view: return
	var interface := XRServer.find_interface("OpenXR")
	if interface != null and interface.is_initialized() and int(interface.get_session_state()) == 5:
		reanchor()
		awaiting_tracked_view = false
