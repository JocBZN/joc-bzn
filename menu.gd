extends Control

# Meniul principal (main scene). Tot UI-ul e construit din cod, stilizat „cyberpunk":
# fundal cu gradient + vignette, titlu cu glow neon, butoane cu borduri cyan.

const GAME_SCENE := "res://main.tscn"
const ACCENT := Color(0.2, 0.9, 1.0)    # cyan — a mai rămas doar pentru fallback-ul de titlu
const ACCENT2 := Color(1.0, 0.2, 0.6)   # magenta

# Culorile butoanelor de meniu (lemn, ca logo-ul). Schimbă-le doar aici — toate butoanele
# mari (START, BACK etc.) își iau culoarea din ele, în `_menu_button()`.
const BTN_MAIN := Color("9e603f")     # principala: umplutura butonului
const BTN_SECOND := Color("594232")   # secundara: conturul

# Auriul ramei ornate (`Menu.png`), folosit la titlurile de pagină. Înainte titlurile erau
# cyan cu glow magenta — rămășiță din tema cyberpunk de dinainte de logo, care se bătea cap
# în cap cu lemnul (același motiv pentru care a fost scos subtitlul „CYBER SURVIVOR").
const TITLU := Color(0.95, 0.85, 0.55)

# Arta de UI din joc, refolosită aici ca meniul și ecranul de level up să arate din același
# joc: rama ornată pe sub-pagini, chenarele de raritate în jurul armelor.
const UI_DIR := "res://Upgrades/Menu UI/"
const RAMA := UI_DIR + "Menu.png"
# Cât ține ornamentul ramei, în pixeli de textură — adică ce NU trebuie întins de nine-patch.
# MĂSURAT pe `Menu.png` (400x328), nu ghicit: umplutura interioară începe la 61px din stânga,
# 60 din dreapta, 50 de sus și 48 de jos. `levelup.gd` folosește 46 peste tot, ceea ce lasă
# ~15px de ornament în zona întinsă — la panoul lui, care e mare și fix, nu se vede; aici,
# pe panouri mici care se strâng pe conținut, colțurile ieșeau vizibil trase.
const RAMA_MARG_LAT := 62
const RAMA_MARG_SUS := 52
const RAMA_MARG_JOS := 50
# Spațiul dintre ramă și conținut: ornamentul + câțiva pixeli, ca textul să nu se lipească.
const RAMA_PAD_LAT := 72
const RAMA_PAD_SUS := 58
const RAMA_PAD_JOS := 56
const BORDER_SEL := UI_DIR + "Border Rare.png"      # verde = ales (ca verdele de selecție de până acum)
const BORDER_NESEL := UI_DIR + "Border Common.png"  # albastru-gri = neales
const CELULA := 132.0    # latura unei celule de armă (chenar + iconiță)
const ICON_PAD := 16     # cât intră iconița în interiorul chenarului, ca să nu calce ornamentul

var WEAPONS := [
	{"id": "pistol",       "name": "PISTOL",       "icon": "res://weapons_icons/pistol.png"},
	{"id": "mage",         "name": "MAGE STAFF",   "icon": "res://weapons_icons/mage_staff.png"},
	{"id": "extinguisher", "name": "EXTINGUISHER", "icon": "res://weapons_icons/stingator.png"},
	{"id": "sword",        "name": "CURSED SWORD", "icon": "res://weapons_icons/cursed sword.png"},
]

const BG_STILL := "res://menu/bg_still.webp"        # cadru clar (1080p), rezervă dacă lipsesc cadrele
const BG_FRAMES_DIR := "res://menu/bg_frames"       # cadrele de animație (1920x1080)
const BG_FRAME_COUNT := 60
const BG_FPS := 10.0
const BLUR_SHADER := "res://menu/menu_blur.gdshader"

const TITLE_DIR := "res://menu/Title"       # logo-ul animat (4 cadre, 256x256)
const TITLE_FRAME_COUNT := 4
const TITLE_FRAME_TIME := 0.4               # secunde per cadru (mai mare = mai lent)
const TITLE_SIZE := 240                     # cât de mare se afișează logo-ul, în pixeli
# ATENȚIE la înălțime: ecranul de referință are 648px, iar cele 4 butoane ocupă 274
# (4 × 58 + 3 × 14 separare). Deci logo + spațiere trebuie să stea sub ~346, altfel
# butonul LEADERBOARD iese din ecran. Acum: 240 + 16 = 256, deci e loc berechet.
# (Erau 5 butoane până pe 2026-07-27, când a dispărut UPGRADES.)

