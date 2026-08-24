extends VBoxContainer
class_name SettingsUI

# Bloc de setări REFOLOSIBIL, cu DOUĂ pagini:
#   • KEYBINDS — slidere de volum (Muzică / Efecte) + remaparea tastelor de mers;
#   • GRAPHICS — fullscreen, v-sync, vignette, glow.
# Sus e o bară cu două butoane care comută între ele; pagina deschisă are butonul mai luminos.
#
# Se folosește în DOUĂ locuri — meniul principal (menu.gd) și meniul de pauză din joc (pause.gd) —
# ca să nu ținem două copii ale logicii. Cel care-l pune deasupra adaugă singur titlul
# „SETTINGS" și butonul BACK; aici e doar conținutul.
#
# Își prinde singur tasta apăsată în _input când e în modul remapare. Nu are nevoie de altceva
# din exterior; citește/scrie totul prin autoload-ul GameSettings.

# Paleta e ACEEAȘI ca în `menu.gd` și `casino.gd` (arama chenarelor din `Border EGT.png`) —
# blocul ăsta se vede și în meniul principal, și în pauză, deci n-are voie să aibă stilul lui.
const ACCENT := Color8(198, 118, 80)
const ACCENT_CLAR := Color8(222, 152, 116)
const ACCENT_STINS := Color8(116, 62, 42)
const OS_ALB := Color8(232, 224, 214)
const BTN_MAIN := Color8(26, 22, 28)   # umplutura butonului (piatră închisă)
const BTN_SECOND := ACCENT_STINS       # conturul

var _remap_action := ""     # ce direcție așteaptă o tastă nouă (gol = nu remapăm acum)
var _remap_buttons := {}    # action -> butonul care arată tasta

# Ascultarea unui buton de pad (pagina GAMEPAD). E pe cu totul alt drum decât remaparea tastelor:
# tastele vin ca evenimente, butoanele se CITESC din starea controllerului — vezi `_process`.
const PAD_ASTEPTARE := 6.0  # câte secunde ascult înainte să renunț singur
var _remap_pad := ""        # ce rând așteaptă un buton nou (gol = nu ascult acum)
var _pad_butoane := {}      # action -> butonul care arată ce e legat
var _pad_timp := 0.0        # cât mai am de ascultat
var _pad_eliberat := false  # a fost controllerul lăsat liber de când am început să ascult?
var _pad_dupa := false      # tocmai am legat un buton: mai înghit ce vine până se lasă pad-ul

var _pagini := {}           # nume pagină -> VBoxContainer
var _taburi := {}           # nume pagină -> butonul din bara de sus

func _ready() -> void:
	# Ascultarea butonului de pad merge pe `_process`, iar blocul ăsta stă și în meniul de pauză,
	# unde jocul e OPRIT — fără linia asta numărătoarea ar sta pe loc fix acolo unde e cel mai
	# probabil să umble omul prin setări.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	add_theme_constant_override("separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_bara_taburi())
	_pagini["keybinds"] = _pagina_keybinds()
	_pagini["graphics"] = _pagina_graphics()
	_pagini["gamepad"] = _pagina_gamepad()
	for nume in _pagini:
		add_child(_pagini[nume])
	_egalizeaza_paginile()
	arata_pagina("keybinds")

# AMÂNDOUĂ PAGINILE OCUPĂ CÂT CEA MAI MARE (cerut de Răzvan pe 2026-08-15: „când dau între
# keybinds și graphics se schimbă mărimea ferestrei, dar eu vreau doar o mărime consistentă la
# ambele"). Comutarea ascunde o pagină și o arată pe cealaltă; un `Control` ascuns nu mai intră în
# socoteala containerului, așa că blocul se strângea la mărimea paginii deschise — și odată cu el
# rama ornată din meniu și cea din pauză, care se croiesc după conținut.
#
# Leacul: le dăm amândurora aceeași mărime minimă, cea mai mare dintre ele (și pe lățime, și pe
# înălțime). Pagina mai mică rămâne centrată în spațiul rezervat, deci rama nu mai mișcă deloc.
# Se face O SINGURĂ DATĂ, aici — dacă mai adaugi rânduri într-o pagină, se recalculează singur.
func _egalizeaza_paginile() -> void:
	var maxim := Vector2.ZERO
	for nume in _pagini:
		var m: Vector2 = _pagini[nume].get_combined_minimum_size()
		maxim.x = maxf(maxim.x, m.x)
		maxim.y = maxf(maxim.y, m.y)
	for nume in _pagini:
		_pagini[nume].custom_minimum_size = maxim

