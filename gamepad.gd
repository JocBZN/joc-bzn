extends Node

# SUPORT DE CONTROLLER (autoload „Gamepad"). Un singur loc pentru tot ce ține de gamepad:
# butoanele legate pe acțiuni, ce dispozitiv folosește jucătorul ACUM, focusul din meniuri,
# vibrația și numele butoanelor scrise pe ecran.
#
# De ce un autoload separat și nu bucăți prin fiecare meniu: jocul are UNSPREZECE ecrane cu
# butoane (meniu, pauză, level up, game over, cazinou, ruletă, trade-up, Alba-Neagra, dubiosul,
# settings, loading). Dacă fiecare și-ar fi rezolvat singur „pe ce buton stă cursorul de pad",
# al doisprezecelea ecran ar fi pornit iar fără suport, în tăcere. Aici e o singură regulă,
# care se aplică oricărui `Button` din joc, inclusiv celor care nu existau când s-a scris
# fișierul ăsta.
#
# ⚠️ Autoload-ul ăsta e PRIMUL din listă, înaintea lui `GameSettings`. Motivul e la `leaga_pad()`.
#
# Ce NU face: nu remapează butoanele de pad din meniu (stick-ul și crucea sunt pe mers, A e pe
# „folosește", B pe „înapoi" — convenția pe care o știe orice jucător) și nu desenează iconițe
# de buton, ci le scrie cu litere, cu numele consolei potrivite (A pe Xbox, ✕ pe PlayStation).

# Cât trebuie împins stick-ul ca să conteze. 0.22 fiindcă un stick uzat de Xbox stă rar fix pe 0:
# sub prag, player-ul ar aluneca singur încet într-o parte cât ține mâna departe de controller.
const DEADZONE := 0.22
# Pragul pentru navigarea prin meniu (ui_up/ui_down/…). E mai mare dinadins: la 0.22 o
# atingere ușoară a stick-ului sărea două rânduri deodată.
const DEADZONE_UI := 0.5

# Meta pusă pe un buton ca să fie el primul focusat când se deschide ecranul lui
# (`Gamepad.primul(buton)`). Fără ea se ia primul buton din ordinea arborelui, care de obicei
# e tot ăla — dar „de obicei" nu e destul pentru START și pentru RESUME.
const META_PRIM := "focus_prim"

# Culoarea inelului de focus. E arama cea mai deschisă din paleta jocului (`menu.gd`,
# `casino.gd` și `pause.gd` folosesc aceleași cupruri), dusă încă puțin spre lumină: pe
# controller inelul ăsta ține locul cursorului, deci n-are voie să semene cu nimic altceva.
const FOCUS_MUCHIE := Color8(255, 190, 130)

# Butoanele de pad puse pe acțiunile JOCULUI (pe lângă tastele din `GameSettings.KEY_ACTIONS`).
# A = folosește, START = pauză. X e al doilea buton de interacțiune fiindcă degetul mare stă
# oricum pe el la jocurile astea, iar A e și „confirmă" în meniuri.
const PAD_BUTOANE := {
	"interact": [JOY_BUTTON_A, JOY_BUTTON_X],
	"pause": [JOY_BUTTON_START],
}

# Mersul: stick-ul stâng ȘI crucea, pe aceleași acțiuni ca WASD. Stick-ul e ANALOG — cu cât îl
# împingi mai puțin, cu atât mergi mai încet (vezi `player.gd`, `Input.get_vector`).
const PAD_MISCARE := {
	"move_left":  {"axa": JOY_AXIS_LEFT_X, "spre": -1.0, "cruce": JOY_BUTTON_DPAD_LEFT},
	"move_right": {"axa": JOY_AXIS_LEFT_X, "spre":  1.0, "cruce": JOY_BUTTON_DPAD_RIGHT},
	"move_up":    {"axa": JOY_AXIS_LEFT_Y, "spre": -1.0, "cruce": JOY_BUTTON_DPAD_UP},
	"move_down":  {"axa": JOY_AXIS_LEFT_Y, "spre":  1.0, "cruce": JOY_BUTTON_DPAD_DOWN},
}

