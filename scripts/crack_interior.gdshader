shader_type canvas_item;

// Secret wall hole interior (scripts/crack.gd). The crack sheet is a flat black
// silhouette; once the wall is open its inside reads as a dark cavity with a warm
// glow where the orb waits, ringed by the original black edge.

uniform float open = 0.0;
// UV rect (x, y, w, h) of the open frame inside the atlas.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.06, 0.04, 0.05, 1.0);
uniform vec4 deep_color : source_color = vec4(0.17, 0.12, 0.16, 1.0);
uniform vec4 glow_color : source_color = vec4(0.85, 0.52, 0.2, 1.0);
uniform float rim_px = 2.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (open > 0.5 && c.a > 0.5) {
		vec2 d = TEXTURE_PIXEL_SIZE * rim_px;
		float edge = min(min(texture(TEXTURE, UV + vec2(d.x, 0.0)).a, texture(TEXTURE, UV - vec2(d.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, d.y)).a, texture(TEXTURE, UV - vec2(0.0, d.y)).a));
		vec2 local = (UV - region.xy) / region.zw;
		float r = length((local - vec2(0.5, 0.5)) * vec2(1.4, 1.0));
		float glow = smoothstep(0.42, 0.0, r);
		vec3 inside = mix(deep_color.rgb, glow_color.rgb, glow * 0.75);
		// Faint brick courses inside the cavity so it reads as depth, not paint.
		float course = step(0.82, fract(local.y * 7.0)) * 0.25 * (1.0 - glow);
		inside = mix(inside, rim_color.rgb, course);
		COLOR = vec4(mix(rim_color.rgb, inside, step(0.5, edge)), c.a);
	} else {
		COLOR = c;
	}
}
