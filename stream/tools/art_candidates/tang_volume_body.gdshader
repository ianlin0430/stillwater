shader_type canvas_item;
uniform vec2 extent=vec2(122.,87.23775);
uniform float body_line=.66;
uniform float facing=1.;
uniform float pitch=0.;
uniform float roll=0.;
uniform vec2 pose_offset=vec2(0.);
uniform vec4 atlas_rect=vec4(0.08984375,0.1015625,0.3587239583,0.384765625);
varying vec2 plane;
varying vec4 tint;
void vertex() {
    tint=COLOR;
    vec2 p=VERTEX;
    plane=p;
    p.y*=cos(roll);
    p.x+=sin(roll)*p.y*.25;
    p=mat2(vec2(cos(pitch),sin(pitch)),vec2(-sin(pitch),cos(pitch)))*p;
    VERTEX=p+pose_offset;
}
void fragment() {
    // Ray/ellipsoid intersection in the 2D canvas: exactly one visible surface.
    // Avoids cross-fades, painter-order seams and interpolated back-face holes.
    float sn=sqrt(max(0.,1.-facing*facing));
    float rx=extent.x*.31;
    float ry=extent.y*.29;
    float rz=13.;
    vec2 center=vec2(extent.x*.07*facing,-extent.y*.11);
    vec2 p=plane-center;
    float a=rx*rx*facing*facing+rz*rz*sn*sn;
    float cross_term=(rx*rx-rz*rz)*facing*sn;
    float inside=1.-pow(p.y/ry,2.)-p.x*p.x/a;
    if (inside<=0.) discard;
    float depth=cross_term/a*p.x+sqrt(rx*rx*rz*rz/a*inside);
    float source_x=p.x*facing+depth*sn+extent.x*.07;
    vec2 source=vec2(source_x/extent.x+.5,plane.y/extent.y+body_line);
    vec4 tex=texture(TEXTURE,atlas_rect.xy+source*atlas_rect.zw);
    if(tex.a<.86) discard;
    COLOR=vec4(tex.rgb,smoothstep(.86,.97,tex.a))*tint;
}
