shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_texture : filter_nearest, repeat_disable;
uniform int source_black_level = 255;
uniform int source_white_level = 0;
void fragment() {
	vec3 linear = texture(source_texture,UV).rgb;
	// Native4fd78..4fe14/50290..502a4 copies only rect(0,40,512,160)
	// from the movie buffer into the cleared512x240 display.
	if (UV.y < 40.0/240.0 || UV.y >= 200.0/240.0) linear = vec3(0.0);
	vec3 encoded = mix(linear*12.92,1.055*pow(max(linear,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),linear));
	vec3 color5 = floor(clamp(encoded,vec3(0.0),vec3(1.0))*31.0+0.5);
	vec3 rgb = clamp(color5-float(source_black_level>>3)+float(source_white_level>>3),vec3(0.0),vec3(31.0))/31.0;
	ALBEDO = OUTPUT_IS_SRGB ? rgb : mix(rgb/12.92,pow((rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),rgb));
}
