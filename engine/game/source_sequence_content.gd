extends RefCounted
const Content = preload("res://source_cutscene_content.gd")
static func named(entries: Array, name: String) -> Dictionary:
	for entry in entries:
		if str(entry.name) == name: return entry
	return {}
static func texture(content: String, descriptor: Dictionary) -> Texture2D:
	if not descriptor.has("image"): return null
	var image := Image.load_from_file(content.path_join(str(descriptor.image)))
	return null if image == null or image.is_empty() else ImageTexture.create_from_image(image)
static func load_sequence(content: String, manifest: Dictionary, tables: Dictionary, scene_id: int, state: Dictionary) -> Dictionary:
	if not state.has_all(["mix","history","filter","threaded","prefill","phase_us"]): return {"fault":"Sequence requires explicit CD state and onset"}
	var resolved := preload("res://source_cutscene_resources.gd").resolve(scene_id,tables,manifest)
	if resolved.has("fault"): return resolved
	var descriptor := named(manifest.get("cutsceneSequences",[]),str(resolved.prefix))
	var audio := named(manifest.get("cutsceneSequenceAudio",[]),str(resolved.prefix))
	if descriptor.is_empty() or audio.is_empty(): return {"fault":"Sequence pose/audio resources are not imported"}
	var data := Content.read_json(content,str(descriptor.file))
	if data.has("fault"): return data
	if data.get("parts",[]).size() != resolved.parts.size(): return {"fault":"Sequence model/room part count differs"}
	var atlas := Content.read_json(content,str(resolved.texture.file))
	if atlas.has("fault"): return atlas
	var actor_texture := texture(content,resolved.texture)
	if actor_texture == null: return {"fault":"Sequence actor atlas is missing"}
	var actor_mask: Texture2D = null
	if resolved.texture.has("maskImage"):
		actor_mask = texture(content,{"image":resolved.texture.maskImage})
	if actor_mask == null: return {"fault":"Sequence transparency mask is missing"}
	var parts: Array = []
	var factors: Array = tables.get("mapYScale",{}).get("values",[])
	for index in range(data.parts.size()):
		var binding: Dictionary = resolved.parts[index]
		if data.parts[index].model != binding.model.file: return {"fault":"Sequence part/model binding differs"}
		var models := Content.read_json(content,str(binding.model.file))
		var room := Content.read_json(content,str(binding.room.file))
		if models.has("fault") or room.has("fault"): return {"fault":"Sequence part model/room data is invalid"}
		var style := int(room.get("style",-1))
		if style < 0 or style >= factors.size() or room.get("entities",[]).is_empty(): return {"fault":"Missing sequence room anchor"}
		var first: Dictionary = room.entities[0]
		var anchor := preload("res://source_rotation.gd").map_position(first.position,int(factors[style]))
		if anchor.has("fault"): return anchor
		anchor.yaw = preload("res://source_rotation.gd").halfword(roundi(float(first.rotation[1])*4096.0))
		var track := named(manifest.models,"TK%02d_TRK.MOD"%style)
		var track_texture := named(manifest.textures,"TK%02d_TRK.BIN"%style)
		var lighting := named(manifest.get("cutsceneRooms",[]),str(binding.room.name))
		if track.is_empty() or track_texture.is_empty() or lighting.is_empty(): return {"fault":"Missing sequence terrain/lighting bindings"}
		var track_models := Content.read_json(content,str(track.file))
		var room_atlas := Content.read_json(content,str(track_texture.file))
		var room_lighting := Content.read_json(content,str(lighting.file))
		var room_texture := texture(content,track_texture)
		var room_mask: Texture2D = texture(content,{"image":track_texture.maskImage}) if track_texture.has("maskImage") else null
		if track_models.has("fault") or room_atlas.has("fault") or room_lighting.has("fault") or room_texture == null: return {"fault":"Invalid sequence scenery content"}
		var points := preload("res://source_point_lighting.gd").decode(room_lighting.source.pointRecords)
		if points.has("fault"): return points
		room_lighting.pointLights = points.lights
		room_lighting.distanceRoot = tables.get("distanceRoot",{}).get("values",[])
		var tiles := preload("res://source_cutscene_tiles.gd").poses(room,tables)
		if tiles.has("fault"): return tiles
		var sky_models := {"models":[]}; var sky_atlas := {"polygons":[]}
		var sky_texture: Texture2D = null
		var sky_mask: Texture2D = null
		var background := int(room.get("background",0))
		if background != 0:
			# Native3b694..3b6c4: types42/48 use dome2/3, otherwise dome1.
			var dome := 2 if background == 42 else 3 if background == 48 else 1
			var sky_model := named(manifest.models,"TB%02d_DOM.MOD"%dome)
			var sky_image := named(manifest.textures,"TB%02d.BIN"%background)
			if sky_model.is_empty() or sky_image.is_empty(): return {"fault":"Missing sequence background dome"}
			sky_models = Content.read_json(content,str(sky_model.file)); sky_atlas = Content.read_json(content,str(sky_image.file))
			sky_texture = texture(content,sky_image)
			if sky_image.has("maskImage"): sky_mask = texture(content,{"image":sky_image.maskImage})
			if sky_models.has("fault") or sky_atlas.has("fault") or sky_texture == null: return {"fault":"Invalid sequence background dome"}
		parts.append({"data":{"frames":data.parts[index].frames},"models":models,"room":room,"tables":tables,"atlas":atlas,"texture":actor_texture,"actor_mask":actor_mask,"anchor":anchor,"track_models":track_models,"room_atlas":room_atlas,"room_lighting":room_lighting,"background_texture":room_texture,"room_mask":room_mask,"tiles":tiles,"sky_models":sky_models,"sky_atlas":sky_atlas,"sky_texture":sky_texture,"sky_mask":sky_mask,"point_lighting_required":not room_lighting.source.pointRecords.is_empty(),"point_lighting_implemented":true})
		parts.back().sky_colors=preload("res://source_background_colors.gd").lookup(manifest,"TB%02d.BIN"%background)
	data.scene_id = scene_id
	var config := state.duplicate(true)
	config.merge({"data":data,"parts":parts,"atlas":atlas,"texture":actor_texture,"actor_mask":actor_mask,"audio":audio,"tables":tables,"content":content,"resources":resolved},true)
	return config
