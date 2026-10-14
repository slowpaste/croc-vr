extends RefCounted
static func actor_texture(scene_id: int) -> String:
	# Native4ff44..4ff84 selects loader25588 mode2/1/0.
	return "OUTRO.BIN" if scene_id == 19 else "INTROJIG.BIN" if scene_id in [7,16] else "INTRO.BIN"

# Native4fe74..4ff30 resolves every model and consecutive room before playback.
static func resolve(scene_id: int, tables: Dictionary, manifest: Dictionary) -> Dictionary:
	var records: Array = tables.get("gameOver",{}).get("sequenceScenes",{}).get("records",[])
	if scene_id < 0 or scene_id >= records.size(): return {"fault":"Invalid original cutscene scene"}
	var scene: Dictionary = records[scene_id]
	if not scene.has_all(["prefix","modelCount","level","firstRoom"]): return {"fault":"Incomplete original cutscene descriptor"}
	var resources: Array = []
	for index in range(int(scene.modelCount)):
		var model_name := "%s%02d.MOD" % [str(scene.prefix),index]
		var map_name := "MP%03d_%02d.MAP" % [int(scene.level),int(scene.firstRoom)+index]
		var model: Dictionary = {}
		var room: Dictionary = {}
		for candidate in manifest.get("models",[]):
			if str(candidate.name) == model_name: model = candidate
		for candidate in manifest.get("maps",[]):
			if str(candidate.name) == map_name: room = candidate
		if model.is_empty() or room.is_empty(): return {"fault":"Missing original cutscene model/room: %s / %s" % [model_name,map_name]}
		resources.append({"model":model,"room":room})
	var texture: Dictionary = {}
	for candidate in manifest.get("textures",[]):
		if str(candidate.name) == actor_texture(scene_id): texture = candidate; break
	if texture.is_empty(): return {"fault":"Missing original cutscene actor atlas: "+actor_texture(scene_id)}
	return {"scene_id":scene_id,"prefix":str(scene.prefix),"parts":resources,"texture":texture,"entry_fade":preload("res://source_cutscene_flow.gd").entry_fade(scene_id)}
