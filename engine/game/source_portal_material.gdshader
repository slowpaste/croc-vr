shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D atlas_texture : filter_nearest, repeat_disable;
uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform bool has_mask = false;
uniform mat4 portal_inverse;
uniform float source_h = 480.0;
uniform float viewer_distance = 4.0;
uniform vec2 aperture = vec2(3.2,1.6);
uniform float black_level = 0.0;
uniform float white_level = 0.0;
uniform bool sky_background = false;
uniform bool sky_clear_background = false;
uniform bool has_sky_color = false;
uniform vec3 sky_fill_color = vec3(0.0);
/*BLEND_DECL*/
varying vec3 portal_point;
varying flat int source_flags;
varying vec4 source_tint;
varying vec2 source_uv;
varying float source_w;
vec3 encode(vec3 value) {return mix(value*12.92,1.055*pow(max(value,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),value));}
vec3 decode(vec3 value) {return mix(value/12.92,pow((value+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),value));}
void vertex() {
 float depth = max(-VERTEX.z,0.01);
 float stage_depth = max(0.05,20.0*(depth*0.75)/(20.0+depth*0.75));
	if (sky_background) stage_depth = 24.0-UV2.y*0.00001;
	if (sky_clear_background) stage_depth=25.0;
 vec2 original_ray = VERTEX.xy/depth*source_h*(3.2/512.0);
 portal_point = vec3(original_ray*(viewer_distance+stage_depth)/viewer_distance,-stage_depth);
 vec4 clip = PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(portal_point,1.0);
 POSITION = clip;
 source_flags = COLOR.a < 0.5 ? 1 : 0;
 source_tint = COLOR*clip.w;source_uv=UV*clip.w;source_w=clip.w;
}
void fragment() {
 vec3 eye = (portal_inverse*vec4(INV_VIEW_MATRIX[3].xyz,1.0)).xyz;
 float fraction = eye.z/(eye.z-portal_point.z);
 vec2 entry = mix(eye.xy,portal_point.xy,fraction);
 if (eye.z <= 0.0 || fraction <= 0.0 || fraction >= 1.0 || any(greaterThan(abs(entry),aperture*0.5))) discard;
 vec2 uv = source_uv/source_w;
 vec4 pixel = texture(atlas_texture,uv);
 bool textured = (source_flags&1) != 0;
 if (textured && pixel.a < 0.5) discard;
 vec3 tint = (source_tint/source_w).rgb;
 vec3 front5 = textured ? floor(clamp(pixel.rgb*31.0*tint*2.0,vec3(0.0),vec3(31.0))) : floor(clamp(tint*31.0,vec3(0.0),vec3(31.0)));
	if (sky_background && has_sky_color && !textured) front5=sky_fill_color*31.0;
 /*BLEND_FRAGMENT*/
 front5 = clamp(front5-floor(black_level/8.0)+floor(white_level/8.0),vec3(0.0),vec3(31.0));
 ALBEDO = decode(front5/31.0);
}
