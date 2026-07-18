extends CanvasLayer

# Butonul mare de INTERACȚIUNE, fix în stânga ecranului — gândit pentru telefon.
#
# Înainte fiecare statuie își desena un butonaș „Summon" deasupra capului, în lume:
# mic, se mișca odată cu camera și era greu de nimerit cu degetul. Acum e UN SINGUR
# buton, mare, într-un loc fix pe ecran (stânga, unde ajunge degetul mare), iar el
# caută singur statuia cea mai apropiată care mai poate fi invocată.

@export var latime: float = 240.0      # cât de mare e butonul (px)
@export var inaltime: float = 150.0
@export var margine: float = 44.0      # cât de departe stă de marginea din stânga
@export var deplasare_jos: float = 64.0  # câți px sub mijlocul ecranului (0 = fix la mijloc)

const ACCENT := Color(0.2, 0.9, 1.0)   # cyan, ca în meniu

var _buton: Button
var _tinta: Node2D = null              # statuia pe care o invocăm dacă apeși

func _ready() -> void:
	layer = 5  # peste lume și vignette (3), sub level up (10) și game over (20)
	_buton = Button.new()
	_buton.text = "SUMMON"
	_buton.visible = false
	_buton.custom_minimum_size = Vector2(latime, inaltime)
	_buton.size = Vector2(latime, inaltime)
	# ancorat pe marginea din STÂNGA, la mijlocul înălțimii (+ `jos` dacă vrei mai jos)
	_buton.anchor_left = 0.0
	_buton.anchor_right = 0.0
	_buton.anchor_top = 0.5
	_buton.anchor_bottom = 0.5
	_buton.offset_left = margine
	_buton.offset_right = margine + latime
	_buton.offset_top = -inaltime * 0.5 + deplasare_jos
	_buton.offset_bottom = inaltime * 0.5 + deplasare_jos
	_buton.add_theme_font_size_override("font_size", 34)
	_buton.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_buton.add_theme_color_override("font_hover_color", ACCENT)
	_buton.add_theme_color_override("font_pressed_color", Color.WHITE)
	_buton.add_theme_stylebox_override("normal", _sb(Color(0.06, 0.08, 0.16, 0.88), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.65)))
	_buton.add_theme_stylebox_override("hover", _sb(Color(0.10, 0.16, 0.28, 0.95), ACCENT))
	_buton.add_theme_stylebox_override("pressed", _sb(Color(0.15, 0.35, 0.5, 0.95), ACCENT))
	_buton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_buton.pressed.connect(_pe_apasare)
	add_child(_buton)

func _process(_delta: float) -> void:
	_tinta = _statuia_cea_mai_apropiata()
	_buton.visible = _tinta != null

# Cea mai apropiată statuie care e în raza ei de interacțiune și n-a fost încă invocată.
func _statuia_cea_mai_apropiata() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var best: Node2D = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("statue"):
		if not is_instance_valid(s) or not s.poate_invoca():
			continue
		var d: float = player.global_position.distance_to(s.global_position)
		if d <= s.interact_range and d < best_d:
			best_d = d
			best = s
	return best

func _pe_apasare() -> void:
	Audio.play("button", 0.0, 0.0)
	if _tinta != null and is_instance_valid(_tinta) and _tinta.poate_invoca():
		_tinta.invoca()
	_buton.visible = false

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	return sb