# ---------- paginile ----------
func _pagina_keybinds() -> VBoxContainer:
	var v := _pagina_goala()
	# volum: două slidere (0 = mut, dreapta = tare)
	v.add_child(_volume_row("MUSIC", GameSettings.music_volume, _on_music_volume))
	v.add_child(_volume_row("SOUND FX", GameSettings.sfx_volume, _on_sfx_volume))
	v.add_child(_spacer(6))
	v.add_child(_center_label("CONTROLS", 26))
	# câte un rând pentru fiecare direcție; apeși butonul și apoi tasta nouă
	for action in GameSettings.KEY_ACTIONS:
		v.add_child(_key_row(action))
	return v

func _pagina_graphics() -> VBoxContainer:
	var v := _pagina_goala()
	v.add_child(_toggle_row("FULLSCREEN", GameSettings.fullscreen, GameSettings.set_fullscreen))
	v.add_child(_toggle_row("V-SYNC", GameSettings.vsync, GameSettings.set_vsync))
	v.add_child(_spacer(6))
	v.add_child(_center_label("EFFECTS", 26))
	v.add_child(_spacer(4))
	v.add_child(_toggle_row("VIGNETTE", GameSettings.vignette, GameSettings.set_vignette))
	v.add_child(_toggle_row("GLOW", GameSettings.glow, GameSettings.set_glow))
	v.add_child(_spacer(8))
	# vignette/glow le desenează `atmosphere.gd`, care există doar în joc
	var nota := _center_label("effects apply in-game", 16)
	nota.modulate = Color(1, 1, 1, 0.55)
	v.add_child(nota)
	return v

# Pagina CONTROLLERULUI: ce controller e conectat, vibrația, și BUTOANELE — fiecare cu rândul lui,
# de schimbat.
#
# Se schimbă exact ca tastele de pe pagina KEYBINDS (apeși rândul, apoi butonul nou), doar că
# ascultarea se face cu totul altfel — vezi `_process`. MERSUL nu are rând de schimbat: stick-ul
# stâng și crucea sunt ȘI navigarea prin meniuri, deci mutarea lor ar fi însemnat un meniu prin
# care nu mai poți umbla — adică exact ecranul din care ai fi vrut să repari greșeala.
func _pagina_gamepad() -> VBoxContainer:
	var v := _pagina_goala()
	# rândul de sus: ce controller e conectat (se actualizează singur — vezi `_reimprospateaza_pad`)
	_pad_nume = _center_label("", 20)
	v.add_child(_pad_nume)
	v.add_child(_spacer(4))
	v.add_child(_toggle_row("VIBRATION", GameSettings.vibration, _on_vibration))
	v.add_child(_spacer(4))
	v.add_child(_center_label("BUTTONS", 26))
	v.add_child(_info_row("MOVE", "Stick / D-Pad"))
	for action in Gamepad.PAD_ACTIONS:
		v.add_child(_pad_row(action))
	v.add_child(_spacer(4))
	v.add_child(_reset_row())
	_reimprospateaza_pad()
	# numele controllerului și literele de pe butoane depind de ce e băgat în priză ACUM
	Input.joy_connection_changed.connect(func(_d, _c): _reimprospateaza_pad())
	return v

var _pad_nume: Label

