shader_type canvas_item;
// H5 review-only shader. Production reef_motion.gdshader is untouched.
uniform bool den_clip = false;
uniform vec2 den_point = vec2(0.);
uniform float den_side = 1.;
uniform vec2 extent = vec2(100.,60.);
uniform float body_line = 0.5;
uniform float phase = 0.;
uniform float effort = 0.;
uniform float facing = 1.;
uniform float bite = 0.;
uniform float fin_open = 1.;
uniform float pitch = 0.;
uniform vec2 pose_offset = vec2(0.);
uniform bool eel = false;
uniform bool upright = false;
uniform float clasp = 0.;
uniform vec2 grip = vec2(0.);
uniform float extension = 1.;
uniform bool clip_sand = false;
uniform float fin_ray = 0.;
uniform float sleep_amount = 0.;
uniform vec2 pectoral_root = vec2(.74,.58);
uniform vec2 pectoral_span = vec2(.2,.25);
uniform float pectoral_drive = 1.;
uniform float pectoral_phase = 0.;
uniform float breath_phase = 0.;
uniform float tail_drive = 0.;
uniform float roll = 0.;
uniform float ray_flick = 0.;
uniform float eye_scan = 0.;
uniform bool blenny = false;
uniform float curious = 0.;
uniform vec2 eye_anchor = vec2(.9,.35);
uniform vec4 atlas_region = vec4(0.,0.,1.,1.);
uniform bool portal = false;
uniform float portal_radius = 21.;
uniform float portal_fold = 0.;
uniform float grounded_graze = 0.;
varying float sand_y;
varying vec2 local_point;
void vertex() {
    vec2 p = VERTEX;
    mat4 to_canvas = CANVAS_MATRIX * MODEL_MATRIX;
    vec2 rest_point=vec2(p.x/extent.x+.5,p.y/extent.y+body_line);
    if (eel) {
        p.y += (1. - extension) * extent.y;
        float height = clamp(-p.y/extent.y, 0., 1.);
        p.x *= facing;
        p.x += (sin(phase * .42 - height * 1.6) * 6. + facing * 7.) * height * height;
        p.x += bite * 3. * height * height;
    } else if (upright) {
        // Upright seahorse: dorsal fan, with a quiet whole-body sway about its
        // curled tail while clasped. Never run a horizontal fish tail wave.
        float dorsal = (1.-smoothstep(.10,.32,rest_point.x)) *
                       (1.-smoothstep(.10,.24,abs(rest_point.y-.49)));
        p.x += sin(pectoral_phase*2.) * dorsal * .7 * pectoral_drive;
        // Unclasp the lower curl a little while drifting; fixed grip when held.
        float release=(1.-clasp)*smoothstep(.78,.98,rest_point.y)*smoothstep(3.,8.,distance(p,grip));
        p.x+=release*2.5;
        p.y+=release*1.5;
        p.x*=facing;
        vec2 hinge=vec2(grip.x*facing,grip.y);
        p=hinge+mat2(vec2(cos(pitch),sin(pitch)),vec2(-sin(pitch),cos(pitch)))*(p-hinge);
    } else {
        float tail = clamp(.5 - p.x/extent.x, 0., 1.);
        float fin = smoothstep(0.08, 0.32, abs(p.y)/extent.y);
        float body_drive = (tail_drive * 2.8) * (1. - sleep_amount*.8);
        p.y += sin(phase - tail*4.4) * body_drive * tail*tail;
        // A quiet, slow breath keeps coasting alive without adding jitter.
        // Whole-body breathing is continuous; no subpixel gill/eye mesh distortion.
        // Fin base stays attached; only the outer fan and caudal membrane flex.
        p.y += sin(phase*1.17-tail*3.8)*(effort*.6)*fin;
        p.y *= 1. + (fin_open-1.) * fin;
        // Firefish tall first dorsal ray bends progressively away from its base.
        float ray = (1.-smoothstep(.05,.51,rest_point.y))*smoothstep(.35,.7,rest_point.x) * fin_ray;
        p.x += sin(phase*.43)*ray*effort*3.+ray*ray_flick*8.;
        vec2 atlas_point=rest_point;
        // Tuck the lower pectoral fan toward its attached root during substrate grazing.
        // The body stays above the bed instead of clipping away the extended fin.
        float planted_fin=smoothstep(.58,.76,atlas_point.y)*smoothstep(.51,.62,atlas_point.x)*(1.-smoothstep(.85,.91,atlas_point.x));
        p.y=mix(p.y,min(p.y,extent.y*.08),planted_fin*grounded_graze*.8);
        vec2 fin_delta=(atlas_point-pectoral_root)/pectoral_span;
        float pectoral=(1.-smoothstep(.5,1.,length(fin_delta)))*max(0.,-fin_delta.x);
        p.y+=sin(pectoral_phase)*pectoral*2.2*pectoral_drive;
        p.x+=cos(pectoral_phase)*pectoral*.8*pectoral_drive;
        // Local operculum breathing; the eye and body silhouette remain quiet.




        float jaw = smoothstep(.72,.98,p.x/extent.x+.5) * smoothstep(-.03,.07,p.y/extent.y);
        p.y += jaw * bite * 2.0;
        p.y *= 1. - portal_fold*.70*fin;
        // Flip the complete side drawing in one frame, with no turn deformation.
        p.x += sin(roll)*p.y*.25;
        p.x *= facing;
        p.y *= cos(roll);
        p=mat2(vec2(cos(pitch),sin(pitch)),vec2(-sin(pitch),cos(pitch)))*p;
    }
    p+=pose_offset;
    sand_y=p.y;
    local_point=p;
    // Snap the shared pivot without changing simulation positions or deforming
    // individual mesh vertices. Mirroring leaves this pivot unchanged.
    vec2 pivot = (to_canvas * vec4(pose_offset, 0., 1.)).xy;
    vec2 correction = floor(pivot) + vec2(.5) - pivot;
    p += inverse(mat2(to_canvas[0].xy, to_canvas[1].xy)) * correction;
    VERTEX=p;
}
void fragment() {
    vec4 texel=texture(TEXTURE,UV);
    float alpha=texel.a;
    // Move only the highlight by one native atlas cell inside the blenny's dark eye.
    vec2 ap=(UV/TEXTURE_PIXEL_SIZE-atlas_region.xy)/atlas_region.zw;
    if (blenny && eye_scan>.5 && distance(ap,eye_anchor)<.032) {
        vec2 source=UV+vec2(12.*TEXTURE_PIXEL_SIZE.x,0.);
        vec4 moved=texture(TEXTURE,source);
        if (max(texel.r,max(texel.g,texel.b))<.22 || min(texel.r,min(texel.g,texel.b))>.82) {
            COLOR.rgb=moved.rgb;
        }
    }
    // Quiet breathing changes a whole color cluster, not the position of a single texel.
    float gill_patch=(1.-step(.07,abs(ap.x-(pectoral_root.x+.09))))*(1.-step(.10,abs(ap.y-body_line)));
    COLOR.rgb*=1.+gill_patch*sin(breath_phase*.45)*.025;
    float eye_patch=1.-step(.027,distance(ap,eye_anchor));
    COLOR.rgb=mix(COLOR.rgb,COLOR.rgb*1.10,eye_patch*curious);
    if (alpha<.86) discard;
    COLOR.a *= smoothstep(.86,.97,alpha)/max(alpha,.001);
    if (den_clip && (local_point.x-den_point.x)*den_side<0.) discard;
    if (clip_sand && sand_y>0.) discard;
    if (portal && abs(local_point.x)<portal_radius && local_point.y>2.) discard;
}
