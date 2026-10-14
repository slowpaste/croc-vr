shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D source_texture : filter_nearest, repeat_disable;
void fragment() { COLOR = texture(source_texture,UV); }
