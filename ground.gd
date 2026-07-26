extends Sprite2D

# Podea infinită cu 2 biome (iarbă + deșert). Podeaua e o pânză mare care urmărește
# player-ul, iar un SHADER (biome.gdshader) desenează deșertul în petice pătrate random
# (vezi biome_map.gd — latură 6..20 chunk-uri), după poziția reală din lume, cu margini soft.

@export var tile_size: float = 64.0
@export var chunk_size: float = 512.0   # mărimea unui chunk (px) — TREBUIE să fie ca în props.gd/rocks.gd
@export var blend_chunks: float = 1.5   # cât de soft e marginea deșertului (în chunk-uri) — mai mare = mai soft
@export var nether_tile_size: float = 96.0   # cât de mare se vede o dală de cărămidă în Nether

var _mat: ShaderMaterial
var _grass: Texture2D
var _desert: Texture2D
var _brick: Texture2D

func _ready() -> void:
	add_to_group("ground")   # ca `nether.gd` să poată schimba podeaua
	var shader := load("res://biome.gdshader") as Shader
	var grass := load("res://harta/grass-alternative-3.png") as Texture2D
	var desert := load("res://harta/desert-tile.png") as Texture2D
	if shader == null or grass == null or desert == null:
		push_warning("Biome: lipsește shaderul sau un tile — deschide Godot ca să importe desert-tile.png")
		return
	_grass = grass
	_desert = desert
	if ResourceLoader.exists("res://harta/nether/Brick32.png"):
		_brick = load("res://harta/nether/Brick32.png") as Texture2D
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("grass_tex", grass)
	_mat.set_shader_parameter("desert_tex", desert)
	_mat.set_shader_parameter("tile_size", tile_size)
	_mat.set_shader_parameter("chunk_size", chunk_size)
	# Parametrii biomului vin din biome_map.gd → un SINGUR loc de reglat (vizualul urmează blocarea copacilor/pietrelor)
	_mat.set_shader_parameter("macro", BiomeMap.MACRO)
	_mat.set_shader_parameter("min_size", BiomeMap.MIN_SIZE)
	_mat.set_shader_parameter("max_size", BiomeMap.MAX_SIZE)
	_mat.set_shader_parameter("desert_percent", BiomeMap.DESERT_PERCENT)
	_mat.set_shader_parameter("edge_snap", BiomeMap.EDGE_SNAP)
	material = _mat

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	global_position = player.global_position  # podeaua urmărește player-ul (shaderul e legat de lume, deci nu tremură)
	if _mat != null:
		# le actualizăm live ca să poți regla din Inspector în timp ce joci
		_mat.set_shader_parameter("chunk_size", chunk_size)
		_mat.set_shader_parameter("blend_chunks", blend_chunks)

# Trece podeaua pe cărămida din Nether (și înapoi pe iarbă+deșert). Chemată din `nether.gd`.
#
# Trucul: shaderul amestecă `grass_tex` cu `desert_tex` după harta de biomuri. Dacă îi dăm
# ACEEAȘI textură pe amândouă, amestecul iese cărămidă peste tot — deci nu trebuie să scoatem
# materialul, nici să atingem harta de biomuri. `tile_size` rămâne singurul buton: cât de mare
# se vede o dală (fișierul e 128px; la 96 iese puțin mai mare decât iarba de 64).
func set_nether(on: bool) -> void:
	if _mat == null:
		return
	if on and _brick == null:
		push_warning("Nether: lipsește harta/nether/Brick32.png (rulează --headless --import)")
		return
	_mat.set_shader_parameter("grass_tex", _brick if on else _grass)
	_mat.set_shader_parameter("desert_tex", _brick if on else _desert)
	_mat.set_shader_parameter("tile_size", nether_tile_size if on else tile_size)
