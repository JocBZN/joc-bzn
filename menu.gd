extends Control

# Meniul principal (main scene). Tot UI-ul e construit din cod, stilizat „cyberpunk":
# fundal cu gradient + vignette, titlu cu glow neon, butoane cu borduri cyan.

const GAME_SCENE := "res://main.tscn"
const ACCENT := Color(0.2, 0.9, 1.0)    # cyan
const ACCENT2 := Color(1.0, 0.2, 0.6)   # magenta (glow-ul titlului)

var WEAPONS := [
	{"id": "pistol",       "name": "PISTOL",     "icon": "res://weapons_icons/pistol.png"},
	{"id": "mage",         "name": "MAGE STAFF", "icon": "res://weapons_icons/mage_staff.png"},
	{"id": "extinguisher", "name": "STINGĂTOR",  "icon": "res://weapons_icons/stingator.png"},
]

var _panels := {}
var _weapon_buttons := []
var _lb_list: VBoxContainer
var _coins_label: Label
var _shop_rows := []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gradient_bg()
	_vignette()
	_build_main()
	_build_weapon()
	_build_character()
	_build_leaderboard()
	_build_shop()
	_show("main")

func _show(which: String) -> void:
	for key in _panels:
		_panels[key].visible = (key == which)

# fundal cu gradient vertical (mov-navy închis → aproape negru)
func _gradient_bg() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.07, 0.05, 0.15))
	grad.set_color(1, Color(0.02, 0.02, 0.05))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

# margini întunecate (vignette), pentru mood
func _vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

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
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_color_override("font_outline_color", Color(ACCENT2.r, ACCENT2.g, ACCENT2.b, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var sub := _center_label("C Y B E R   S U R V I V O R", 18)
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.7))
	box.add_child(sub)
	box.add_child(_spacer(28))
	box.add_child(_menu_button("START", _on_start))
	box.add_child(_menu_button("CHOOSE CHARACTER", _show.bind("character")))
	box.add_child(_menu_button("CHOOSE WEAPON", _show.bind("weapon")))
	box.add_child(_menu_button("UPGRADES", _on_shop))
	box.add_child(_menu_button("LEADERBOARD", _on_leaderboard))

func _on_start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

# ---------- CHOOSE WEAPON ----------
func _build_weapon() -> void:
	var box := _make_panel("weapon")
	box.add_child(_header("CHOOSE WEAPON"))
	box.add_child(_spacer(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_weapon_buttons.clear()
	for i in WEAPONS.size():
		var w = WEAPONS[i]
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 8)
		row.add_child(slot)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 150)
		if ResourceLoader.exists(w["icon"]):
			b.icon = load(w["icon"])
		b.expand_icon = true
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_weapon_chosen.bind(String(w["id"])))
		slot.add_child(b)
		_weapon_buttons.append(b)
		slot.add_child(_center_label(w["name"], 18))
	_refresh_weapon_selection()
	box.add_child(_spacer(22))
	box.add_child(_menu_button("BACK", _show.bind("main")))

func _on_weapon_chosen(id: String) -> void:
	GameSettings.weapon_type = id
	_refresh_weapon_selection()

func _refresh_weapon_selection() -> void:
	for i in _weapon_buttons.size():
		var sel: bool = WEAPONS[i]["id"] == GameSettings.weapon_type
		var b: Button = _weapon_buttons[i]
		var border := Color(0.4, 1.0, 0.5) if sel else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
		var bg := Color(0.10, 0.24, 0.16, 0.95) if sel else Color(0.06, 0.08, 0.16, 0.85)
		b.add_theme_stylebox_override("normal", _sb(bg, border, 3 if sel else 2))
		b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.08), border, 3))
		b.add_theme_stylebox_override("pressed", _sb(bg.lightened(0.15), border, 3))

# ---------- CHOOSE CHARACTER (placeholder) ----------
func _build_character() -> void:
	var box := _make_panel("character")
	box.add_child(_header("CHOOSE CHARACTER"))
	box.add_child(_center_label("Only one character for now: \"Grasu\".\nMore coming soon!", 20))
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

# ---------- UPGRADES (meta-progresie) ----------
func _build_shop() -> void:
	var box := _make_panel("shop")
	box.add_child(_header("UPGRADES"))
	_coins_label = _center_label("", 26)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # auriu
	box.add_child(_coins_label)
	box.add_child(_spacer(8))
	_shop_rows.clear()
	for u in GameSettings.META:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		var info := Label.new()
		info.custom_minimum_size = Vector2(400, 0)
		info.add_theme_font_size_override("font_size", 18)
		row.add_child(info)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(160, 44)
		buy.add_theme_font_size_override("font_size", 18)
		buy.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		buy.pressed.connect(_on_buy.bind(String(u["id"])))
		row.add_child(buy)
		_shop_rows.append({"id": u["id"], "name": u["name"], "per": u["per"], "info": info, "buy": buy})
	box.add_child(_spacer(20))
	box.add_child(_menu_button("BACK", _show.bind("main")))

func _on_shop() -> void:
	_refresh_shop()
	_show("shop")

func _on_buy(id: String) -> void:
	GameSettings.buy(id)
	_refresh_shop()

func _refresh_shop() -> void:
	_coins_label.text = "COINS:  %d" % GameSettings.coins
	for r in _shop_rows:
		var id: String = r["id"]
		var lvl := GameSettings.level_of(id)
		var mx := GameSettings.max_of(id)
		r["info"].text = "%s   (%s)      Lv %d/%d" % [r["name"], r["per"], lvl, mx]
		var buy: Button = r["buy"]
		if lvl >= mx:
			buy.text = "MAX"
			buy.disabled = true
		else:
			buy.text = "BUY  %d" % GameSettings.cost_of(id)
			buy.disabled = GameSettings.coins < GameSettings.cost_of(id)
		buy.add_theme_stylebox_override("normal", _sb(Color(0.06, 0.12, 0.08, 0.9), Color(0.4, 1.0, 0.5, 0.55)))
		buy.add_theme_stylebox_override("hover", _sb(Color(0.10, 0.20, 0.12, 0.95), Color(0.4, 1.0, 0.5)))
		buy.add_theme_stylebox_override("pressed", _sb(Color(0.14, 0.28, 0.16, 0.95), Color(0.5, 1.0, 0.6)))
		buy.add_theme_stylebox_override("disabled", _sb(Color(0.08, 0.08, 0.10, 0.6), Color(0.3, 0.3, 0.35, 0.4)))
		buy.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
		buy.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))

# ---------- helpers ----------
func _sb(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 58)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _sb(Color(0.06, 0.08, 0.16, 0.85), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.10, 0.16, 0.28, 0.95), ACCENT))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.15, 0.35, 0.5, 0.95), ACCENT))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b

func _header(text: String) -> Label:
	var l := _center_label(text, 42)
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_color_override("font_outline_color", Color(ACCENT2.r, ACCENT2.g, ACCENT2.b, 0.8))
	l.add_theme_constant_override("outline_size", 6)
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
