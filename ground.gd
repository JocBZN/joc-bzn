extends Sprite2D

# Podea infinită cu 2 biome (iarbă → deșert). Podeaua e o pânză mare care urmărește
# player-ul, iar un SHADER (biome.gdshader) desenează iarbă în stânga și deșert în dreapta,
# după poziția X reală din lume, cu o trecere lină. Reglezi granița din Inspector.

@export var tile_size: float = 64.0
@export var boundary_x: float = 2500.0      # de la ce X spre dreapta începe deșertul
@export var transition_width: float = 600.0 # cât de lată e trecerea verde → deșert (px)

var _mat: ShaderMaterial

func _ready() -> void:
	var shader := load("res://biome.gdshader") as Shader
	var grass := load("res://harta/grass-alternative-3.png") as Texture2D
	var desert := load("res://harta/desert_tile.png") as Texture2D
	if shader == null or grass == null or desert == null:
		push_warning("Biome: lipsește shaderul sau un tile — deschide Godot ca să importe desert_tile.png")
		return
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("grass_tex", grass)
	_mat.set_shader_parameter("desert_tex", desert)
	_mat.set_shader_parameter("tile_size", tile_size)
	material = _mat

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	global_position = player.global_position  # podeaua urmărește player-ul (shaderul e legat de lume, deci nu tremură)
	if _mat != null:
		# le actualizăm live ca să poți regla granița din Inspector în timp ce joci
		_mat.set_shader_parameter("boundary_x", boundary_x)
		_mat.set_shader_parameter("transition_width", transition_width)