# Ce scrie pe ecran pentru fiecare acțiune, pe fiecare fel de controller. Godot numește butoanele
# după Xbox (JOY_BUTTON_A = butonul de jos-dreapta), iar pe PlayStation ăla e ✕.
const NUME_BUTOANE := {
	"xbox": {"interact": "A", "accept": "A", "back": "B", "pause": "START"},
	"ps":   {"interact": "✕", "accept": "✕", "back": "◯", "pause": "OPTIONS"},
}

signal dispozitiv_schimbat(pe_pad: bool)

# "pad", "tasta" sau "mouse" — cu ce s-a jucat ULTIMA oară. Nu e o setare, e o observație:
# jucătorul poate lăsa controllerul din mână la mijlocul unei runde, iar textele de pe ecran
# trebuie să se schimbe singure, fără să intre nimeni în Settings.
var mod := "mouse"

var _pad_id := -1              # primul controller conectat (-1 = niciunul)
var _fel := "xbox"             # "xbox" sau "ps" — pentru numele butoanelor
var _aprinse := {}             # butoanele pe care le-am aprins noi din focus (id -> true)
var _vibr_pana := 0.0          # până când ține vibrația care rulează acum
var _vibr_forta := 0.0         # cât de tare e, ca una slabă să n-o taie pe una tare

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # meniul de level up și pauza rulează cu jocul oprit
	Input.joy_connection_changed.connect(_pad_schimbat)
	_cauta_pad()
	_leaga_ui()
	# orice buton din joc, oricând ar fi creat, primește tratamentul de focus
	get_tree().node_added.connect(_nod_nou)
	_leaga_arborele(get_tree().root)

# --------------------------------------------------------------------------------------
# ACȚIUNI
# --------------------------------------------------------------------------------------
# Pune pe o acțiune butoanele/axele de pad care i se cuvin. O cheamă `GameSettings._bind()`
# DUPĂ ce a pus tastele, fiindcă `InputMap.action_erase_events()` de acolo șterge TOT ce era
# pe acțiune — inclusiv pad-ul. Fără linia asta, prima remapare de tastă din Settings ar fi
# tăiat în tăcere stick-ul de pe direcția aia.
#
# ⚠️ De aici vine și ordinea autoload-urilor: `GameSettings._ready()` cheamă `_setup_actions()`,
# care ajunge aici. Dacă „Gamepad" ar fi fost după el în listă, autoload-ul încă n-ar fi existat.
func leaga_pad(action: String) -> void:
	if not InputMap.has_action(action):
		return
	if PAD_MISCARE.has(action):
		var m: Dictionary = PAD_MISCARE[action]
		var ax := InputEventJoypadMotion.new()
		ax.axis = m["axa"]
		ax.axis_value = m["spre"]
		InputMap.action_add_event(action, ax)
		InputMap.action_add_event(action, _buton(m["cruce"]))
		InputMap.action_set_deadzone(action, DEADZONE)
	if PAD_BUTOANE.has(action):
		for b in PAD_BUTOANE[action]:
			InputMap.action_add_event(action, _buton(b))

