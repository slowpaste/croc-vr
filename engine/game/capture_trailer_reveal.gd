extends SceneTree
var shaders:Dictionary={}
func _initialize() -> void:call_deferred("run")
func smooth(a:float,b:float,x:float) -> float:return smoothstep(a,b,x)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var output:String=args[args.find("--out")+1]
	var content:String=args[args.find("--content")+1]
	var pilot:=args.has("--pilot")
	root.size=Vector2i(1280,720)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var viewer:=Camera3D.new();root.add_child(viewer);viewer.current=true;viewer.fov=48
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var display=preload("res://source_sequence_screen.gd").new();root.add_child(display)
	assert(display.setup(content,manifest,tables,0,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667},viewer))
	display.set_process(false);display.session.audio.stream.stop_stream()
	var portal=display.session.portal
	portal.set_process(false)
	for child in portal.get_children():
		if child is MeshInstance3D:child.hide()
	for i in range(300):
		if pilot and not i in [0,50,75,110,130,135,141,148,156,205,260,299]:continue
		assert(display.session.present_frame(2 if i<60 else 11,80+i if i<60 else 60+i-60))
		portal.black_level=0;portal.white_level=0
		# Freeze the stage into a plane, then release the genuine scene geometry.
		var depth:=smooth(135,153,float(i))
		var pull:=smooth(60,100,float(i))
		var enter:=smooth(135,165,float(i))
		var tilt:=smooth(170,230,float(i))
		viewer.position=Vector3(.85*pull-.6*enter+.055*sin(float(i)*.07)*enter,.05*pull+.95*tilt,-2.75+2.9*pull-2.55*enter)
		var target:=Vector3(-.06*enter,-.35+.45*sin(enter*PI)-.65*tilt,-5.0-3.5*enter)
		viewer.look_at(target)
		viewer.rotation.z=.012*sin(float(i)*.043)*enter
		for key in portal.materials:
			var mat:ShaderMaterial=portal.materials[key]
			var original:Shader=mat.shader
			if not shaders.has(original.get_instance_id()):
				var code:String=original.code
				code=code.replace("uniform float viewer_distance = 4.0;","uniform float viewer_distance = 4.0;\nuniform float trailer_depth = 0.0;\nuniform float trailer_spread = 1.0;")
				code=code.replace("vec2 original_ray = VERTEX.xy/depth*source_h*(3.2/512.0);","stage_depth = mix(stage_depth*0.003,stage_depth,trailer_depth);\n vec2 original_ray = VERTEX.xy/depth*source_h*(3.2/512.0)*trailer_spread;")
				var custom:=Shader.new();custom.code=code
				shaders[original.get_instance_id()]=custom
				shaders[custom.get_instance_id()]=custom
			mat.shader=shaders[original.get_instance_id()]
			mat.set_shader_parameter("trailer_depth",depth)
			mat.set_shader_parameter("trailer_spread",lerpf(1.0,1.3,enter))
			mat.set_shader_parameter("aperture",Vector2(3.2,1.6).lerp(Vector2(40,40),smooth(143,156,float(i))))
			mat.set_shader_parameter("black_level",0.0)
			mat.set_shader_parameter("white_level",0.0)
		for child in portal.get_children():
			if child is MeshInstance3D and not child in portal.nodes.values():child.visible=depth<.2
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join("reveal-%04d.png"%i))==OK)
	print("REVEAL_CAPTURE_COMPLETE music entrance frame 135 (24.5s in edit)")
	display.queue_free();await process_frame
	quit(0)
