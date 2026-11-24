// Deep space: the real Milky Way picture, plus three layers of stars made from the view direction:
// a dust of faint ones, a scatter of medium ones, and a few bright ones with soft glows and colour
// (blue-white, white, warm yellow, orange), so the sky has depth instead of one flat picture.
shader_type sky;

uniform sampler2D milky : source_color, filter_linear_mipmap;
uniform float milky_energy = 0.9;
uniform float star_energy = 1.0;
uniform vec3 sun_dir = vec3(0.6, 0.45, 0.65);

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

vec3 star_colour(float h) {
	if (h < 0.25) return vec3(0.7, 0.8, 1.0);
	if (h < 0.65) return vec3(1.0, 0.98, 0.95);
	if (h < 0.88) return vec3(1.0, 0.88, 0.65);
	return vec3(1.0, 0.7, 0.45);
}

// one layer of stars on a grid of cells over the sphere of directions
vec3 stars(vec3 dir, float cells, float chance, float size, float bright) {
	vec3 p = dir * cells;
	vec3 id = floor(p);
	vec3 f = fract(p) - 0.5;
	float h = hash31(id);
	if (h > chance) return vec3(0.0);
	vec3 off = vec3(hash31(id + 1.3), hash31(id + 2.7), hash31(id + 4.1)) - 0.5;
	float d = length(f - off * 0.7);
	float core = smoothstep(size, 0.0, d);
	float glow = exp(-d * 18.0 / max(size * 6.0, 0.001)) * 0.25;
	float b = bright * (0.4 + 0.6 * hash31(id + 7.7));
	return star_colour(hash31(id + 9.9)) * (core + glow) * b;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = texture(milky, SKY_COORDS).rgb;
	col = pow(col, vec3(1.25)) * milky_energy * 1.6;
	vec3 s = vec3(0.0);
	s += stars(dir, 420.0, 0.22, 0.10, 0.55);
	s += stars(dir, 160.0, 0.10, 0.09, 1.4);
	s += stars(dir, 55.0, 0.05, 0.06, 4.5);
	col += s * star_energy;
	// no air: the Sun is a hard white disc with a faint corona
	float sd = dot(dir, normalize(sun_dir));
	col += vec3(1.0, 0.97, 0.9) * (smoothstep(0.99985, 0.9999, sd) * 40.0 + pow(max(sd, 0.0), 900.0) * 3.0);
	COLOR = col;
}
