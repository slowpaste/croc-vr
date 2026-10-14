shader_type spatial;
#include "source_color_space.gdshaderinc"
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D background_texture : hint_screen_texture, filter_nearest;
uniform float source_level : hint_range(0.0, 1.0) = 0.0;
uniform bool polygon_mode = false;
uniform bool physical_polygons = false;
uniform bool physical_full_black = false;
uniform int triangle_count = 0;
uniform vec2 polygon_vertices[30];
float edge(vec2 a, vec2 b, vec2 p) {
	return (b.x-a.x)*(p.y-a.y)-(b.y-a.y)*(p.x-a.x);
}
void vertex() {
	if (polygon_mode && physical_polygons) {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX.xy*16.0,-4.0,1.0);
	} else POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	float shade = source_level;
	if (polygon_mode) {
		shade = 0.0;
		vec2 pixel = vec2(UV.x,1.0-UV.y);
		if (physical_polygons) {
			pixel = (pixel-vec2(0.5))*vec2(16.0/1.6,16.0/0.75)+vec2(0.5);
			if (physical_full_black) shade=1.0;
		}
		for (int i = 0; i < 10; i++) {
			if (i >= triangle_count) { break; }
			vec2 a = polygon_vertices[i*3];
			vec2 b = polygon_vertices[i*3+1];
			vec2 c = polygon_vertices[i*3+2];
			float area = edge(a,b,c);
			float ab = edge(a,b,pixel);
			float bc = edge(b,c,pixel);
			float ca = edge(c,a,pixel);
			if (abs(area) > 0.00000001 && ((ab >= 0.0 && bc >= 0.0 && ca >= 0.0) || (ab <= 0.0 && bc <= 0.0 && ca <= 0.0))) { shade = 1.0; }
		}
	}
	if (shade <= 0.0) discard;
	vec3 background = textureLod(background_texture,SCREEN_UV,0.0).rgb;
	vec3 color5 = floor(clamp(source_linear_to_display(background),vec3(0.0),vec3(1.0))*31.0+0.5);
	float amount = floor(shade*255.0/8.0+0.0001);
	ALBEDO = source_display_to_linear(max(color5-amount,vec3(0.0))/31.0);
	ALPHA = 1.0;
}
