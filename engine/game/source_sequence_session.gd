extends Node3D
var player := preload("res://source_cutscene_player.gd").new()
var audio := preload("res://source_cutscene_audio_player.gd").new()
var timeline := preload("res://source_cutscene_timeline.gd").new()
var config: Dictionary = {}
var cached_parts: Array = []
var loaded_frames: Dictionary = {}
var frame_lru: Array[String] = []
var offsets: Array[int] = []
var compositor: Node = null
var graph_part := -1
var graph_cache: Dictionary = {}
var graph_lru: Array[String] = []
var graph_builds := 0
const CACHED_STAGE_BUDGET := 256
static func canonical_frame(frame: Dictionary) -> Dictionary:
	# Empty opaque copies preserve the pixel stream while making graph layout
	# depend on blend count, not on where opaque geometry happens to be culled.
	var result := frame.duplicate()
	var passes: Array = []
	for pass_data in frame.passes:
		if pass_data.kind == "blend" and (passes.is_empty() or passes.back().kind == "blend"):
			passes.append({"kind":"opaque","meshes":{}})
		passes.append(pass_data)
	if not passes.is_empty() and passes.back().kind == "blend": passes.append({"kind":"opaque","meshes":{}})
	result.passes = passes
	return result
var active := false
var complete := false
var fault := ""
func _init() -> void:
	add_child(player); add_child(audio); visible = false
func setup(content: String, manifest: Dictionary, tables: Dictionary, scene_id: int, cd_state: Dictionary) -> bool:
	if active: return false
	audio.stream.stop_stream(); cached_parts.clear(); offsets.clear(); fault = ""; complete = false
	loaded_frames.clear(); frame_lru.clear()
	for graph in graph_cache.values():
		if is_instance_valid(graph): graph.queue_free()
	graph_cache.clear(); graph_lru.clear(); graph_builds = 0
	compositor = null; graph_part = -1
	var preparation:Dictionary=cd_state.get("preparation",{})
	config = preparation.config.duplicate() if not preparation.is_empty() else preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene_id,cd_state)
	if not preparation.is_empty():
		for key in ["mix","history","filter","threaded","prefill","phase_us"]:config[key]=cd_state[key]
	if config.has("fault"): fault = str(config.fault); return false
	var descriptor: Dictionary = {}
	for entry in manifest.get("cutsceneSequenceCaches",[]):
		if int(entry.scene_id) == scene_id: descriptor = entry; break
	if descriptor.is_empty(): fault = "Sequence compositor cache is not imported"; return false
	var expected:String=preparation.identity if not preparation.is_empty() else preload("res://source_sequence_cache_identity.gd").fingerprint(config,tables)
	if str(descriptor.get("fingerprint","")) != expected:
		fault = "Sequence compositor cache is stale; regenerate it for the current source data and renderer"; return false
	var cache:Dictionary=preparation.cache if not preparation.is_empty() else preload("res://source_cutscene_content.gd").read_json(content,str(descriptor.file))
	if cache.has("fault") or int(cache.get("scene_id",-1)) != scene_id or cache.get("parts",[]).size() != config.parts.size(): fault = "Invalid sequence cache binding"; return false
	if str(cache.get("fingerprint","")) != expected: fault = "Sequence cache descriptor identity differs"; return false
	var packs: Array = []; var cursor := 0
	for index in range(config.parts.size()):
		var part: Dictionary = config.parts[index]
		var descriptor_part: Dictionary = cache.parts[index]
		if not descriptor_part.has("frames") or descriptor_part.frames.size() != part.data.frames.size(): fault = "Invalid sequence cached stage meshes"; return false
		cached_parts.append(descriptor_part.frames); offsets.append(cursor); cursor += part.data.frames.size()
		packs.append(part.models)
	if not player.setup_sequence(config.data,packs,tables,config.atlas,config.texture,int(config.prefill)): fault = "Sequence player setup failed"; return false
	player.draw_geometry = false; player.hide()
	if not audio.configure(content,config.audio,config.mix,config.history,config.filter,bool(config.threaded)) or not timeline.begin(player,config.audio,int(config.prefill),int(config.phase_us)):
		fault = "Sequence audio/timeline setup failed"; return false
	if not present_frame(0,0): return false
	active = true; complete = false; visible = true; return true