# --- reglaje pentru intro (schimbă-le liniștit, sunt doar de gust) ---
const INTRO_CLEAR := 1.0      # câte secunde rulează video-ul curat, fără nimic peste el
const INTRO_FADE := 0.6       # cât durează să intre blur-ul + titlul
const INTRO_HOLD := 1.0       # cât stă titlul singur în mijloc, înainte să urce
const INTRO_RISE := 0.7       # cât durează urcarea titlului spre locul lui final
const INTRO_BUTTONS := 0.35   # cât durează să apară butoanele
const MENU_BLUR := 3.0        # cât de tare e blur-ul la final (0 = deloc, 8 = maxim)

var _panels := {}
var _weapon_buttons := []
var _lb_list: VBoxContainer

var _bg_rect: TextureRect       # fundalul (întâi cadrul clar, apoi cadrele animate)
var _bg_next: TextureRect       # cadrul următor, peste primul, pentru trecerea lină
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
var _title_group: Control       # slot de mărime fixă; ține locul titlului în layout
var _title_mover: Control       # titlul propriu-zis, mutat liber în interiorul slotului
var _intro_running := false     # cât e true, o apăsare pe ecran sare peste intro
var _intro_tweens: Array[Tween] = []   # tween-urile intro-ului, ca să le pot opri la skip
var _main_buttons: VBoxContainer
var _settings_btn: Button           # roata dințată din colțul dreapta-sus (deschide Settings)
var _settings_ui: SettingsUI        # blocul refolosibil de setări (volume + remapare taste)
var _lang_btn: Button               # steagul de lângă rotiță (deschide alegerea limbii)
var _lang_buttons := {}             # cod limbă -> butonul din panoul LANGUAGE (pentru evidențiere)
var _op_btn: Button                 # „OP", al treilea din colț (deschide OP START)
var _op_toggle: Button              # butonul ON/OFF din panoul OP START

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
	_build_settings()
	_build_language()
	_build_opstart()
	_show("main")
	Audio.stop_forest_ambient()   # ambientul de pădure e doar în joc, nu în meniu
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
const CLICK_DB := -3.0

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
# Cadrele sunt la 1920x1080, adică exact rezoluția sursei — nu mărite din ceva mic.
# (Au fost 640x360, pe ideea că se văd doar blurate; dar animația pornește din primul cadru,
#  deci în secunda de intro, cât imaginea e CLARĂ, se vedea o poză mărită de 3 ori.)
#
# ⚠️ Import-ul lor e „VRAM Compressed" (`compress/mode=2` în .import), NU lossless. La 60 de
# cadre 1080p, lossless ar însemna 1920·1080·4 B fiecare = ~486 MB de memorie video, ceea ce
# nu merge nicăieri, cu atât mai puțin pe telefon. Comprimate, tot pachetul stă în ~62 MB.
# Dacă regenerezi cadrele, verifică să rămână pe `compress/mode=2`.
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
	# Al doilea strat, exact peste primul: ține cadrul URMĂTOR și i se plimbă transparența
	# de la 0 la 1 între cadre. Fără el, la 10 fps mișcarea se vede în trepte.
	_bg_next = TextureRect.new()
	_bg_next.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_next.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_next.material = _blur_mat      # același material: se blurează la fel ca stratul de jos
	_bg_next.modulate.a = 0.0
	add_child(_bg_next)
	for i in range(1, BG_FRAME_COUNT + 1):
		var p := "%s/frame_%03d.webp" % [BG_FRAMES_DIR, i]
		if ResourceLoader.exists(p):
			_frames.append(load(p))
	# animația pornește din prima, nu după intro: fundalul e viu de la primul cadru.
	# Cadrul static rămâne doar ca rezervă, dacă lipsesc cadrele animate.
	if _frames.size() >= 2:
		_bg_rect.texture = _frames[0]
		_animating = true

func _process(delta: float) -> void:
	_tick_bg(delta)
	_tick_title(delta)

# Derulează cadrele „ping-pong" (înainte, apoi înapoi), ca reluarea să nu aibă tăietură.
# Sursa are doar 10 cadre pe secundă, deci între ele se face trecere lină (cross-fade):
# stratul de jos ține cadrul curent, cel de sus cadrul următor, iar transparența lui
# urcă de la 0 la 1 pe durata unui cadru. Altfel imaginea sare din 10 în 10 cadre.
func _tick_bg(delta: float) -> void:
	if not _animating or _frames.size() < 2:
		return
	_frame_t += delta
	var step := 1.0 / BG_FPS
	while _frame_t >= step:
		_frame_t -= step
		_advance_frame()
	_bg_rect.texture = _frames[_frame_i]
	_bg_next.texture = _frames[_peek_next_frame()]
	_bg_next.modulate.a = clampf(_frame_t / step, 0.0, 1.0)

