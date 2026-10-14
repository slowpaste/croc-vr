extends "res://source_cutscene_session.gd"
var portal := preload("res://source_cutscene_portal.gd").new()
var portal_config: Dictionary = {}
var prepared_frames:Array=[]
var portal_manifest:Dictionary={}
var portal_performance:Dictionary={"prepared":false,"load_max_us":0,"present_max_us":0,"frames":0}
func setup_sad(content:String,manifest:Dictionary,tables:Dictionary,cd_state:Dictionary) -> bool:
	portal_manifest=manifest
	return super.setup_sad(content,manifest,tables,cd_state)
func _init() -> void:
	super._init()
	add_child(portal)
func setup(config: Dictionary) -> bool:
	portal_config=config
	prepared_frames.clear()
	for entry in portal_manifest.get("cutscenePortalMeshes",[]):
		if entry.name!="SAD" or int(entry.revision)!=1:continue
		var original:Dictionary={}
		for source in portal_manifest.cutsceneCompositor:
			if source.name=="SAD":original=source
		if original.is_empty() or str(original.fingerprint)!=str(entry.fingerprint):fault="Stale SAD portal cache";return false
		var descriptor:=preload("res://source_cutscene_content.gd").read_json(str(config.content),str(entry.file))
		if descriptor.has("fault") or str(descriptor.get("fingerprint",""))!=str(entry.fingerprint):fault="Invalid SAD portal cache";return false
		var loaded:=preload("res://source_cutscene_compositor_cache.gd").frames(str(config.content),descriptor)
		if loaded.has("fault") or loaded.frames.size()!=config.compositor_frames.size():fault="Invalid SAD portal frames";return false
		prepared_frames=loaded.frames;portal_performance.prepared=true
	var playback := config.duplicate()
	playback.compositor_frames=[]
	if not super.setup(playback):return false
	player.draw_geometry=false;player.hide();player.camera.current=false
	return present_portal(0)
func present_portal(index: int) -> bool:
	var started:=Time.get_ticks_usec()
	var textures := {"actor":portal_config.texture,"room":portal_config.background_texture,"sky":portal_config.sky_texture}
	var masks := {"actor":portal_config.actor_mask}
	if portal_config.get("room_mask") != null:masks.room=portal_config.room_mask
	if portal_config.get("sky_mask") != null:masks.sky=portal_config.sky_mask
	var result:bool=portal.present(portal_config.compositor_frames[index],textures,masks) if prepared_frames.is_empty() else portal.present_prepared(prepared_frames[index],textures,masks)
	if result:portal.set_source_background(portal_config.sky_colors,float(portal_config.compositor_frames[index].h))
	portal_performance.present_max_us=maxi(portal_performance.present_max_us,Time.get_ticks_usec()-started)
	portal_performance.frames+=1
	return result
func advance(microseconds: int, held: int, budget: int = 1) -> Dictionary:
	var result := super.advance(microseconds,held,budget)
	if not result.has("fault") and not result.get("presented",[]).is_empty():
		if not present_portal(player.last_index):return {"fault":"SAD portal frame binding failed"}
	return result
