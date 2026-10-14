extends Node3D
var player := preload("res://source_cutscene_player.gd").new()
var audio := preload("res://source_cutscene_audio_player.gd").new()
var timeline := preload("res://source_cutscene_timeline.gd").new()
var active := false
var complete := false
var fault := ""
var room_anchor: Dictionary = {}
var background_view: Dictionary = {}
var background := MeshInstance3D.new()
var background_meshes: Array = []
var sky := MeshInstance3D.new()
var sky_meshes: Array = []
var compositor: Node = null
var compositor_frames: Array = []
func setup_sad(content: String, manifest: Dictionary, tables: Dictionary, cd_state: Dictionary) -> bool:
	if active: return false
	var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,cd_state)
	if config.has("fault"):
		fault = str(config.fault)
		return false
	if config.background_meshes.is_empty() or not config.has("background_texture"):
		fault = "SAD background cache is not imported"
		return false
	if config.sky_meshes.is_empty():
		fault = "SAD dome cache is not imported"
		return false
	if not config.foreground_ordered or not config.background_ordered:
		fault = "SAD cache ordering revision is obsolete"
		return false
	if config.compositor_frames.is_empty() or not config.has("actor_mask"):
		fault = "SAD blended compositor cache is not imported"
		return false
	return setup(config)
func _init() -> void:
	add_child(player); add_child(audio)
	player.add_child(background)
	player.add_child(sky)
	visible = false
func setup(config: Dictionary) -> bool:
	if active or not config.has_all(["data","models","tables","atlas","texture","content","audio","mix","history","filter","threaded","prefill","phase_us","meshes"]): return false
	if int(config.prefill) < 0 or int(config.phase_us) < 0: return false
	var scenery: Array = config.get("background_meshes",[])
	var dome: Array = config.get("sky_meshes",[])
	if not dome.is_empty():
		if dome.size() != config.data.frames.size() or not config.has("sky_texture"): return false
		for mesh in dome:
			if not mesh is ArrayMesh or mesh.get_surface_count() != 1: return false
	if not scenery.is_empty():
		if scenery.size() != config.data.frames.size() or not config.has("background_texture"): return false
		for mesh in scenery:
			if not mesh is ArrayMesh or mesh.get_surface_count() != 1: return false
	if not player.setup(config.data,config.models,config.tables,config.atlas,config.texture,int(config.prefill),config.meshes): return false
	if not audio.configure(str(config.content),config.audio,config.mix,config.history,config.filter,bool(config.threaded)): return false
	if not timeline.begin(player,config.audio,int(config.prefill),int(config.phase_us)): return false
	room_anchor = config.get("anchor",{}).duplicate(true)
	background_view.clear()
	background_meshes = scenery.duplicate()
	background.mesh = null
	compositor_frames = config.get("compositor_frames",[])
	if not compositor_frames.is_empty():
		if compositor_frames.size() != config.data.frames.size(): return false
		compositor = preload("res://source_cutscene_compositor.gd").new()
		add_child(compositor)
		if not compositor.setup_cached(compositor_frames[0],{"room":config.background_texture,"actor":config.texture,"sky":config.sky_texture},{"actor":config.actor_mask}): return false
		player.hide()
	sky_meshes = dome.duplicate()
	sky.mesh = null
	if not dome.is_empty():
		var material := ShaderMaterial.new()
		material.shader = preload("res://source_cutscene_material.gdshader")
		material.set_shader_parameter("atlas_texture",config.sky_texture)
		material.set_shader_parameter("source_fixed_far",true)
		material.set_shader_parameter("source_vertical_offset",preload("res://source_cutscene_frame.gd").vertical_offset())
		material.set_shader_parameter("source_vertical_scale",0.625)
		sky.material_override = material
	if not scenery.is_empty():
		var material := ShaderMaterial.new()
		material.shader = preload("res://source_cutscene_material.gdshader")
		material.set_shader_parameter("atlas_texture",config.background_texture)
		material.set_shader_parameter("source_ordered_depth",true)
		material.set_shader_parameter("source_vertical_offset",preload("res://source_cutscene_frame.gd").vertical_offset())
		material.set_shader_parameter("source_vertical_scale",0.625)
		background.material_override = material
	active = true
	complete = false
	fault = ""
	visible = true
	return true
func advance(microseconds: int, held: int, budget: int) -> Dictionary:
	if not fault.is_empty(): return {"fault":fault}
	if complete: return {"complete":true}
	if not active: return {"fault":"Cutscene session is not initialized"}
	var result := timeline.advance(microseconds,held,budget)
	if result.has("fault"):
		fault = str(result.fault)
		active = false
		audio.stream.stop_stream()
		return {"fault":fault}
	var sound := audio.receive(result)
	if sound.has("fault"):
		fault = str(sound.fault)
		active = false
		audio.stream.stop_stream()
		return {"fault":fault}
	if not room_anchor.is_empty() and not result.get("presented",[]).is_empty():
		var source_camera: Dictionary = player.frames[player.last_index].camera
		var anchored := preload("res://source_cutscene_view.gd").anchored_camera(source_camera,room_anchor.position,int(room_anchor.yaw),player.tables.rotation.pairs)
		background_view = preload("res://source_cutscene_view.gd").camera_view(anchored,player.tables.rotation.pairs)
		result.background_view = background_view
	if not background_meshes.is_empty() and not result.get("presented",[]).is_empty():
		background.mesh = background_meshes[player.last_index]
	if not sky_meshes.is_empty() and not result.get("presented",[]).is_empty(): sky.mesh = sky_meshes[player.last_index]
	if compositor != null and not result.get("presented",[]).is_empty():
		if not compositor.present_cached(compositor_frames[player.last_index]):
			fault = "Original compositor pass topology changed"
			active = false; audio.stream.stop_stream()
			return {"fault":fault}
	complete = bool(result.complete)
	if complete: active = false
	result.audio = sound
	return result
func set_paused(value: bool) -> void:
	timeline.clock.paused = value
	audio.stream.stream_paused = value