func _advance_frame() -> void:
	_frame_i += _frame_dir
	if _frame_i >= _frames.size():
		_frame_i = _frames.size() - 2
		_frame_dir = -1
	elif _frame_i < 0:
		_frame_i = 1
		_frame_dir = 1

# Ce cadru urmează, FĂRĂ să mișc starea — la capete ping-pong-ul se întoarce, deci
# „următorul" nu e mereu `_frame_i + 1`.
func _peek_next_frame() -> int:
	var i := _frame_i + _frame_dir
	if i >= _frames.size():
		i = _frames.size() - 2
	elif i < 0:
		i = 1
	return i

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

# Intro: fundal animat curat → blur + titlul apare în mijloc → titlul urcă la locul lui,
# iar butoanele apar din spatele lui. Butoanele își țin locul în layout tot timpul (doar
# transparente + dezactivate), altfel titlul ar sări brusc când apar ele.
func _play_intro() -> void:
	_intro_running = true
	_set_blur(0.0)
	_tint.modulate.a = 0.0
	_vig.modulate.a = 0.0
	_title_group.modulate.a = 0.0
	_main_buttons.modulate.a = 0.0
	_settings_btn.modulate.a = 0.0
	_lang_btn.modulate.a = 0.0
	_op_btn.modulate.a = 0.0
	_set_buttons_enabled(false)   # invizibile, dar tot ocupă loc — deci nu se poate da click

	# layout-ul se calculează abia după un cadru; până atunci pozițiile sunt încă zero
	await get_tree().process_frame
	if not _intro_running: return
	var rise := _title_rise_offset()
	_title_mover.position.y = rise

	await get_tree().create_timer(INTRO_CLEAR).timeout
	if not _intro_running: return

	# blur, întunecare și titlu intră toate odată
	var t := create_tween().set_parallel(true)
	_intro_tweens.append(t)
	t.tween_method(_set_blur, 0.0, MENU_BLUR, INTRO_FADE)
	t.tween_property(_tint, "modulate:a", 1.0, INTRO_FADE)
	t.tween_property(_vig, "modulate:a", 1.0, INTRO_FADE)
	t.tween_property(_title_group, "modulate:a", 1.0, INTRO_FADE)
	await t.finished
	if not _intro_running: return

	# o pauză în care titlul stă singur în mijloc
	await get_tree().create_timer(INTRO_HOLD).timeout
	if not _intro_running: return

	# titlul alunecă în sus spre locul lui, iar butoanele se aprind pe la jumătatea drumului
	var t2 := create_tween().set_parallel(true)
	_intro_tweens.append(t2)
	t2.tween_property(_title_mover, "position:y", 0.0, INTRO_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(_main_buttons, "modulate:a", 1.0, INTRO_BUTTONS) \
		.set_delay(INTRO_RISE * 0.5)
	t2.tween_property(_settings_btn, "modulate:a", 1.0, INTRO_BUTTONS) \
		.set_delay(INTRO_RISE * 0.5)
	t2.tween_property(_lang_btn, "modulate:a", 1.0, INTRO_BUTTONS) \
		.set_delay(INTRO_RISE * 0.5)
	t2.tween_property(_op_btn, "modulate:a", 1.0, INTRO_BUTTONS) \
		.set_delay(INTRO_RISE * 0.5)
	await t2.finished
	if not _intro_running: return

	_intro_running = false
	_intro_tweens.clear()
	_set_buttons_enabled(true)

# Orice apăsare pe ecran (sau tastă) în timpul intro-ului sare direct la meniul gata.
func _input(event: InputEvent) -> void:
	if not _intro_running:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		get_viewport().set_input_as_handled()
		_skip_intro()

# Duce intro-ul direct în starea finală: oprește tween-urile pornite (altfel ar continua
# să scrie peste valorile puse aici) și pune totul la valorile de final.
func _skip_intro() -> void:
	_intro_running = false   # oprește și corutina _play_intro la următorul await
	for t in _intro_tweens:
		if is_instance_valid(t) and t.is_valid():
			t.kill()
	_intro_tweens.clear()

	_set_blur(MENU_BLUR)
	_tint.modulate.a = 1.0
	_vig.modulate.a = 1.0
	_title_group.modulate.a = 1.0
	_main_buttons.modulate.a = 1.0
	_settings_btn.modulate.a = 1.0
	_lang_btn.modulate.a = 1.0
	_op_btn.modulate.a = 1.0
	_title_mover.position.y = 0.0

	# butoanele se activează abia din cadrul următor, ca apăsarea care a dat skip să nu
	# ajungă din greșeală pe START
	await get_tree().process_frame
	_set_buttons_enabled(true)

# Cât de jos pornește titlul: exact atât cât să fie centrat pe ecran, ca înainte de a urca.
func _title_rise_offset() -> float:
	if _title_mover == null:
		return 0.0
	var center_y := _title_mover.global_position.y + _title_mover.size.y * 0.5
	return size.y * 0.5 - center_y

func _set_buttons_enabled(on: bool) -> void:
	for b in _main_buttons.get_children():
		if b is BaseButton:
			b.disabled = not on
	if _settings_btn != null:
		_settings_btn.disabled = not on
	if _lang_btn != null:
		_lang_btn.disabled = not on
	if _op_btn != null:
		_op_btn.disabled = not on

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

# `titlu` = numele paginii, desenat DEASUPRA ramei, nu în ea. Două motive: ornamentul de sus
# al ramei e mai gros decât marginea nine-patch, deci un titlu pus înăuntru se lipea de el; și
# scoate ~66px din interior, de care pagina SETTINGS chiar avea nevoie ca să încapă în ecran.
#
# `cu_rama` = pagina primește chenarul ornat din joc (`Menu.png`). Meniul principal NU-l
# vrea — acolo logo-ul stă peste fundalul animat și o ramă în jur ar sufoca imaginea; toate
# sub-paginile îl primesc, ca să fie clar că sunt „ferestre" și ca să semene cu level up-ul.
func _make_panel(key: String, titlu: String = "", cu_rama: bool = true) -> VBoxContainer:
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
	if cu_rama:
		var afara := VBoxContainer.new()   # titlul + rama, unul sub altul
		afara.add_theme_constant_override("separation", 10)
		afara.alignment = BoxContainer.ALIGNMENT_CENTER
		if titlu != "":
			afara.add_child(_header(titlu))
		afara.add_child(_rama_container(box))
		center.add_child(afara)
	else:
		center.add_child(box)
	return box

# Rama ornată care se strânge exact pe conținut.
#
# De ce PanelContainer + StyleBoxTexture și nu un NinePatchRect ca în `levelup.gd`: acolo
# panoul are mărime FIXĂ, deci NinePatch-ul e potrivit. Aici paginile au înălțimi diferite
# (LEADERBOARD crește cu scorurile, SETTINGS e cea mai înaltă), iar un NinePatchRect nu se
# strânge singur pe copii. PanelContainer face exact asta: își ia mărimea din conținut și
# desenează stilul în spate.
func _rama_container(continut: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = load(RAMA)
	# cât din textură e „colț/margine" și nu se întinde
	sb.texture_margin_left = RAMA_MARG_LAT
	sb.texture_margin_right = RAMA_MARG_LAT
	sb.texture_margin_top = RAMA_MARG_SUS
	sb.texture_margin_bottom = RAMA_MARG_JOS
	# spațiul dintre ramă și text; trebuie clar peste ornament, altfel textul se lipește de el
	sb.content_margin_left = RAMA_PAD_LAT
	sb.content_margin_right = RAMA_PAD_LAT
	sb.content_margin_top = RAMA_PAD_SUS
	sb.content_margin_bottom = RAMA_PAD_JOS
	p.add_theme_stylebox_override("panel", sb)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art: fără înmuiere
	p.add_child(continut)
	return p

# ---------- MAIN ----------
func _build_main() -> void:
	var box := _make_panel("main", "", false)   # fără ramă: logo peste fundalul animat
	# Titlul stă într-un slot de mărime fixă, NU direct în VBox. Motivul: un container își
	# rescrie copiii la fiecare layout, deci nu i-aș putea anima poziția — iar slotul ține
	# locul ocupat, așa că restul meniului nu se mișcă atunci când titlul urcă la intro.
	_title_group = Control.new()
	_title_group.custom_minimum_size = Vector2(TITLE_SIZE, TITLE_SIZE)
	_title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title_group)
	_title_mover = _build_title()
	_title_group.add_child(_title_mover)
	_title_mover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# subtitlul „CYBER SURVIVOR" a fost scos când a intrat logo-ul: numele e deja în logo,
	# iar textul cyan se bătea cu stilul de lemn. Ca să-l aduci înapoi, adaugi aici un
	# _center_label(...) în _title_group și scazi TITLE_SIZE cu ~40, altfel nu mai încape.
	box.add_child(_spacer(16))
	# la fel, butoanele într-un grup separat — apar după titlu
	_main_buttons = VBoxContainer.new()
	_main_buttons.add_theme_constant_override("separation", 14)
	_main_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_main_buttons)
	_main_buttons.add_child(_menu_button("START", _on_start, true))
	_main_buttons.add_child(_menu_button("CHOOSE CHARACTER", _show.bind("character")))
	_main_buttons.add_child(_menu_button("CHOOSE WEAPON", _show.bind("weapon")))
	_main_buttons.add_child(_menu_button("LEADERBOARD", _on_leaderboard))
	# Butoanele mici de sus NU stau în lista verticală (ar înghesui-o și ar ieși din ecran).
	# Sunt ancorate în colțul dreapta-sus: rotița de Settings, iar la stânga ei steagul de limbă.
	_settings_btn = _corner_button(_show.bind("settings"), 0)
	_settings_btn.text = "⚙"
	_settings_btn.add_theme_font_size_override("font_size", 26)
	_settings_btn.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	_panels["main"].add_child(_settings_btn)

	_lang_btn = _corner_button(_show.bind("language"), 1)
	_lang_btn.expand_icon = true
	# pixel art: fără filtrare, altfel steagul de 24x16 iese neclar când e mărit
	_lang_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Marginile normale (14 px lateral) ar lăsa steagului doar 24px din cei 52 ai butonului,
	# deci ar ieși un timbru pierdut în mijloc. Aici le strângem, ca să umple butonul.
	for stare in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = _lang_btn.get_theme_stylebox(stare).duplicate()
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		_lang_btn.add_theme_stylebox_override(stare, sb)
	_panels["main"].add_child(_lang_btn)
	_refresh_lang_button()

	# al treilea din colț: cheat-ul de testare. Nu e ascuns după vreo combinație de taste —
	# jocul e al lui Răzvan și el e cel care testează.
	_op_btn = _corner_button(_show.bind("opstart"), 2)
	_op_btn.text = "OP"
	_op_btn.add_theme_font_size_override("font_size", 20)
	_panels["main"].add_child(_op_btn)
	_refresh_op_button()

