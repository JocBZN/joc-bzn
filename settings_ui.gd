extends VBoxContainer
class_name SettingsUI

# Bloc de setări REFOLOSIBIL: slidere de volum (Muzică / Efecte) + remaparea tastelor de mers.
# Se folosește în DOUĂ locuri — meniul principal (menu.gd) și meniul de pauză din joc (pause.gd) —
# ca să nu ținem două copii ale logicii de remapare. Cel care-l pune deasupra adaugă singur
# titlul „SETTINGS" și butonul BACK; aici e doar conținutul (rândurile).
#
# Își prinde singur tasta apăsată în _input când e în modul remapare. Nu are nevoie de altceva
# din exterior; citește/scrie totul prin autoload-ul GameSettings.

const BTN_MAIN := Color("9e603f")     # umplutura butonului (lemn, ca în meniu)
const BTN_SECOND := Color("594232")   # conturul

var _remap_action := ""     # ce direcție așteaptă o tastă nouă (gol = nu remapăm acum)
var _remap_buttons := {}    # action -> butonul care arată tasta

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	# volum: două slidere (0 = mut, dreapta = tare)
	add_child(_volume_row("MUSIC", GameSettings.music_volume, _on_music_volume))
	add_child(_volume_row("SOUND FX", GameSettings.sfx_volume, _on_sfx_volume))
	add_child(_spacer(12))
	add_child(_center_label("CONTROLS", 26))
	add_child(_spacer(4))
	# câte un rând pentru fiecare direcție; apeși butonul și apoi tasta nouă
	for action in GameSettings.KEY_ACTIONS:
		add_child(_key_row(action))

# Cât timp remapăm, următoarea tastă apăsată devine noua comandă (Escape = renunț).
func _input(event: InputEvent) -> void:
	if _remap_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc != KEY_ESCAPE:
			GameSettings.rebind(_remap_action, kc)
		_remap_buttons[_remap_action].text = GameSettings.key_name(_remap_action)
		_remap_action = ""

# Anulează o remapare în curs (chemat când se închide pagina de settings).
func cancel_remap() -> void:
	if _remap_action != "" and _remap_buttons.has(_remap_action):
		_remap_buttons[_remap_action].text = GameSettings.key_name(_remap_action)
	_remap_action = ""

# ---------- rânduri ----------
# „Etichetă  [====slider====]"
func _volume_row(text: String, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(160, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(260, 0)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(cb)
	row.add_child(s)
	return row

# „Direcție  [ TASTA ]" — butonul intră în modul „așteaptă o tastă" la click
func _key_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = GameSettings.KEY_ACTIONS[action]["label"]
	l.custom_minimum_size = Vector2(160, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var b := Button.new()
	b.text = GameSettings.key_name(action)
	b.custom_minimum_size = Vector2(180, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND, 3))
	b.add_theme_stylebox_override("hover", _sb(BTN_MAIN.lightened(0.10), BTN_SECOND.lightened(0.10), 3))
	b.add_theme_stylebox_override("pressed", _sb(BTN_MAIN.lightened(0.20), BTN_SECOND.lightened(0.20), 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_begin_remap.bind(action))
	_remap_buttons[action] = b
	row.add_child(b)
	return row

func _on_music_volume(v: float) -> void:
	GameSettings.set_music_volume(v)

func _on_sfx_volume(v: float) -> void:
	GameSettings.set_sfx_volume(v)
	Audio.play("button", -3.0, 0.0)   # un clic scurt ca să auzi noul nivel (throttled în audio.gd)

# intră în modul remapare pentru o direcție: următoarea tastă apăsată devine noua comandă
func _begin_remap(action: String) -> void:
	if _remap_action != "" and _remap_buttons.has(_remap_action):
		_remap_buttons[_remap_action].text = GameSettings.key_name(_remap_action)  # lasă cealaltă cum era
	_remap_action = action
	_remap_buttons[action].text = "press a key…"

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
