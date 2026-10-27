shader_type canvas_item;
// Palette adjustment of the generated soup pixels only; ceramic and independent
// topping sprites retain their original colors. uv_region accounts for AtlasTexture.
uniform vec4 uv_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 broth_shift = vec3(0.0);
// New generated cutout has translucent exterior glow. Clip its display only;
// original sprites and source PNG alpha are preserved with the default0.
uniform float sprite_alpha_cutoff = 0.0;
// Crafted-recipe branch. appearance == 0.0 (default) runs the exact legacy path.
uniform float appearance = 0.0;
uniform vec3 broth_color : source_color = vec3(0.55, 0.33, 0.12);
uniform float broth_strength = 0.0;
uniform float milk = 0.0;
uniform vec3 oil_color : source_color = vec3(1.0);
uniform float oil_amount = 0.0;
uniform vec3 noodle_color : source_color = vec3(0.93, 0.78, 0.40);
uniform float noodle_strength = 0.0;
// Fragment COLOR already includes TEXTURE. Carry the vertex tint separately
// so an authored creamy/green soup is not multiplied by orange texture again.
// The historical branch deliberately retains its accepted old pixel formula.
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	if (sprite_alpha_cutoff > 0.0) {
		sample_color.a = step(sprite_alpha_cutoff, sample_color.a);
	}
	vec2 local_uv = (UV - uv_region.xy) / uv_region.zw;
	vec2 ellipse = (local_uv - vec2(0.50, 0.40)) / vec2(0.43, 0.30);
	float radius2 = dot(ellipse, ellipse);
	// Historical soup shift; broth_shift is zero when a raw broth recipe replaces it,
	// and a raw-noodle-only bowl keeps it beneath the noodle expression.
	float pale = 1.0 - smoothstep(0.22, 0.48, sample_color.r - sample_color.b);
	float soup = 1.0 - smoothstep(0.90, 1.0, radius2);
	vec3 legacy_rgb = clamp(sample_color.rgb + broth_shift * soup * pale, vec3(0.0), vec3(1.0));
	if (appearance > 0.0) {
		// Masks: the source soup is orange-brown (luma ~0.3-0.6, green/red ~0.45-0.7)
		// and the gold noodles are brighter (luma > ~0.62). The red ceramic is told
		// apart by a low green/red ratio, not by r-g (orange soup has a large r-g
		// too, which an earlier guard wrongly excluded). The ellipse keeps the rim.
		// Recoloring multiplies by the pixel's own luminance so strands, ripples
		// and shading survive instead of becoming a flat wash.
		vec3 src = sample_color.rgb;
		float luma = dot(src, vec3(0.299, 0.587, 0.114));
		float inside = 1.0 - smoothstep(0.84, 1.0, radius2);
		float guard = smoothstep(0.26, 0.40, src.g / max(src.r, 0.001));
		float noodle_part = smoothstep(0.60, 0.72, luma);
		float noodle_mask = inside * guard * noodle_part;
		float soup_mask = inside * guard * (1.0 - noodle_part);
		float detail = clamp(luma / 0.45, 0.55, 1.5);
		vec3 soup_target = broth_color * detail;
		// Emulsified (creamy) soups lift toward an opaque pale tone.
		soup_target = mix(soup_target, vec3(0.96, 0.89, 0.76) * clamp(detail, 0.8, 1.25), milk * 0.7);
		vec3 rgb = mix(legacy_rgb, soup_target, min(broth_strength * 1.15, 1.0) * soup_mask);
		vec3 noodle_target = noodle_color * clamp(luma / 0.78, 0.6, 1.4);
		rgb = mix(rgb, noodle_target, noodle_strength * noodle_mask);
		// Oil: a glaze toward the bowl edge plus fixed pixel-aligned droplets, on the
		// soup only and deterministic per cell. Both keep the soup's own shading.
		float oil_on = step(0.001, oil_amount);
		float ring = smoothstep(0.30, 0.75, radius2) * (1.0 - smoothstep(0.88, 1.0, radius2));
		rgb = mix(rgb, oil_color * clamp(detail, 0.7, 1.3), oil_amount * 0.45 * ring * soup_mask * oil_on);
		vec2 grid = local_uv * vec2(26.0, 17.0);
		vec2 cell = floor(grid);
		vec2 f = fract(grid) - 0.5;
		float present = step(1.0 - oil_amount * 0.8, hash(cell + 7.0));
		float disc = step(length(f), 0.20 + 0.25 * hash(cell));
		float shine = 0.9 + 0.4 * step(0.0, -f.x - f.y);
		rgb = mix(rgb, clamp(oil_color * shine, 0.0, 1.0), 0.9 * present * disc * soup_mask * oil_on);
		float authored = max(step(0.001, broth_strength) * soup_mask,
			step(0.001, noodle_strength) * noodle_mask);
		vec3 rendered = mix(legacy_rgb * src.rgb, rgb, authored);
		COLOR = vec4(rendered * vertex_tint.rgb, sample_color.a * COLOR.a);
	} else {
		sample_color.rgb = legacy_rgb;
		COLOR = sample_color * COLOR;
	}
}
