extends Node3D
var viewport := SubViewport.new()
var presenter := preload("res://source_credits_presenter.gd").new()
var screen := MeshInstance3D.new()
var paused := false
var tick_accumulator := 0.0
var fade: Dictionary = {}
var exiting := false
var complete := false
var has_world_background := false
func _init() -> void:
	viewport.size = Vector2i(512,240); viewport.own_world_3d = true
	viewport.use_xr = false; viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport); viewport.add_child(presenter)
	viewport.add_child(Camera3D.new())
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	viewport.add_child(environment)
	var quad := QuadMesh.new(); quad.size = Vector2(2.67,2.67*240.0/512.0)
	screen.mesh = quad; add_child(screen); visible = false
func setup(content: String, manifest: Dictionary, variant: int, viewer: Camera3D, distance: float = 2.5, world_background: bool = false) -> bool:
	if viewer == null or not is_inside_tree() or distance < 0.5: return false
	if not presenter.setup(content,manifest,variant): return false
	global_transform = Transform3D(viewer.global_basis,viewer.global_position-viewer.global_basis.z*distance)
	has_world_background = world_background
	viewport.transparent_bg = world_background
	var material := ShaderMaterial.new()
	material.shader = preload("res://source_credits_overlay.gdshader") if world_background else preload("res://source_cutscene_screen_material.gdshader")
	material.render_priority = 126
	material.set_shader_parameter("source_texture",viewport.get_texture())
	fade = preload("res://source_transition_fade.gd").start(1)
	if not world_background:
		material.set_shader_parameter("source_black_level",255)
		material.set_shader_parameter("source_white_level",0)
	screen.material_override = material
	paused = false; tick_accumulator = 0; visible = true
	exiting = false; complete = false
	return true
func advance(delta: float) -> Dictionary:
	if not presenter.fault.is_empty(): return {"fault":presenter.fault}
	if presenter.state.is_empty(): return {"fault":"Credits screen is not initialized"}
	if paused: return {"paused":true,"complete":complete}
	tick_accumulator += maxf(delta,0.0)*30.0
	var result := {"complete":complete}
	var ticks := 0
	while tick_accumulator >= 1.0 and not result.complete:
		tick_accumulator -= 1.0
		ticks += 1
		if exiting:
			fade = preload("res://source_transition_fade.gd").advance(fade,0)
			complete = bool(fade.ready)
			result = {"complete":complete,"credits_complete":true,"exiting":true}
		else:
			fade = preload("res://source_transition_fade.gd").advance(fade,0)
			result = presenter.advance()
			if result.has("fault"): return result
			if bool(result.complete):
				exiting = true
				fade = preload("res://source_transition_fade.gd").start(8)
			result.credits_complete = bool(result.complete)
			result.complete = false
		if not has_world_background: screen.material_override.set_shader_parameter("source_black_level",int(fade.level))
	result.ticks = ticks
	return result
func set_paused(value: bool) -> void: paused = value
