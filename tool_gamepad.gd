extends Node

# Unealta care verifica REMAPAREA BUTOANELOR DE PAD (`gamepad.gd` + pagina GAMEPAD din
# `settings_ui.gd`). Nu face parte din joc.
#
#   godot --path <proj> res://tool_gamepad.tscn
#
# ⚠️ Ruleaza FERESTRUIT: partea a doua deschide meniul adevarat si face poze, iar headless
# deseneaza negru.
#
# Verifica trei lucruri, in ordinea asta:
#   1. legaturile din fabrica ajung CHIAR in InputMap (nu doar in dictionarul din memorie);
#   2. remaparea: schimbul de butoane intre actiuni care se bat, declansatoarele, butoanele
#      interzise, RESET-ul si salvarea pe disc;
#   3. pagina din meniu: incape in ecran, scrie ce trebuie pe fiecare rand si asculta cand ii ceri.
#
# ⚠️ Testul SCRIE in salvarea adevarata (`GameSettings._save()` e chemat de fiecare remapare).
# De-aia primul lucru pe care il face e o copie pe octeti a fisierului, iar ultimul o pune la loc
# si verifica bit cu bit ca e aceeasi. Fara asta, o rulare de test ar fi lasat butoanele lui
# Razvan legate aiurea.

const SALVARE := "user://scores.save"
const POZE := "C:/Users/GHEORG~1/AppData/Local/Temp/claude/C--WINDOWS-system32/551d4bf5-3856-4389-8b46-37e7316ca081/scratchpad/gamepad_%s.png"

var _erori := 0
var _copie: PackedByteArray
var _padbinds_initial: Dictionary

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_copie = FileAccess.get_file_as_bytes(SALVARE) if FileAccess.file_exists(SALVARE) else PackedByteArray()
	_padbinds_initial = GameSettings.padbinds.duplicate(true)
	print("--- copie de siguranta: %d octeti; padbinds la start: %s" % [_copie.size(), _padbinds_initial])
	# ⚠️ un cadru de asteptare: in `_ready` radacina inca isi construieste copiii, deci `add_child`
	# de la partea a 6-a (meniul adevarat) e refuzat cu „Parent node is busy setting up children"
	await get_tree().process_frame
	_ruleaza()

func _ruleaza() -> void:
	_fabrica()
	_remapare()
	_declansator()
	_interzise()
	_reset_si_disc()
	_apasarea()
	await _meniul()
	_pune_copia()
	print("\n%s" % ("✔ TOATE VERIFICARILE AU TRECUT" if _erori == 0 else "✘ %d probleme" % _erori))
	get_tree().quit(1 if _erori > 0 else 0)

# ---------------------------------------------------------------- 1. din fabrica
func _fabrica() -> void:
	print("\n[1] legaturile din fabrica")
	Gamepad.reseteaza_butoanele()
	_cer(_buton("interact", JOY_BUTTON_A), "interact are A")
	_cer(_buton("interact", JOY_BUTTON_X), "interact are X")
	_cer(_buton("ui_accept", JOY_BUTTON_A), "ui_accept are A")
	_cer(_buton("ui_cancel", JOY_BUTTON_B), "ui_cancel are B")
	_cer(_buton("pause", JOY_BUTTON_START), "pause are START")
	# tastele NU se pierd cand punem butoanele de pad (aceeasi actiune, evenimente diferite)
	_cer(_tasta("interact", KEY_E), "interact a ramas pe tasta E")
	_cer(_tasta("pause", KEY_ESCAPE), "pause a ramas pe ESC")
	_cer(Gamepad.nume_coduri("interact") == "A / X", "randul INTERACT scrie A / X, nu doar A")
	_cer(Gamepad.nume_coduri("pause") == "START", "randul PAUSE scrie START")

