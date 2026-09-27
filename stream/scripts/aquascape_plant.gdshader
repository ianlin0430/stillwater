shader_type canvas_item;
uniform float clock=0.;
uniform float height=170.;
uniform float phase=0.;
uniform float bend=0.;
void vertex(){
 float root_weight=clamp(-VERTEX.y/height,0.,1.);
 float delayed_wave=sin(clock*.78-root_weight*1.9+phase*.21)*3.;
 VERTEX.x+=(bend+delayed_wave)*root_weight*root_weight;
 VERTEX.y+=sin(clock*.57+phase)*root_weight*1.4;
}
