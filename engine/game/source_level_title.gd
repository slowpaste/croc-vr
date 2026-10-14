extends RefCounted
static func resolve(mode: int, map_name: String, selected: int, tables: Dictionary, names: Array) -> Dictionary:
	if mode not in [4,5] or names.size()!=100: return {}
	var level := -1
	if mode == 5:
		var selection := preload("res://source_menu_selection.gd").level_for_index(selected,tables.get("menuLevels",{}).get("values",[]))
		if selection.has("fault"): return {}
		level=int(selection.level)
	elif map_name.length()==12 and map_name.begins_with("MP"):
		level=int(map_name.substr(2,3))
	if level<0 or level>=100 or str(names[level]).strip_edges().is_empty(): return {}
	return {"level":level,"name":str(names[level])}