# Un buton pătrat de 52x52 lipit de colțul dreapta-sus. `pozitie` = al câtelea e, numărând de
# la dreapta spre stânga (0 = primul din colț), ca să nu repet offset-urile la fiecare buton.
func _corner_button(cb: Callable, pozitie: int) -> Button:
	const MARIME := 52
	const MARGINE := 16
	const SPATIU := 10
	var b := Button.new()
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND, 3))
	b.add_theme_stylebox_override("hover", _sb(BTN_MAIN.lightened(0.10), BTN_SECOND.lightened(0.10), 3))
	b.add_theme_stylebox_override("pressed", _sb(BTN_MAIN.lightened(0.20), BTN_SECOND.lightened(0.20), 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	var dreapta := MARGINE + pozitie * (MARIME + SPATIU)
	b.offset_left = -(dreapta + MARIME)
	b.offset_right = -dreapta
	b.offset_top = MARGINE
	b.offset_bottom = MARGINE + MARIME
	b.pressed.connect(cb)
	return b

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
	var box := _make_panel("weapon", "CHOOSE WEAPON")
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
		# Butonul e doar zona de click (transparentă); ce se vede sunt chenarul de raritate
		# și iconița din el — aceeași construcție ca rândurile din `levelup.gd`, ca alegerea
		# armei să arate din același joc ca ecranul de level up.
		var b := Button.new()
		b.custom_minimum_size = Vector2(CELULA, CELULA)
		b.flat = true
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_weapon_chosen.bind(String(w["id"])))
		slot.add_child(b)

		var chenar := TextureRect.new()
		chenar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chenar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chenar.stretch_mode = TextureRect.STRETCH_SCALE
		chenar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chenar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(chenar)

		var poza := TextureRect.new()
		if ResourceLoader.exists(w["icon"]):
			poza.texture = load(w["icon"])
		# iconița stă ÎN interiorul chenarului, nu peste el
		poza.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		poza.offset_left = ICON_PAD
		poza.offset_top = ICON_PAD
		poza.offset_right = -ICON_PAD
		poza.offset_bottom = -ICON_PAD
		poza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		poza.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		poza.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(poza)

		_weapon_buttons.append({"buton": b, "chenar": chenar})
		_viata(b)
		slot.add_child(_center_label(w["name"], 18))
	_refresh_weapon_selection()
	box.add_child(_spacer(22))
	box.add_child(_menu_button("BACK", _show.bind("main")))

func _on_weapon_chosen(id: String) -> void:
	GameSettings.weapon_type = id
	_refresh_weapon_selection()

# Arma aleasă primește chenarul verde (Rare), restul pe cel albastru-gri (Common), plus o
# ușoară întunecare — se vede dintr-o privire care e alegerea curentă.
func _refresh_weapon_selection() -> void:
	for i in _weapon_buttons.size():
		var sel: bool = WEAPONS[i]["id"] == GameSettings.weapon_type
		var chenar: TextureRect = _weapon_buttons[i]["chenar"]
		chenar.texture = load(BORDER_SEL if sel else BORDER_NESEL)
		var b: Button = _weapon_buttons[i]["buton"]
		b.modulate = Color(1, 1, 1) if sel else Color(0.72, 0.72, 0.76)

# ---------- CHOOSE CHARACTER (placeholder) ----------
func _build_character() -> void:
	var box := _make_panel("character", "CHOOSE CHARACTER")
	box.add_child(_center_label("Only one character for now: \"Grasu\".\nMore coming soon!", 20))
	box.add_child(_spacer(24))
	box.add_child(_menu_button("BACK", _show.bind("main")))

# ---------- LEADERBOARD ----------
func _build_leaderboard() -> void:
	var box := _make_panel("leaderboard", "LEADERBOARD")
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
			# tr(...) explicit: textul are %d-uri, deci traducerea automată n-ar găsi nimic
			# după ce numerele sunt deja puse în el (vezi i18n.gd)
			var linie: String = tr("%d.   %d:%02d   ·   Level %d   ·   %d kills") % [rank, m, sec, s["level"], k]
			if float(s["time"]) >= Difficulty.RUN_LENGTH:
				linie += "   ·   " + tr("SURVIVED")   # a apucat Final Swarm
			_lb_list.add_child(_center_label(linie, 22))
			rank += 1
	_show("leaderboard")

# ---------- LANGUAGE ----------
# Panoul cu cele 9 limbi, deschis din butonul-steag de sus. Fiecare limbă e un buton cu
# steagul mare și numele scris ÎN limba respectivă (așa îl recunoaște oricine, chiar dacă
# meniul e momentan într-o limbă pe care n-o înțelege).
#
# Textele NU se rescriu de mână la schimbare: `TranslationServer.set_locale()` anunță toate
# nodurile, iar Label/Button își traduc singure textul (vezi i18n.gd). Aici doar mutăm
# evidențierea pe limba nouă și schimbăm steagul de pe butonul din colț.
const LANG_CELL := Vector2(132, 74)   # mărimea butonului cu steag (numele stă sub el)

func _build_language() -> void:
	var box := _make_panel("language", "LANGUAGE")
	box.add_child(_spacer(10))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	_lang_buttons.clear()
	# ca la „CHOOSE WEAPON": butonul ține doar imaginea, numele e o etichetă sub el
	for l in I18n.LIMBI:
		var cod := String(l["cod"])
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 4)
		grid.add_child(slot)
		var b := Button.new()
		b.custom_minimum_size = LANG_CELL
		b.icon = I18n.steag(cod)
		b.expand_icon = true
		# pixel art: fără filtrare, altfel steagul de 24x16 iese neclar când e mărit
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_language_chosen.bind(cod))
		slot.add_child(b)
		_lang_buttons[cod] = b
		# numele scris ÎN limba lui, deci NU se traduce (de-aia nu e o cheie în i18n.gd)
		slot.add_child(_center_label(String(l["nume"]), 18))
	_refresh_language_selection()
	box.add_child(_spacer(22))
	box.add_child(_menu_button("BACK", _show.bind("main")))