func _buton(index: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = index
	return ev

# Navigarea din meniuri (`ui_up`, `ui_accept`, …) vine gata cu butoane de pad din Godot, dar
# NU ne bazăm pe asta: verificăm și completăm ce lipsește. Costă zece linii și scapă jocul de o
# categorie întreagă de „la mine merge" (un `project.godot` cu `input_devices/…` reglat altfel,
# o versiune viitoare care schimbă implicitele).
func _leaga_ui() -> void:
	var vrem := {
		"ui_accept": [JOY_BUTTON_A],
		"ui_cancel": [JOY_BUTTON_B],
		"ui_left":   [JOY_BUTTON_DPAD_LEFT],
		"ui_right":  [JOY_BUTTON_DPAD_RIGHT],
		"ui_up":     [JOY_BUTTON_DPAD_UP],
		"ui_down":   [JOY_BUTTON_DPAD_DOWN],
	}
	for action in vrem:
		if not InputMap.has_action(action):
			continue
		for index in vrem[action]:
			if not _are_buton(action, index):
				InputMap.action_add_event(action, _buton(index))
	# stick-ul stâng pe navigare, cu prag mare (vezi DEADZONE_UI)
	var axe := {
		"ui_left":  {"axa": JOY_AXIS_LEFT_X, "spre": -1.0},
		"ui_right": {"axa": JOY_AXIS_LEFT_X, "spre":  1.0},
		"ui_up":    {"axa": JOY_AXIS_LEFT_Y, "spre": -1.0},
		"ui_down":  {"axa": JOY_AXIS_LEFT_Y, "spre":  1.0},
	}
	for action in axe:
		if not InputMap.has_action(action):
			continue
		if not _are_axa(action, axe[action]["axa"], axe[action]["spre"]):
			var ax := InputEventJoypadMotion.new()
			ax.axis = axe[action]["axa"]
			ax.axis_value = axe[action]["spre"]
			InputMap.action_add_event(action, ax)
		InputMap.action_set_deadzone(action, DEADZONE_UI)

func _are_buton(action: String, index: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == index:
			return true
	return false

func _are_axa(action: String, axa: int, spre: float) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and ev.axis == axa and signf(ev.axis_value) == signf(spre):
			return true
	return false

# --------------------------------------------------------------------------------------
# CE ȚINE JUCĂTORUL ÎN MÂNĂ
# --------------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_schimba_mod("pad")
	elif event is InputEventJoypadMotion and absf(event.axis_value) > DEADZONE:
		_schimba_mod("pad")
	elif event is InputEventKey and event.pressed and not event.echo:
		_schimba_mod("tasta")
	elif event is InputEventMouseButton and event.pressed:
		_schimba_mod("mouse")   # un CLIC e limpede, nu se discută
	elif event is InputEventMouseMotion:
		_miscare_mouse(event.relative.length())

# Cât de greu îi e mouse-ului să ia comanda ÎNAPOI de la controller. Un singur eveniment de
# mișcare nu ajunge, oricât de mare — și nu e o precauție teoretică: rulând testul, la fiecare
# schimbare de scenă sistemul trimite un salt de câteva sute de pixeli (cursorul e repoziționat
# față de fereastra nouă), iar jocul ieșea din modul „pad" singur, în mijlocul rundei: reapărea
# cursorul și se stingea inelul de focus, fără ca jucătorul să fi atins nimic.
#
# Regula: cel puțin 3 evenimente ȘI 40 de pixeli adunați — adică o MÂNĂ care mișcă mouse-ul, nu
# un salt. Plus o clipă de răgaz după ce pad-ul a luat comanda (ascunderea cursorului poate ea
# însăși produce o mișcare) și uitare după o secundă de liniște, ca praful de pe senzor să nu se
# adune la nesfârșit până trece de prag.
const MOUSE_PRAG := 40.0
const MOUSE_MIN_EVENIMENTE := 3
const MOUSE_RAGAZ := 0.6
const MOUSE_UITARE := 1.0

var _mouse_suma := 0.0
var _mouse_nr := 0
var _mouse_ultima := 0.0
var _pad_ultima := 0.0

func _miscare_mouse(dist: float) -> void:
	var acum := Time.get_ticks_msec() / 1000.0
	if mod != "pad":
		_schimba_mod("mouse")
		return
	if acum - _pad_ultima < MOUSE_RAGAZ:
		return
	if acum - _mouse_ultima > MOUSE_UITARE:
		_mouse_suma = 0.0
		_mouse_nr = 0
	_mouse_ultima = acum
	_mouse_suma += dist
	_mouse_nr += 1
	if _mouse_nr >= MOUSE_MIN_EVENIMENTE and _mouse_suma > MOUSE_PRAG:
		_schimba_mod("mouse")

func _schimba_mod(nou: String) -> void:
	if nou == "pad":
		# fiecare atingere a controllerului șterge ce adunase mouse-ul (vezi `_miscare_mouse`)
		_pad_ultima = Time.get_ticks_msec() / 1000.0
		_mouse_suma = 0.0
		_mouse_nr = 0
	if nou == mod:
		return
	var era_pad := mod == "pad"
	mod = nou
	# Cursorul dispare cât joci pe controller. Un cursor de mouse uitat în mijlocul ecranului e
	# semnul clasic că un joc „are controller, dar nu chiar".
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if nou == "pad" else Input.MOUSE_MODE_VISIBLE
	# Ai pus mâna pe mouse → chenarul de focus n-are ce căuta pe ecran: de acum comandă cursorul.
	# La tastatură NU eliberăm focusul, ca săgețile să poată duce navigarea mai departe.
	if nou == "mouse":
		var vp := get_viewport()
		if vp != null:
			vp.gui_release_focus()
	if era_pad != (nou == "pad"):
		dispozitiv_schimbat.emit(nou == "pad")

func pe_pad() -> bool:
	return mod == "pad"

func are_pad() -> bool:
	return _pad_id >= 0

# Numele controllerului conectat, pentru pagina de Settings („Xbox Controller"). Gol = niciunul.
func nume_pad() -> String:
	return Input.get_joy_name(_pad_id) if _pad_id >= 0 else ""

# Ce buton scrie pe ecran pentru o acțiune, în funcție de ce ține jucătorul în mână ACUM:
# tasta remapată (E) cât joacă pe tastatură, butonul de pad (A / ✕) cât joacă pe controller.
func nume_buton(action: String) -> String:
	if not pe_pad():
		return GameSettings.key_name(action)
	var tabel: Dictionary = NUME_BUTOANE[_fel]
	return String(tabel.get(action, tabel["accept"]))

# Numele unui buton de pad, INDIFERENT de ce ține jucătorul în mână (pentru lista din Settings,
# care e despre controller chiar dacă o deschizi cu mouse-ul). Cheile: „interact", „accept",
# „back", „pause".
func nume_pad_buton(cheie: String) -> String:
	var tabel: Dictionary = NUME_BUTOANE[_fel]
	return String(tabel.get(cheie, cheie))

func _pad_schimbat(_device: int, _conectat: bool) -> void:
	var aveam := _pad_id
	_cauta_pad()
	# Controllerul s-a deconectat în mijlocul rundei (baterie moartă, cablu smuls) → punem jocul
	# pe pauză. E regula standard pe console și e singura corectă: jocul ăsta nu se oprește
	# niciodată singur, deci fără linia asta player-ul stă în loc și e mâncat cât cauți bateriile.
	if aveam >= 0 and _pad_id < 0 and mod == "pad":
		opreste_vibratia()
		var p = get_tree().get_first_node_in_group("pause_menu")
		if p != null and p.has_method("cere_pauza"):
			p.cere_pauza()

func _cauta_pad() -> void:
	var lista := Input.get_connected_joypads()
	_pad_id = lista[0] if lista.size() > 0 else -1
	_fel = "xbox"
	if _pad_id >= 0:
		var n := Input.get_joy_name(_pad_id).to_lower()
		# numele raportate de Windows/SDL: „PS5 Controller", „DualSense Wireless Controller",
		# „Sony Interactive Entertainment Wireless Controller"
		if n.contains("ps3") or n.contains("ps4") or n.contains("ps5") \
				or n.contains("dual") or n.contains("sony") or n.contains("playstation"):
			_fel = "ps"

# --------------------------------------------------------------------------------------
# VIBRAȚIE
# --------------------------------------------------------------------------------------
# `slab` = motorul mic (zumzet ascuțit), `tare` = motorul mare (bubuit). Se cheamă din
# `player.gd`, din același loc de unde pornește și tremuratul camerei — o singură sursă de
# adevăr pentru „cât de tare a fost lovitura", deci vibrația nu poate rămâne în urma imaginii.
func vibreaza(slab: float, tare: float, durata: float) -> void:
	if _pad_id < 0 or durata <= 0.0 or not GameSettings.vibration:
		return
	var acum := Time.get_ticks_msec() / 1000.0
	var forta := maxf(slab, tare)
	# O zguduitură mică nu are voie să taie una mare care încă ține (un critic în timpul
	# cutremurului de boss ar fi oprit bubuitul și l-ar fi înlocuit cu un țiuit).
	if acum < _vibr_pana and forta < _vibr_forta:
		return
	Input.start_joy_vibration(_pad_id, clampf(slab, 0.0, 1.0), clampf(tare, 0.0, 1.0), durata)
	_vibr_pana = acum + durata
	_vibr_forta = forta

func opreste_vibratia() -> void:
	if _pad_id >= 0:
		Input.stop_joy_vibration(_pad_id)
	_vibr_pana = 0.0
	_vibr_forta = 0.0

# --------------------------------------------------------------------------------------
# FOCUSUL DIN MENIURI
# --------------------------------------------------------------------------------------
# Godot mută singur focusul cu stick-ul/crucea și apasă butonul focusat cu A — dar numai DACĂ
# ceva are focus. La pornire nu are nimic, deci fără paznicul ăsta un controller n-ar face nimic
# în meniuri, oricâte butoane i-ai lega.
#
# Regula: focusul stă mereu pe ecranul de DEASUPRA. Ecranele jocului sunt CanvasLayer-e cu
# `layer` crescător (HUD 4 < interact 5 < level up 10 < cazinou 12 < pauză 15 < game over 20),
# deci „deasupra" nu e o listă scrisă de mână care rămâne în urmă la următorul ecran nou: e
# chiar numărul după care se desenează.
func _process(_delta: float) -> void:
	_asculta_padul()
	if mod != "pad":
		return
	_pazeste_focusul()

# Trezirea modului „pad" citită DIRECT din starea controllerului, nu doar din evenimente.
#
# ⚠️ De ce nu ajunge `_input`: evenimentele consumate cu `set_input_as_handled()` nu mai ajung la
# nodurile următoare, iar autoload-urile sunt ULTIMELE care primesc `_input` (ordinea e invers
# decât în arbore). Prima apăsare pe controller e chiar cea care sare peste intro-ul meniului,
# adică exact una consumată — deci jocul rămânea în modul „mouse" fix când puneai mâna pe pad.
# Prins rulând, pe 2026-08-20.
#
# Pragul e 0.5, nu DEADZONE: un stick uzat care stă la 0.25 ar fi furat comanda de la mouse la
# fiecare cadru, iar cursorul ar fi clipit între vizibil și ascuns.
const TREZIRE_STICK := 0.5

func _asculta_padul() -> void:
	# Se citește ȘI cât suntem deja pe „pad": așa `_schimba_mod` reîmprospătează răgazul care
	# ține mouse-ul la distanță cât timp jucătorul chiar are mâinile pe controller.
	if _pad_id >= 0 and _pad_e_atins():
		_schimba_mod("pad")

func _pad_e_atins() -> bool:
	for b in JOY_BUTTON_MAX:
		if Input.is_joy_button_pressed(_pad_id, b):
			return true
	# doar cele două stick-uri; declanșatoarele (axele 4-5) stau pe unele drivere la valori
	# nenule cât nu le atinge nimeni
	for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if absf(Input.get_joy_axis(_pad_id, a)) > TREZIRE_STICK:
			return true
	return false

func _pazeste_focusul() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var focus := vp.gui_get_focus_owner()
	for strat in _straturi():
		var prim := _primul_focusabil(strat)
		if prim == null:
			continue   # stratul ăsta n-are butoane (HUD, textul de interacțiune) → mai jos
		if focus != null and is_instance_valid(focus) and _e_focusabil(focus) \
				and strat.is_ancestor_of(focus):
			return     # focusul e deja pe ecranul de sus, nu-l smucim
		prim.grab_focus()
		return

# Rădăcina scenei + CanvasLayer-ele ei VIZIBILE, de la cel mai de sus în jos.
func _straturi() -> Array:
	var out: Array = []
	var scena := get_tree().current_scene
	if scena == null:
		return out
	for c in scena.get_children():
		if c is CanvasLayer and c.visible:
			out.append(c)
	out.sort_custom(func(a, b): return a.layer > b.layer)
	# meniul principal e un Control simplu, fără CanvasLayer-e: el e ultimul strat
	if scena is Control:
		out.append(scena)
	return out

# Butonul de pe care pornește cursorul pe un ecran: cel cerut anume cu `primul()`, altfel primul
# din ordinea arborelui.
#
# ⚠️ Se cheamă în FIECARE cadru, pentru fiecare strat vizibil, deci n-are voie să construiască
# liste: prima variantă aduna toate butoanele într-un Array și costa 45µs pe cadru degeaba.
# Acum coboară o singură dată prin arbore, fără să aloce nimic, și se oprește din primul buton
# marcat pe care-l găsește.
var _prim_gasit: Control = null

func _primul_focusabil(nod: Node) -> Control:
	_prim_gasit = null
	var marcat := _cauta_focus(nod)
	return marcat if marcat != null else _prim_gasit

func _cauta_focus(nod: Node) -> Control:
	if nod is Control:
		if not nod.is_visible_in_tree():
			return null      # o pagină ascunsă n-are ce da mai departe (nici copiii ei)
		if _e_focusabil(nod):
			if nod.has_meta(META_PRIM):
				return nod   # butonul cerut anume (START, RESUME) bate ordinea din arbore
			if _prim_gasit == null:
				_prim_gasit = nod
	for c in nod.get_children():
		var r := _cauta_focus(c)
		if r != null:
			return r
	return null

func _e_focusabil(c: Control) -> bool:
	if not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	if c.focus_mode == Control.FOCUS_NONE:
		return false
	if c is BaseButton and c.disabled:
		return false
	return true

# Cere ca butonul ăsta să fie primul focusat pe ecranul lui.
func primul(c: Control) -> void:
	if c != null:
		c.set_meta(META_PRIM, true)

# --------------------------------------------------------------------------------------
# CUM SE VEDE FOCUSUL
# --------------------------------------------------------------------------------------
# Toate butoanele din joc au `focus` pus pe `StyleBoxEmpty` (chenarul punctat al lui Godot ar fi
# arătat oribil peste pixel art), iar aprinderea lor e legată de MOUSE: `mouse_entered` mărește
# butonul, aprinde chenarul cartonașului, schimbă fișa armei. Cu un controller nu intră nimeni
# cu mouse-ul pe ele, deci ecranul ar fi rămas mort.
#
# Leacul, într-un singur loc pentru tot jocul: când un buton primește focus și jucătorul e pe
# controller, îi punem pe `focus` chiar stilul lui de `hover` și îi dăm semnalele de mouse.
# Așa fiecare ecran își păstrează exact aprinderea lui, fără să știe că există un pad.
func _nod_nou(n: Node) -> void:
	_leaga_control(n)

func _leaga_arborele(n: Node) -> void:
	_leaga_control(n)
	for c in n.get_children():
		_leaga_arborele(c)

func _leaga_control(n: Node) -> void:
	if not (n is BaseButton or n is Range):
		return
	if not n.focus_entered.is_connected(_a_luat_focus):
		n.focus_entered.connect(_a_luat_focus.bind(n))
		n.focus_exited.connect(_a_pierdut_focus.bind(n))

func _a_luat_focus(c: Control) -> void:
	if mod == "mouse" or not is_instance_valid(c):
		return
	if c is Range:
		c.modulate = Color(1.35, 1.25, 1.15)   # sliderele n-au „hover", deci le luminăm
		return
	var hover := c.get_theme_stylebox("hover")
	if hover is StyleBoxFlat:
		# Nu punem hover-ul CA ATARE, ci o copie cu muchia aprinsă și trasă puțin în afara
		# butonului. Motivul se vede pe START: el are deja, în repaus, o muchie de aramă
		# deschisă (e butonul principal), deci un hover copiat exact peste el nu s-ar fi
		# deosebit cu nimic — pe controller n-ai cursor, deci dacă nu se vede unde ești, nu
		# știi ce apeși. Inelul ăsta se vede pe ORICE buton din joc, oricât de luminos ar fi.
		var ring: StyleBoxFlat = hover.duplicate()
		ring.border_color = FOCUS_MUCHIE
		ring.set_border_width_all(maxi(3, ring.border_width_top))
		ring.set_expand_margin_all(3.0)
		c.add_theme_stylebox_override("focus", ring)
		_aprinse[c.get_instance_id()] = true
	c.mouse_entered.emit()   # aprinderea proprie a ecranului (mărire, chenar, fișa armei)

func _a_pierdut_focus(c: Control) -> void:
	if not is_instance_valid(c):
		return
	if c is Range:
		c.modulate = Color(1, 1, 1)
		return
	if _aprinse.erase(c.get_instance_id()):
		c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# dacă mouse-ul chiar stă pe el, nu-i stingem aprinderea de sub cursor
	if c is BaseButton and c.is_hovered():
		return
	c.mouse_exited.emit()
