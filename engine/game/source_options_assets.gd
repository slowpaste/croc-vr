extends RefCounted
# Native4aad8..4ac04 consumes these model groups sequentially.
const SLOTS = [1316,1252,1256,1272,1276,1284,1296,1280,1312,1300,1292,1288,1264,1268,1260,1304,1308]
static func bind(manifest: Dictionary) -> Dictionary:
	if not manifest.get("resources",null) is Array: return {"fault":"Missing imported Options resources"}
	var groups: Array = []
	for resource in manifest.resources:
		if resource.get("owner","") == "OPTIONS.WAD" and resource.get("type","") == "model": groups.append(resource)
	if groups.size() != SLOTS.size(): return {"fault":"Original Options bank requires17 model groups"}
	for group in groups:
		if not group.has_all(["offset","file"]) or (not group.offset is float and not group.offset is int) or str(group.file).is_empty(): return {"fault":"Incomplete Options model binding"}
		if float(group.offset)!=float(int(group.offset)): return {"fault":"Fractional Options model offset"}
	groups.sort_custom(func(a,b):return int(a.offset)<int(b.offset))
	var slots := {}
	var previous := -1
	for index in range(groups.size()):
		var offset := int(groups[index].offset)
		if offset <= previous: return {"fault":"Duplicate or invalid Options model offset"}
		previous = offset
		slots[SLOTS[index]] = groups[index].duplicate(true)
	return {"slots":slots}
