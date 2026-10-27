extends Control
## 이미지 원본의 그릇과 각 분량을 별도 레이어로 합성한다. 중복 분량도 별도 노드다.
const Catalog = preload("res://scripts/domain/ingredient_catalog.gd")
const Art = preload("res://scripts/ui/bowl_editor_art.gd")
const MockArt = preload("res://scripts/ui/mock_fidelity_art.gd")
const Appearance = preload("res://scripts/ui/recipe_appearance.gd")
const BrothShader =preload("res://scripts/ui/bowl_broth_tint.gdshader")
var config: Dictionary = {}
## Non-empty when the applied config's raw recipe could not be expressed.
var appearance_error: String = ""
var _base: TextureRect
var _portions: Array[TextureRect] = []
var _steam: Array[TextureRect] = []
var _steam_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base = _texture("LayeredBowlBase")
	for index in 3:
		var wisp := _texture("Steam_%d" % index)
		wisp.texture = Art.food("steam-wisp")
		_steam.append(wisp)
	resized.connect(_arrange)
	if not config.is_empty():
		set_config(config)


func _texture(node_name: String) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(image)
	return image


func set_config(value: Dictionary) -> void:
	config = value.duplicate(true)
	if _base == null:
		return
	var noodle: String = str(config.get("noodle", "noodle_thin"))
	_base.texture = MockArt.bowl(noodle)
	var palette := ShaderMaterial.new()
	palette.shader = BrothShader
	palette.set_shader_parameter("sprite_alpha_cutoff",0.94 if noodle=="noodle_buckwheat" else 0.0)
	var atlas: AtlasTexture = _base.texture as AtlasTexture
	if atlas != null:
		var source_size: Vector2 = atlas.atlas.get_size()
		palette.set_shader_parameter("uv_region", Vector4(atlas.region.position.x / source_size.x, atlas.region.position.y / source_size.y, atlas.region.size.x / source_size.x, atlas.region.size.y / source_size.y))
	var shifts: Dictionary = {"broth_tonkotsu": Vector3.ZERO, "broth_chicken": Vector3(0.0, -0.08, -0.15), "broth_dashi": Vector3(-0.08, -0.12, -0.15), "broth_clam": Vector3(-0.02, 0.0, 0.04), "broth_roasted_sardine": Vector3(-0.15, -0.17, -0.16)}
	var shift: Vector3 = shifts.get(str(config.get("broth", "broth_tonkotsu")), Vector3.ZERO)
	var look: Dictionary = Appearance.profile(config)
	appearance_error = str(look["error"])
	if appearance_error != "":
		# Explicit failure: report it and draw the untouched original bowl. The
		# caller can read appearance_error; no tinted success-shaped fallback.
		push_error("Invalid recipe appearance: " + appearance_error)
		palette.set_shader_parameter("broth_shift", Vector3.ZERO)
	else:
		# The soup keeps its historical shift unless a raw broth recipe replaces it;
		# a raw noodle recipe only adds the noodle expression on top. With neither
		# raw key the shader's appearance branch stays off (exact legacy path).
		if not look["crafted"]:
			if config.get("tare", "") == "tare_miso":
				shift += Vector3(-0.03, -0.07, -0.10)
			if config.get("oil", "") == "oil_chili":
				shift += Vector3(0.06, -0.04, -0.06)
			palette.set_shader_parameter("broth_shift", shift)
		else:
			palette.set_shader_parameter("broth_shift", Vector3.ZERO)
		if look["crafted"] or look["noodle_crafted"]:
			palette.set_shader_parameter("appearance", 1.0)
			palette.set_shader_parameter("broth_color", look["broth_color"])
			palette.set_shader_parameter("broth_strength", look["broth_strength"])
			palette.set_shader_parameter("milk", look["milk"])
			palette.set_shader_parameter("oil_color", look["oil_color"])
			palette.set_shader_parameter("oil_amount", look["oil_amount"])
			palette.set_shader_parameter("noodle_color", look["noodle_color"])
			palette.set_shader_parameter("noodle_strength", look["noodle_strength"])
	_base.material = palette
	for old in _portions:
		remove_child(old)
		old.queue_free()
	_portions.clear()
	for id in Catalog.toppings_of(config):
		var portion: TextureRect = _texture("Portion_%d_%s" % [_portions.size(), id])
		portion.texture = Art.food(id)
		_portions.append(portion)
	_arrange()


func _arrange() -> void:
	if _base == null or _base.texture == null:
		return
	# Texture dimensions are integers: cast before division so a landscape bowl
	# never collapses into a square and leaves unused space in a shallow preview.
	var ratio: float = float(_base.texture.get_width()) / float(_base.texture.get_height())
	var width: float = minf(size.x, size.y * ratio)
	var bowl_size := Vector2(width, width / ratio)
	var origin: Vector2 = (size - bowl_size) * 0.5
	_base.position = origin
	_base.size = bowl_size
	# Positions follow the soup ellipse, not the transparent source canvas.
	var points: Array[Vector2] = [Vector2(0.32, 0.52), Vector2(0.65, 0.40), Vector2(0.46, 0.58), Vector2(0.70, 0.60)]
	for i in _portions.size():
		var image: TextureRect = _portions[i]
		var portion_size := Vector2(width * 0.43, bowl_size.y * 0.60)
		image.size = portion_size
		image.position = origin + bowl_size * points[i] - portion_size * 0.5
	_arrange_steam(origin, bowl_size)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _base == null:
		return
	_steam_time += delta
	_arrange_steam(_base.position, _base.size)


func _arrange_steam(origin: Vector2, bowl_size: Vector2) -> void:
	# Each original translucent wisp rises from the soup and fades at the top.
	# This is view-only animation; cooking progress and payment remain elsewhere.
	for index in _steam.size():
		var phase: float = fmod(_steam_time * 0.34 + float(index) / 3.0, 1.0)
		var wisp: TextureRect = _steam[index]
		wisp.size = Vector2(bowl_size.x * 0.07, bowl_size.y * 0.35)
		wisp.position = origin + bowl_size * Vector2(0.34 + index * 0.14, 0.10 - phase * 0.18)
		wisp.modulate.a = sin(phase * PI) * 0.32


func play_addition() -> void:
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.96
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
