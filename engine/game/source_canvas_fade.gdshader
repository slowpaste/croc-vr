shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Compatibility's canvas framebuffer is already in display RGB.
uniform sampler2D background_texture : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float direction = -1.0;
void fragment() {
	vec4 background=textureLod(background_texture,SCREEN_UV,0.0);
	vec3 rgb5=floor(clamp(background.rgb,vec3(0),vec3(1))*31.0+0.5);
	COLOR=vec4(clamp(rgb5+direction*amount,vec3(0),vec3(31))/31.0,background.a);
}
