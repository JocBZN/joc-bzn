extends Control

# Meniul principal (main scene). Tot UI-ul e construit din cod, stilizat „cyberpunk":
# fundal cu gradient + vignette, titlu cu glow neon, butoane cu borduri cyan.

const GAME_SCENE := "res://main.tscn"
const ACCENT := Color(0.2, 0.9, 1.0)    # cyan
const ACCENT2 := Color(1.0, 0.2, 0.6)   # magenta (glow-ul titlului)

var WEAPONS := [
	{"id": "pistol",       "name": "PISTOL",       "icon": "res://weapons_icons/pistol.png"},
	{"id": "mage",         "name": "MAGE STAFF",   "icon": "res://weapons_icons/mage_staff.png"},
	{"id": "extinguisher", "name": "STINGĂTOR",    "icon": "res://weapons_icons/stingator.png"},
	{"id": "sword",        "name": "CURSED SWORD", "icon": "res://weapons_icons/cursed sword.png"},
]

const BG_STILL := "res://menu/bg_still.webp"        # cadru clar (720p) pentru secunda de intro
const BG_FRAMES_DIR := "res://menu/bg_frames"       # cadrele de animație (640x360)
const BG_FRAME_COUNT := 60
const BG_FPS := 10.0
const BLUR_SHADER := "res://menu/menu_blur.gdshader"

const TITLE_DIR := "res://menu/Title"       # logo-ul animat (4 cadre, 256x256)
const TITLE_FRAME_COUNT := 4
const TITLE_FRAME_TIME := 0.4               # secunde per cadru (mai mare = mai lent)
const TITLE_SIZE := 240                     # cât de mare se afișează logo-ul, în pixeli
# ATENȚIE la înălțime: ecranul de referință are 648px, iar cele 5 butoane ocupă 346
# (5 × 58 + 4 × 14 separare). Deci logo + spațiere trebuie să stea sub ~274, altfel
# butonul LEADERBOARD iese din ecran. Acum: 240 + 16 = 256, rămân ~23px marjă sus/jos.

# --- reglaje pentru intro (schimbă-le liniștit, sunt doar de gust) ---
const INTRO_CLEAR := 1.0      # câte secunde rulează video-ul curat, fără nimic peste el
const INTRO_FADE := 0.6       # cât durează să intre blur-ul + titlul
const INTRO_BUTTONS := 0.35   # cât durează să apară butoanele, imediat după titlu
const MENU_BLUR := 3.0        # cât de tare e blur-ul la final (0 = deloc, 8 = maxim)

var _panels := {}
var _weapon_buttons := []
var _lb_list: VBoxContainer
var _coins_label: Label
var _shop_rows := []

var _bg_rect: TextureRect       # fundalul (întâi cadrul clar, apoi cadrele animate)
var _frames: Array[Texture2D] = []
var _frame_i := 0
var _frame_dir := 1             # ping-pong: 1 = înainte, -1 = înapoi
var _frame_t := 0.0
var _animating := false
var _blur_mat: ShaderMaterial   # materialul de pe fundal, ca să pot anima blur-ul
var _tint: ColorRect            # stratul întunecat peste video (lizibilitate text)
var _vig: TextureRect           # vignette-ul
var _title_rect: TextureRect    # logo-ul animat
var _title_frames: Array[Texture2D] = []
var _title_i := 0
var _title_dir := 1             # ping-pong, ca la fundal
var _title_t := 0.0
var _title_group: VBoxContainer # titlul + subtitlul, ca să le pot stinge împreună
var _main_buttons: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ordinea de adăugare = ordinea straturilor: video jos de tot, apoi tint, vignette, UI
	_bg_setup()
	_tint_overlay()
	_vignette()
	_build_main()
	_build_weapon()
	_build_character()
	_build_leaderboard()
	_build_shop()
	_show("main")
	Audio.play_menu_music()
	# după ce tot UI-ul e construit, punem sunetul de click pe TOATE butoanele deodată
	# (inclusiv cele de armă și de cumpărat) — nu trebuie să-l adaugi manual la fiecare.
	_hook_button_sounds(self)
	# ultimul, fiindcă așteaptă (await) — tot ce e mai sus trebuie să fie deja gata
	await _play_intro()

