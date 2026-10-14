extends Node3D
signal finished
var video:=VideoStreamPlayer.new()
var viewer:Camera3D
var awaiting_pose:=true
func _init() -> void:
	add_child(preload("res://source_cinematic_surround.gd").new())
	var viewport:=SubViewport.new();viewport.size=Vector2i(320,240);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport);viewport.add_child(video)
	var stream:=VideoStreamTheora.new();stream.file="res://argonaut-logo.ogv";video.stream=stream
	video.finished.connect(func():finished.emit())
	var screen:=MeshInstance3D.new();screen.name="Screen"
	var quad:=QuadMesh.new();quad.size=Vector2(3.2,2.4);screen.mesh=quad
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_fog=true;screen.material_override=material;add_child(screen)
func setup(camera:Camera3D, volume:int) -> void:
	viewer=camera
	video.volume_db=linear_to_db(float(volume)/127.0) if volume>0 else -80.0
	video.play();reanchor()
func reanchor() -> void:
	global_transform=preload("res://source_horizon_anchor.gd").transform(viewer.global_transform,4.0)
	global_position.y-=0.35
func _process(_delta:float) -> void:
	get_node("Screen").material_override.albedo_texture=video.get_video_texture()
	if awaiting_pose:
		var interface:=XRServer.find_interface("OpenXR")
		if not get_viewport().use_xr or (interface!=null and int(interface.get_session_state())==5):
			reanchor();awaiting_pose=false
