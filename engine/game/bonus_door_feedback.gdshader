shader_type spatial;
render_mode cull_disabled;
#include "source_color_space.gdshaderinc"
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D still_texture : source_color, filter_nearest, repeat_disable;
uniform int collected_mask = 0;
uniform vec2 atlas_size;
uniform vec4 panel_origins[6];
varying flat int material_index;
void vertex() { material_index = int(UV2.y + 0.5); }
bool in_gem(vec2 position, vec2 center) {
 vec2 delta = (position - center) / vec2(17.5,20.0);
 return dot(delta,delta) <= 1.05;
}
void fragment() {
 vec4 pixel = collected_mask == 31 ? texture(atlas_texture, UV) : texture(still_texture, UV);
 if (pixel.a < 0.5) discard;
 vec3 color = pixel.rgb;
 int gem_index = -1;
 if (material_index >= 416 && material_index <= 421) {
  vec4 origin = panel_origins[material_index-416];
  vec2 position = UV * atlas_size - origin.xy + origin.zw - vec2(0.5);
  // Include the complete painted facet and colored fringe, including the
  // portions split across the upper/lower door panels.
  bool lower = material_index >= 418;
  for (int i=0; i<3; i++) {
   if (in_gem(position,vec2((lower ? 96.0 : 0.0)+16.0+float(i)*32.0,lower ? 9.0 : 34.0))) gem_index=i;
  }
  if (lower && in_gem(position,vec2(128.0,34.0))) gem_index=3;
  if (lower && in_gem(position,vec2(160.0,34.0))) gem_index=4;
 }
 bool missing = gem_index >= 0 && (collected_mask & (1 << gem_index)) == 0;
 bool inactive_border = material_index >= 422 && material_index <= 431 && collected_mask != 31;
 if (missing || inactive_border) {
  float shade = dot(source_linear_to_display(color),vec3(0.299,0.587,0.114));
  color = source_display_to_linear(vec3(0.08 + shade * 0.22));
 }
 ALBEDO = color;
 ROUGHNESS = 1.0;
}
