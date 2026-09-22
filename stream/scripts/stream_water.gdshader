shader_type canvas_item;
uniform float water_clock = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	// One source texel of lateral plant sway; the sand and contact plane stay fixed.
	float bank = smoothstep(0.24, 0.49, abs(uv.x - 0.5));
	float rooted = 1.0 - smoothstep(0.45, 0.79, uv.y);
	float ripple = sin(water_clock * 0.38 + uv.y * 13.0) + 0.35 * sin(water_clock * 0.61 + uv.y * 25.0);
	uv.x += floor(ripple * bank * rooted * 1.2 + 0.5) / 640.0;
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	float surface = 1.0 - smoothstep(0.045, 0.14, UV.y);
	float glint = sin(UV.x * 49.0 - water_clock * 0.32) * surface * 0.012;
	c.rgb += vec3(0.65, 0.85, 0.72) * glint;
	COLOR = c * vertex_tint;
}