# merge recursiv prin tot meniul și conectează click-ul la orice buton găsește
func _hook_button_sounds(n: Node) -> void:
	for c in n.get_children():
		if c is BaseButton and not c.pressed.is_connected(_click_sfx):
			c.pressed.connect(_click_sfx)
		_hook_button_sounds(c)

# CLICK_DB = cât de tare e click-ul (0 = normal, -6 mai încet, +6 mai tare)
const CLICK_DB := 0.0

func _click_sfx() -> void:
	Audio.play("button", CLICK_DB, 0.0)   # 0.0 = fără variație de ton, sună identic mereu

func _show(which: String) -> void:
	for key in _panels:
		_panels[key].visible = (key == which)

# ---------- FUNDAL ANIMAT ----------
# Fundalul e primul copil, deci stă sub tot restul meniului.
#
# De ce cadre PNG/WebP și nu video: Godot poate reda doar Ogg Theora (.mp4/H.264 nu e
# inclus în engine), iar conversia în Theora a ieșit de fiecare dată cu imaginea coruptă.
# Așa că am tăiat 6 secunde din „main menu background.mp4" în cadre (vezi README).
#
# Cadrele animate sunt mici (640x360) fiindcă se văd doar blurate; pentru secunda de
# intro, cât imaginea e clară, folosim un cadru separat de 720p.
func _bg_setup() -> void:
	if not ResourceLoader.exists(BG_STILL):
		_gradient_bg()   # dacă lipsesc cadrele, meniul arată ca înainte
		return
	_bg_rect = TextureRect.new()
	_bg_rect.texture = load(BG_STILL)
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = load(BLUR_SHADER)
	_blur_mat.set_shader_parameter("blur_amount", 0.0)
	_bg_rect.material = _blur_mat
	add_child(_bg_rect)
	for i in range(1, BG_FRAME_COUNT + 1):
		var p := "%s/frame_%03d.webp" % [BG_FRAMES_DIR, i]
		if ResourceLoader.exists(p):
			_frames.append(load(p))

func _process(delta: float) -> void:
	_tick_bg(delta)
	_tick_title(delta)

# Derulează cadrele „ping-pong" (înainte, apoi înapoi), ca reluarea să nu aibă tăietură.
func _tick_bg(delta: float) -> void:
	if not _animating or _frames.size() < 2:
		return
	_frame_t += delta
	var step := 1.0 / BG_FPS
	while _frame_t >= step:
		_frame_t -= step
		_frame_i += _frame_dir
		if _frame_i >= _frames.size():
			_frame_i = _frames.size() - 2
			_frame_dir = -1
		elif _frame_i < 0:
			_frame_i = 1
			_frame_dir = 1
		_bg_rect.texture = _frames[_frame_i]

# strat întunecat peste video, ca textul alb să rămână lizibil peste imagini deschise
func _tint_overlay() -> void:
	_tint = ColorRect.new()
	_tint.color = Color(0.02, 0.02, 0.06, 0.55)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

func _set_blur(v: float) -> void:
	if _blur_mat:
		_blur_mat.set_shader_parameter("blur_amount", v)

# Intro: 1 secundă video curat (fără titlu, fără butoane) → blur + titlu → butoanele.
func _play_intro() -> void:
	_set_blur(0.0)
	_tint.modulate.a = 0.0
	_vig.modulate.a = 0.0
	_title_group.modulate.a = 0.0
	_main_buttons.modulate.a = 0.0
	_main_buttons.visible = false   # ascunse de tot, ca să nu poți da click pe ele în intro

	await get_tree().create_timer(INTRO_CLEAR).timeout

	# de aici încolo imaginea e blurată, deci trecem pe cadrele mici — nu se vede diferența
	_animating = true

	# blur, întunecare și titlu intră toate odată
	var t := create_tween().set_parallel(true)
	t.tween_method(_set_blur, 0.0, MENU_BLUR, INTRO_FADE)
	t.tween_property(_tint, "modulate:a", 1.0, INTRO_FADE)
	t.tween_property(_vig, "modulate:a", 1.0, INTRO_FADE)
	t.tween_property(_title_group, "modulate:a", 1.0, INTRO_FADE)
	await t.finished

	_main_buttons.visible = true
	create_tween().tween_property(_main_buttons, "modulate:a", 1.0, INTRO_BUTTONS)

# fundal cu gradient vertical (mov-navy închis → aproape negru) — rezervă, dacă lipsește video-ul
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
	_vig = tr

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
	# titlul și subtitlul stau împreună, ca să le pot stinge/aprinde dintr-o mișcare la intro
	_title_group = VBoxContainer.new()
	_title_group.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_title_group)
	_title_group.add_child(_build_title())
	# subtitlul „CYBER SURVIVOR" a fost scos când a intrat logo-ul: numele e deja în logo,
	# iar textul cyan se bătea cu stilul de lemn. Ca să-l aduci înapoi, adaugi aici un
	# _center_label(...) în _title_group și scazi TITLE_SIZE cu ~40, altfel nu mai încape.
	box.add_child(_spacer(16))
	# la fel, butoanele într-un grup separat — apar după titlu
	_main_buttons = VBoxContainer.new()
	_main_buttons.add_theme_constant_override("separation", 14)
	_main_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_main_buttons)
	_main_buttons.add_child(_menu_button("START", _on_start))
	_main_buttons.add_child(_menu_button("CHOOSE CHARACTER", _show.bind("character")))
	_main_buttons.add_child(_menu_button("CHOOSE WEAPON", _show.bind("weapon")))
	_main_buttons.add_child(_menu_button("UPGRADES", _on_shop))
	_main_buttons.add_child(_menu_button("LEADERBOARD", _on_leaderboard))

# Logo-ul animat, în locul vechiului titlu scris cu text.
# Dacă lipsesc cadrele, ne întoarcem la titlul-text, ca meniul să nu rămână gol.
func _build_title() -> Control:
	for i in range(1, TITLE_FRAME_COUNT + 1):
		var p := "%s/title_%d.png" % [TITLE_DIR, i]
		if ResourceLoader.exists(p):
			_title_frames.append(load(p))
	if _title_frames.is_empty():
		var l := _center_label("Nicotine & Knives", 78)
		l.add_theme_color_override("font_color", ACCENT)
		l.add_theme_color_override("font_outline_color", Color(ACCENT2.r, ACCENT2.g, ACCENT2.b, 0.9))
		l.add_theme_constant_override("outline_size", 8)
		return l
	_title_rect = TextureRect.new()
	_title_rect.texture = _title_frames[0]
	_title_rect.custom_minimum_size = Vector2(TITLE_SIZE, TITLE_SIZE)
	_title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _title_rect

# aceeași idee ca la fundal: înainte, apoi înapoi (1→2→3→4→3→2→...)
func _tick_title(delta: float) -> void:
	if _title_rect == null or _title_frames.size() < 2:
		return
	_title_t += delta
	while _title_t >= TITLE_FRAME_TIME:
		_title_t -= TITLE_FRAME_TIME
		_title_i += _title_dir
		if _title_i >= _title_frames.size():
			_title_i = _title_frames.size() - 2
			_title_dir = -1
		elif _title_i < 0:
			_title_i = 1
			_title_dir = 1
		_title_rect.texture = _title_frames[_title_i]

func _on_start() -> void:
	Audio.stop_music()   # tema de meniu se oprește când intri în joc
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
			# scorurile vechi (dinainte de kill count) n-au cheia "kills" → 0
			var k: int = int(s.get("kills", 0))
			var linie := "%d.   %d:%02d   ·   Level %d   ·   %d kills" % [rank, m, sec, s["level"], k]
			if float(s["time"]) >= Difficulty.RUN_LENGTH:
				linie += "   ·   SURVIVED"   # a apucat Final Swarm
			_lb_list.add_child(_center_label(linie, 22))
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
