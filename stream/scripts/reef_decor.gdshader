shader_type canvas_item;
uniform vec2 extent;
uniform vec4 region;
uniform float clock=0.;
uniform float phase=0.;
uniform bool foreground=false;
uniform bool plant=false;
uniform bool anemone=false;
uniform vec2 hold0=vec2(10000.);
uniform vec2 hold1=vec2(10000.);
uniform vec2 hold2=vec2(10000.);
uniform vec2 hold3=vec2(10000.);
void vertex() {
    vec2 p=VERTEX;
    float height=clamp(-p.y/extent.y,0.,1.);
    if (plant) {
        // Keep the four physical grip points fixed; only free tips/leaves breathe.
        float free_tip=smoothstep(0.,14.,distance(p,hold0))*smoothstep(0.,14.,distance(p,hold1))*smoothstep(0.,14.,distance(p,hold2))*smoothstep(0.,14.,distance(p,hold3));
        p.x+=sin(clock*.7+height*2.+phase)*2.0*height*height*free_tip;
    }
    if (anemone) p.x+=sin(clock*1.1+p.x*.055+phase)*.8*height*height;
    VERTEX=p;
}
void fragment() {
    vec4 texel=texture(TEXTURE,UV);
    vec2 at=(UV/TEXTURE_PIXEL_SIZE-region.xy)/region.zw;
    if (texel.a<.86) discard;
    if (foreground) {
        // A real textured front lip occludes the body, not a fade or sand-plane cut.
        float lip=anemone ? .57+.05*sin(at.x*23.) : .84;
        if (plant || at.y<lip) discard;
    }
    COLOR.a*=smoothstep(.86,.97,texel.a)/max(texel.a,.001);
}
