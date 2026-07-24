/*
	VHS and CRT monitor effect — full-screen post-process adaptation.

	Based on "VHS and CRT monitor effect 2" by A7meD (Godot 4 screen-texture
	port): https://godotshaders.com/shader/vhs-and-crt-monitor-effect-2/
	which is itself based on "VHS and CRT monitor effect" by pend00:
	https://godotshaders.com/shader/vhs-and-crt-monitor-effect/
	Original license: CC0 — "can be used freely without the author's
	permission". This adaptation is also CC0.

	Adapted for the AtomicRobot project (1280x800, GL Compatibility,
	Web/HTML5 export, pixel art at 2.5x zoom):
	- Always samples the screen (SCREEN_UV); the original's `overlay` UV/
	  SCREEN_UV switch and `clip_warp` alpha cutout were removed — on an
	  opaque full-screen ColorRect a transparent border would just reveal
	  the un-warped game underneath. The border is always opaque black.
	- ALL animation is driven by `unscaled_time`, NOT the built-in TIME:
	  this project freezes Engine.time_scale during hit-pause, which freezes
	  TIME in canvas shaders. An integration autoload MUST feed this uniform
	  every frame (e.g. material.set_shader_parameter("unscaled_time", t)
	  with t accumulated from unscaled delta). If never fed, the effect
	  renders frozen at t = 0 but is otherwise correct.
	- Defaults tuned subtle for gameplay readability (low distortion, mild
	  noise, discolor off). Crank them for title cards / cutscenes.
	- Texture reads unified into a single unconditional path (uniform
	  control flow, safe for WebGL2 implicit-derivative mip selection).
	- unscaled_time is wrapped with mod() before use so sin()/fract() keep
	  precision during long play sessions.

	Web/WebGL2 audit: no derivatives, no textureLod, no switch/const-array
	dynamic indexing, no reversed-edge smoothstep, no non-constant loops,
	explicit float literals throughout. Safe for GLES3 / WebGL2 / ANGLE.
*/
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

/**
	REQUIRED time source — see header. Feed real (unscaled) seconds every
	frame from an autoload; do not rely on TIME (frozen during hit-pause).
*/
uniform float unscaled_time = 0.0;

/**
	Virtual CRT grid. 512x320 matches the game-pixel grid at 2.5x zoom on
	the 1280x800 viewport (one scanline per art pixel row).
*/
uniform vec2 resolution = vec2(512.0, 320.0);

/** Snap sampling to the virtual grid (also sizes the static-noise grain). */
uniform bool pixelate = true;

/** Scanline darkness (0 = off) and line thickness. */
uniform float scanlines_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float scanlines_width : hint_range(0.0, 0.5) = 0.25;

/** Vertical RGB grille strength (0 = off). */
uniform float grille_opacity : hint_range(0.0, 1.0) = 0.2;

/** VHS tracking roll: master toggle, speed, band size/variation, and how
	far the bands displace the image horizontally (keep low for gameplay). */
uniform bool roll = true;
uniform float roll_speed = 8.0;
uniform float roll_size : hint_range(0.0, 100.0) = 15.0;
uniform float roll_variation : hint_range(0.1, 5.0) = 1.8;
uniform float distort_intensity : hint_range(0.0, 0.2) = 0.015;

/** Rolling tape noise (bright band sparkle) and uniform static grain. */
uniform float noise_opacity : hint_range(0.0, 1.0) = 0.15;
uniform float noise_speed = 5.0;
uniform float static_noise_intensity : hint_range(0.0, 1.0) = 0.04;

/**
	Horizontal chromatic aberration. Effective UV offset is aberration * 0.1,
	so 0.015 is about 2 native pixels at 1280 wide — subtle.
*/
uniform float aberration : hint_range(-1.0, 1.0) = 0.015;

/** Brightness compensation for scanline/grille darkening. */
uniform float brightness = 1.2;

/**
	VHS color wash: 50% desaturation + contrast boost. Off by default —
	it flattens the pixel-art palette. Nice for flashbacks/cutscenes.
*/
uniform bool discolor = false;

/**
	Barrel curvature of the virtual tube. Default 0.0 (off) — gameplay
	readability first; 0.5–1.0 gives the classic bulge. The rounded black
	border scales with it automatically.
*/
uniform float warp_amount : hint_range(0.0, 5.0) = 0.0;

/** Corner darkening. */
uniform float vignette_intensity = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.4;

vec2 random(vec2 uv) {
	uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv) {
	vec2 uv_index = floor(uv);
	vec2 uv_fract = fract(uv);
	vec2 blur = smoothstep(vec2(0.0), vec2(1.0), uv_fract);

	return mix(
		mix(dot(random(uv_index + vec2(0.0, 0.0)), uv_fract - vec2(0.0, 0.0)),
			dot(random(uv_index + vec2(1.0, 0.0)), uv_fract - vec2(1.0, 0.0)), blur.x),
		mix(dot(random(uv_index + vec2(0.0, 1.0)), uv_fract - vec2(0.0, 1.0)),
			dot(random(uv_index + vec2(1.0, 1.0)), uv_fract - vec2(1.0, 1.0)), blur.x),
		blur.y
	) * 0.5 + 0.5;
}

