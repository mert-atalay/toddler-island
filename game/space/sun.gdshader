// The Sun: a white-hot disc with a wide soft glow, always facing the camera.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float disc = smoothstep(0.12, 0.1, r);
	float glow = exp(-r * 5.0) * 0.9 + exp(-r * 14.0) * 0.8;
	ALBEDO = vec3(1.0, 0.96, 0.88) * (disc * 3.0 + glow) * smoothstep(1.0, 0.7, r);
}
