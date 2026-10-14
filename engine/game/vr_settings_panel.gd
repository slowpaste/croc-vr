extends Node
# Settings service: visible settings belong to the original Options menu.
var controls: RefCounted
var opened := false
var foveation: Node
var settings_path := "user://vr-controls.cfg"
var open_down := false
var controller_focused := false
func setup(config: RefCounted, view: Node3D) -> void:
	controls=config;controls.foveation_debug=false
	foveation=preload("res://vr_foveation.gd").new();add_child(foveation)
	foveation.setup(view);foveation.apply(controls.foveation_level,false)
func save_changes() -> void:
	controls.camera_tilt=get_parent().vr_camera_pitch
	controls.reset_gestures();controls.save_settings(settings_path)
	foveation.apply(controls.foveation_level,false)
func toggle() -> void:
	var world:=get_parent()
	if int(world.source_main_mode)==8:
		world.source_options_state.exit_requested=true;world.process_source_options(0,0)
	elif int(world.source_main_mode) in [0,1,4,5]:world.enter_source_title_options(1,int(world.source_main_mode) if int(world.source_main_mode) in [4,5] else 1)
func keyboard(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if int(get_parent().source_main_mode)==8:get_parent().process_source_options(0,0x100000)
		else:toggle()
		return true
	return false
func xr_input(left: XRController3D, _right: XRController3D, focused: bool) -> void:
	controller_sample(left.is_button_pressed("by_button"),focused)
func controller_sample(opening: bool, focused: bool) -> void:
	if not focused:controller_focused=false;return
	if not controller_focused:controller_focused=true;open_down=opening;return
	if opening and not open_down:toggle()
	open_down=opening
