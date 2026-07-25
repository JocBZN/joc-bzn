extends CanvasLayer

# Meniul de PAUZĂ din joc. ESC în timpul unei runde pune jocul pe pauză și arată:
#   Main Menu · Restart Run · Settings · Quit Game
# ESC din nou închide meniul (reia jocul). Pe pagina de Settings, ESC urcă înapoi la listă.
# Construit tot din cod, ca gameover.gd. Pagina de Settings refolosește SettingsUI (ca meniul).

const BTN_MAIN := Color("9e603f")     # umplutura butonului (lemn, ca în meniu)
const BTN_SECOND := Color("594232")   # conturul
const ACCENT := Color(0.2, 0.9, 1.0)  # cyan (titluri), ca în menu.gd

var _open := false
var _page := "main"           # "main" (lista) sau "settings"
var _main_page: Control
var _settings_page: Control
var _settings_ui: SettingsUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # merge și când jocul e pe pauză
	layer = 15                                 # peste HUD, sub Game Over (20)
	visible = false

	# fundal întunecat peste tot ecranul
	var overlay := ColorRect.new()
	overlay.color = Color(0.06, 0.06, 0.09, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build_main_page()
	_build_settings_page()
	_show_page("main")

# ---------- ESC ----------
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not _open:
		if _blocked():
			return          # nu deschide peste Level Up sau Game Over
		_open_menu()
	elif _page == "settings":
		_settings_ui.cancel_remap()
		_show_page("main")  # din Settings, ESC urcă la listă (nu reia jocul)
	else:
		_close_menu()
	get_viewport().set_input_as_handled()

# Nu deschide meniul de pauză cât e deja alt ecran modal deschis (level up / game over).
func _blocked() -> bool:
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if lu != null and lu.visible:
		return true
	var go = get_tree().get_first_node_in_group("gameover_screen")
	if go != null and go.visible:
		return true
	return false

func _open_menu() -> void:
	_show_page("main")
	visible = true
	_open = true
	get_tree().paused = true

func _close_menu() -> void:
	_settings_ui.cancel_remap()
	visible = false
	_open = false
	get_tree().paused = false

# ---------- pagini ----------
func _build_main_page() -> void:
	_main_page = _make_page()
	var box := _page_box(_main_page)
	box.add_child(_title("PAUSED"))
	box.add_child(_spacer(18))
	box.add_child(_button("Resume", _on_resume))
	box.add_child(_button("Main Menu", _on_main_menu))
	box.add_child(_button("Restart Run", _on_restart))
	box.add_child(_button("Settings", _on_settings))
	box.add_child(_button("Quit Game", _on_quit))

func _build_settings_page() -> void:
	_settings_page = _make_page()
	var box := _page_box(_settings_page)
	box.add_child(_title("SETTINGS"))
	box.add_child(_spacer(8))
	_settings_ui = SettingsUI.new()
	box.add_child(_settings_ui)
	box.add_child(_spacer(20))
	box.add_child(_button("Back", _on_settings_back))

func _show_page(which: String) -> void:
	_page = which
	_main_page.visible = (which == "main")
	_settings_page.visible = (which == "settings")

# ---------- callback-uri ----------
func _on_resume() -> void:
	_close_menu()   # reia jocul (la fel ca ESC din listă)

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_settings() -> void:
	_show_page("settings")

func _on_settings_back() -> void:
	_settings_ui.cancel_remap()
	_show_page("main")

func _on_quit() -> void:
	get_tree().quit()

# ---------- helpers ----------
# o pagină = un Control full-rect cu un CenterContainer; întoarce Control-ul (invizibil/vizibil)
func _make_page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	return page

func _page_box(page: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box

func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND, 3))
	b.add_theme_stylebox_override("hover", _sb(BTN_MAIN.lightened(0.10), BTN_SECOND.lightened(0.10), 3))
	b.add_theme_stylebox_override("pressed", _sb(BTN_MAIN.lightened(0.20), BTN_SECOND.lightened(0.20), 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("button", -3.0, 0.0))
	b.pressed.connect(cb)
	return b

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

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
