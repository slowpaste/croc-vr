shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D background_texture : filter_nearest, repeat_disable;
uniform sampler2D foreground_texture : filter_nearest, repeat_disable;
uniform sampler2D source_mask_texture : filter_nearest, repeat_disable;
uniform bool source_textured = true;
uniform bool source_semitransparent = true;
uniform int source_blend_mode = 2;
vec3 encode_color(vec3 linear) {
	return mix(linear*12.92,1.055*pow(max(linear,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),linear));
}
vec3 decode_color(vec3 encoded) {
	return mix(encoded/12.92,pow((encoded+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),encoded));
}
void fragment() {
	vec4 background = texture(background_texture,UV);
	vec4 foreground = texture(foreground_texture,UV);
	vec4 mask = texture(source_mask_texture,UV);
	vec3 b = floor(clamp(encode_color(background.rgb),vec3(0.0),vec3(1.0))*31.0+0.5);
	vec3 f = floor(clamp(encode_color(foreground.rgb),vec3(0.0),vec3(1.0))*31.0+0.5);
	vec3 result = b;
	if (foreground.a >= 0.5 && (!source_textured || mask.g >= 0.5)) {
		result = f;
		if (source_semitransparent && (!source_textured || mask.r >= 0.5)) {
			if (source_blend_mode == 0) result = floor((b+f)/2.0);
			else if (source_blend_mode == 1) result = min(vec3(31.0),b+f);
			else if (source_blend_mode == 2) result = max(vec3(0.0),b-f);
			else if (source_blend_mode == 3) result = min(vec3(31.0),b+floor(f/4.0));
		}
	}
	COLOR = vec4(decode_color(result/31.0),1.0);
}
