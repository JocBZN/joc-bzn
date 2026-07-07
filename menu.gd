extends Control

# Meniul principal (main scene). Tot UI-ul e construit din cod.
# Panouri: main, weapon, character, leaderboard — arăt câte unul o dată.

const GAME_SCENE := "res://main.tscn"

var WEAPONS := [
	{"name": "Bullet 1", "scene": "res://bullet.tscn",  "icon": "res://bullets/bullet1.png"},
	{"name": "Bullet 2", "scene": "res://bullet2.tscn", "icon": "res://bullets/bullet2.png"},
	{"name": "Bullet 3", "scene": "res://bullet3.tscn", "icon": "res://bullets/bullet3.png"},
]

var _panels := {}
var _weapon_buttons := []
var _lb_list: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_main()
	_build_weapon()
	_build_character()
	_build_leaderboard()
	_show("main")

func _show(which: String) -> void:
	for key in _panels:
		_panels[key].visible = (key == which)

# creează un panou pe tot ecranul și întoarce cutia verticală centrată din el
func _make_panel(key: String) -> VBoxContainer:
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_panels[key] = panel
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box

# ---------- MAIN ----------
func _build_main() -> void:
	var box := _make_panel("main")
	var title := Label.new()
	title.text = "JOC-BZN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	box.add_child(title)
	box.add_child(_spacer(24))
	box.add_child(_menu_button("START", _on_start))
	box.add_child(_menu_button("CHOOSE CHARACTER", _show.bind("character")))
	box.add_child(_menu_button("CHOOSE WEAPON", _show.bind("weapon")))
	box.add_child(_menu_button("LEADERBOARD", _on_leaderboard))

func _on_start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

# ---------- CHOOSE WEAPON ----------
func _build_weapon() -> void:
	var box := _make_panel("weapon")
	box.add_child(_header("CHOOSE WEAPON"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_weapon_buttons.clear()
	for i in WEAPONS.size():
		var w = WEAPONS[i]
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(slot)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 120)
		b.icon = load(w["icon"])
		b.expand_icon = true
		b.pressed.connect(_on_weapon_chosen.bind(String(w["scene"])))
		slot.add_child(b)
		_weapon_buttons.append(b)
		var lbl := Label.new()
		lbl.text = w["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(120, 0)
		slot.add_child(lbl)
	_refresh_weapon_selection()
	box.add_child(_spacer(16))
	box.add_child(_menu_button("BACK", _show.bind("main")))

func _on_weapon_chosen(scene_path: String) -> void:
	GameSettings.weapon_path = scene_path
	_refresh_weapon_selection()

func _refresh_weapon_selection() -> void:
	for i in _weapon_buttons.size():
		var sel: bool = WEAPONS[i]["scene"] == GameSettings.weapon_path
		_weapon_buttons[i].modulate = Color(0.4, 1.0, 0.5) if sel else Color.WHITE

# ---------- CHOOSE CHARACTER (placeholder) ----------
func _build_character() -> void:
	var box := _make_panel("character")
	box.add_child(_header("CHOOSE CHARACTER"))
	var lbl := Label.new()
	lbl.text = "Only one character for now: \"Grasu\".\nMore coming soon!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	box.add_child(lbl)
	box.add_child(_spacer(24))
	box.add_child(_menu_button("BACK", _show.bind("main")))

# ---------- LEADERBOARD ----------
func _build_leaderboard() -> void:
	var box := _make_panel("leaderboard")
	box.add_child(_header("LEADERBOARD"))
	_lb_list = VBoxContainer.new()
	_lb_list.add_theme_constant_override("separation", 6)
	_lb_list.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_lb_list)
	box.add_child(_spacer(24))
	box.add_child(_menu_button("BACK", _show.bind("main")))

func _on_leaderboard() -> void:
	for c in _lb_list.get_children():
		c.queue_free()
	if GameSettings.scores.is_empty():
		_lb_list.add_child(_center_label("No scores yet. Play a round!", 20))
	else:
		var rank := 1
		for s in GameSettings.scores:
			var m := int(s["time"]) / 60
			var sec := int(s["time"]) % 60
			_lb_list.add_child(_center_label("%d.   %d:%02d   ·   Level %d" % [rank, m, sec, s["level"]], 22))
			rank += 1
	_show("leaderboard")

# ---------- helpers ----------
func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 54)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b

func _header(text: String) -> Label:
	var l := _center_label(text, 40)
	l.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	return l

func _center_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
