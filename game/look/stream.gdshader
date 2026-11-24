// The stream: clear water flowing downhill along the ribbon (UV.x runs downstream), with small
// white ripples where it moves fastest.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, depth_draw_always;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 flow = vec2(UV.x * 0.35 - TIME * 0.6, UV.y * 0.5);
	float a = texture(noise_tex, flow).r;
	float b = texture(noise_tex, flow * 1.7 + 0.3).r;
	vec3 nw = normalize(vec3((a - 0.5) * 0.8, 1.0, (b - 0.5) * 0.8));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float edge = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float foam = smoothstep(0.68, 0.8, a * b * 1.7) * edge;
	ALBEDO = mix(vec3(0.3, 0.62, 0.66), vec3(1.0), foam * 0.7);
	ALPHA = mix(0.35, 0.8, edge);
	ROUGHNESS = 0.08;
}
