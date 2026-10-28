shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float radius = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.005, 0.008, 0.006);
	ALPHA = (1.0 - smoothstep(0.25, 1.0, radius)) * 0.28;
}
