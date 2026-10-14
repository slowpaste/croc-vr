extends "res://source_sequence_session.gd"
var portal := preload("res://source_cutscene_portal.gd").new()
var prepared_parts:Array=[]
var portal_performance:Dictionary={"prepared":false,"load_max_us":0,"present_max_us":0,"frames":0}
func _init() -> void:
	super._init()
	add_child(portal)
func setup(content: String, manifest: Dictionary, tables: Dictionary, scene_id: int, cd_state: Dictionary) -> bool:
	prepared_parts.clear()
	for entry in manifest.get("cutsceneSequencePortalCaches",[]):
		if int(entry.scene_id)!=scene_id or int(entry.get("revision",0))!=1:continue
		var source:Dictionary={}
		for original in manifest.cutsceneSequenceCaches:
			if int(original.scene_id)==scene_id:source=original
		if source.is_empty() or str(entry.fingerprint)!=str(source.fingerprint):fault="Stale portal cache identity";return false
		var preparation:Dictionary=cd_state.get("preparation",{})
		var cached:Dictionary=preparation.portal if not preparation.is_empty() else preload("res://source_cutscene_content.gd").read_json(content,str(entry.file))
		if cached.has("fault") or str(cached.get("fingerprint",""))!=str(entry.fingerprint) or int(cached.get("revision",0))!=1: fault="Invalid portal cache descriptor";return false
		prepared_parts=cached.parts;portal_performance.prepared=true
	if manifest.has("quest3Optimized") and prepared_parts.is_empty():fault="Quest 3 bundle requires a prepared VR cinematic cache";return false
	return super.setup(content,manifest,tables,scene_id,cd_state)
func present_frame(part_index: int, local_index: int) -> bool:
	var started:=Time.get_ticks_usec()
	var key := "%d:%d"%[part_index,local_index]
	if not loaded_frames.has(key):
		if not prepared_parts.is_empty() and (prepared_parts.size()!=cached_parts.size() or prepared_parts[part_index].frames.size()!=cached_parts[part_index].size()):fault="Portal cache frame count differs";return false
		var entry:Dictionary=prepared_parts[part_index].frames[local_index] if not prepared_parts.is_empty() else cached_parts[part_index][local_index]
		var loaded := preload("res://source_cutscene_compositor_cache.gd").frames(str(config.content),{"frames":[entry]})
		if loaded.has("fault"):fault=str(loaded.fault);return false
		var corrected:Dictionary=loaded.frames[0] if not prepared_parts.is_empty() else preload("res://source_sequence_sky_correction.gd").apply(loaded.frames[0],config.parts[part_index],local_index)
		if corrected.has("fault"):fault=str(corrected.fault);return false
		loaded_frames[key]=corrected
	frame_lru.erase(key);frame_lru.append(key)
	while frame_lru.size()>2:loaded_frames.erase(frame_lru.pop_front())
	var part: Dictionary = config.parts[part_index]
	var textures := {"actor":part.texture,"room":part.background_texture}
	var masks := {"actor":part.actor_mask}
	if part.sky_texture != null:textures.sky=part.sky_texture
	if part.room_mask != null:masks.room=part.room_mask
	if part.sky_mask != null:masks.sky=part.sky_mask
	portal_performance.load_max_us=maxi(portal_performance.load_max_us,Time.get_ticks_usec()-started)
	started=Time.get_ticks_usec()
	var presented:bool=portal.present_prepared(loaded_frames[key],textures,masks) if not prepared_parts.is_empty() else portal.present(loaded_frames[key],textures,masks)
	if not presented:fault="Portal frame binding failed";return false
	portal.set_source_background(part.sky_colors,float(loaded_frames[key].h))
	portal_performance.present_max_us=maxi(portal_performance.present_max_us,Time.get_ticks_usec()-started)
	portal_performance.frames+=1
	return true