# „INTERACT  [ A / X ]" — butonul din dreapta intră în ascultare la apăsare.
func _pad_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = Gamepad.PAD_ACTIONS[action]["eticheta"]
	l.custom_minimum_size = Vector2(160, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var b := _buton(Gamepad.nume_coduri(action), 20, Vector2(180, 32))
	b.pressed.connect(_begin_remap_pad.bind(action))
	_pad_butoane[action] = b
	row.add_child(b)
	return row

# Un singur buton, centrat sub listă: pune butoanele înapoi cum erau din fabrică. E plasa de
# siguranță a paginii — cine își încurcă legăturile pe un controller ciudat iese de aici fără să
# fie nevoit să-și amintească ce a legat unde.
func _reset_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := _buton("RESET", 18, Vector2(180, 28))
	b.pressed.connect(_on_reset_pad)
	row.add_child(b)
	return row

func _on_reset_pad() -> void:
	cancel_remap()
	Audio.play("button", -3.0, 0.0)
	Gamepad.reseteaza_butoanele()
	_reimprospateaza_pad()

# Intră în ascultare pentru un rând. De aici mai departe lucrează `_process`.
func _begin_remap_pad(action: String) -> void:
	cancel_remap()
	_remap_pad = action
	_pad_timp = PAD_ASTEPTARE
	_pad_eliberat = false
	_pad_butoane[action].text = "%d" % ceili(_pad_timp)
	# ⚠️ „press a button…" se scrie pe rândul de SUS, nu pe buton. Butonul are 180px ficși, iar
	# rândurile sunt HBox-uri CENTRATE: un text lung îl lățește, împinge eticheta din stânga și
	# strâmbă toată coloana (aceeași capcană e scrisă și la `_info_row`). Sus e loc, e centrat, și
	# se vede mai bine decât într-o casetă cât un buton — iar pe buton rămâne numărătoarea, care
	# spune singură că se poate și renunța.
	_pad_nume.text = tr("press a button…")
	_pad_nume.add_theme_color_override("font_color", ACCENT_CLAR)
	set_process(true)

# Ascultarea butonului nou. Trei lucruri, fiecare învățat pe pielea altcuiva:
#
# 1. ÎNTÂI aștept controllerul LIBER. Rândul din meniu se apasă tot cu A (sau cu ce e legat pe
#    „confirmă"), deci fără pasul ăsta prima citire ar fi găsit chiar butonul care tocmai a
#    deschis ascultarea și l-ar fi legat pe el însuși, instantaneu, fără ca omul să apuce să
#    citească „press a button…".
# 2. CITESC starea pad-ului, nu aștept evenimente (`Gamepad.cod_apasat`). Motivul e scris pe larg
#    în `gamepad.gd`: apăsarea se consumă la butonul care are focus și nu mai ajunge nicăieri.
# 3. Se renunță SINGUR după `PAD_ASTEPTARE` secunde, cu numărătoarea scrisă pe rând. Pe un
#    controller nu poate exista „apasă Escape ca să lași": orice buton ai apăsa, ăla se leagă.
#    Singura ieșire onestă e să nu apeși nimic — și trebuie să se și VADĂ că e o ieșire.
func _process(delta: float) -> void:
	# după ce am legat un buton, mai înghit ce vine până se lasă controllerul din mână: altfel
	# butonul proaspăt pus pe „confirmă" ar apăsa, la ridicare, chiar rândul de sub cursor
	if _pad_dupa:
		if Gamepad.pad_liber():
			_pad_dupa = false
			set_process(false)
		return
	if _remap_pad == "":
		set_process(false)
		return
	if not _pad_eliberat:
		_pad_eliberat = Gamepad.pad_liber()
		return
	var cod := Gamepad.cod_apasat()
	if cod != -1:
		var action := _remap_pad
		_remap_pad = ""
		_pad_dupa = true
		Gamepad.remapeaza(action, cod)
		Audio.play("button", -3.0, 0.0)
		_reimprospateaza_pad()
		return
	_pad_timp -= delta
	if _pad_timp <= 0.0:
		cancel_remap()
		return
	_pad_butoane[_remap_pad].text = "%d" % ceili(_pad_timp)

# Scrie numele controllerului conectat și butonul de pe fiecare rând, cu literele potrivite (A pe
# Xbox, ✕ pe PlayStation). Fără controller, lista rămâne pe convenția Xbox — e ce vede oricine
# deschide pagina din curiozitate, nu un ecran gol.
func _reimprospateaza_pad() -> void:
	if _pad_nume == null or not is_instance_valid(_pad_nume):
		return
	var nume := Gamepad.nume_pad()
	_pad_nume.text = nume if nume != "" else tr("No controller connected")
	_pad_nume.add_theme_color_override("font_color", ACCENT_CLAR if nume != "" else Color(0.62, 0.58, 0.56))
	for action in _pad_butoane:
		if action != _remap_pad:   # rândul care ascultă acum își ține textul lui
			_pad_butoane[action].text = Gamepad.nume_coduri(action)

# „Etichetă      valoare" — ca `_key_row`, dar valoarea e un text, nu un buton: aici nu se apasă
# nimic. Un buton care nu face nimic ar fi fost cea mai bună cale de a-l pune pe jucător să dea
# clic pe el de trei ori.
func _info_row(text: String, valoare: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(160, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var val := Label.new()
	val.text = valoare
	# EXACT cât butoanele de pe celelalte rânduri (160 + 180): rândurile stau în HBox-uri
	# CENTRATE, deci unul mai lat decât restul le împinge pe toate și coloana iese strâmbă.
	# De-aia scrie „Stick / D-Pad" și nu „Left Stick / D-Pad": diferența de lățime se vedea.
	val.custom_minimum_size = Vector2(180, 0)
	val.add_theme_font_size_override("font_size", 18)
	val.add_theme_color_override("font_color", ACCENT_CLAR)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	return row

# Vibrația pornită se și SIMTE pe loc, nu la următoarea lovitură încasată: un comutator care nu
# dă niciun semn te lasă să te întrebi dacă a mers.
func _on_vibration(on: bool) -> void:
	GameSettings.set_vibration(on)
	if on:
		Gamepad.vibreaza(0.35, 0.35, 0.25)

# Separația e 6, nu 12 ca la început: bara de taburi a luat din înălțime, iar din 2026-07-27
# blocul stă și într-o ramă ornată în meniul principal, care mai ia ~114px pe verticală.
# Pagina KEYBINDS (2 slidere + 5 taste) e cea care dictează — dacă mai adaugi un rând acolo,
# verifică pe o poză că rama nu iese din ecranul de 648px.
func _pagina_goala() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v

# Bara de sus: „KEYBINDS | GRAPHICS"
func _bara_taburi() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# ⚠️ Taburile s-au subțiat de la 200 la 150 când a intrat al treilea (GAMEPAD, 2026-08-20):
	# 3 × 200 + separații ar fi lățit tot blocul de Settings cu ~220px, iar blocul e încadrat de
	# rama ornată din meniul principal — deci s-ar fi lățit și ea, pe un ecran de 1152.
	for nume in ["keybinds", "graphics", "gamepad"]:
		var b := _buton(nume.to_upper(), 20, Vector2(150, 40))
		b.pressed.connect(arata_pagina.bind(nume))
		_taburi[nume] = b
		row.add_child(b)
	return row

# Arată o pagină și o ascunde pe cealaltă. Dacă eram în mijlocul unei remapări, o anulăm —
# altfel prima tastă apăsată pe pagina de grafică ar fi înghițită de remaparea rămasă în aer.
func arata_pagina(nume: String) -> void:
	if not _pagini.has(nume):
		return
	cancel_remap()
	for n in _pagini:
		_pagini[n].visible = n == nume
	for n in _taburi:
		_stil_tab(_taburi[n], n == nume)

# Cât timp remapăm, următoarea apăsare devine noua comandă (Escape = renunț).
func _input(event: InputEvent) -> void:
	if _remap_pad != "" or _pad_dupa:
		# Cât ascult un buton de pad, TOT ce vine de la controller e al meu. Dacă l-aș lăsa să
		# treacă, B ar închide meniul de dedesubt și crucea ar muta focusul pe alt rând fix cât
		# ascult. Butonul îl citesc din starea pad-ului (`_process`), nu din evenimentul ăsta,
		# deci nu pierd nimic înghițindu-le pe toate.
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			cancel_remap()   # de la tastatură nu se leagă butoane de pad: orice tastă = „lasă"
			return
	if _remap_action == "":
		return
	# Pe controller nu se remapează taste (n-are ce tastă să dea), deci ORICE buton de pad apăsat
	# cât aștept o tastă înseamnă „lasă". Fără linia asta, B ar fi ajuns la meniul de pauză de
	# dedesubt și ți-ar fi schimbat pagina cu remaparea rămasă agățată în aer.
	if event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		cancel_remap()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc != KEY_ESCAPE:
			GameSettings.rebind(_remap_action, kc)
		_remap_buttons[_remap_action].text = GameSettings.key_name(_remap_action)
		_remap_action = ""

# Anulează o remapare în curs — de tastă SAU de buton de pad (chemat când se închide pagina de
# settings și când se schimbă tabul).
func cancel_remap() -> void:
	if _remap_action != "" and _remap_buttons.has(_remap_action):
		_remap_buttons[_remap_action].text = GameSettings.key_name(_remap_action)
	_remap_action = ""
	if _remap_pad != "" and _pad_butoane.has(_remap_pad):
		_pad_butoane[_remap_pad].text = Gamepad.nume_coduri(_remap_pad)
	_remap_pad = ""
	_reimprospateaza_pad()   # rândul de sus scrie iar numele controllerului, nu instrucțiunea
	_pad_dupa = false
	set_process(false)

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
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art: butonul nu se înmoaie
	s.add_theme_stylebox_override("slider", _bara(Color8(18, 15, 20), 3))
	s.add_theme_stylebox_override("grabber_area", _bara(ACCENT_STINS, 3))
	s.add_theme_stylebox_override("grabber_area_highlight", _bara(ACCENT, 3))
	s.add_theme_icon_override("grabber", _grabber(ACCENT))
	s.add_theme_icon_override("grabber_highlight", _grabber(ACCENT_CLAR))
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
	# 32, nu 40 ca la început: în meniul principal blocul ăsta stă acum într-o ramă ornată, iar
	# cele 5 rânduri de taste erau exact cât să împingă rama afară din ecran. În pauză, unde e
	# loc berechet, diferența nu se simte.
	var b := _buton(GameSettings.key_name(action), 20, Vector2(180, 32))
	b.pressed.connect(_begin_remap.bind(action))
	_remap_buttons[action] = b
	row.add_child(b)
	return row

# „Setare  [ ON ]" — butonul comută între ON și OFF și anunță GameSettings.
func _toggle_row(text: String, value: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(160, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var b := _buton("ON" if value else "OFF", 20, Vector2(180, 32))
	b.pressed.connect(_on_toggle.bind(b, cb))
	b.set_meta("valoare", value)
	row.add_child(b)
	return row

func _on_toggle(b: Button, cb: Callable) -> void:
	var noua: bool = not bool(b.get_meta("valoare"))
	b.set_meta("valoare", noua)
	b.text = "ON" if noua else "OFF"
	Audio.play("button", -3.0, 0.0)
	cb.call(noua)

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
# Butonul de lemn folosit peste tot aici (taste, comutatoare, taburi).
func _buton(text: String, font_size: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND, 3))
	b.add_theme_stylebox_override("hover", _sb(BTN_MAIN.lightened(0.10), BTN_SECOND.lightened(0.10), 3))
	b.add_theme_stylebox_override("pressed", _sb(BTN_MAIN.lightened(0.20), BTN_SECOND.lightened(0.20), 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

# Tab-ul paginii deschise stă aprins, ca să se vadă unde ești. ⚠️ Deosebirea se face pe MUCHIE,
# nu pe umplutură: pe piatră aproape neagră un `darkened(0.18)` nu se vede deloc, pe când o muchie
# de aramă aprinsă lângă una stinsă se citește instant.
func _stil_tab(b: Button, activ: bool) -> void:
	var bg := Color8(52, 36, 34) if activ else BTN_MAIN
	var bd := ACCENT_CLAR if activ else ACCENT_STINS
	b.add_theme_stylebox_override("normal", _sb(bg, bd, 3))
	b.add_theme_stylebox_override("hover", _sb(Color8(64, 44, 40), ACCENT, 3))
	b.add_theme_color_override("font_color", OS_ALB if activ else Color(0.62, 0.58, 0.56))

func _sb(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(2)   # colțuri aproape drepte: pixel art, nu material design
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

# --- sliderele de volum ---
# Fără astea rămâneau sliderele CENUȘII implicite ale motorului, adică singurul lucru din tot
# meniul care arăta a Godot și nu a joc. Godot le desenează din trei bucăți: `slider` (șanțul),
# `grabber_area` (partea plină, din stânga butonului) și iconița `grabber` (butonul însuși).
func _bara(c: Color, inaltime: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(1)
	sb.content_margin_top = inaltime
	sb.content_margin_bottom = inaltime
	return sb

# Butonul sliderului: un pătrat de aramă cu muchie închisă, desenat din cod (n-avem poză pentru el
# și n-are rost una — 12×12 pixeli).
func _grabber(c: Color) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for x in 12:
		for y in 12:
			var margine: bool = x < 2 or y < 2 or x > 9 or y > 9
			img.set_pixel(x, y, c.darkened(0.55) if margine else c)
	return ImageTexture.create_from_image(img)

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
