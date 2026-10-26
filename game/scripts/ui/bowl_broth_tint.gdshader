shader_type canvas_item;
// Palette adjustment of the generated soup pixels only; ceramic and independent
// topping sprites retain their original colors. uv_region accounts for AtlasTexture.
uniform vec4 uv_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 broth_shift = vec3(0.0);
// New generated cutout has translucent exterior glow. Clip its display only;
// original sprites and source PNG alpha are preserved with the default0.
uniform float sprite_alpha_cutoff = 0.0;
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	if (sprite_alpha_cutoff > 0.0) {
		sample_color.a = step(sprite_alpha_cutoff, sample_color.a);
	}
	vec2 local_uv = (UV - uv_region.xy) / uv_region.zw;
	vec2 ellipse = (local_uv - vec2(0.50, 0.40)) / vec2(0.43, 0.30);
	float soup = 1.0 - smoothstep(0.90, 1.0, dot(ellipse, ellipse));
	float pale = 1.0 - smoothstep(0.22, 0.48, sample_color.r - sample_color.b);
	sample_color.rgb = clamp(sample_color.rgb + broth_shift * soup * pale, vec3(0.0), vec3(1.0));
	COLOR = sample_color * COLOR;
}
