shader_type canvas_item;

// Hit flash. Driven by the "Hit" AnimationPlayer track on the player and on every
// enemy (NodePath ".../material:shader_parameter/flash_value"), so these two uniform
// NAMES are load-bearing — renaming them silently breaks every hit reaction in the
// game. Behaviour below is byte-for-byte the original when buff_value is 0.
uniform vec4 flash_color : source_color;
uniform float flash_value : hint_range(0.0, 1.0, 0.1) = 0;

// --- Power-up overlay (scripts/autoload/powerup_system.gd) -------------------
//
// Deliberately screen-space, not UV-space. The character SpriteFrames are
// AtlasTexture regions packed into one sheet, so anything that offsets or quantises
// UV (a neighbour-sampled outline, a UV-space pixelate) reads a NEIGHBOURING FRAME
// and smears the wrong animation frame across the sprite. FRAGCOORD has no such
// problem and gives the chunky look we actually want.

// Palette the buff shifts the character toward, and the master 0..1 strength
// (PowerupRules.ramp_strength fades this in/out so a buff never pops on or off).
uniform vec4 buff_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float buff_value : hint_range(0.0, 1.0) = 0.0;
// Throb rate in Hz. 0 = steady.
uniform float buff_pulse_hz = 0.0;
// Screen pixels per dither cell. 0 = solid tint with no cell grid.
uniform float buff_pixel_size = 0.0;
// How much of the cell grid shows through (0 = solid tint, 1 = full checkerboard).
uniform float buff_dither : hint_range(0.0, 1.0) = 0.0;

const float TAU_ = 6.28318530718;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	vec4 col = mix(texture_color, flash_color, flash_value);

	if (buff_value > 0.0) {
		float pulse = 1.0;
		if (buff_pulse_hz > 0.0) {
			pulse = 0.5 + 0.5 * sin(TIME * buff_pulse_hz * TAU_);
		}

		// Chunky checkerboard in screen space so the buff reads as pixels rather
		// than an airbrushed glow. Cells stay put on screen while the character
		// moves through them, which is what makes it look like an effect layer
		// over the sprite instead of a repaint of it.
		float cell = 1.0;
		if (buff_pixel_size > 0.0) {
			vec2 grid = floor(FRAGCOORD.xy / buff_pixel_size);
			float checker = mod(grid.x + grid.y, 2.0);
			cell = mix(1.0, checker, buff_dither);
		}

		// Never let the tint drop to nothing at the bottom of the pulse — the
		// character should stay visibly buffed for the whole duration, it should
		// just breathe.
		float amount = buff_value * mix(0.4, 1.0, pulse) * cell;
		col.rgb = mix(col.rgb, buff_color.rgb, amount);
		// A touch of additive lift on the bright half of the pulse so it energises
		// rather than just recolours.
		col.rgb += buff_color.rgb * amount * pulse * 0.25;
	}

	COLOR = col;
	COLOR.a = texture_color.a;
}
