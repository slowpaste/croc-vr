shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D source_texture : filter_nearest, repeat_disable;
void fragment() {
	vec4 pixel = texture(source_texture,UV);
	if (pixel.a < 0.01) discard;
	vec3 encoded = mix(pixel.rgb*12.92,1.055*pow(max(pixel.rgb,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),pixel.rgb));
	vec3 rgb = floor(clamp(encoded,vec3(0.0),vec3(1.0))*31.0+0.5)/31.0;
	ALBEDO = OUTPUT_IS_SRGB ? rgb : mix(rgb/12.92,pow((rgb+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),rgb));
	ALPHA = pixel.a;
}
