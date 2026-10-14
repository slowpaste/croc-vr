shader_type spatial;
#include "source_color_space.gdshaderinc"
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D background_texture : hint_screen_texture, filter_nearest;
uniform float source_level : hint_range(0.0, 1.0) = 0.0;
void vertex() { POSITION = vec4(VERTEX.xy,1.0,1.0); }
void fragment() {
	if (source_level <= 0.0) discard;
	vec3 background = textureLod(background_texture,SCREEN_UV,0.0).rgb;
	vec3 color5 = floor(clamp(source_linear_to_display(background),vec3(0.0),vec3(1.0))*31.0+0.5);
	float amount = floor(source_level*255.0/8.0+0.0001);
	ALBEDO = source_display_to_linear(min(color5+amount,vec3(31.0))/31.0);
	ALPHA = 1.0;
}
