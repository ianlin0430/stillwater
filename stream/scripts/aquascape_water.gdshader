shader_type canvas_item;
uniform float clock=0.;
void fragment(){
 vec4 base=texture(TEXTURE,UV);
 vec2 cell=floor(UV*vec2(320.,180.))/vec2(320.,180.);
 float surface=1.-smoothstep(.025,.13,cell.y);
 float ripple=sin(cell.x*91.-clock*1.25+sin(cell.x*23.+clock*.3))*surface;
 float shaft=pow(max(0.,sin(cell.x*19.+cell.y*1.8+sin(clock*.24)*.3)),12.);
 float open_water=smoothstep(.14,.28,cell.y)*(1.-smoothstep(.55,.78,cell.y));
 float caustic=max(0.,sin(cell.x*62.+clock*.6)*sin(cell.y*53.-clock*.4)-.45);
 float sand=smoothstep(.78,.92,cell.y)*(1.-smoothstep(.21,.30,abs(cell.x-.5)));
 base.rgb+=vec3(.34,.65,.68)*(ripple*.025+shaft*open_water*.028+caustic*sand*.035);
 COLOR=base;
}
