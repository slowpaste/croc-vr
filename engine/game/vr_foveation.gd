extends Node
# Fixed per-eye shading map. Debug samples this exact map in eye-screen space.
const MAP_SIZE := 128
var viewport: Viewport
var overlay: MeshInstance3D
var material: ShaderMaterial
var density: ImageTexture
var level := 0
var debug_enabled := false
var xr_density := false
var gaze_ready := false
var stable_gaze_seconds := 0.0
var active_density := false
var suspension_reason := "Off"

static func density_image(setting: int) -> Image:
	var image := Image.create(MAP_SIZE,MAP_SIZE,false,Image.FORMAT_RGBA8)
	var radius: float = [1.0,0.36,0.28,0.20][clampi(setting,0,3)]
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var distance := (Vector2(x+0.5,y+0.5)/float(MAP_SIZE)-Vector2(0.5,0.5)).length()
			var rate := 0.0 if setting==0 or distance<=radius else 1.0/3.0
			if setting>=2 and distance>radius+0.18: rate=2.0/3.0
			image.set_pixel(x,y,Color(rate,rate,0.0))
	return image

func setup(view: Node3D) -> void:
	viewport = view.get_viewport()
	overlay = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	overlay.mesh = quad
	overlay.extra_cull_margin = 16384.0
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;
uniform sampler2D density_map : filter_nearest, repeat_disable;
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
void fragment() {
 float rate = texture(density_map, SCREEN_UV).r;
 ALBEDO = vec3(0.1, 1.0, 0.25);
 ALPHA = rate < 0.1 ? 0.22 : 0.0;
}
"""
	material.shader = shader
	material.render_priority = 127
	overlay.material_override = material
	view.add_child(overlay)
	apply(0,false)

func apply(setting: int, show_region: bool) -> void:
	level = clampi(setting,0,3)
	debug_enabled = show_region
	active_density = false
	suspension_reason = "Off" if level == 0 else "Waiting for reliable gaze"
	if density==null or int(density.get_meta("level",-1))!=level:
		density = ImageTexture.create_from_image(density_image(level))
		density.set_meta("level",level)
	viewport.vrs_texture = density if level>0 else null
	viewport.vrs_mode = Viewport.VRS_TEXTURE if level>0 else Viewport.VRS_DISABLED
	viewport.vrs_update_mode = Viewport.VRS_UPDATE_ONCE
	var interface := XRServer.find_interface("OpenXR")
	xr_density = viewport.use_xr and interface != null and interface.is_initialized()
	if xr_density and level > 0:
		interface.vrs_min_radius = [50.0,50.0,45.0,40.0][level]
		interface.vrs_strength = [0.2,0.2,0.35,0.5][level]
		viewport.vrs_texture = null
		viewport.vrs_mode = Viewport.VRS_DISABLED
		viewport.vrs_update_mode = Viewport.VRS_UPDATE_ALWAYS
		stable_gaze_seconds = 0.0
	material.set_shader_parameter("density_map",density)
	# The native map is per-eye and render-thread owned; don't display a false fixed mask.
	overlay.visible = debug_enabled and not xr_density

func _process(delta: float) -> void:
	if not xr_density or level == 0: return
	var interface := XRServer.find_interface("OpenXR")
	var tracker = XRServer.get_tracker("/user/eyes_ext")
	gaze_ready = interface != null and interface.is_initialized() and interface.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED and tracker != null and tracker.has_pose("eye_gaze_pose")
	if gaze_ready:
		var pose = tracker.get_pose("eye_gaze_pose")
		gaze_ready = pose != null and pose.has_tracking_data and pose.tracking_confidence == XRPose.XR_TRACKING_CONFIDENCE_HIGH
	var world := get_parent().get_parent()
	var gameplay: bool = world.get("source_main_mode") == 4 and world.get("source_controller_enabled") == true and not is_instance_valid(world.get("source_stage_stats_renderer"))
	update_tracking_policy(delta,gaze_ready,gameplay)
	viewport.vrs_mode = Viewport.VRS_XR if active_density else Viewport.VRS_DISABLED

func update_tracking_policy(delta: float, tracked: bool, gameplay: bool) -> void:
	gaze_ready=tracked
	stable_gaze_seconds = stable_gaze_seconds+delta if gaze_ready and gameplay else 0.0
	active_density = stable_gaze_seconds >= 0.3
	suspension_reason = "Gaze tracked" if active_density else "Full detail: menus/cinematics" if not gameplay else "Full detail: waiting for reliable gaze"

func _exit_tree() -> void:
	if is_instance_valid(viewport):
		viewport.vrs_mode = Viewport.VRS_DISABLED
		viewport.vrs_texture = null
	if is_instance_valid(overlay): overlay.queue_free()
