shader_type canvas_item;
// Newly generated ingredient art has a soft exterior alpha halo. Clip only
// those marked textures at display time, preserving all original PNG bytes.
varying vec4 art_modulate;
void vertex() {
	art_modulate = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	source.a = step(0.94, source.a);
	COLOR = source * art_modulate;
}
