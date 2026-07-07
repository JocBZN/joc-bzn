extends CanvasLayer

# Ecranul de GAME OVER: apare când mori. Pune jocul pe pauză și arată
# timpul supraviețuit + nivelul atins + un buton de restart.
# Tot UI-ul e construit din cod (fără scenă de desenat).

var time_label: Label
var level_label: Label

func _ready() -> void:
	add_to_group("gameover_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS  # merge și când jocul e pe pauză
	layer = 20                               # peste tot (inclusiv HUD și level up)
	visible = false

	# fundal întunecat peste tot ecranul
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.25))
	box.add_child(title)

	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	box.add_child(time_label)

	level_label = Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 24)
	box.add_child(level_label)

	# buton de restart (cu puțin spațiu deasupra)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)

	var btn := Button.new()
	btn.text = "PLAY AGAIN"
	btn.custom_minimum_size = Vector2(240, 60)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_restart)
	box.add_child(btn)

	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.custom_minimum_size = Vector2(240, 50)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(_on_menu)
	box.add_child(menu_btn)

# Chemată de player.die() când rămâi fără viață.
func show_gameover(secunde: float, nivel: int) -> void:
	GameSettings.add_score(secunde, nivel)  # salvează în leaderboard
	var m := int(secunde) / 60
	var s := int(secunde) % 60
	time_label.text = "Survived: %d:%02d" % [m, s]
	level_label.text = "Level reached: %d" % nivel
	visible = true
	get_tree().paused = true

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")
