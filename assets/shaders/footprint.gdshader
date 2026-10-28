shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D stamp : source_color, filter_linear_mipmap;
varying vec4 ink;
void vertex() {
 ink = vec4(INSTANCE_CUSTOM.rgb, abs(INSTANCE_CUSTOM.a));
 if (INSTANCE_CUSTOM.a < 0.0) { UV.x = 1.0-UV.x; }
}
void fragment() {
 vec4 tex = texture(stamp, UV);
 if (tex.a < 0.38 || ink.a < 0.01) { discard; }
 ALBEDO = ink.rgb * (0.75+dot(tex.rgb,vec3(0.333))*1.2);
 ROUGHNESS = ink.r > 0.1 ? 0.42 : 0.95;
 SPECULAR = 0.25;
 ALPHA = smoothstep(0.38,0.75,tex.a)*ink.a;
}
