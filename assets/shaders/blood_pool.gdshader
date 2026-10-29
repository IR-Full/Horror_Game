shader_type spatial;
render_mode cull_disabled;
uniform float seed = 1.0;
uniform float spread : hint_range(0.01, 1.0) = 1.0;
uniform float age : hint_range(0.0, 1.0) = 0.45;
uniform float fresh_boost : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 73.1) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void fragment() {
 vec2 p = (UV-0.5)*2.0 / max(spread, 0.01);
 float broad = noise(p*3.5);
 float fine = noise(p*38.0);
 float edge = length(p) + (broad-0.5)*0.28 + (noise(p*15.0)-0.5)*0.045;
 if (edge > 0.9) { discard; }
 float rim = smoothstep(0.70, 0.90, edge);
 float clot = smoothstep(0.70, 0.86, noise(p*9.0)) * (1.0-rim);
 vec3 wet = mix(vec3(0.12,0.004,0.003), vec3(0.29,0.017,0.012), broad);
 wet *= mix(1.0,1.55,fresh_boost);
 vec3 dried = vec3(0.065,0.011,0.006);
 ALBEDO = mix(wet, dried, clamp(rim*0.82 + clot*0.5 + age*0.16,0.0,1.0));
 ROUGHNESS = mix(0.24 + fine*0.025, 0.82, clamp(rim + clot*0.65,0.0,1.0));
 SPECULAR = 0.4;
}
