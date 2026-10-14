extends RefCounted
static func compose(tables: Dictionary, names: Array, progress: Array, selected: int, pickups: Array) -> Dictionary:
	var selection: Dictionary = preload("res://source_menu_selection.gd").level_for_index(selected,tables.get("menuLevels",{}).get("values",[]))
	if selection.has("fault"): return selection
	var text = preload("res://source_game_over_text.gd")
	var data: Dictionary = tables.get("gameOver",{})
	var layout: Dictionary = text.layout(data)
	if layout.has("fault"): return layout
	var name_row: Dictionary = text.level_name_row(data,names,int(selection.level))
	if name_row.has("fault"): return name_row
	var password_row: Dictionary = text.password_row(data,progress,selected,pickups)
	if password_row.has("fault"): return password_row
	layout.labels.append(name_row)
	layout.labels.append(password_row)
	layout.level = int(selection.level)
	return layout
