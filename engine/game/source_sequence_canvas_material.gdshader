shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Experimental ordered framebuffer path. Vertex alpha stores flags/source;
// it is metadata, never opacity: flags occupy bits0/5/6, source bits2/3.
// Input color/UV are affine screen attributes.
uniform sampler2D actor_texture : filter_nearest, repeat_disable;
uniform sampler2D room_texture : filter_nearest, repeat_disable;
uniform sampler2D sky_texture : filter_nearest, repeat_disable;
uniform sampler2D actor_mask : filter_nearest, repeat_disable;
uniform sampler2D room_mask : filter_nearest, repeat_disable;
uniform sampler2D sky_mask : filter_nearest, repeat_disable;
uniform sampler2D prior_frame : hint_screen_texture, filter_nearest, repeat_disable;
uniform bool apply_blend = false;
uniform int blend_mode = 0;
uniform bool use_vertex_data = false;
uniform sampler2D vertex_data : filter_nearest, repeat_disable;
varying vec3 source_tint;
varying flat int source_metadata;
varying vec2 source_uv;
const int DITHER[16] = int[16](-4,0,-3,1,2,-2,3,-1,-3,1,-4,0,3,-1,2,-2);
vec3 encode_color(vec3 value) {
	return mix(value*12.92,1.055*pow(max(value,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),value));
}
vec3 decode_color(vec3 value) {
	return mix(value/12.92,pow((value+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),value));
}
void vertex() {
	// HDR canvas vertex colors arrive in linear space; recover source RGB8.
	source_tint = round(encode_color(COLOR.rgb)*255.0)/255.0;
	source_metadata = int(COLOR.a*255.0+0.5);
	source_uv = UV;
	if (use_vertex_data) {
		ivec2 address = ivec2(UV);
		vec4 first = texelFetch(vertex_data,address,0);
		vec4 second = texelFetch(vertex_data,address+ivec2(0,1),0);
		source_tint = first.rgb;
		source_uv = vec2(first.a,second.r);
		source_metadata = int(second.g+0.5);
	}
}
void fragment() {
	int flags = source_metadata&97;
	int source = (source_metadata>>2)&3;
	bool textured = (flags&1) != 0;
	vec4 pixel = source == 0 ? texture(actor_texture,source_uv) : source == 1 ? texture(room_texture,source_uv) : texture(sky_texture,source_uv);
	vec4 mask = source == 0 ? texture(actor_mask,source_uv) : source == 1 ? texture(room_mask,source_uv) : texture(sky_mask,source_uv);
	if (textured && pixel.a < 0.5) discard;
	ivec2 position = ivec2(floor(FRAGCOORD.xy));
	float dither = ((flags&64) == 0 || textured) ? float(DITHER[(position.y&3)*4+(position.x&3)]) : 0.0;
	vec3 color8 = floor(clamp(source_tint*255.0+vec3(0.0001),vec3(0.0),vec3(255.0)));
	vec3 texture5 = floor(pixel.rgb*31.0+vec3(0.5));
	vec3 value = textured ? floor(texture5*color8/16.0) : color8;
	vec3 result = clamp(floor((value+vec3(dither))/8.0),vec3(0.0),vec3(31.0));
	if (apply_blend && (!textured || mask.r >= 0.5)) {
		vec3 previous = floor(clamp(encode_color(texture(prior_frame,SCREEN_UV).rgb),vec3(0.0),vec3(1.0))*31.0+0.5);
		if (blend_mode == 0) result = floor((previous+result)/2.0);
		else if (blend_mode == 1) result = min(vec3(31.0),previous+result);
		else if (blend_mode == 2) result = max(vec3(0.0),previous-result);
		else result = min(vec3(31.0),previous+floor(result/4.0));
	}
	COLOR = vec4(decode_color(result/31.0),1.0);
}
