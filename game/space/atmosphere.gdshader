// A soft glow of air around a planet, drawn on a slightly bigger sphere and added on top.
shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never;

uniform float radius = 400.0;     // the planet's radius
uniform float thickness = 0.022;   // as a fraction of the radius
uniform vec3 sun_dir = vec3(1.0, 0.3, 0.2);
uniform vec3 tint : source_color = vec3(0.35, 0.6, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize(wpos - ro);
	float t = max(dot(centre - ro, rd), 0.0);
	vec3 p = ro + rd * t;
	float d = length(p - centre);
	float k = d > radius ? exp(-(d - radius) / (radius * thickness)) : pow(d / radius, 10.0) * 0.6;
	float lit = clamp(dot(normalize(p - centre), normalize(sun_dir)) + 0.4, 0.0, 1.0);
	ALBEDO = tint * k * lit * 1.2;
}
