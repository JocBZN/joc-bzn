extends CanvasLayer

# Ecranul de LEVEL UP: la creșterea în nivel pune jocul pe PAUZĂ și arată 3 îmbunătățiri
# (alese aleatoriu din cele 9). Dai click pe una → se aplică pe player → jocul repornește.
# Fiecare buton are ICOANA (din Upgrades/) + numele + stat-ul scris dedesubt.
# Efectele sunt tematice pe substanță. Cocaina schimbă glonțul pe bullet2, Stroh pe bullet3.

const ICON_DIR := "res://Upgrades/"

# "desc" = textul cu stat-ul, afișat sub icoană. Efectul e în _apply().
var UPGRADES := [
	{"id": "cocaina",   "nume": "Cocaină",   "icon": "upgrade_1.png", "desc": "Glonț 2 · +viteză · +cadență"},
	{"id": "iarba",     "nume": "Iarbă",     "icon": "upgrade_2.png", "desc": "+3 HP/sec & vindecă 30"},
	{"id": "seringa",   "nume": "Seringă",   "icon": "upgrade_3.png", "desc": "+12 Damage gloanțe"},
	{"id": "bere",      "nume": "Bere",      "icon": "upgrade_4.png", "desc": "+35 Viață maximă"},
	{"id": "vodca",     "nume": "Vodcă",     "icon": "upgrade_5.png", "desc": "-3 Damage primit"},
	{"id": "stroh",     "nume": "Stroh",     "icon": "upgrade_6.png", "desc": "Glonț 3 foc · +damage · +cadență"},
	{"id": "foite",     "nume": "Foițe OCB", "icon": "upgrade_7.png", "desc": "+250 Viteză glonț"},
	{"id": "grinder",   "nume": "Grinder",   "icon": "upgrade_8.png", "desc": "-15% XP pt nivel"},
	{"id": "bere_doza", "nume": "Bere doză", "icon": "upgrade_9.png", "desc": "+60 Viață acum"},
	{"id": "gloante_paralele", "nume": "Gloanțe paralele", "icon": "res://bullets/bullet1.png", "desc": "+1 glonț paralel"},
	{"id": "strapungere", "nume": "Foraj", "icon": "res://bullets/bullet2.png", "desc": "Gloanțele trec prin +1 inamic"},
	{"id": "critic", "nume": "Adrenalină", "icon": "upgrade_3.png", "desc": "+15% șansă damage dublu"},
	{"id": "glont_mare", "nume": "Doză dublă", "icon": "res://bullets/bullet3.png", "desc": "Gloanțe mai mari · +5 damage"},
	{"id": "recul", "nume": "Croșeu", "icon": "upgrade_5.png", "desc": "Gloanțele împing inamicii înapoi"},
]

var _buttons := []
var _name_labels := []
var _desc_labels := []
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

	# rând orizontal cu 3 sloturi (fiecare = icoană + nume + stat)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	for i in 3:
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 6)
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(slot)

		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 150)
		b.expand_icon = true                          # icoana se micșorează ca să încapă în buton
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_on_choice.bind(i))
		slot.add_child(b)
		_buttons.append(b)

		# numele item-ului (alb, sub icoană)
		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.custom_minimum_size = Vector2(160, 0)
		name_lbl.add_theme_font_size_override("font_size", 18)
		slot.add_child(name_lbl)
		_name_labels.append(name_lbl)

		# stat-ul oferit (verde, sub nume)
		var desc_lbl := Label.new()
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(160, 0)
		desc_lbl.add_theme_font_size_override("font_size", 15)
		desc_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
		slot.add_child(desc_lbl)
		_desc_labels.append(desc_lbl)

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
		var icon_path: String = u["icon"]
		if not icon_path.begins_with("res://"):
			icon_path = ICON_DIR + icon_path   # numele scurte se caută în Upgrades/; căile res:// se folosesc direct
		_buttons[i].icon = load(icon_path)
		_buttons[i].tooltip_text = u["nume"]
		_name_labels[i].text = u["nume"]
		_desc_labels[i].text = u["desc"]
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

# Efectele reale, tematice pe substanță. Modifică numerele cum vrei.
func _apply(id: String, p) -> void:
	match id:
		"cocaina":
			# stimulent puternic: glonț nou (bullet2) + viteză + cadență
			p.bullet_scene = load("res://bullet2.tscn")
			p.speed += 60.0
			p.upgrade_fire_rate(0.8)
		"iarba":
			# chill / vindecare: regenerare + un plus de viață pe loc
			p.hp_regen += 3
			p.hp = min(p.max_hp, p.hp + 30)
		"seringa":
			# lovitură directă: mult damage pe glonț
			p.bullet_damage += 12
		"bere":
			# tanky: mai multă viață maximă (te și vindecă)
			p.upgrade_max_hp(35)
		"vodca":
			# amorțeală / curaj lichid: primești mai puțin damage
			p.contact_damage = max(1, p.contact_damage - 3)
		"stroh":
			# 80% alcool, foc: glonț nou (bullet3) + damage + cadență
			p.bullet_scene = load("res://bullet3.tscn")
			p.bullet_damage += 10
			p.upgrade_fire_rate(0.85)
		"foite":
			# subțire & rapid: gloanțe mai iuți (bat mai departe)
			p.bullet_speed += 250.0
		"grinder":
			# eficiență: nivelezi mai repede (îți trebuie mai puțin XP)
			p.xp_to_next = max(5, int(p.xp_to_next * 0.85))
		"bere_doza":
			# refresh rapid: vindecare instant mare
			p.hp = min(p.max_hp, p.hp + 60)
		"gloante_paralele":
			# încă un glonț paralel (1 → 2 → 3 ...)
			p.bullet_count += 1
		"strapungere":
			# glonțul trece prin încă un inamic înainte să dispară
			p.pierce += 1
		"critic":
			# +15% șansă de damage dublu (plafonat la 100%)
			p.crit_chance = min(1.0, p.crit_chance + 0.15)
		"glont_mare":
			# gloanțe mai mari (hitbox + sprite) și puțin mai puternice
			p.bullet_scale += 0.3
			p.bullet_damage += 5
		"recul":
			# gloanțele împing inamicii înapoi
			p.knockback += 250.0
