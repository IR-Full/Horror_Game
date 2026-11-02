shader_type spatial;
uniform float road=0.0;
varying vec3 world_at;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_at.xz;float grain=hash(floor(p*110.0));float patches=hash(floor(p*1.7));
 float needles=step(.96,hash(floor(p*20.0)))*.045;
 vec3 soil=mix(vec3(.038,.052,.032),vec3(.085,.062,.038),patches);
 soil=mix(soil,vec3(.065,.057,.042),road*.7);
 ALBEDO=soil*(.7+grain*.6)+needles;ROUGHNESS=.89-road*.13;
 NORMAL_MAP=normalize(vec3((grain-.5)*.1,(patches-.5)*.08,1.0))*.5+.5;
}