# ---------------------------------------------------------------- 2. remapare
func _remapare() -> void:
	print("\n[2] remapare, schimb si conflicte")
	# a. mutare simpla, fara conflict: SELECT de pe A pe Y
	Gamepad.remapeaza("ui_accept", JOY_BUTTON_Y)
	_cer(_buton("ui_accept", JOY_BUTTON_Y), "ui_accept s-a mutat pe Y")
	_cer(not _buton("ui_accept", JOY_BUTTON_A), "A nu mai e pe ui_accept (altfel ai doua butoane de confirmare)")
	_cer(_buton("interact", JOY_BUTTON_A), "interact a ramas pe A (alt context, nu se bat)")

	# b. schimb: BACK cere Y, care e luat de SELECT, deci SELECT primeste B, de unde a plecat BACK
	Gamepad.remapeaza("ui_cancel", JOY_BUTTON_Y)
	_cer(_buton("ui_cancel", JOY_BUTTON_Y), "ui_cancel a luat Y")
	_cer(_buton("ui_accept", JOY_BUTTON_B), "ui_accept a primit in schimb B")
	_cer(not _buton("ui_accept", JOY_BUTTON_Y), "Y nu a ramas pe doua actiuni deodata")

	# c. furt partial: PAUSE cere X, iar INTERACT (A + X) ramane pe A, nu pe zero butoane
	Gamepad.reseteaza_butoanele()
	Gamepad.remapeaza("pause", JOY_BUTTON_X)
	_cer(_buton("pause", JOY_BUTTON_X), "pause a luat X")
	_cer(not _buton("interact", JOY_BUTTON_X), "X a plecat de pe interact")
	_cer(_buton("interact", JOY_BUTTON_A), "interact a ramas pe A (avea doua, i-a mai ramas unul)")
	_cer(Gamepad.nume_coduri("interact") == "A", "randul INTERACT scrie acum doar A")

	# d. nicio actiune nu poate ramane fara buton, oricat te-ai juca cu ele
	Gamepad.reseteaza_butoanele()
	for pas in [["ui_accept", JOY_BUTTON_B], ["ui_cancel", JOY_BUTTON_A], ["pause", JOY_BUTTON_A],
			["interact", JOY_BUTTON_START], ["ui_accept", JOY_BUTTON_A]]:
		Gamepad.remapeaza(pas[0], pas[1])
	for action in Gamepad.PAD_ACTIONS:
		_cer(Gamepad.coduri(action).size() > 0, "%s a ramas cu cel putin un buton" % action)
	# si niciun buton nu sta pe doua actiuni care se folosesc in acelasi loc
	for a in Gamepad.PAD_ACTIONS:
		for b in Gamepad.PAD_ACTIONS:
			if a >= b or not Gamepad._se_bat(a, b):
				continue
			for cod in Gamepad.coduri(a):
				_cer(not cod in Gamepad.coduri(b), "%s si %s nu impart butonul %d" % [a, b, cod])

# ---------------------------------------------------------------- 3. declansatoare
func _declansator() -> void:
	print("\n[3] declansatoare (LT/RT)")
	Gamepad.reseteaza_butoanele()
	var rt: int = Gamepad.COD_AXA + JOY_AXIS_TRIGGER_RIGHT
	Gamepad.remapeaza("interact", rt)
	_cer(_axa("interact", JOY_AXIS_TRIGGER_RIGHT), "interact a ajuns pe axa 5, nu pe un buton")
	_cer(not _buton("interact", JOY_BUTTON_A), "A a plecat de pe interact")
	_cer(Gamepad.nume_cod(rt) == "RT", "pe Xbox se scrie RT")
	_cer(is_equal_approx(InputMap.action_get_deadzone("interact"), Gamepad.TRAGACI_APASAT),
		"pragul actiunii a urcat la %.1f (un declansator care sta la 0.25 in repaus nu apasa singur)" % Gamepad.TRAGACI_APASAT)
	_cer(_tasta("interact", KEY_E), "tasta E a ramas si dupa mutarea pe declansator")

# ---------------------------------------------------------------- 4. butoane interzise
func _interzise() -> void:
	print("\n[4] butoane interzise")
	Gamepad.reseteaza_butoanele()
	for cod in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_GUIDE]:
		Gamepad.remapeaza("interact", cod)
		_cer(not _buton("interact", cod), "butonul %d nu s-a putut lega (cruce / buton de sistem)" % cod)
	_cer(_buton("interact", JOY_BUTTON_A), "interact a ramas neatins dupa incercarile interzise")
	Gamepad.remapeaza("interact", Gamepad.COD_AXA + JOY_AXIS_LEFT_X)
	_cer(not _axa("interact", JOY_AXIS_LEFT_X), "stick-ul nu se poate lega ca buton")

