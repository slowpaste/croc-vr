shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D source_texture : filter_nearest, repeat_disable;
void fragment() {
	vec4 pixel = texture(source_texture,UV);
	ALBEDO = pixel.rgb;
	ALPHA = pixel.a;
}
