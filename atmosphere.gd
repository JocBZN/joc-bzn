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

# NOTĂ: frunzele NU mai sunt aici. Au fost un overlay pe tot ecranul, dar acum cad
# doar sub copaci, în lume → vezi `leaffall.gd` (pornit din `props.gd`).

var _light: PointLight2D
var _player: Node2D

func _ready() -> void:
	# „Lumină normală": am scos NOAPTEA (CanvasModulate întuneca tot) și LUMINA de pe player (PointLight2D).
	# Lumea rămâne luminată normal. (Dacă vrei înapoi noaptea cyberpunk, decomentează cele două linii.)
	#_setup_night()
	#_setup_light()
	_setup_vignette()
	_setup_glow()

func _process(_delta: float) -> void:
	# lumina urmărește player-ul
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and _light != null:
		_light.global_position = _player.global_position

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