# ---------------------------------------------------------------- 5. RESET + disc
func _reset_si_disc() -> void:
	print("\n[5] RESET si salvarea pe disc")
	Gamepad.remapeaza("ui_accept", JOY_BUTTON_Y)
	var d = _de_pe_disc()
	_cer(d is Dictionary and d.get("padbinds", {}).has("ui_accept"), "remaparea a ajuns pe disc")
	Gamepad.reseteaza_butoanele()
	d = _de_pe_disc()
	_cer(d is Dictionary and d.get("padbinds", {}).is_empty(), "RESET a golit padbinds si pe disc")
	_cer(_buton("ui_accept", JOY_BUTTON_A), "dupa RESET, ui_accept e iar pe A")
	_cer(_buton("interact", JOY_BUTTON_A) and _buton("interact", JOY_BUTTON_X), "dupa RESET, interact e iar pe A + X")
	# salvarea nu s-a stricat pe drum: restul setarilor sunt intregi
	_cer(d is Dictionary and d.has("scores") and d.has("coins"), "salvarea are mai departe scoruri si monede")

# ------------------------------------------------- 5b. apasarea chiar face ce trebuie
# Pana aici am verificat ce scrie in InputMap. Asta verifica CAPATUL CELALALT: bagam in motor un
# eveniment de controller si intrebam daca actiunea s-a aprins. Fara pasul asta, o legatura scrisa
# gresit (buton pe axa, prag prea mare) ar fi trecut toate verificarile de mai sus si ar fi picat
# abia in mana jucatorului.
func _apasarea() -> void:
	print("\n[5b] apasarea butonului nou aprinde actiunea")
	Gamepad.reseteaza_butoanele()
	Gamepad.remapeaza("ui_accept", JOY_BUTTON_Y)
	_cer(_apasa_buton(JOY_BUTTON_Y, "ui_accept"), "Y aprinde ui_accept dupa remapare")
	_cer(not _apasa_buton(JOY_BUTTON_A, "ui_accept"), "A nu mai aprinde nimic (a fost eliberat)")
	Gamepad.remapeaza("interact", Gamepad.COD_AXA + JOY_AXIS_TRIGGER_RIGHT)
	_cer(_apasa_axa(JOY_AXIS_TRIGGER_RIGHT, 1.0, "interact"), "declansatorul apasat aprinde interact")
	_cer(not _apasa_axa(JOY_AXIS_TRIGGER_RIGHT, 0.3, "interact"), "atins usor (0.3) NU aprinde nimic")
	Gamepad.reseteaza_butoanele()

func _apasa_buton(index: int, action: String) -> bool:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = true
	Input.parse_input_event(ev)
	# ⚠️ Godot aduna evenimentele si le da drumul la inceputul cadrului urmator; fara golirea asta,
	# `is_action_pressed` de mai jos ar raspunde despre cadrul TRECUT si testul ar pica degeaba.
	Input.flush_buffered_events()
	var aprins := Input.is_action_pressed(action)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	return aprins

func _apasa_axa(axa: int, valoare: float, action: String) -> bool:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axa
	ev.axis_value = valoare
	Input.parse_input_event(ev)
	# ⚠️ Godot aduna evenimentele si le da drumul la inceputul cadrului urmator; fara golirea asta,
	# `is_action_pressed` de mai jos ar raspunde despre cadrul TRECUT si testul ar pica degeaba.
	Input.flush_buffered_events()
	var aprins := Input.is_action_pressed(action)
	ev = ev.duplicate()
	ev.axis_value = 0.0
	Input.parse_input_event(ev)
	return aprins

