// The real night sky on a dome round the camera: NASA-derived star and Milky Way map, fading in at
// dusk. It adds light over the day sky, so it is invisible in daylight.
shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never, fog_disabled;

uniform sampler2D stars : source_color, filter_linear_mipmap;
uniform float night = 0.0;

void fragment() {
	vec3 c = texture(stars, UV).rgb;
	ALBEDO = c * night * 1.6;
}
