// The painted ground: meadow grass with patches, dirt paths with pebbled edges (from a painted path
// picture), sand with ripples, wet stream banks, rock on steep slopes, and drifting cloud shadows.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D paint : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float world_size = 240.0;
global uniform vec2 cloud_offset;

varying vec4 weights;
varying vec3 wpos;
varying vec3 base;

vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// distance to the nearest scattered point, and that point's id (for pebbles)
vec2 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o - f);
			if (d < best) { best = d; id = hash(i + g + 3.1); }
		}
	}
	return vec2(best, id);
}

void vertex() {
	weights = CUSTOM0;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	base = lin(COLOR.rgb);
}

void fragment() {
	vec2 uv = wpos.xz / world_size + 0.5;
	float path = texture(paint, uv).r;
	float n1 = texture(noise_tex, wpos.xz * 0.045).r;
	float n2 = texture(noise_tex, wpos.xz * 0.37).r;
	float n3 = texture(noise_tex, wpos.xz * 1.9).r;
	// meadow: the vertex colour, broken up at three sizes, with drier and lusher patches
	vec3 col = base * (0.84 + 0.22 * n1) * (0.9 + 0.14 * n2) * (0.94 + 0.1 * n3);
	col = mix(col, col * vec3(1.18, 1.06, 0.72), smoothstep(0.6, 0.8, n1) * 0.45);
	col = mix(col, col * vec3(0.85, 1.05, 0.85), smoothstep(0.42, 0.22, n1) * 0.35);
	col = mix(col, col * vec3(1.12, 1.04, 0.78), weights.a * 0.5);
	// dirt path, with pebbles scattered along its edges
	vec3 dirt = lin(mix(vec3(0.66, 0.53, 0.37), vec3(0.56, 0.45, 0.31), n2)) * (0.88 + 0.18 * n3);
	vec2 c = cells(wpos.xz * 3.4);
	float pebble = smoothstep(0.26, 0.18, c.x) * step(0.55, c.y);
	float edge = smoothstep(0.12, 0.45, path) * smoothstep(0.95, 0.6, path);
	vec3 peb = lin(mix(vec3(0.58, 0.55, 0.5), vec3(0.7, 0.66, 0.58), fract(c.y * 7.0)));
	float on_path = smoothstep(0.38, 0.62, path);
	col = mix(col, dirt, on_path);
	col = mix(col, peb, pebble * edge * 0.85);
	// sand, with wind ripples
	float ripple = 0.5 + 0.5 * sin(wpos.x * 2.6 + wpos.z * 0.9 + n1 * 8.0);
	vec3 sand = lin(mix(vec3(0.91, 0.83, 0.63), vec3(0.85, 0.77, 0.57), n2)) * (0.95 + 0.06 * ripple);
	col = mix(col, sand, weights.r);
	// wet banks and stream bed
	col = mix(col, col * vec3(0.55, 0.55, 0.52), weights.b * 0.75);
	// rock on steep slopes
	vec3 rock = lin(mix(vec3(0.5, 0.49, 0.47), vec3(0.64, 0.62, 0.58), n3)) * (0.9 + 0.15 * n2);
	col = mix(col, rock, weights.g);
	// cloud shadows drifting across
	float cl = texture(noise_tex, (wpos.xz + cloud_offset) * 0.011).r;
	col *= mix(1.0, 0.68, smoothstep(0.56, 0.74, cl));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.35, weights.b * (1.0 - on_path));
}
