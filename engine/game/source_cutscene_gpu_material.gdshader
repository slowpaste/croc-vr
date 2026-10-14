shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D atlas_texture : filter_nearest, repeat_disable;
uniform float source_vertical_offset = 0.0;
uniform float source_vertical_scale = 1.0;
uniform bool source_ordered_depth = true;
varying vec4 source_tint;
varying vec2 source_uv;
varying float source_w;
varying flat int source_flags;
const int DITHER[16] = int[16](-4,0,-3,1,2,-2,3,-1,-3,1,-4,0,3,-1,2,-2);
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	clip.y += source_vertical_offset * clip.w;
	clip.y *= source_vertical_scale;
	if (source_ordered_depth) {
		float depth = (1023.0-UV2.x)/1024.0 + UV2.y/16777216.0;
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		clip.z = (depth*2.0-1.0)*clip.w;
		#else
		clip.z = depth*clip.w;
		#endif
	}
	POSITION = clip;
	source_tint = COLOR * clip.w;
	source_uv = UV * clip.w;
	source_w = clip.w;
	source_flags = int(CUSTOM0.x+0.5);
}
void fragment() {
	vec4 tint = source_tint/source_w;
	vec4 pixel = texture(atlas_texture,source_uv/source_w);
	bool textured = (source_flags&1) != 0;
	if (textured && pixel.a < 0.5) discard;
	// Croc flag0x20 selects semi-transparency, not the GPU raw-texture bit.
	// Bit0x100 is reserved for synthetic raw-command color diagnostics.
	bool raw = textured && (source_flags&256) != 0;
	bool dithered = (source_flags&64) == 0 || (textured && !raw);
	ivec2 position = ivec2(floor(SCREEN_UV*VIEWPORT_SIZE));
	float dither = dithered ? float(DITHER[(position.y&3)*4+(position.x&3)]) : 0.0;
	vec3 color8 = floor(clamp(tint.rgb*255.0+vec3(0.0001),vec3(0.0),vec3(255.0)));
	vec3 texture5 = floor(pixel.rgb*31.0+vec3(0.5));
	vec3 value = textured ? floor(texture5*color8/16.0) : color8;
	vec3 color5 = raw ? texture5 : clamp(floor((value+vec3(dither))/8.0),vec3(0.0),vec3(31.0));
	vec3 rgb = color5/31.0;
	ALBEDO = OUTPUT_IS_SRGB ? rgb : mix(rgb/12.92,pow((rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),rgb));
}
