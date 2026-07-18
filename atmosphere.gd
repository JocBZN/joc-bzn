extends Node

# Pas de ATMOSFERĂ — transformă lumea în noapte cyberpunk, tot din cod:
#   • CanvasModulate  → întunecă tot 2D-ul (tentă albastru-mov de noapte)
#   • PointLight2D    → o baltă de lumină care urmărește player-ul
#   • Vignette        → margini întunecate care duc ochiul spre centru
#   • WorldEnvironment→ un glow subtil (bloom) pe zonele luminoase
# Selectează nodul Atmosphere în editor ca să reglezi valorile de mai jos din Inspector.

@export var night_color := Color(0.30, 0.30, 0.48)  # cât de întuneric + ce tentă (mai mic = mai negru)
@export var light_color := Color(0.75, 0.90, 1.0)   # culoarea luminii din jurul tău (cyan)
@export var light_radius := 650.0                    # cât de mare e balta de lumină
@export var light_energy := 1.7                      # cât de puternică e lumina
@export var vignette_strength := 0.55                # cât de întunecate sunt marginile (0..1)

# --- FRUNZE care cad peste tot ecranul ---
# Imaginea `harta/Leaf Overlay.png` e o bandă de 80x16 = 5 frunze DIFERITE de 16x16
# (nu sunt cadre de animație — fiecare e altă frunză). Le decupăm cu AtlasTexture.
@export var leaves_enabled := true
@export var leaf_count := 28                  # câte frunze sunt pe ecran deodată
@export var leaf_speed_min := 35.0            # cât de repede cad (pixeli/secundă)
@export var leaf_speed_max := 85.0
@export var leaf_wind := 30.0                 # bătaia de vânt spre dreapta (negativ = spre stânga)
@export var leaf_sway := 45.0                 # cât de mult se leagănă în lateral
@export var leaf_scale_min := 2.0             # frunza e 16px, deci are nevoie de scale ca la restul artei
@export var leaf_scale_max := 3.5
@export var leaf_alpha := 0.85                # 1 = opace, mai mic = mai discrete
@export var leaf_spin := 0.9                  # cât de repede se rotesc (radiani/secundă)

const LEAF_TEX := "res://harta/Leaf Overlay.png"
const LEAF_SIZE := 16      # o celulă din bandă
const LEAF_COUNT_IN_TEX := 5

var _leaves: Array = []    # fiecare: {"sprite", "viteza", "leganat", "frecventa", "t", "rotire"}

var _light: PointLight2D
var _player: Node2D

func _ready() -> void:
	# „Lumină normală": am scos NOAPTEA (CanvasModulate întuneca tot) și LUMINA de pe player (PointLight2D).
	# Lumea rămâne luminată normal. (Dacă vrei înapoi noaptea cyberpunk, decomentează cele două linii.)
	#_setup_night()
	#_setup_light()
	_setup_vignette()
	_setup_glow()
	if leaves_enabled:
		_setup_leaves()

func _process(delta: float) -> void:
	# lumina urmărește player-ul
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and _light != null:
		_light.global_position = _player.global_position
	_update_leaves(delta)

func _setup_night() -> void:
	var cm := CanvasModulate.new()
	cm.color = night_color
	add_child(cm)

func _setup_light() -> void:
	_light = PointLight2D.new()
	_light.texture = _radial_texture(256, 1.0)
	_light.color = light_color
	_light.energy = light_energy
	_light.texture_scale = light_radius / 128.0  # textura 256px are raza ~128px
	add_child(_light)

func _setup_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3  # peste lume, sub meniuri (level up = 10, game over = 20)
	add_child(layer)
	var tr := TextureRect.new()
	tr.texture = _radial_texture(256, vignette_strength, true)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(tr)

# --- FRUNZELE ---
# Stau pe un CanvasLayer, adică în SPAȚIUL ECRANULUI: nu se mișcă odată cu camera,
# ci plutesc peste toată imaginea, oriunde ai fi în lume. Layer 2 = peste lume, dar
# SUB vignette (3), ca marginile întunecate să le prindă și pe ele — altfel frunzele
# din colțuri par lipite pe geam.
func _setup_leaves() -> void:
	if not ResourceLoader.exists(LEAF_TEX):
		push_warning("Atmosphere: lipsește %s" % LEAF_TEX)
		return
	var banda := load(LEAF_TEX)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	var ecran := _screen_size()
	for i in leaf_count:
		var s := Sprite2D.new()
		# decupăm o frunză la întâmplare din cele 5 de pe bandă
		var atlas := AtlasTexture.new()
		atlas.atlas = banda
		var idx := randi() % LEAF_COUNT_IN_TEX
		atlas.region = Rect2(idx * LEAF_SIZE, 0, LEAF_SIZE, LEAF_SIZE)
		s.texture = atlas
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art curat, fără blur
		var sc := randf_range(leaf_scale_min, leaf_scale_max)
		s.scale = Vector2(sc, sc)
		s.modulate.a = leaf_alpha
		s.rotation = randf() * TAU
		# la pornire le împrăștiem pe TOT ecranul, ca să nu vezi un val care intră de sus
		s.position = Vector2(randf() * ecran.x, randf() * ecran.y)
		layer.add_child(s)
		_leaves.append({
			"sprite": s,
			# frunzele mai mari cad mai repede (par mai aproape de cameră)
			"viteza": randf_range(leaf_speed_min, leaf_speed_max) * (sc / leaf_scale_max),
			"leganat": randf_range(0.4, 1.0) * leaf_sway,
			"frecventa": randf_range(0.6, 1.6),
			"t": randf() * TAU,
			"rotire": randf_range(-leaf_spin, leaf_spin),
		})

func _update_leaves(delta: float) -> void:
	if _leaves.is_empty():
		return
	var ecran := _screen_size()
	var margine := 40.0
	for f in _leaves:
		var s: Sprite2D = f["sprite"]
		f["t"] += delta
		# cad în jos, se leagănă în lateral (sinus) și sunt împinse de vânt
		s.position.y += f["viteza"] * delta
		s.position.x += (leaf_wind + sin(f["t"] * f["frecventa"]) * f["leganat"]) * delta
		s.rotation += f["rotire"] * delta
		# au ieșit pe jos → reintră pe sus, în alt loc (ciclu fără sfârșit)
		if s.position.y > ecran.y + margine:
			s.position.y = -margine
			s.position.x = randf() * ecran.x
		# ies în lateral → reintră pe partea cealaltă
		if s.position.x > ecran.x + margine:
			s.position.x = -margine
		elif s.position.x < -margine:
			s.position.x = ecran.x + margine

func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _setup_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# Textură rotundă cu gradient radial, generată din cod (fără imagine externă).
#   invers=false → centru plin, margini transparente (pentru lumină)
#   invers=true  → centru transparent, margini întunecate (pentru vignette)
func _radial_texture(size: int, strength: float, invers := false) -> GradientTexture2D:
	var grad := Gradient.new()
	if invers:
		grad.set_color(0, Color(0, 0, 0, 0))
		grad.set_color(1, Color(0, 0, 0, strength))
	else:
		grad.set_color(0, Color(1, 1, 1, strength))
		grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex
