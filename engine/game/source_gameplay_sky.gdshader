shader_type spatial;
#include "source_color_space.gdshaderinc"
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform vec3 dome_color = vec3(0.0);
varying flat int source_flags;
void vertex() {
	source_flags=int(UV2.x+0.5);
	POSITION=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0);
	POSITION.z=0.000001*POSITION.w;
}
void fragment() {
	if((source_flags&1)==0) {
		ALBEDO=source_display_to_linear(dome_color);
	} else {
	vec4 pixel=texture(atlas_texture,UV);
	if(pixel.a<0.5)discard;
	ALBEDO=pixel.rgb*source_display_to_linear(COLOR.rgb);
	}
}
