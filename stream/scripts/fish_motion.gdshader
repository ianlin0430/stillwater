shader_type canvas_item;

uniform float body_width = 112.0;
uniform float body_height = 45.0;
uniform float swim_phase = 0.0;
uniform float amplitude = 1.0;
uniform float fin_spread = 1.0;
uniform float head_facing = 1.0;
uniform float tail_facing = 1.0;
uniform float fin_flutter = 0.35;
uniform float feeding = 0.0;
uniform bool soft_filaments = false;
varying vec2 local_uv;

void vertex() {
	local_uv = VERTEX / vec2(body_width, body_height) + 0.5;
	float tail = clamp(0.5 - VERTEX.x / body_width, 0.0, 1.0);
	float edge = smoothstep(0.12, 0.45, abs(VERTEX.y) / body_height);
	float fin = edge * smoothstep(0.15, 0.55, tail);
	VERTEX.y += sin(swim_phase - tail * 4.8) * amplitude * tail * tail;
	VERTEX.y *= 1.0 + (fin_spread - 1.0) * fin;
	VERTEX.y += sin(swim_phase * 1.45 + tail * 5.0) * fin_flutter * fin;
	// Each spine position projects with its own facing, so the body folds at the bend.
	// A shallow spine arc gives the turning pose volume instead of a flat fold.
	VERTEX.y += sin(tail * 3.14159) * (head_facing - tail_facing) * body_height * 0.18;
	float jaw = smoothstep(0.65, 0.95, local_uv.x) * smoothstep(0.48, 0.75, local_uv.y);
	VERTEX.y += jaw * feeding * (0.5 + 0.5 * sin(swim_phase * 2.0)) * 0.9;
	VERTEX.x *= mix(head_facing, tail_facing, tail);
}

// Thin atlas filaments alias into disconnected dots at game scale.
// The rig draws attached, continuous pixel-width rays instead.
void fragment() {
	vec4 c = COLOR;
	float luma = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	bool outside_body = local_uv.y < 0.3 || local_uv.y > 0.72;
	if (soft_filaments && outside_body && (luma < 0.35 || local_uv.x < 0.46)) {
		c.a = 0.0;
	}
	COLOR = c;
}
