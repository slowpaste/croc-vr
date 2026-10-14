// Imported RGB bytes are display colors. Spatial shaders consume linear RGB
// on Mobile/Forward+, while Compatibility consumes display RGB directly.
vec3 source_display_to_linear(vec3 value) {
	if (OUTPUT_IS_SRGB) return value;
	return mix(value/12.92,pow((value+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),value));
}
vec3 source_linear_to_display(vec3 value) {
	if (OUTPUT_IS_SRGB) return value;
	return mix(value*12.92,1.055*pow(max(value,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),value));
}
