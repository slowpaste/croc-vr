extends Node3D
const SpriteRenderer = preload("res://source_menu_text_renderer.gd")
var backdrop := SpriteRenderer.new()
var labels := SpriteRenderer.new()
var clear := MeshInstance3D.new()
var clear_material := ShaderMaterial.new()
func configure_vr_panel(enabled: bool) -> void:
	backdrop.configure_vr_panel(enabled)
	labels.configure_vr_panel(enabled)
	clear_material.set_shader_parameter("physical_panel",enabled)
	clear.position = labels.position
	clear.scale = labels.scale
func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	clear.mesh = quad
	clear_material.shader = preload("res://source_frontend_clear.gdshader")
	clear_material.render_priority = 124
	clear.material_override = clear_material
	clear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clear.extra_cull_margin = 16384
	add_child(clear)
	backdrop.text_material.render_priority = 125
	labels.text_material.render_priority = 126
	add_child(backdrop)
	add_child(labels)
	visible = false

func update_screen(tables: Dictionary, names: Array, progress: Array, selected: int, pickups: Array, bindings: Dictionary) -> bool:
	return update_layout(preload("res://source_game_over_screen.gd").compose(tables,names,progress,selected,pickups),tables,bindings)

func update_entry(tables: Dictionary, state: Dictionary, bindings: Dictionary) -> bool:
	return update_layout(preload("res://source_password_entry_text.gd").layout(tables.get("gameOver",{}),state),tables,bindings)

func update_continue(tables: Dictionary, state: Dictionary, bindings: Dictionary) -> bool:
	return update_layout(preload("res://source_continue_text.gd").layout(tables.get("gameOver",{}),state),tables,bindings,false)

func update_layout(screen: Dictionary, tables: Dictionary, bindings: Dictionary, draw_backdrop: bool = true) -> bool:
	visible = false
	if screen.has("fault"): return false
	for key in (["font","backdrop"] if draw_backdrop else ["font"]):
		if not bindings.has(key) or not bindings[key].has_all(["data","texture"]): return false
	var color: Array = tables.get("gameOver",{}).get("clearColor",[])
	if color.size() != 3: return false
	clear_material.set_shader_parameter("clear_color",Vector3(float(color[0]),float(color[1]),float(color[2]))/255.0)
	if draw_backdrop:
		if not backdrop.set_text(preload("res://source_game_over_backdrop.gd").layout(),bindings.backdrop.data,bindings.backdrop.texture): return false
	else: backdrop.hide()
	if not labels.set_text(screen,bindings.font.data,bindings.font.texture): return false
	visible = true
	return true
