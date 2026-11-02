shader_type spatial;
varying vec3 world_at;
varying vec3 world_normal;
void vertex(){world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float hash(float p){return fract(sin(p*127.1)*43758.5453);}
void fragment(){
 vec2 p=abs(world_normal.x)>.5?world_at.zy:world_at.xy;
 if(abs(world_normal.y)>.5)p=world_at.xz;
 float board=floor(p.y/.22);float edge=smoothstep(.0,.012,mod(p.y,.22));
 float grain=sin(p.x*130.0+sin(p.y*12.0)*2.0)*.018+sin(p.x*330.0+p.y*45.0)*.008;
 float worn=hash(board)*.055;vec3 color=vec3(.095,.072,.047)+grain+worn;
 ALBEDO=color*mix(.3,1.0,edge);ROUGHNESS=.88;
}
