shader_type canvas_item;
render_mode unshaded;
uniform float stress : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.38, length(p * vec2(0.86, 1.0)));
	float grain = hash(floor(FRAGCOORD.xy) + floor(TIME * 18.0));
	float pulse = (sin(TIME * 6.0) * 0.5 + 0.5) * stress;
	vec3 tint = mix(vec3(0.012, 0.021, 0.025), vec3(0.22, 0.025, 0.014), damage * 0.75);
	float alpha = edge * (0.36 + pulse * 0.1 + damage * 0.2) + grain * 0.023;
	COLOR = vec4(tint, alpha);
}
