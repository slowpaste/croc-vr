extends Node3D
var track=preload("res://source_menu_text_renderer.gd").new()
var bonus=preload("res://source_menu_text_renderer.gd").new()
var vr := false
func _init() -> void:
	add_child(track);add_child(bonus)
func configure(enabled: bool) -> void:
	vr=enabled
	for sprite in [track,bonus]:
		sprite.configure_vr_panel(enabled)
		if enabled:sprite.scale*=1.4
func present(state: Dictionary, paused: bool, bindings: Dictionary) -> bool:
	var layout:=preload("res://source_gameplay_hud.gd").layout(state,paused,vr)
	return track.set_text(layout.track,bindings.track.data,bindings.track.material.albedo_texture) and bonus.set_text(layout.bonus,bindings.bonus.data,bindings.bonus.material.albedo_texture)
