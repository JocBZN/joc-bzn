extends CanvasLayer

# Ecranul de LEVEL UP: la creșterea în nivel pune jocul pe PAUZĂ și arată 3 îmbunătățiri
# (alese aleatoriu din cele 9). Dai click pe una → se aplică pe player → jocul repornește.
# Butoanele arată ICOANE (din folderul Upgrades/), nu text.

const ICON_DIR := "res://Upgrades/"

# Cele 9 îmbunătățiri. "icon" = poza din Upgrades/; efectul e în _apply().
# (Efectele sunt PROVIZORII — le potrivim pe temă mai încolo.)
var UPGRADES := [
	{"id": "cocaina",    "nume": "Cocaină",    "icon": "upgrade_1.png"},
	{"id": "iarba",      "nume": "Iarbă",      "icon": "upgrade_2.png"},
	{"id": "seringi",    "nume": "Seringi",    "icon": "upgrade_3.png"},
	{"id": "bere",       "nume": "Bere",       "icon": "upgrade_4.png"},
	{"id": "vodca",      "nume": "Vodcă",      "icon": "upgrade_5.png"},
	{"id": "whiskey",    "nume": "Whiskey",    "icon": "upgrade_6.png"},
	{"id": "foite",      "nume": "Foițe OCB",  "icon": "upgrade_7.png"},
	{"id": "grinder",    "nume": "Grinder",    "icon": "upgrade_8.png"},
	{"id": "energizant", "nume": "Energizant", "icon": "upgrade_9.png"},
]

var _buttons := []
var _current := []   # cele 3 upgrade-uri afișate acum
var _pending := 0    # câte niveluri mai avem de ales (dacă urci mai multe deodată)

func _ready() -> void:
	add_to_group("levelup_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS  # merge și când jocul e pe pauză
	layer = 10                               # deasupra HUD-ului
	visible = false

	# fundal întunecat peste tot ecranul
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# container care centrează totul pe ecran
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "LEVEL UP!  Alege:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	box.add_child(title)

	# rând orizontal cu 3 butoane-icoană
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 150)
		b.expand_icon = true                          # icoana se micșorează ca să încapă în buton
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_on_choice.bind(i))
		row.add_child(b)
		_buttons.append(b)

# Chemată de player (player.gd -> _level_up) la fiecare creștere în nivel.
func open() -> void:
	_pending += 1
	if not visible:
		_show_choices()

func _show_choices() -> void:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	_current = pool.slice(0, 3)  # primele 3 după amestecare = 3 alese la întâmplare
	for i in 3:
		var u = _current[i]
		_buttons[i].icon = load(ICON_DIR + u["icon"])
		_buttons[i].tooltip_text = u["nume"]   # numele apare la hover (util în dezvoltare)
	visible = true
	get_tree().paused = true

func _on_choice(index: int) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p != null:
		_apply(_current[index]["id"], p)
	_pending -= 1
	if _pending > 0:
		_show_choices()          # mai ai un nivel de ales (ai urcat mai multe deodată)
	else:
		visible = false
		get_tree().paused = false

# Efecte PROVIZORII (le schimbăm mai încolo). Toate folosesc statistici reale ale player-ului.
func _apply(id: String, p) -> void:
	match id:
		"cocaina":    p.speed += 80.0
		"iarba":      p.hp = p.max_hp
		"seringi":    p.bullet_damage += 8
		"bere":       p.upgrade_max_hp(20)
		"vodca":      p.upgrade_fire_rate(0.85)
		"whiskey":    p.bullet_damage += 10
		"foite":      p.upgrade_fire_rate(0.9)
		"grinder":    p.bullet_damage += 5
		"energizant": p.speed += 100.0