func present_frame(part_index: int, local_index: int) -> bool:
	var key_frame := str(part_index)+":"+str(local_index)
	if not loaded_frames.has(key_frame):
		var loaded := preload("res://source_cutscene_compositor_cache.gd").frames(str(config.content),{"frames":[cached_parts[part_index][local_index]]})
		if loaded.has("fault"): fault = str(loaded.fault); return false
		var corrected := preload("res://source_sequence_sky_correction.gd").apply(loaded.frames[0],config.parts[part_index],local_index)
		if corrected.has("fault"): fault = str(corrected.fault); return false
		loaded_frames[key_frame] = corrected
	frame_lru.erase(key_frame); frame_lru.append(key_frame)
	while frame_lru.size() > 4:
		var retired: String = frame_lru.pop_front()
		loaded_frames.erase(retired)
	var frame: Dictionary = canonical_frame(loaded_frames[key_frame])
	if int(frame.get("h",0)) <= 0 or not frame.has("passes"):
		fault = "Invalid sequence cached projection"; return false
	var reusable: bool = is_instance_valid(compositor) and graph_part == part_index and frame.passes.size() == compositor.bindings.size()
	if reusable:
		for index in range(frame.passes.size()):
			if frame.passes[index].kind != compositor.bindings[index].kind: reusable = false; break
	if reusable and compositor.present_cached(frame): return true
	var kinds: Array[String] = []
	for pass_data in frame.passes: kinds.append(str(pass_data.kind))
	var key := str(part_index)+":"+",".join(kinds)
	if graph_cache.has(key):
		var restored: Node = graph_cache[key]
		if not restored.present_cached(frame): fault = "Cached sequence graph update failed"; return false
		activate_graph(restored); graph_part = part_index
		graph_lru.erase(key); graph_lru.append(key)
		return true
	var required_stages := 0
	for pass_data in frame.passes: required_stages += 1 if pass_data.kind == "opaque" else 3
	var retained_stages := 0
	for graph in graph_cache.values(): retained_stages += graph.stages.size()
	# A large layout may exceed the budget by itself, but must not coexist with
	# other layouts. Retire before allocating its replacement to bound peak usage.
	while not graph_lru.is_empty() and retained_stages+required_stages > CACHED_STAGE_BUDGET:
		var retired_key: String = graph_lru.pop_front()
		var retired_graph: Node = graph_cache[retired_key]
		retained_stages -= retired_graph.stages.size()
		graph_cache.erase(retired_key)
		if compositor == retired_graph: compositor = null; graph_part = -1
		retired_graph.free()
	var part: Dictionary = config.parts[part_index]
	var textures := {"actor":part.texture,"room":part.background_texture}
	if part.sky_texture != null: textures.sky = part.sky_texture
	var masks := {"actor":part.actor_mask}
	if part.room_mask != null: masks.room = part.room_mask
	if part.sky_mask != null: masks.sky = part.sky_mask
	var next := preload("res://source_cutscene_compositor.gd").new(); add_child(next)
	if not next.setup_cached(frame,textures,masks):
		next.queue_free(); fault = "Sequence compositor setup failed"; return false
	graph_builds += 1; graph_cache[key] = next; graph_lru.append(key)
	activate_graph(next); graph_part = part_index
	while graph_lru.size() > 4:
		var removed: String = graph_lru.pop_front()
		var previous: Node = graph_cache[removed]; graph_cache.erase(removed); previous.queue_free()
	return true
func activate_graph(next: Node) -> void:
	if is_instance_valid(compositor) and compositor != next:
		for stage in compositor.stages: stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for stage in next.stages: stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	compositor = next
func advance(microseconds: int, held: int, budget: int = 1) -> Dictionary:
	if not fault.is_empty(): return {"fault":fault}
	if complete: return {"complete":true}
	if not active: return {"fault":"Sequence session is not initialized"}
	var result := timeline.advance(microseconds,held,budget)
	if not result.has("fault"):
		var sound := audio.receive(result)
		if sound.has("fault"): result = sound
	if not result.has("fault") and not result.get("presented",[]).is_empty():
		var part_index := int(player.current_part)
		if not present_frame(part_index,int(player.last_index)-offsets[part_index]): result = {"fault":fault}
	if result.has("fault"):
		fault = str(result.fault); active = false; audio.stream.stop_stream(); return {"fault":fault}
	complete = bool(result.complete)
	if complete: active = false
	return result
func output_texture() -> Texture2D:
	return compositor.output.get_texture() if is_instance_valid(compositor) else null
func set_paused(value: bool) -> void:
	timeline.clock.paused = value; audio.stream.stream_paused = value
