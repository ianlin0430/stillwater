shader_type canvas_item;
uniform vec2 extent = vec2(100.,60.);
uniform float body_line = 0.5;
uniform float phase = 0.;
uniform float effort = 0.;
uniform float facing = 1.;
uniform float tail_facing = 1.;
uniform float projection = 1.;
uniform float bite = 0.;
uniform float fin_open = 1.;
uniform float pitch = 0.;
uniform vec2 pose_offset = vec2(0.);
uniform bool eel = false;
uniform float extension = 1.;
uniform bool clip_sand = false;
uniform float fin_ray = 0.;
uniform float sleep_amount = 0.;
uniform vec2 pectoral_root = vec2(.74,.58);
uniform vec2 pectoral_span = vec2(.2,.25);
uniform float pectoral_drive = 1.;
uniform float breath_phase = 0.;
varying float sand_y;
void vertex() {
    vec2 p = VERTEX;
    if (eel) {
        p.y += (1. - extension) * extent.y;
        float height = clamp(-p.y/extent.y, 0., 1.);
        p.x *= facing;
        p.x += (sin(phase * .42 - height * 1.6) * 6. + facing * 7.) * height * height;
        p.x += bite * 3. * height * height;
    } else {
        float tail = clamp(.5 - p.x/extent.x, 0., 1.);
        float fin = smoothstep(0.08, 0.32, abs(p.y)/extent.y);
        float body_drive = (.35 + effort * 2.4) * (1. - sleep_amount*.8);
        p.y += sin(phase - tail*4.4) * body_drive * tail*tail;
        // Fin base stays attached; only the outer fan and caudal membrane flex.
        p.y += sin(phase*1.17-tail*3.8)*(.2+effort*.4)*fin;
        p.y *= 1. + (fin_open-1.) * fin;
        // Firefish tall first dorsal ray bends progressively away from its base.
        float ray = smoothstep(.12, .7, -p.y/extent.y) * fin_ray;
        p.x += sin(phase*.43)*ray*4.;
        vec2 atlas_point=vec2(p.x/extent.x+.5,p.y/extent.y+body_line);
        vec2 fin_delta=(atlas_point-pectoral_root)/pectoral_span;
        float pectoral=(1.-smoothstep(.5,1.,length(fin_delta)))*max(0.,-fin_delta.x);
        p.y+=sin(phase*1.6)*pectoral*2.2*pectoral_drive;
        p.x+=cos(phase*1.6)*pectoral*.8*pectoral_drive;
        // Local operculum breathing; the eye and body silhouette remain quiet.
        float gill=exp(-pow((atlas_point.x-.80)/.055,2.)-pow((atlas_point.y-body_line)/.15,2.));
        p.x+=sin(breath_phase)*gill*.28;
        float jaw = smoothstep(.72,.98,p.x/extent.x+.5) * smoothstep(-.03,.07,p.y/extent.y);
        p.y += jaw * bite * .85;
        float local_facing=mix(facing,tail_facing,tail);
        // A finite front-facing thickness preserves volume through each turn.
        p.x *= ((local_facing<0.?-1.:1.)*(.14+.86*abs(local_facing))) * projection;
        p.y += sin(tail*3.14159) * (facing-tail_facing) * extent.y*.1;
        p=mat2(vec2(cos(pitch),sin(pitch)),vec2(-sin(pitch),cos(pitch)))*p;
    }
    p+=pose_offset;
    sand_y=p.y;
    VERTEX=p;
}
void fragment() {
    float alpha=texture(TEXTURE,UV).a;
    if (alpha<.86) discard;
    COLOR.a *= smoothstep(.86,.97,alpha)/max(alpha,.001);
    if (clip_sand && sand_y>0.) discard;
}
