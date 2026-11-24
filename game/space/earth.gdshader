// The Earth from space: the daytime map lit by the Sun, city lights on the night side, drifting
// clouds, a bright sunset line, a glint of sunlight on the oceans and a blue rim of air.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D day_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D night_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(1.0, 0.3, 0.2);
uniform float cloud_shift = 0.0;

varying vec3 wn;
varying vec3 wpos;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 s = normalize(sun_dir);
	float l = dot(n, s);
	float dayk = smoothstep(-0.1, 0.18, l);
	vec3 d = texture(day_tex, UV).rgb;
	vec3 nl = texture(night_tex, UV).rgb;
	float c = texture(cloud_tex, UV + vec2(cloud_shift, 0.0)).r;
	float ocean = smoothstep(0.12, 0.04, d.g - d.b * 0.6) * step(d.r, 0.2);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 h = normalize(v + s);
	float glint = pow(max(dot(n, h), 0.0), 60.0) * ocean * 0.8;
	vec3 lit = d * (max(l, 0.0) * 1.35 + 0.02) + vec3(1.0, 0.95, 0.85) * glint * max(l, 0.0);
	lit = mix(lit, vec3(1.0) * (max(l, 0.0) * 1.15 + 0.02), c * 0.92);
	// a warm band along the sunset line
	lit += vec3(0.9, 0.4, 0.15) * smoothstep(0.25, 0.0, abs(l - 0.02)) * 0.18 * (1.0 - c * 0.5);
	vec3 night = nl * vec3(1.6, 1.35, 0.9) * (1.0 - c * 0.85);
	vec3 col = mix(night, lit, dayk);
	float rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	col += vec3(0.32, 0.58, 1.0) * rim * clamp(l + 0.35, 0.0, 1.0) * 1.1;
	ALBEDO = col;
}