func _on_language_chosen(cod: String) -> void:
	I18n.schimba_limba(cod)
	_refresh_language_selection()
	_refresh_lang_button()

# Limba activă are chenar verde, ca arma aleasă în „CHOOSE WEAPON".
func _refresh_language_selection() -> void:
	for cod in _lang_buttons:
		var sel: bool = cod == GameSettings.language
		var b: Button = _lang_buttons[cod]
		var bg := Color(0.10, 0.24, 0.16, 0.95) if sel else BTN_MAIN
		var bd := Color(0.4, 1.0, 0.5) if sel else BTN_SECOND
		b.add_theme_stylebox_override("normal", _sb(bg, bd, 3))
		b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.10), bd.lightened(0.10), 3))
		b.add_theme_stylebox_override("pressed", _sb(bg.lightened(0.20), bd.lightened(0.20), 3))

func _refresh_lang_button() -> void:
	if _lang_btn != null:
		_lang_btn.icon = I18n.steag(GameSettings.language)

# ---------- OP START ----------
# Cheat de testare: runda pornește cu statusuri de final, ca să se poată ajunge repede la Nether,
# Ender și Celesto fără să joci 20 de minute până acolo.
#
# E o PAGINĂ, nu un buton care comută direct din colț, din două motive: scrie negru pe alb ce
# primești (altfel ar trebui să ții minte trei cifre), și se poartă ca toate celelalte butoane
# din colț, care deschid pagini. Butonul „OP" din colț se face VERDE cât e pornit, deci starea
# se vede fără să intri.
#
# Cifrele vin din `GameSettings` (`OP_DAMAGE`, `OP_ATTACK_SPEED`, `OP_PROJECTILES`) — aceleași pe
# care le aplică `player.gd`. Scrise de mână aici, pagina ar fi ajuns să mintă după prima reglare.
const OP_VERDE_BG := Color(0.10, 0.24, 0.16, 0.95)
const OP_VERDE_BD := Color(0.4, 1.0, 0.5)

