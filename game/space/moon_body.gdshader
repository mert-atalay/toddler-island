// The Moon seen from space: the real surface map lit by the Sun, a touch of earthshine on its night side.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D surface : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(1.0, 0.3, 0.2);

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float l = dot(normalize(wn), normalize(sun_dir));
	vec3 t = texture(surface, UV).rgb;
	ALBEDO = t * (smoothstep(-0.05, 1.0, l) * 1.5 + 0.03);
}
