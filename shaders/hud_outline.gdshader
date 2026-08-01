shader_type canvas_item;

// White rim for HUD artwork drawn on transparency: the health orbs
// (scenes/hp_1.tscn) and the corner logo in main.tscn / boss_room.tscn. Both are dark
// linework on alpha, so they dissolve into the dark end of the city backdrop and into
// their own drop shadows. This dilates the sprite's alpha outward and paints the halo
// white, which also keeps the orbs' three damage stages legible from each other at
// 40px — losing an orbit ring reads much faster when every ring is outlined.
//
// Labels can NOT use this shader. A Label's TEXTURE is the font atlas and each glyph
// quad's UV is a small region inside it, so dilating the UV samples whatever glyph
// happens to be packed alongside. Outline text with the built-in
// `theme_override_constants/outline_size` + `font_outline_color` instead — that's what
// the "HP " label does.
//
// `width` is in UV, NOT texels, on purpose: the source PNGs are ~1456px square but the
// orbs draw at 40px, so a TEXTURE_PIXEL_SIZE-based width would be far too small to
// see. It measures along the sprite's WIDTH; the vertical radius is derived below so
// the rim stays round on non-square art.
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.0, 0.2, 0.005) = 0.02;

// Shrinks the artwork inside its own rect, in [0,1], to make room for the rim. The
// halo can only be drawn on fragments the node actually rasterises, so art that runs
// to the edge of its texture (the corner logo has ~1.4% of margin top and bottom) gets
// its rim clipped off. 1.0 = no inset, which is what the square orbs use — they have
// plenty of transparent margin already.
uniform float art_scale : hint_range(0.5, 1.0, 0.005) = 1.0;

// Rays sampled around each pixel. 16 is where the corners of the atom's orbit lines
// stop looking chewed; more is just fill rate on a 40px sprite.
const int SAMPLES = 16;
const float TAU_ = 6.28318530718;

void fragment() {
	// Vertex colour, i.e. the node's modulate * self_modulate. It has to be captured
	// and re-applied at the end: writing COLOR outright would otherwise throw it away,
	// which silently killed the HUD's damage/pickup flashes (scripts/health_container.gd).
	vec4 tint = COLOR;

	// Equal rim thickness on both axes. A UV step costs a different number of screen
	// pixels horizontally and vertically whenever the art isn't square, so the vertical
	// radius is scaled by the texture's aspect (TEXTURE_PIXEL_SIZE is 1/size, hence
	// y/x == width/height). Square art leaves this at 1.0 and nothing changes; the
	// 794x500 logo would otherwise get a rim 1.6x fatter above and below than beside.
	// Assumes the node draws the texture at its native aspect — both users are
	// TextureRects on STRETCH_KEEP_ASPECT_CENTERED.
	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	vec2 radius = vec2(width, width * aspect);
	float inv_scale = 1.0 / art_scale;

	// The sampling below is deliberately written out twice rather than pulled into a
	// helper: Godot's shader compiler cannot take a built-in sampler like TEXTURE as a
	// user function argument (it errors out on custom_samplers and emits broken code).
	//
	// Both samples read the artwork INSET by art_scale, and force anything landing
	// outside the texture to fully transparent instead of letting it clamp to the edge
	// texel — otherwise the inset margin would just be the logo's outermost row of
	// pixels smeared outward. Masked with step() rather than an if, so the texture
	// fetch stays in uniform control flow.
	vec2 art_uv = (UV - vec2(0.5)) * inv_scale + vec2(0.5);
	vec2 art_in = step(vec2(0.0), art_uv) * step(art_uv, vec2(1.0));
	vec4 col = texture(TEXTURE, clamp(art_uv, vec2(0.0), vec2(1.0))) * (art_in.x * art_in.y);

	// Alpha dilation: a transparent pixel joins the halo if ANY neighbour within
	// `radius` is opaque.
	float ring = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		float ang = TAU_ * float(i) / float(SAMPLES);
		vec2 uv = (UV + vec2(cos(ang), sin(ang)) * radius - vec2(0.5)) * inv_scale + vec2(0.5);
		vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
		float a = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))).a * inside.x * inside.y;
		ring = max(ring, a);
	}

	// Keep the artwork wherever it is opaque and let the halo fill in behind it, so
	// the outline surrounds the orb instead of eating into it.
	vec4 halo = vec4(outline_color.rgb, outline_color.a * ring);
	COLOR = mix(halo, col, col.a) * tint;
}
