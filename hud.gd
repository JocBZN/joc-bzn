extends CanvasLayer

# HUD construit din cod (fără imagini):
#   - bară de VIAȚĂ (roșu) sus-stânga
#   - bară de XP (cyan) jos, pe toată lățimea ecranului
#   - text cu nivelul curent
# Toate se actualizează din valorile player-ului (grupul "player").

var health_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label
var timer_label: Label      # cronometrul mare, sus-centru
var kills_label: Label      # numărul de inamici uciși, sus-dreapta

const TIMER_NORMAL := Color(1, 1, 1)             # alb cât e liniște
const TIMER_WARN := Color(1.0, 0.75, 0.2)        # galben sub 1 minut rămas
const TIMER_SWARM := Color(1.0, 0.25, 0.25)      # roșu în Final Swarm

# --- Banner mare pe ecran (anunțuri de val: "VALUL 3", "BOSS!", ...) ---
var banner: Label
var banner_sub: Label
var _banner_box: VBoxContainer
var _banner_tween: Tween

func _ready() -> void:
	add_to_group("hud")  # ca spawner-ul să ne găsească pentru anunțuri
	_build_banner()

	# --- Bara de VIAȚĂ (sus-stânga, mărime fixă) ---
	health_bar = _make_bar(Color(0.85, 0.15, 0.2), Color(0.15, 0.03, 0.03))  # roșu pe fundal închis
	health_bar.position = Vector2(20, 20)
	health_bar.size = Vector2(320, 22)
	add_child(health_bar)

	# --- Bara de XP (jos de tot, întinsă pe toată lățimea) ---
	xp_bar = _make_bar(Color(0.2, 0.8, 1.0), Color(0.03, 0.08, 0.12))  # cyan pe fundal închis
	xp_bar.anchor_left = 0.0
	xp_bar.anchor_right = 1.0
	xp_bar.anchor_top = 1.0
	xp_bar.anchor_bottom = 1.0
	xp_bar.offset_left = 0
	xp_bar.offset_right = 0
	xp_bar.offset_top = -20   # înălțimea barei
	xp_bar.offset_bottom = 0
	add_child(xp_bar)

	# --- Text cu nivelul (deasupra barei de XP) ---
	level_label = Label.new()
	level_label.anchor_top = 1.0
	level_label.anchor_bottom = 1.0
	level_label.offset_left = 20
	level_label.offset_top = -46
	level_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(level_label)

	# --- Cronometrul (sus, centrat) ---
	# Întâi numără invers de la 10:00; după ce ajunge la 0 o ia în sus, cu roșu.
	timer_label = Label.new()
	timer_label.anchor_left = 0.0
	timer_label.anchor_right = 1.0
	timer_label.offset_top = 14
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.add_theme_color_override("font_color", TIMER_NORMAL)
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	timer_label.add_theme_constant_override("outline_size", 7)
	add_child(timer_label)

	# --- Kill count (sus-dreapta) ---
	kills_label = Label.new()
	kills_label.anchor_left = 1.0
	kills_label.anchor_right = 1.0
	kills_label.offset_left = -220
	kills_label.offset_right = -20
	kills_label.offset_top = 20
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills_label.add_theme_font_size_override("font_size", 22)
	kills_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	kills_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	kills_label.add_theme_constant_override("outline_size", 5)
	add_child(kills_label)

# Creează o ProgressBar colorată (culoare de umplere + culoare de fundal).
func _make_bar(fill: Color, bg: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = bg
	sb_bg.set_corner_radius_all(4)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill
	sb_fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fill)
	return bar

# Construiește bannerul centrat pe ecran (ascuns până la primul anunț).
func _build_banner() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # să nu blocheze click-urile
	center.offset_top = -80  # puțin mai sus de mijloc
	add_child(center)

	_banner_box = VBoxContainer.new()
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_box.modulate.a = 0.0  # invizibil la start
	center.add_child(_banner_box)

	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 52)
	banner.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 8)
	_banner_box.add_child(banner)

	banner_sub = Label.new()
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.add_theme_font_size_override("font_size", 22)
	banner_sub.add_theme_color_override("font_color", Color(1, 1, 1))
	banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner_sub.add_theme_constant_override("outline_size", 5)
	_banner_box.add_child(banner_sub)

# Afișează un text mare care apare, ține câteva secunde, apoi se stinge.
func announce(text: String, sub: String = "") -> void:
	banner.text = text
	banner_sub.text = sub
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_box.modulate.a = 0.0
	_banner_box.scale = Vector2(0.7, 0.7)
	_banner_box.pivot_offset = _banner_box.size * 0.5
	_banner_tween = create_tween()
	# apare cu un mic "pop"
	_banner_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.2)
	_banner_tween.parallel().tween_property(_banner_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# ține pe ecran
	_banner_tween.tween_interval(1.6)
	# se stinge
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.6)

func _process(_delta: float) -> void:
	_update_timer()
	kills_label.text = "Kills: %d" % GameSettings.run_kills
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	health_bar.max_value = player.max_hp
	health_bar.value = player.hp
	xp_bar.max_value = player.xp_to_next
	xp_bar.value = player.xp
	level_label.text = "Level " + str(player.level)

# Cronometrul: numără invers cele 10 minute, apoi urcă de la 0 cu roșu (Final Swarm).
func _update_timer() -> void:
	if Difficulty.is_final_swarm():
		timer_label.text = "+" + _mmss(Difficulty.overtime())
		timer_label.add_theme_color_override("font_color", TIMER_SWARM)
	else:
		var ramas := Difficulty.time_left()
		timer_label.text = _mmss(ramas)
		# ultimul minut se face galben, ca avertisment că vine Final Swarm
		timer_label.add_theme_color_override("font_color", TIMER_WARN if ramas <= 60.0 else TIMER_NORMAL)

func _mmss(secunde: float) -> String:
	var s := int(secunde)
	return "%d:%02d" % [s / 60, s % 60]