func _build_opstart() -> void:
	var box := _make_panel("opstart", "OP START")
	box.add_child(_op_rand("Damage", str(GameSettings.OP_DAMAGE)))
	box.add_child(_op_rand("Attack Speed", "%.2f/s" % GameSettings.OP_ATTACK_SPEED))
	box.add_child(_op_rand("Projectiles", str(GameSettings.OP_PROJECTILES)))
	box.add_child(_spacer(18))
	_op_toggle = _menu_button("ON" if GameSettings.op_start else "OFF", _on_op_toggle)
	box.add_child(_op_toggle)
	box.add_child(_spacer(10))
	box.add_child(_menu_button("BACK", _show.bind("main")))
	_refresh_op_toggle()

# „Damage            100" — numele se traduce (cheile există deja, sunt cele din panoul de
# statusuri din joc), cifra nu are ce să traducă.
func _op_rand(nume: String, valoare: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = nume
	l.add_theme_font_size_override("font_size", 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := Label.new()
	v.text = valoare
	v.add_theme_font_size_override("font_size", 22)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.custom_minimum_size = Vector2(120, 0)
	v.add_theme_color_override("font_color", OP_VERDE_BD)
	h.add_child(v)
	return h

func _on_op_toggle() -> void:
	GameSettings.set_op_start(not GameSettings.op_start)
	_refresh_op_toggle()
	_refresh_op_button()

# Textul se scrie în ENGLEZĂ, ca peste tot în joc — Godot traduce singur ce e pe Button (vezi
# `i18n.gd`), inclusiv textul pus din cod. Cu `tr()` aici ar fi ieșit invers: în buton ar fi
# ajuns un text deja tradus, care nu s-ar mai fi schimbat la schimbarea limbii.
func _refresh_op_toggle() -> void:
	if _op_toggle == null:
		return
	var on: bool = GameSettings.op_start
	_op_toggle.text = "ON" if on else "OFF"
	if on:
		_op_toggle.add_theme_stylebox_override("normal", _sb(OP_VERDE_BG, OP_VERDE_BD, 3))
		_op_toggle.add_theme_stylebox_override("hover", _sb(OP_VERDE_BG.lightened(0.10), OP_VERDE_BD.lightened(0.10), 3))
		_op_toggle.add_theme_stylebox_override("pressed", _sb(OP_VERDE_BG.lightened(0.20), OP_VERDE_BD.lightened(0.20), 3))
	else:
		_op_toggle.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND, 3))
		_op_toggle.add_theme_stylebox_override("hover", _sb(BTN_MAIN.lightened(0.10), BTN_SECOND.lightened(0.10), 3))
		_op_toggle.add_theme_stylebox_override("pressed", _sb(BTN_MAIN.lightened(0.20), BTN_SECOND.lightened(0.20), 3))

