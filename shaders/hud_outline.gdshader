shader_type canvas_item;

// White rim for the HUD health orbs (scenes/hp_1.tscn). The orb art
// (images/Logo+Web*.png) is black linework on transparency, so it dissolves into the
// dark end of the city backdrop and into its own drop shadow. This dilates the
// sprite's alpha outward and paints the halo white, which also keeps the three damage
// stages legible from each other at 40px — losing an orbit ring reads much faster
// when every ring is outlined.
//
// `width` is in UV, NOT texels, on purpose: the source PNGs are ~1456px square but
// draw at 40px in the HBoxContainer, so a TEXTURE_PIXEL_SIZE-based width would be
// far too small to see. 0.02 == 2% of the orb.
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.0, 0.2, 0.005) = 0.02;

// Rays sampled around each pixel. 16 is where the corners of the atom's orbit lines
// stop looking chewed; more is just fill rate on a 40px sprite.
const int SAMPLES = 16;
const float TAU_ = 6.28318530718;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Alpha dilation: a transparent pixel joins the halo if ANY neighbour within
	// `width` is opaque. Sampling past the UV edge clamps to the art's transparent
	// margin, so the rim never wraps around to the far side of the orb.
	float ring = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		float ang = TAU_ * float(i) / float(SAMPLES);
		ring = max(ring, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * width).a);
	}

	// Keep the artwork wherever it is opaque and let the halo fill in behind it, so
	// the outline surrounds the orb instead of eating into it.
	vec4 halo = vec4(outline_color.rgb, outline_color.a * ring);
	COLOR = mix(halo, col, col.a);
}