vec2 warp(vec2 uv) {
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta.xy, delta.xy);
	float delta4 = delta2 * delta2;
	float delta_offset = delta4 * warp_amount;
	return uv + delta * delta_offset;
}

// Rounded-rectangle mask that hides the warped image's curved edge.
float border(vec2 uv) {
	float radius = min(warp_amount, 0.08);
	radius = max(min(min(abs(radius * 2.0), abs(1.0)), abs(1.0)), 1e-5);
	vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0, 1.0) + radius;
	float dist = length(max(vec2(0.0), abs_uv)) / radius;
	float square = smoothstep(0.96, 1.0, dist);
	return clamp(1.0 - square, 0.0, 1.0);
}

float vignette(vec2 uv) {
	uv *= 1.0 - uv.xy;
	float vig = uv.x * uv.y * 15.0;
	return pow(vig, vignette_intensity * vignette_opacity);
}

void fragment() {
	// Wrapped time source (NOT the built-in TIME — see header). The mod()
	// keeps sin()/fract() arguments small during long sessions; the hourly
	// wrap seam is imperceptible in noise.
	float t = mod(unscaled_time, 3600.0);

	vec2 uv = warp(SCREEN_UV);
	vec2 text_uv = uv;
	float time = roll ? t : 0.0;

	if (pixelate) {
		text_uv = ceil(uv * resolution) / resolution;
	}

	// VHS tracking bands (also feeds the rolling tape noise below).
	float roll_line = 0.0;
	vec2 roll_uv = vec2(0.0);
	if (roll || noise_opacity > 0.0) {
		roll_line = smoothstep(0.3, 0.9, sin(uv.y * roll_size - (time * roll_speed)));
		roll_line *= roll_line * smoothstep(0.3, 0.9,
			sin(uv.y * roll_size * roll_variation - (time * roll_speed * roll_variation)));
		if (roll) {
			roll_uv = vec2(roll_line * distort_intensity * (1.0 - SCREEN_UV.x), 0.0);
		}
	}

	// Single unconditional sample path (roll_uv is zero when roll is off),
	// keeping all texture reads in uniform control flow for WebGL2.
	vec4 text;
	text.r = texture(SCREEN_TEXTURE, text_uv + roll_uv * 0.8 + vec2(aberration, 0.0) * 0.1).r;
	text.g = texture(SCREEN_TEXTURE, text_uv + roll_uv * 1.2 - vec2(aberration, 0.0) * 0.1).g;
	text.b = texture(SCREEN_TEXTURE, text_uv + roll_uv).b;
	text.a = 1.0;

	float r = text.r;
	float g = text.g;
	float b = text.b;

	// Vertical RGB grille (phase-offset sine stripes per channel).
	if (grille_opacity > 0.0) {
		float g_r = smoothstep(0.85, 0.95, abs(sin(uv.x * (resolution.x * 3.14159265))));
		r = mix(r, r * g_r, grille_opacity);

		float g_g = smoothstep(0.85, 0.95, abs(sin(1.05 + uv.x * (resolution.x * 3.14159265))));
		g = mix(g, g * g_g, grille_opacity);

		float b_b = smoothstep(0.85, 0.95, abs(sin(2.1 + uv.x * (resolution.x * 3.14159265))));
		b = mix(b, b * b_b, grille_opacity);
	}

	text.r = clamp(r * brightness, 0.0, 1.0);
	text.g = clamp(g * brightness, 0.0, 1.0);
	text.b = clamp(b * brightness, 0.0, 1.0);

	// Scanlines.
	float scanlines = 0.5;
	if (scanlines_opacity > 0.0) {
		scanlines = smoothstep(scanlines_width, scanlines_width + 0.5,
			abs(sin(uv.y * (resolution.y * 3.14159265))));
		text.rgb = mix(text.rgb, text.rgb * vec3(scanlines), scanlines_opacity);
	}

	// Rolling tape noise riding on the tracking bands.
	if (noise_opacity > 0.0) {
		float n = smoothstep(0.4, 0.5,
			noise(uv * vec2(2.0, 200.0) + vec2(10.0, t * noise_speed)));
		roll_line *= n * scanlines * clamp(
			random((ceil(uv * resolution) / resolution) + vec2(t * 0.8, 0.0)).x + 0.8,
			0.0, 1.0);
		text.rgb = clamp(mix(text.rgb, text.rgb + roll_line, noise_opacity),
			vec3(0.0), vec3(1.0));
	}

	// Uniform static grain.
	if (static_noise_intensity > 0.0) {
		text.rgb += clamp(
			random((ceil(uv * resolution) / resolution) + fract(t)).x,
			0.0, 1.0) * static_noise_intensity;
	}

	text.rgb *= border(uv);
	text.rgb *= vignette(uv);

	// Optional VHS color wash (off by default — flattens pixel-art colors).
	if (discolor) {
		float saturation = 0.5;
		float contrast = 1.2;
		vec3 greyscale = vec3(text.r + text.g + text.b) / 3.0;
		text.rgb = mix(text.rgb, greyscale, saturation);

		float midpoint = pow(0.5, 2.2);
		text.rgb = (text.rgb - vec3(midpoint)) * contrast + midpoint;
	}

	COLOR = text;
}
