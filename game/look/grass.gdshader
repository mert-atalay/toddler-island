// The grass field: blades that sway in rolling gusts and part round the explorer as she walks
// through. Each clump's colour comes from the ground under it, so grass and ground match.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
global uniform vec2 cloud_offset;
global uniform vec3 player_pos;

varying float tip;
varying vec3 wp;
varying vec3 tint;

void vertex() {
	tip = UV.y;
	tint = pow(COLOR.rgb, vec3(2.2));
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// blades shrink away smoothly with distance, so the grass field never ends in a hard edge
	float shrink = smoothstep(52.0, 34.0, distance(root, CAMERA_POSITION_WORLD));
	VERTEX *= shrink;
	float gust = texture(noise_tex, root.xz * 0.018 + vec2(TIME * 0.045, TIME * 0.02)).r;
	float flutter = sin(TIME * 2.3 + root.x * 0.9 + root.z * 0.7);
	vec3 off = vec3(1.0, 0.0, 0.45) * (0.08 + 0.42 * gust * gust + 0.05 * flutter) * tip * tip;
	vec2 to = root.xz - player_pos.xz;
	float d = length(to);
	float push = smoothstep(0.95, 0.25, d);
	off.xz += normalize(to + vec2(0.001)) * push * 0.32 * tip;
	off.y -= push * 0.1 * tip;
	mat3 inv = inverse(mat3(MODEL_MATRIX));
	VERTEX += inv * off * shrink;
	NORMAL = normalize(inv * vec3(0.0, 1.0, 0.0));
	wp = w;
}

void fragment() {
	float n = texture(noise_tex, wp.xz * 0.6).r;
	vec3 col = tint * mix(0.8, 1.14, tip) * (0.92 + 0.16 * n);
	col = mix(col, col * vec3(1.15, 1.1, 0.75), smoothstep(0.75, 1.0, tip) * 0.35);
	float cl = texture(noise_tex, (wp.xz + cloud_offset) * 0.011).r;
	col *= mix(1.0, 0.68, smoothstep(0.56, 0.74, cl));
	ALBEDO = col;
	ROUGHNESS = 0.92;
	BACKLIGHT = col * 0.45 * tip;
}
