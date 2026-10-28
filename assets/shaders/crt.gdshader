shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float signal_strength : hint_range(0.0, 1.0) = 0.3;
void fragment() {
	float wave = 0.5 + sin(UV.x * 55.0 + TIME * 2.2) * 0.16 * sin(UV.x * 13.0 - TIME);
	float trace = 1.0 - smoothstep(0.018, 0.07, abs(UV.y - wave));
	float scan = 0.75 + sin(UV.y * 130.0) * 0.2;
	vec3 phosphor = vec3(0.11, 0.72, 0.43) * (0.05 + trace * signal_strength) * scan;
	ALBEDO = phosphor * 0.6;
	EMISSION = phosphor * 0.7;
}
