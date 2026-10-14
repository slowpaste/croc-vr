extends RefCounted
var resident_samples: Array[Dictionary] = []
var cursor := 4160
var permanent_boundary := -1
var controller_boundary := -1
var controller_profile := ""
var ambience_bytes := 0

func sample_address(file: String) -> Dictionary:
	for sample in resident_samples:
		if str(sample.file) == file:
			return {"address":int(sample.address)}
	return {"fault":"Sound sample is absent from the resident source bank"}

func load_assets(content: String, assets: Array) -> Dictionary:
	for asset in assets:
		if int(asset.kind) != 3: continue
		var file := str(asset.file)
		if file.is_absolute_path() or file.split("/").has(".."):
			return {"fault":"Unsafe SPU sample metadata path"}
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(file)))
		if not data is Dictionary or not data.has("sourceBytes"):
			return {"fault":"Missing original SPU sample size"}
		var result := append_sample(str(asset.name),file,int(data.sourceBytes))
		if result.has("fault"): return result
	return {"ok":true}

func enter_room(content: String, manifest: Dictionary, room: String) -> Dictionary:
	var binding: Dictionary = manifest.get("linkage",{}).get("rooms",{}).get(room,{})
	var profile := str(binding.get("profile",""))
	var controller: Dictionary = manifest.get("linkage",{}).get("controllers",{}).get(profile,{})
	if binding.is_empty() or controller.is_empty(): return {"fault":"Missing SPU stage/controller binding"}
	if permanent_boundary < 0:
		var loaded := load_assets(content,manifest.linkage.bootstrap)
		if loaded.has("fault"): return loaded
		permanent_boundary = resident_samples.size()-1
	else:
		var retired := retire_after(controller_boundary if profile == controller_profile else permanent_boundary)
		if retired.has("fault"): return retired
	ambience_bytes = 0
	if controller_boundary < 0 or controller_profile != profile:
		var loaded := load_assets(content,controller.assets)
		if loaded.has("fault"): return loaded
		controller_profile = profile
		controller_boundary = resident_samples.size()-1
	return load_assets(content,binding.assets)

func reserve_ambience(size: int) -> Dictionary:
	if size < 0 or size%16 != 0 or ambience_bytes != 0:
		return {"fault":"Invalid or already resident ambience bank"}
	cursor = int((cursor+7)/8)*8
	var address := cursor
	cursor += size; ambience_bytes = size
	return {"address":address,"size":size}

func append_sample(name: String, file: String, size: int) -> Dictionary:
	if size < 0 or size%16 != 0:
		return {"fault":"Invalid original SPU sample size"}
	cursor = int((cursor+7)/8)*8
	var sample := {"name":name,"file":file,"address":cursor,"size":size}
	resident_samples.append(sample)
	cursor += size
	return sample

func retire_after(boundary: int) -> Dictionary:
	# Native2db00..2dbe0 / 2dc14..2dcdc free indices after the retained
	# boundary. Boundary0 explicitly clears the count and resets the hint.
	if boundary < 0 or boundary >= resident_samples.size():
		return {"fault":"Unknown original sound-bank boundary"}
	var retained := boundary+1 if boundary != 0 else 0
	var released: Array = resident_samples.slice(retained)
	resident_samples.resize(retained)
	ambience_bytes = 0
	cursor = 4160
	if retained > 0:
		var last: Dictionary = resident_samples[-1]
		cursor = maxi(4160,int(last.address)+int(last.size))
	return {"released":released,"retained":retained,"cursor":cursor}

static func fresh_stage(content: String, manifest: Dictionary, room: String) -> Dictionary:
	var binding: Dictionary = manifest.get("linkage",{}).get("rooms",{}).get(room,{})
	var controller: Dictionary = manifest.get("linkage",{}).get("controllers",{}).get(binding.get("profile",""),{})
	if binding.is_empty() or controller.is_empty(): return {"fault":"Missing SPU stage/controller binding"}
	var assets: Array = manifest.linkage.bootstrap+controller.assets+binding.assets
	var layout = load("res://source_spu_layout.gd").new()
	for asset in assets:
		if int(asset.kind) != 3: continue
		var file := str(asset.file)
		if file.is_absolute_path() or file.split("/").has(".."): return {"fault":"Unsafe SPU sample metadata path"}
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(file)))
		if not data is Dictionary or not data.has("sourceBytes"): return {"fault":"Missing original SPU sample size"}
		var size := int(data.sourceBytes)
		if size < 0 or size%16 != 0: return {"fault":"Invalid original SPU sample size"}
		layout.append_sample(str(asset.name),file,size)
	return {"samples":layout.resident_samples,"end":layout.cursor,"scope":"fresh stage; live bank lifecycle not connected"}
