// Sea and pond: clear turquoise shallows that deepen to blue, waves that roll toward the shore and
// leave lines of foam on the sand, a gentle swell, and sun glints. Depth comes from the ground's heights.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx, depth_draw_always;

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float world_size = 240.0;
uniform vec3 shallow : source_color = vec3(0.45, 0.85, 0.82);
uniform vec3 deep : source_color = vec3(0.12, 0.42, 0.62);
global uniform vec2 cloud_offset;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += 0.05 * sin(wp.x * 0.25 + TIME * 0.9) + 0.04 * sin(wp.z * 0.33 + TIME * 1.2);
}

void fragment() {
	vec2 uv = wp.xz / world_size + 0.5;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float ground = mix(-6.0, texture(height_tex, uv).r, inside);
	float depth = max(0.0, -ground);
	// ripples from two drifting noise layers
	float a = texture(noise_tex, wp.xz * 0.06 + vec2(TIME * 0.012, TIME * 0.008)).r;
	float b = texture(noise_tex, wp.xz * 0.11 - vec2(TIME * 0.01, -TIME * 0.015)).r;
	vec3 nw = normalize(vec3((a - 0.5) * 0.9, 1.0, (b - 0.5) * 0.9));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 3.8, depth));
	// waves rolling in: bands that travel toward shallower water and break into foam
	float wobble = texture(noise_tex, wp.xz * 0.05).r * 5.0;
	float band = sin(depth * 4.5 + TIME * 1.4 + wobble);
	float foam = smoothstep(0.3, 0.0, depth) * (0.65 + 0.35 * sin(TIME * 2.0 + wobble));
	foam += smoothstep(0.93, 1.0, band) * smoothstep(1.6, 0.25, depth);
	foam = clamp(foam, 0.0, 1.0);
	float cl = texture(noise_tex, (wp.xz + cloud_offset) * 0.011).r;
	col *= mix(1.0, 0.75, smoothstep(0.56, 0.74, cl));
	ALBEDO = mix(col, vec3(1.0), foam * 0.9);
	ALPHA = max(mix(0.5, 0.93, smoothstep(0.0, 1.8, depth)), foam);
	ROUGHNESS = mix(0.06, 0.5, foam);
	SPECULAR = 0.7;
}