# ---------------------------------------------------------------- 6. pagina din meniu
func _meniul() -> void:
	print("\n[6] pagina GAMEPAD din meniul adevarat")
	var meniu: Node = load("res://menu.tscn").instantiate()
	get_tree().root.add_child(meniu)
	await get_tree().process_frame
	meniu._skip_intro()
	meniu._show("settings")
	var ui = meniu._settings_ui
	_cer(ui != null, "meniul adevarat s-a deschis pe pagina de Settings")
	ui.arata_pagina("gamepad")
	await get_tree().create_timer(0.4).timeout

	# Incape in ecran? Rama ornata din meniu se croieste dupa continut, iar paginile din Settings
	# au toate marimea celei mai mari - deci un rand in plus AICI impinge rama afara din 648px.
	var afara: Control = ui
	while afara.get_parent() != null and not (afara.get_parent() is CenterContainer):
		afara = afara.get_parent()
	var ecran := get_viewport().get_visible_rect().size
	print("    rama: y=%.0f..%.0f, ecran %.0fx%.0f" % [afara.global_position.y,
		afara.global_position.y + afara.size.y, ecran.x, ecran.y])
	_cer(afara.global_position.y >= 0.0, "rama nu iese pe sus din ecran")
	_cer(afara.global_position.y + afara.size.y <= ecran.y, "rama nu iese pe jos din ecran")

	# randurile scriu ce trebuie
	_cer(ui._pad_butoane.size() == 4, "sunt 4 randuri de schimbat (INTERACT, SELECT, BACK, PAUSE)")
	_cer(ui._pad_butoane["interact"].text == "A / X", "randul INTERACT scrie A / X")
	_cer(ui._pad_butoane["pause"].text == "START", "randul PAUSE scrie START")
	await _poza("1_lista")

	# ascultarea: randul apasat arata numaratoarea, iar instructiunea se scrie sus (pe rand n-are
	# unde: 180px ficsi, si un text lung ar impinge eticheta si ar strâmba coloana)
	ui._begin_remap_pad("pause")
	_cer(ui._pad_nume.text.begins_with("press a button"), "randul de sus cere un buton")
	_cer(ui._pad_butoane["pause"].text.is_valid_int(), "pe randul apasat curge numaratoarea")
	_cer(ui._pad_butoane["interact"].text == "A / X", "celelalte randuri stau neatinse cat ascult")
	_cer(ui.is_processing(), "ascultarea merge pe _process (si cu jocul oprit)")
	await get_tree().create_timer(0.5).timeout
	print("    numaratoarea dupa 0,5s: ", ui._pad_butoane["pause"].text)
	await _poza("2_ascult")
	ui.cancel_remap()
	_cer(ui._pad_butoane["pause"].text == "START", "la renuntare, randul isi ia textul inapoi")
	_cer(not ui._pad_nume.text.begins_with("press a button"), "randul de sus scrie iar ce controller e")
	_cer(not ui.is_processing(), "dupa renuntare nu mai macinam _process degeaba")

	# rand schimbat din afara: pagina se ia dupa el, iar RESET-ul ei pune totul la loc
	Gamepad.remapeaza("ui_cancel", JOY_BUTTON_Y)
	ui._reimprospateaza_pad()
	_cer(ui._pad_butoane["ui_cancel"].text == "Y", "randul BACK s-a schimbat dupa remapare")
	ui._on_reset_pad()
	_cer(ui._pad_butoane["ui_cancel"].text == "B", "RESET-ul din pagina a pus totul la loc")

# ---------------------------------------------------------------- unelte
func _pune_copia() -> void:
	Gamepad.reseteaza_butoanele()
	if _copie.is_empty():
		print("\n(nu era nicio salvare pe disc la start, n-am ce pune la loc)")
		return
	var f := FileAccess.open(SALVARE, FileAccess.WRITE)
	if f != null:
		f.store_buffer(_copie)
		f = null
	var acum := FileAccess.get_file_as_bytes(SALVARE)
	_cer(acum == _copie, "salvarea lui Razvan e bit cu bit cum era inainte de test (%d octeti)" % _copie.size())

func _de_pe_disc():
	var f := FileAccess.open(SALVARE, FileAccess.READ)
	return f.get_var() if f != null else null

func _buton(action: String, index: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == index:
			return true
	return false

func _axa(action: String, axa: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and ev.axis == axa:
			return true
	return false

func _tasta(action: String, kc: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == kc:
			return true
	return false

func _poza(nume: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(POZE % nume)

func _cer(conditie: bool, mesaj: String) -> void:
	if conditie:
		print("  OK  ", mesaj)
	else:
		_erori += 1
		print("  ✘   ", mesaj)
