extends CanvasLayer

# HUD construit din cod (fără imagini):
#   - bară de VIAȚĂ (roșu) sus-stânga
#   - bară de XP (cyan) jos, pe toată lățimea ecranului
#   - text cu nivelul curent
# Toate se actualizează din valorile player-ului (grupul "player").

var health_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label

func _ready() -> void:
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

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	health_bar.max_value = player.max_hp
	health_bar.value = player.hp
	xp_bar.max_value = player.xp_to_next
	xp_bar.value = player.xp
	level_label.text = "Nivel " + str(player.level)
