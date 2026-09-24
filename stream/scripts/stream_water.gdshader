shader_type canvas_item;
uniform float water_clock = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	// Reef rocks, burrows and grazing contact surfaces stay fixed.
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	float surface = 1.0 - smoothstep(0.045, 0.14, UV.y);
	float glint = sin(UV.x * 49.0 - water_clock * 0.32) * surface * 0.012;
	c.rgb += vec3(0.65, 0.85, 0.72) * glint;
	COLOR = c * vertex_tint;
}
