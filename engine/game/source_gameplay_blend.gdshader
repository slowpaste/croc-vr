shader_type spatial;
#include "source_color_space.gdshaderinc"
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D source_mask : filter_nearest, repeat_disable;
uniform sampler2D background_texture : hint_screen_texture, filter_nearest;
uniform bool has_mask = false;
varying flat int source_flags;
varying flat int blend_mode;
vec3 encoded(vec3 value) {
 return source_linear_to_display(value);
}
vec3 linear_color(vec3 value) {
 return source_display_to_linear(value);
}
void vertex() { source_flags = int(UV2.x+0.5); blend_mode = int(UV2.y+0.5); }
void fragment() {
 bool textured = (source_flags&1) != 0;
 vec4 pixel = textured ? texture(atlas_texture,UV) : vec4(1.0);
 if (pixel.a < 0.5) discard;
 vec3 foreground = pixel.rgb * source_display_to_linear(COLOR.rgb);
 bool blend_pixel = !textured || !has_mask || texture(source_mask,UV).r > 0.5;
 if (blend_mode == 1 && blend_pixel) discard; // Separate cumulative additive pass.
 vec3 background = textureLod(background_texture,SCREEN_UV,0.0).rgb;
 vec3 result = foreground;
 if (blend_pixel) {
  vec3 back5 = floor(clamp(encoded(background),vec3(0.0),vec3(1.0))*31.0+0.5);
  vec3 front5 = floor(clamp(encoded(foreground),vec3(0.0),vec3(1.0))*31.0+0.5);
  if (blend_mode == 0) result = floor(back5/2.0)+floor(front5/2.0);
  else if (blend_mode == 1) result = back5+front5;
  else if (blend_mode == 2) result = back5-front5;
  else result = back5+floor(front5/4.0);
  result = linear_color(clamp(result,vec3(0.0),vec3(31.0))/31.0);
 }
 ALBEDO = clamp(result,vec3(0.0),vec3(1.0));
 ALPHA = 1.0;
}
