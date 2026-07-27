extends CanvasLayer

# Text de INTERACȚIUNE deasupra celui mai apropiat obiect cu care poți interacționa
# (statuie, portal…). Orice obiect care se pune în grupul „interactable" și are
# `interact_range`, `poate_invoca()` și `invoca()` e găsit automat de aici.
#
# Înainte era un buton mare „SUMMON" fix pe ecran (gândit pentru telefon). Acum, pe PC:
# deasupra statuii scrie „Press E to interact" (gri, cu fontul jocului), iar apeși tasta
# `interact` (implicit E, remapabilă în Settings) ca s-o invoci. Textul arată tasta reală —
# dacă o schimbi din Settings, se schimbă și aici.
#
# Eticheta stă în CanvasLayer (nu în lume), dar o poziționăm convertind poziția statuii din
# lume în pixeli de ecran (get_canvas_transform), ca să apară fix deasupra ei și să nu intre
# în y-sort-ul lumii (rămâne mereu deasupra).

const LABEL_COLOR := Color(0.62, 0.62, 0.66)   # gri
@export var world_offset_y: float = -175.0     # cât de sus deasupra statuii (px de lume; negativ = sus)
const LABEL_W := 360.0

var _label: Label
var _tinta: Node2D = null

func _ready() -> void:
	layer = 5  # peste lume și vignette (3), sub level up (10) și game over (20)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(LABEL_W, 0)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", LABEL_COLOR)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)

func _process(_delta: float) -> void:
	_tinta = _tinta_cea_mai_apropiata()
	_label.visible = _tinta != null
	if _tinta == null:
		return
	# tr(...) explicit: textul are un %s, deci traducerea automată n-ar găsi cheia (vezi i18n.gd)
	_label.text = tr("Press %s to interact") % GameSettings.key_name("interact")
	# Cât de sus stă textul. O statuie de ~260px și un cufăr de ~90px nu-l vor la aceeași
	# înălțime, așa că fiecare obiect poate cere alta prin `label_offset_y`. Cine n-o are
	# (statui, portaluri) rămâne pe `world_offset_y`, valoarea de dinainte.
	var sus: float = world_offset_y
	var cerut = _tinta.get("label_offset_y")
	if cerut != null:
		sus = float(cerut)
	# poziția obiectului din lume → pixeli de ecran, apoi centrăm eticheta pe orizontală
	var screen: Vector2 = get_viewport().get_canvas_transform() * (_tinta.global_position + Vector2(0, sus))
	_label.position = screen - Vector2(LABEL_W * 0.5, 0)

# apasă tasta de interacțiune → cheamă `invoca()` pe ținta curentă
# (la statuie pornește invocarea; la portal deocamdată nu face nimic)
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _tinta != null and is_instance_valid(_tinta) and _tinta.poate_invoca():
		get_viewport().set_input_as_handled()
		Audio.play("button", -3.0, 0.0)
		_tinta.invoca()

# Cel mai apropiat obiect interactibil care e în raza lui și mai poate fi folosit.
func _tinta_cea_mai_apropiata() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var best: Node2D = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(s) or not s.poate_invoca():
			continue
		var d: float = player.global_position.distance_to(s.global_position)
		if d <= s.interact_range and d < best_d:
			best_d = d
			best = s
	return best
