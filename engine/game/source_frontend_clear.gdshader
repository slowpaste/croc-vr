shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 clear_color : source_color = vec3(0.0);
uniform bool physical_panel = false;
void vertex() { if (physical_panel) { POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0); } else { POSITION = vec4(VERTEX.xy,1.0,1.0); } }
void fragment() { ALBEDO = clear_color; ALPHA = 1.0; }
