extends RefCounted
# JSON parsing and identity verification run outside the display thread.
static func prepare(content: String, manifest: Dictionary, tables: Dictionary, scene: int, state: Dictionary) -> Dictionary:
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene,state)
	if config.has("fault"):return config
	var identity := preload("res://source_sequence_cache_identity.gd").fingerprint(config,tables)
	var cache:Dictionary={}
	var portal:Dictionary={}
	for entry in manifest.get("cutsceneSequenceCaches",[]):
		if int(entry.scene_id)!=scene:continue
		if str(entry.get("fingerprint",""))!=identity:return {"fault":"Stale sequence cache identity"}
		cache=preload("res://source_cutscene_content.gd").read_json(content,str(entry.file))
	for entry in manifest.get("cutsceneSequencePortalCaches",[]):
		if int(entry.scene_id)!=scene:continue
		portal=preload("res://source_cutscene_content.gd").read_json(content,str(entry.file))
		if str(entry.get("fingerprint",""))!=identity or str(portal.get("fingerprint",""))!=identity or int(portal.get("revision",0))!=1:return {"fault":"Stale portal cache identity"}
	if cache.is_empty() or cache.has("fault") or str(cache.get("fingerprint",""))!=identity:return {"fault":"Invalid prepared sequence cache"}
	return {"config":config,"cache":cache,"portal":portal,"identity":identity}
