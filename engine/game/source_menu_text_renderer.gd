extends MeshInstance3D
var text_material := ShaderMaterial.new()
var rendered_labels: Array = []
var frame_buttons_enabled := false
var button_mesh: MeshInstance3D
var button_material: ShaderMaterial
var revision:=0
var previous_layout:Dictionary={}
var previous_atlas:Dictionary={}
var previous_texture:Texture2D
var previous_buttons:=false
func configure_vr_panel(enabled: bool) -> void:
	preload("res://vr_frontend_panel.gd").configure_sprite(self,enabled)
	frame_buttons_enabled=enabled
	if button_material!=null:button_material.set_shader_parameter("physical_panel",enabled)
func _init() -> void:
	text_material.shader = preload("res://source_menu_text.gdshader")
	text_material.render_priority = 126
	material_override = text_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384
	visible = false
func set_text(layout: Dictionary, atlas: Dictionary, texture: Texture2D) -> bool:
	if layout.has("fault") or not atlas.has("polygons") or texture == null:
		return false
	if previous_texture==texture and is_same(previous_atlas,atlas) and previous_buttons==frame_buttons_enabled and previous_layout==layout:
		var should_show:bool=mesh!=null or (button_mesh!=null and button_mesh.mesh!=null)
		if visible!=should_show:visible=should_show;revision+=1
		return true
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var icon_count := 0
	var icons := SurfaceTool.new();icons.begin(Mesh.PRIMITIVE_TRIANGLES)
	for label in layout.labels:
		var characters: Array = []
		for character in str(label.get("text","")):
			if character.unicode_at(0)>32:characters.append(character.unicode_at(0))
		var glyph_index := 0
		for glyph in label.glyphs:
			var button: String=preload("res://frame_button_icons.gd").SOURCE.get(characters[glyph_index],"") if frame_buttons_enabled and glyph_index<characters.size() else ""
			glyph_index+=1
			if not button.is_empty():
				var p := Vector2(glyph.position);var size:=Vector2(glyph.size)
				var corners := [p,p+Vector2(size.x,0),p+Vector2(0,size.y),p+size]
				var button_uv := preload("res://frame_button_icons.gd").uv(button)
				for corner in [0,1,2,1,3,2]:
					icons.set_color(glyph.get("tint",Color.WHITE));icons.set_uv(button_uv[corner]);icons.add_vertex(Vector3(corners[corner].x/256.0-1.0,1.0-corners[corner].y/120.0,0));icon_count+=1
				continue
			var index := int(glyph.sprite)
			if index < 0 or index >= atlas.polygons.size():
				return false
			var uv: Array = atlas.polygons[index].uv.duplicate(true)
			if glyph.has("source_u_span"):
				uv[3][0] = float(uv[2][0])+float(glyph.source_u_span)/float(atlas.width)
				uv[1][0] = float(uv[0][0])+float(glyph.source_u_span)/float(atlas.width)
			# Model atlas pairs were swapped; UI sprite pairs retain source top first.
			var mapping := [2,3,0,1]
			var p := Vector2(glyph.position)
			var size := Vector2(glyph.size)
			var corners := [p,p+Vector2(size.x,0),p+Vector2(0,size.y),p+size]
			for corner in [0,1,2,1,3,2]:
				surface.set_color(glyph.get("tint",Color.WHITE))
				var source_uv: Array = uv[mapping[corner]]
				surface.set_uv(Vector2(source_uv[0],source_uv[1]))
				surface.add_vertex(Vector3(corners[corner].x/256.0-1.0,1.0-corners[corner].y/120.0,0))
				count += 1
	mesh = surface.commit() if count > 0 else null
	text_material.set_shader_parameter("atlas_texture",texture)
	if icon_count>0 and button_mesh==null:
		button_mesh=MeshInstance3D.new();add_child(button_mesh)
		button_material=ShaderMaterial.new();button_material.shader=preload("res://source_menu_text.gdshader")
		button_material.render_priority=text_material.render_priority
		button_material.set_shader_parameter("physical_panel",text_material.get_shader_parameter("physical_panel"))
		button_material.set_shader_parameter("atlas_texture",preload("res://frame_button_icons.gd").texture())
		button_mesh.material_override=button_material;button_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;button_mesh.extra_cull_margin=16384
	if button_mesh!=null:button_mesh.mesh=icons.commit() if icon_count>0 else null;button_mesh.visible=icon_count>0
	visible = count > 0 or icon_count>0
	rendered_labels=[]
	for label in layout.labels:rendered_labels.append(str(label.get("text","")))
	previous_layout=layout.duplicate(true);previous_atlas=atlas;previous_texture=texture;previous_buttons=frame_buttons_enabled;revision+=1
	return true
