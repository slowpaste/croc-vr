extends CompositorEffect
# Raster passes work with Mobile attachment buffers, which lack storage usage.
# Run after transparent objects and spatial UI, processing each stereo view.
const VERTEX := """
#version 450
void main() {
 vec2 p=vec2((gl_VertexIndex<<1)&2,gl_VertexIndex&2);
 gl_Position=vec4(p*2.0-1.0,0.0,1.0);
}
"""
const FRAGMENT := """
#version 450
layout(set=0,binding=0) uniform sampler2D color_texture;
layout(push_constant,std430) uniform Params { float luminance; float reserved; float amount; float direction; } params;
layout(location=0) out vec4 output_color;
vec3 encode(vec3 c) { return mix(c*12.92,1.055*pow(max(c,vec3(0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c)); }
vec3 decode(vec3 c) { return mix(c/12.92,pow((c+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),c)); }
void main() {
 vec4 color=texelFetch(color_texture,ivec2(gl_FragCoord.xy),0);
 if(params.amount>0.0) {
  vec3 rgb5=floor(clamp(encode(color.rgb*params.luminance),vec3(0),vec3(1))*31.0+0.5);
  color.rgb=decode(clamp(rgb5+params.direction*params.amount,vec3(0),vec3(31))/31.0)/params.luminance;
 }
 output_color=color;
}
"""
var rd: RenderingDevice
var shader := RID()
var sampler := RID()
var pipelines: Dictionary = {}
var lock := Mutex.new()
var amount := 0
var direction := -1
func _init() -> void:
	effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color=true
	rd=RenderingServer.get_rendering_device();enabled=false
func configure(level: int, white: bool) -> void:
	lock.lock();amount=clampi(level,0,255)>>3;direction=1 if white else -1;lock.unlock()
func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and rd!=null:
		if shader.is_valid():rd.free_rid(shader)
		if sampler.is_valid():rd.free_rid(sampler)
func draw(source: RID, target: RID, constants: PackedByteArray) -> void:
	var framebuffer:=FramebufferCacheRD.get_cache_multipass([target],[],1)
	var format:=rd.framebuffer_get_format(framebuffer)
	if not pipelines.has(format):
		var blend:=RDPipelineColorBlendState.new();blend.attachments=[RDPipelineColorBlendStateAttachment.new()]
		pipelines[format]=rd.render_pipeline_create(shader,format,RenderingDevice.INVALID_ID,RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,RDPipelineRasterizationState.new(),RDPipelineMultisampleState.new(),RDPipelineDepthStencilState.new(),blend)
	var uniform:=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;uniform.binding=0
	uniform.add_id(sampler);uniform.add_id(source)
	var uniforms:=UniformSetCacheRD.get_cache(shader,0,[uniform])
	var list:=rd.draw_list_begin(framebuffer)
	rd.draw_list_bind_render_pipeline(list,pipelines[format]);rd.draw_list_bind_uniform_set(list,uniforms,0)
	rd.draw_list_set_push_constant(list,constants,constants.size());rd.draw_list_draw(list,false,1,3);rd.draw_list_end()
func _render_callback(callback_type: int, data: RenderData) -> void:
	if rd==null or callback_type!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:return
	lock.lock();var current_amount:=amount;var current_direction:=direction;lock.unlock()
	if current_amount==0:return
	var buffers:RenderSceneBuffersRD=data.get_render_scene_buffers()
	if buffers==null:return
	var size:=buffers.get_internal_size()
	if size.x<=0 or size.y<=0:return
	if not shader.is_valid():
		var source:=RDShaderSource.new();source.source_vertex=VERTEX;source.source_fragment=FRAGMENT
		var spirv:=rd.shader_compile_spirv_from_source(source)
		if not spirv.compile_error_vertex.is_empty() or not spirv.compile_error_fragment.is_empty():push_error(spirv.compile_error_vertex+spirv.compile_error_fragment);return
		shader=rd.shader_create_from_spirv(spirv);sampler=rd.sampler_create(RDSamplerState.new())
	var format:=rd.texture_get_format(buffers.get_color_layer(0))
	var context:=StringName("source_fade_"+str(get_instance_id()))
	# Cached per viewport and released with its buffers, including on resize.
	buffers.create_texture(context,"color",format.format,RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT,RenderingDevice.TEXTURE_SAMPLES_1,size,buffers.get_view_count(),1,false,false)
	# Mobile UNORM buffers store half luminance; floating-point HDR buffers do not.
	var luminance:=1.0 if format.format==RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT else 2.0
	var constants:=PackedFloat32Array([luminance,0,current_amount,current_direction]).to_byte_array()
	var copy_constants:=PackedFloat32Array([luminance,0,0,0]).to_byte_array()
	for view in range(buffers.get_view_count()):
		var original:=buffers.get_color_layer(view)
		var scratch:=buffers.get_texture_slice(context,"color",view,0,1,1)
		draw(original,scratch,constants);draw(scratch,original,copy_constants)
