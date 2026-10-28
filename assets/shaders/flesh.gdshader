shader_type spatial;
uniform vec4 tint : source_color = vec4(0.22, 0.035, 0.022, 1.0);
uniform float detail = 1.0;
varying vec3 local;
void vertex() { local = VERTEX; }
float n(vec3 p) { return sin(p.x*17.2+sin(p.z*23.1))*sin(p.y*31.7+sin(p.x*9.3)); }
void fragment() {
 float patches = n(local*0.32)*0.5+0.5;
 float fibre = sin(local.x*170.0 + sin(local.y*18.0)*5.0 + local.z*45.0);
 float groove = smoothstep(0.55, 0.96, fibre);
 float clot = smoothstep(0.85, 0.98, patches);
 ALBEDO = tint.rgb * vec3(0.95,1.05,1.0) * mix(0.82,1.16, patches) * (1.0-groove*0.14);
 ALBEDO = mix(ALBEDO, vec3(0.055,0.003,0.002),clot*0.65);
 ROUGHNESS = mix(0.60,0.82,clot) + groove*0.04;
 SPECULAR = 0.28;
 NORMAL_MAP = normalize(vec3(fibre*0.025*detail, n(local*35.0)*0.015*detail, 1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH = 0.12;
}
