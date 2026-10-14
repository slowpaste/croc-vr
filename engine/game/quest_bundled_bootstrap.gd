extends Node3D
var installer=preload("res://source_bundled_content.gd").new()
var worker:=Thread.new()
var label: Label3D
var screen_label: Label
var index: Dictionary
func _ready() -> void:
	var origin:=XROrigin3D.new();add_child(origin)
	var camera:=XRCamera3D.new();origin.add_child(camera);camera.current=true
	var xr:=XRServer.find_interface("OpenXR")
	if xr!=null and (xr.is_initialized() or xr.initialize()):get_viewport().use_xr=true
	label=Label3D.new();label.position=Vector3(0,0,-2);label.font_size=42;label.pixel_size=0.0015
	label.no_depth_test=true;camera.add_child(label)
	screen_label=Label.new();screen_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER);add_child(screen_label)
	set_message("Preparing Croc game data…")
	index=installer.read_index()
	if not index.is_empty() and bool(index.get("requiresOpenXR",false)) and OS.has_feature("android") and not get_viewport().use_xr:
		set_message("Quest VR could not start. Close and reopen Croc VR.");return
	if index.is_empty() or not installer.prepare_archives(index):set_message("The included game data could not be opened. Reinstall this APK.");return
	if worker.start(installer.install.bind(index))!=OK:set_message("Game data preparation could not start. Relaunch Croc VR.")
func set_message(message: String) -> void:
	label.text=message;screen_label.text=message
func _process(_delta: float) -> void:
	if not worker.is_started():return
	var state:Dictionary=installer.status()
	if worker.is_alive():
		set_message("Preparing Croc game data: %d%%\nThis happens once. Keep the app open."%roundi(float(state.progress)*100));return
	var success=worker.wait_to_finish()
	if not success:set_message(str(state.fault));return
	set_message("Starting Croc VR…")
	set_process(false);call_deferred("start_game")
func start_game() -> void:
	await get_tree().process_frame
	if not installer.mount(index):set_message("The included game data could not be loaded. Relaunch Croc VR.");return
	ProjectSettings.set_setting("croc/bundled_content_root","res://imported_data")
	get_tree().change_scene_to_file("res://imported.tscn")
func _exit_tree() -> void:
	if worker.is_started():worker.wait_to_finish()
