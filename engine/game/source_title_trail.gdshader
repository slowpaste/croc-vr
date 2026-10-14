shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform bool physical_panel = false;
void vertex() { if (physical_panel) { POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0); } else { POSITION = vec4(VERTEX.x,-VERTEX.y,1.0,1.0); } }
void fragment() {
	vec4 pixel = texture(atlas_texture,UV);
	ALBEDO = pixel.rgb;
	ALPHA = pixel.a;
}
