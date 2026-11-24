// A sphere drawn on a flat disc from an equirectangular map: used for the Moon in the island's night
// sky (and its little landing-site sparkle after the trip). Lit from one side for its phase.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix;

uniform sampler2D surface : source_color, filter_linear_mipmap;
uniform vec3 light_dir = vec3(-0.6, 0.2, 0.8);
uniform float alpha = 1.0;
uniform vec2 sparkle_lonlat = vec2(-9.0, -9.0);  // landing site, radians; off-disc when unset

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) discard;
	vec3 n = vec3(p.x, -p.y, sqrt(1.0 - r2));
	float lon = atan(n.x, n.z);
	float lat = asin(n.y);
	vec3 c = texture(surface, vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI)).rgb;
	float lit = clamp(dot(n, normalize(light_dir)) * 1.2 + 0.08, 0.0, 1.0);
	vec3 col = c * lit * 1.3;
	float sp = 1.0 - smoothstep(0.0, 0.05, length(vec2(lon, lat) - sparkle_lonlat));
	col += vec3(1.0, 0.9, 0.5) * sp * (0.6 + 0.4 * sin(TIME * 4.0));
	ALBEDO = col;
	ALPHA = alpha * smoothstep(1.0, 0.97, r2);
}
