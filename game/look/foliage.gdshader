// Leaves, grass and flowers that sway in the wind. The sway grows with height up the plant,
// so stems stay planted. Used in place of the plants' own materials.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.3;
uniform float sway = 0.05;          // in the mesh's own units
uniform float sway_height = 1.0;    // mesh height in its own units
uniform float sway_speed = 1.4;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float t = TIME * sway_speed + wp.x * 0.31 + wp.z * 0.23;
	float gust = 0.6 + 0.4 * sin(TIME * 0.37 + wp.x * 0.05);
	VERTEX.x += sin(t) * sway * h * h * gust;
	VERTEX.z += cos(t * 0.83) * sway * 0.6 * h * h * gust;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.92;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
