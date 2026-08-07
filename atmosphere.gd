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

# --- atmosfera dimensiunilor (Nether / Ender) ---
# Două lucruri, chemate amândouă dintr-un singur loc: `set_dimension()`.
#   1. un CanvasModulate care colorează LUMEA (Nether = roșu de jar, Ender = albastru rece).
#      E pus în canvas-ul obișnuit, deci prinde podeaua, inamicii, player-ul — dar NU și
#      HUD-ul, care stă în CanvasLayer-e. De aia culoarea se face aici și nu în shader:
#      un filtru peste tot ecranul ar fi înroșit și viața, și XP-ul, și cronometrul.
#   2. un shader peste ecran (scântei / stele) — vezi `nether_hell.gdshader`, `ender_cosmic.gdshader`.
const DIM_SHADERS := {
	"nether": "res://nether_hell.gdshader",
	"ender": "res://ender_cosmic.gdshader",
}
# Culoarea cu care se ÎNMULȚEȘTE lumea. Alb = nimic. Peste 1.0 pe un canal = îl aprinde
# (albastrul Ender-ului), sub 1.0 = îl stinge. Nu coborâm mult toate canalele deodată:
# podeaua Ender-ului e deja aproape neagră, iar inamicii trebuie să rămână vizibili.
const DIM_TINT := {
	"": Color(1.0, 1.0, 1.0),
	"nether": Color(1.05, 0.80, 0.72),
	"ender": Color(0.68, 0.80, 1.12),
}
const DIM_FADE := 0.8         # în câte secunde intră/iese atmosfera (fulgerul de teleportare ține 0.45)

var _light: PointLight2D
var _player: Node2D
var _vignette: TextureRect    # stratul de margini întunecate (se poate stinge din Settings → GRAPHICS)
var _env: Environment         # mediul care ține glow-ul (idem)
var _dim_modulate: CanvasModulate
var _dim_rect: ColorRect
var _dim_mat: ShaderMaterial
var _dim_kind := ""           # "", "nether" sau "ender"
var _dim_tween: Tween

func _ready() -> void:
	add_to_group("atmosphere")   # ca `game_settings.gd` să ne găsească la schimbarea setărilor
	# „Lumină normală": am scos NOAPTEA (CanvasModulate întuneca tot) și LUMINA de pe player (PointLight2D).
	# Lumea rămâne luminată normal. (Dacă vrei înapoi noaptea cyberpunk, decomentează cele două linii.)
	#_setup_night()
	#_setup_light()
	_setup_vignette()
	_setup_glow()
	_setup_dimension()
	apply_settings()

# Aprinde/stinge vignette-ul și glow-ul după pagina GRAPHICS. Chemată la pornire și de fiecare
# dată când jucătorul bifează ceva acolo (din meniul de pauză se vede pe loc).
func apply_settings() -> void:
	if _vignette != null:
		_vignette.visible = GameSettings.vignette
	if _env != null:
		_env.glow_enabled = GameSettings.glow

func _process(_delta: float) -> void:
	# lumina urmărește player-ul
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and _light != null:
		_light.global_position = _player.global_position
	# Paralaxa cerului din Ender: shaderul trebuie să știe unde a ajuns lumea pe ecran, ca stelele
	# să curgă în urma ta în loc să stea lipite de ecran. `canvas_transform.origin` e exact asta,
	# în pixeli de ecran și deja înmulțit cu zoom-ul camerei — deci merge oricât ar fi camera trasă,
	# și nu trebuie să căutăm noi Camera2D-ul. `nether_hell.gdshader` n-are uniforma asta; a o scrie
	# oricum e inofensiv (Godot o ține deoparte până apare un shader care o cere).
	if _dim_kind != "" and _dim_mat != null:
		_dim_mat.set_shader_parameter("world_offset", -get_viewport().get_canvas_transform().origin)

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
	_vignette = tr

# ---------- atmosfera dimensiunilor ----------
# Nodurile se fac o dată, la pornire, și stau stinse cât ești în lumea normală: CanvasModulate
# alb (adică nimic) și ColorRect ascuns, cu `amount = 0`.
func _setup_dimension() -> void:
	_dim_modulate = CanvasModulate.new()
	_dim_modulate.color = DIM_TINT[""]
	add_child(_dim_modulate)

	var layer := CanvasLayer.new()
	layer.layer = 2   # peste lume și HUD, sub vinieta obișnuită (3) și sub cronometrele dimensiunilor (4)
	add_child(layer)
	_dim_mat = ShaderMaterial.new()
	_dim_rect = ColorRect.new()
	_dim_rect.material = _dim_mat
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.visible = false
	layer.add_child(_dim_rect)

# Chemată din `nether.gd` și `ender.gd` la intrare (`"nether"` / `"ender"`) și la ieșire (`""`).
# Se poate chema oricând, de oricâte ori: dacă e deja pe ce ceri, nu face nimic.
func set_dimension(kind: String) -> void:
	if _dim_modulate == null or kind == _dim_kind:
		return
	var shader: Shader = null
	if kind != "":
		shader = load(DIM_SHADERS.get(kind, "")) as Shader
		if shader == null:
			push_warning("Atmosphere: lipsește shaderul dimensiunii " + kind)
			return
	_dim_kind = kind
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()
	_dim_tween = create_tween()
	# ⚠️ TWEEN_PAUSE_PROCESS, nu implicitul. Dacă mori în Nether, `player.die()` ne scoate
	# afară — dar ecranul de Game Over pune jocul pe PAUZĂ în aceeași clipă, iar un tween
	# obișnuit ar îngheța cu lumea rămasă roșie sub „YOU DIED". (Prins pe captură la testare.)
	_dim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_dim_tween.set_parallel(true)
	_dim_tween.tween_property(_dim_modulate, "color", DIM_TINT.get(kind, DIM_TINT[""]), DIM_FADE)
	if kind == "":
		_dim_tween.tween_property(_dim_mat, "shader_parameter/amount", 0.0, DIM_FADE)
		# ascuns abia DUPĂ stingere, altfel efectul ar dispărea dintr-o bucată
		_dim_tween.chain().tween_callback(_hide_dimension)
	else:
		_dim_mat.shader = shader
		# prima intrare: parametrul n-a fost scris niciodată, iar un tween nu poate porni de la
		# `null` — îl punem pe 0, adică exact de unde trebuie să crească
		if _dim_mat.get_shader_parameter("amount") == null:
			_dim_mat.set_shader_parameter("amount", 0.0)
		_dim_rect.visible = true
		_dim_tween.tween_property(_dim_mat, "shader_parameter/amount", 1.0, DIM_FADE)

func _hide_dimension() -> void:
	if _dim_kind == "":
		_dim_rect.visible = false

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
	_env = env

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
