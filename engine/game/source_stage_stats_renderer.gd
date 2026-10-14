extends Node3D
const Stats = preload("res://source_stage_stats.gd")
const SpriteRenderer = preload("res://source_menu_text_renderer.gd")
var labels := SpriteRenderer.new()
var track := SpriteRenderer.new()
var shared := SpriteRenderer.new()
var backdrop := preload("res://source_fade_overlay.gd").new()
func configure_vr_panel(enabled: bool) -> void:
	for sprite in [labels,track,shared]: sprite.configure_vr_panel(enabled)
func _init() -> void:
	backdrop.fade_material.render_priority = 125
	add_child(backdrop)
	add_child(labels)
	add_child(track)
	add_child(shared)
func update_stats(state: Dictionary, text_data: Dictionary, bindings: Dictionary) -> bool:
	for key in ["font","track","shared"]:
		if not bindings.has(key): return false
	var icons := Stats.icon_layout(state)
	backdrop.set_source_level(Stats.backdrop_level(state))
	var numbers := Stats.number_layout(state)
	if labels.frame_buttons_enabled:
		text_data=text_data.duplicate(true)
		text_data.continuePrompt.text=str(text_data.continuePrompt.text).replace("=","{")
		text_data.glyphs["123"]={"sprite":0,"width":20,"height":20,"advance":24}
	numbers.labels[0].glyphs.append_array(icons.track.labels[0].glyphs)
	return labels.set_text(Stats.label_layout(text_data,int(state.busy)),bindings.font.data,bindings.font.texture) and track.set_text(numbers,bindings.track.data,bindings.track.texture) and shared.set_text(icons.shared,bindings.shared.data,bindings.shared.texture)
