shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_mask_texture : filter_nearest, repeat_disable;
uniform float source_vertical_scale = 1.0;
varying vec2 source_uv;
varying float source_w;
varying flat int source_flags;
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	clip.y *= source_vertical_scale;
	float depth = (1023.0-UV2.x)/1024.0+UV2.y/16777216.0;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	clip.z = (depth*2.0-1.0)*clip.w;
	#else
	clip.z = depth*clip.w;
	#endif
	POSITION = clip;
	source_uv = UV*clip.w; source_w = clip.w;
	source_flags = int(CUSTOM0.x+0.5);
}
void fragment() {
	vec4 mask = (source_flags&1) != 0 ? texture(source_mask_texture,source_uv/source_w) : vec4(1.0);
	if (mask.g < 0.5) discard;
	ALBEDO = mask.rgb;
}
