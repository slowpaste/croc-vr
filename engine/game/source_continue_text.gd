extends RefCounted
static func layout(data: Dictionary, state: Dictionary) -> Dictionary:
	if not data.has_all(["continueMenu","glyphs","headingGlyphs"]): return {"fault":"Missing original continue menu"}
	var menu: Dictionary = data.continueMenu
	var empty := {"text":"","y":0}
	var scaled := preload("res://source_menu_text.gd").layout({"labels":[menu.yes,menu.no,empty,empty,empty],"glyphs":data.glyphs,"centerX":256},state.sizes,false)
	if scaled.has("fault"): return scaled
	var heading := preload("res://source_game_over_text.gd").centered(menu.heading,data.headingGlyphs)
	if heading.has("fault"): return heading
	return {"labels":[heading,scaled.labels[0],scaled.labels[1]]}
