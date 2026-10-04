// The EndCard's backdrop: drains the colour out of the frozen level (`grey`) and
// darkens it under the card (`dim` x `tint`). A death tweens grey 0 -> 1 before the
// card shows; a win keeps the colour (grey 0) and only dims.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.08, 0.08, 0.08, 0.5);

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(c, vec3(luma), grey);
	COLOR = vec4(mix(col, tint.rgb, tint.a * dim), 1.0);
}
