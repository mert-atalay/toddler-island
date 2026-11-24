// Stylized water for the river and the lake: clear turquoise at the edges deepening to blue, a soft
// ring of foam where it meets the bank, gentle moving ripples that catch the sun, and the river
// flowing along its course (flow_tex holds the downstream direction in RG, 0.5 = still).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D flow_tex : filter_linear;
uniform float world_size = 512.0;
uniform vec3 shallow : source_color = vec3(0.45, 0.82, 0.78);
uniform vec3 deep : source_color = vec3(0.12, 0.42, 0.62);
uniform float clarity = 1.6;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 fuv = wpos.xz / world_size + 0.5;
	vec2 flow = (texture(flow_tex, fuv).rg - 0.5) * 2.0;
	float t = TIME;
	// two phases of flowing ripples, blended so the pattern never stretches
	float ph1 = fract(t * 0.25);
	float ph2 = fract(t * 0.25 + 0.5);
	vec2 uv = wpos.xz * 0.12;
	float a1 = texture(noise_tex, uv - flow * ph1 * 1.2).r;
	float a2 = texture(noise_tex, uv - flow * ph2 * 1.2 + 0.37).r;
	float w = abs(ph1 - 0.5) * 2.0;
	float n = mix(a1, a2, w);
	float n2 = texture(noise_tex, wpos.xz * 0.04 + vec2(t * 0.01, t * 0.007)).r;
	vec3 nw = normalize(vec3((n - 0.5) * 0.5 + (n2 - 0.5) * 0.3, 1.0, (n2 - 0.5) * 0.5 - (n - 0.5) * 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	// how deep the water is here, from the depth buffer
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	world.xyz /= world.w;
	float depth = clamp(-world.z + VERTEX.z, 0.0, 20.0);
	float k = 1.0 - exp(-depth * clarity * 0.6);
	vec3 col = mix(shallow, deep, k);
	// see through to the bed in the shallows
	vec3 below = textureLod(screen_tex, SCREEN_UV + nw.xz * 0.01, 1.0).rgb;
	col = mix(below * vec3(0.7, 0.95, 0.95), col, clamp(k * 1.4 + 0.25, 0.0, 1.0));
	// foam where it meets the bank, broken up a little
	float edge = 1.0 - smoothstep(0.0, 0.55, depth);
	float foam = edge * smoothstep(0.35, 0.65, n + edge * 0.4);
	col = mix(col, vec3(1.0), foam * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	ALPHA = clamp(0.55 + k * 0.45 + foam, 0.0, 1.0);
}
