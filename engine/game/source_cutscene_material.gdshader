shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D atlas_texture : filter_nearest, repeat_disable;
uniform float source_vertical_offset = 0.0;
uniform float source_vertical_scale = 1.0;
uniform bool source_fixed_far = false;
uniform bool source_ordered_depth = false;
varying vec4 source_tint;
varying vec2 source_uv;
varying float source_w;
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	clip.y += source_vertical_offset * clip.w;
	clip.y *= source_vertical_scale;
	if (source_ordered_depth) {
		// Keep native earlier-emitted faces on top within a shared bucket.
		float depth = (1023.0-UV2.x)/1024.0 + UV2.y/16777216.0;
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		clip.z = (depth*2.0-1.0)*clip.w;
		#else
		clip.z = depth*clip.w;
		#endif
	}
	if (source_fixed_far) {
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		clip.z = -0.999998 * clip.w;
		#else
		clip.z = 0.000001 * clip.w;
		#endif
	}
	POSITION = clip;
	float w = clip.w;
	source_tint = COLOR * w;
	source_uv = UV * w;
	source_w = w;
}
void fragment() {
	vec4 tint = source_tint / source_w;
	vec4 pixel = texture(atlas_texture,source_uv / source_w);
	if (pixel.a < 0.5) discard;
	float modulation = tint.a < 0.5 ? 255.0/128.0 : 1.0;
	vec3 rgb = clamp(pixel.rgb * tint.rgb * modulation,vec3(0.0),vec3(1.0));
	ALBEDO = OUTPUT_IS_SRGB ? rgb : mix(rgb/12.92,pow((rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),rgb));
}