# Butonul din colț se aprinde verde cât cheat-ul e pornit — ca arma aleasă și limba activă.
# Marginile se strâng la 6px, ca la butonul-steag: cu cele obișnuite (14 lateral) rămâneau 24px
# din cei 52 ai butonului, iar „OP" ieșea tăiat.
func _refresh_op_button() -> void:
	if _op_btn == null:
		return
	var on: bool = GameSettings.op_start
	var bg := OP_VERDE_BG if on else BTN_MAIN
	var bd := OP_VERDE_BD if on else BTN_SECOND
	_op_btn.add_theme_stylebox_override("normal", _sb_stramt(bg, bd))
	_op_btn.add_theme_stylebox_override("hover", _sb_stramt(bg.lightened(0.10), bd.lightened(0.10)))
	_op_btn.add_theme_stylebox_override("pressed", _sb_stramt(bg.lightened(0.20), bd.lightened(0.20)))
	_op_btn.add_theme_color_override("font_color", OP_VERDE_BD if on else Color(0.94, 0.89, 0.82))

func _sb_stramt(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := _sb(bg, border, 3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

# ---------- SETTINGS ----------
# Conținutul (volume + remapare taste) vine din componentul refolosibil SettingsUI, folosit și
# de meniul de pauză din joc (pause.gd). Aici doar îl încadrăm cu titlu + BACK.
# ⚠️ Pagina asta e cea mai ÎNALTĂ din meniu (2 slidere + 5 taste) și abia încape în cele
# 648px ale ecranului de referință, împreună cu rama. De aia n-are spațiatoare între blocuri,
# spre deosebire de celelalte pagini. Dacă mai adaugi un rând de setări, verifică pe o poză
# că rama nu iese din ecran — nu te avertizează nimic.
func _build_settings() -> void:
	var box := _make_panel("settings", "SETTINGS")
	_settings_ui = SettingsUI.new()
	box.add_child(_settings_ui)
	box.add_child(_menu_button("BACK", _on_settings_back))

func _on_settings_back() -> void:
	_settings_ui.cancel_remap()
	_show("main")

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

# `principal` = butonul cel mai important al paginii (START). E mai mare, mai luminos și cu
# text mai gras, ca ochiul să aibă de ce se agăța — înainte toate cele 4 butoane erau
# identice, deci nimic nu spunea „de aici începi".
func _menu_button(text: String, cb: Callable, principal: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 68) if principal else Vector2(340, 54)
	# fără asta, VBox-ul din interiorul ramei întinde butonul până în ornament
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 30 if principal else 22)
	b.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92) if principal else Color(0.94, 0.89, 0.82))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.99, 0.96))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	# Opace, NU transparente ca stilul vechi: cu transparență, butoanele de sus ieșeau
	# vizibil mai deschise decât cele de jos (transpărea cerul din fundalul blurat).
	# hover\pressed sunt aceleași culori, doar deschise treptat — nu culori noi de întreținut
	var baza := BTN_MAIN.lightened(0.10) if principal else BTN_MAIN
	var contur := BTN_SECOND.lightened(0.10) if principal else BTN_SECOND
	b.add_theme_stylebox_override("normal", _sb(baza, contur, 3))
	b.add_theme_stylebox_override("hover", _sb(baza.lightened(0.10), contur.lightened(0.10), 3))
	b.add_theme_stylebox_override("pressed", _sb(baza.lightened(0.20), contur.lightened(0.20), 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	_viata(b)
	return b

# Butonul crește puțin la hover și se „înfundă" la apăsare. Doar culoarea (cum era înainte)
# nu se simte — mișcarea, da.
#
# ⚠️ Se animează DOAR `scale`, niciodată `position`: butoanele stau în VBoxContainer-e, iar
# containerul își rescrie copiii la fiecare layout, deci o poziție animată ar fi ștearsă
# imediat (sau s-ar bate cu containerul). `scale` nu e atins de containere.
const HOVER_SCALE := 1.04
const PRESS_SCALE := 0.97
const HOVER_TIMP := 0.09

func _viata(b: Control) -> void:
	# pivotul trebuie să fie centrul, altfel butonul crește spre dreapta-jos; mărimea e
	# știută abia după primul layout, de aia îl punem la fiecare redimensionare
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(_scaleaza.bind(b, HOVER_SCALE))
	b.mouse_exited.connect(_scaleaza.bind(b, 1.0))
	if b is BaseButton:
		b.button_down.connect(_scaleaza.bind(b, PRESS_SCALE))
		# la ridicarea degetului: dacă mouse-ul e încă pe buton rămânem în hover
		b.button_up.connect(func(): _scaleaza(b, HOVER_SCALE if b.is_hovered() else 1.0))

func _scaleaza(b: Control, la: float) -> void:
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size * 0.5
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2(la, la), HOVER_TIMP).set_trans(Tween.TRANS_QUAD)

func _header(text: String) -> Label:
	var l := _center_label(text, 42)
	l.add_theme_color_override("font_color", TITLU)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.04, 0.9))
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
