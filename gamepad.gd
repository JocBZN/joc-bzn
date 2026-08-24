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
# Ce NU face: nu desenează iconițe de buton, ci le scrie cu litere, cu numele consolei potrivite
# (A pe Xbox, ✕ pe PlayStation). Stick-ul stâng și crucea rămân pe mers și pe navigare orice ar
# fi — restul butoanelor se schimbă din Settings → GAMEPAD (vezi `PAD_ACTIONS` și `remapeaza()`).

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

# Butoanele de pad care se pot SCHIMBA din Settings → GAMEPAD. Pentru fiecare: ce scrie pe rândul
# lui în meniu, pe ce butoane stă din fabrică și în ce context se folosește.
#
# `unde` e cheia întregii remapări: două acțiuni se bat cap în cap doar dacă se folosesc în
# ACELAȘI loc. „interact" (în joc) și „ui_accept" (în meniuri) pot sta liniștite amândouă pe A —
# asta e chiar setarea din fabrică, și e bună: în joc nu e niciun meniu deschis, iar în meniu
# n-ai ce interacționa. „ui_accept" și „ui_cancel", în schimb, trăiesc pe același ecran.
#
# ⚠️ Ordinea contează: în ea se desenează rândurile din Settings.
const PAD_ACTIONS := {
	"interact":  {"eticheta": "INTERACT", "implicit": [JOY_BUTTON_A, JOY_BUTTON_X], "unde": ["joc"]},
	# ⚠️ Dash-ul NU stă pe B, deși B pare liber în joc: `pause.gd` ascultă ȘI `ui_cancel`, care
	# pe pad e chiar B — deci un dash pus acolo ar fi deschis meniul de pauză la fiecare pas.
	# RB e butonul de „abilitate" din reflexul oricui a ținut un controller în mână.
	"dash":      {"eticheta": "DASH",     "implicit": [JOY_BUTTON_RIGHT_SHOULDER],  "unde": ["joc"]},
	"ui_accept": {"eticheta": "SELECT",   "implicit": [JOY_BUTTON_A],               "unde": ["meniu"]},
	"ui_cancel": {"eticheta": "BACK",     "implicit": [JOY_BUTTON_B],               "unde": ["meniu"]},
	"pause":     {"eticheta": "PAUSE",    "implicit": [JOY_BUTTON_START],           "unde": ["joc", "meniu"]},
}

# Butoanele pe care NU le dăm la schimbat: crucea (e mers ȘI navigare prin meniuri — pusă pe
# „confirmă", ar apăsa exact butonul peste care tocmai a ajuns) și butonul de acasă, care e al
# sistemului, nu al jocului (pe Windows deschide bara de joc, nu ajunge niciodată la noi).
const INTERZISE := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_GUIDE]

# Declanșatoarele (LT/RT, L2/R2) nu sunt butoane pentru Godot, ci AXE. Ca să poată sta în aceeași
# listă cu butoanele — și în același rând din meniu — le dăm coduri de la 1000 în sus:
# 1000 + numărul axei. Un cod peste 1000 înseamnă „declanșator", orice altceva e buton.
const COD_AXA := 1000
# De la cât în sus zicem că un declanșator e apăsat. Nu e prag de gust: pe unele drivere axele
# 4-5 stau la valori mici cât nu le atinge nimeni (vezi `_pad_e_atins`), iar 0.7 e destul de sus
# cât să nu se lege singur un buton în timp ce jucătorul ține controllerul în poală.
const TRAGACI_APASAT := 0.7

# Mersul: stick-ul stâng ȘI crucea, pe aceleași acțiuni ca WASD. Stick-ul e ANALOG — cu cât îl
# împingi mai puțin, cu atât mergi mai încet (vezi `player.gd`, `Input.get_vector`).
const PAD_MISCARE := {
	"move_left":  {"axa": JOY_AXIS_LEFT_X, "spre": -1.0, "cruce": JOY_BUTTON_DPAD_LEFT},
	"move_right": {"axa": JOY_AXIS_LEFT_X, "spre":  1.0, "cruce": JOY_BUTTON_DPAD_RIGHT},
	"move_up":    {"axa": JOY_AXIS_LEFT_Y, "spre": -1.0, "cruce": JOY_BUTTON_DPAD_UP},
	"move_down":  {"axa": JOY_AXIS_LEFT_Y, "spre":  1.0, "cruce": JOY_BUTTON_DPAD_DOWN},
}

# Ce scrie pe ecran pentru fiecare BUTON, pe fiecare fel de controller. Godot numește butoanele
# după Xbox (JOY_BUTTON_A = butonul de jos-dreapta), iar pe PlayStation ăla e ✕.
#
# ⚠️ Tabelul e pe COD, nu pe acțiune (cum era până la remapare): butonul scris în joc („apasă A ca
# să folosești") se ia acum din ce are jucătorul CHIAR legat, nu dintr-un tabel care presupunea că
# A rămâne pe „folosește" pentru totdeauna.
const NUME_COD := {
	"xbox": {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "VIEW", JOY_BUTTON_START: "START",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		COD_AXA + JOY_AXIS_TRIGGER_LEFT: "LT", COD_AXA + JOY_AXIS_TRIGGER_RIGHT: "RT",
	},
	"ps": {
		JOY_BUTTON_A: "✕", JOY_BUTTON_B: "◯", JOY_BUTTON_X: "▢", JOY_BUTTON_Y: "△",
		JOY_BUTTON_BACK: "SHARE", JOY_BUTTON_START: "OPTIONS",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_TOUCHPAD: "TOUCH",
		COD_AXA + JOY_AXIS_TRIGGER_LEFT: "L2", COD_AXA + JOY_AXIS_TRIGGER_RIGHT: "R2",
	},
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
	if PAD_ACTIONS.has(action):
		for cod in coduri(action):
			_adauga_cod(action, cod)

func _buton(index: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = index
	return ev

# Navigarea din meniuri (`ui_up`, `ui_accept`, …) vine gata cu butoane de pad din Godot, dar
# NU ne bazăm pe asta: verificăm și completăm ce lipsește. Costă zece linii și scapă jocul de o
# categorie întreagă de „la mine merge" (un `project.godot` cu `input_devices/…` reglat altfel,
# o versiune viitoare care schimbă implicitele).
func _leaga_ui() -> void:
	# ⚠️ `ui_accept` și `ui_cancel` NU sunt aici, deși tot navigare sunt: ele se pot schimba din
	# Settings, deci le pune `aplica_butoane()`, DUPĂ ce s-au citit setările de pe disc. Dacă ar
	# fi rămas aici, A și B ar fi fost lipite la loc la fiecare pornire, peste alegerea omului.
	var vrem := {
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

# --------------------------------------------------------------------------------------
# BUTOANELE CARE SE POT SCHIMBA
# --------------------------------------------------------------------------------------
# Ce butoane are ACUM o acțiune: cele alese de jucător, altfel cele din fabrică.
func coduri(action: String) -> Array:
	if not PAD_ACTIONS.has(action):
		return []
	var alese = GameSettings.padbinds.get(action, null)
	if alese is Array and not alese.is_empty():
		return alese
	return PAD_ACTIONS[action]["implicit"]

# Pune pe „ui_accept" și „ui_cancel" butoanele alese de jucător. O cheamă `GameSettings`, o dată
# la pornire (după `_load()`) și după fiecare remapare.
#
# ⚠️ De ce nu direct în `_ready()`-ul de aici: autoload-ul ăsta e PRIMUL din listă, deci când
# pornește el `GameSettings` încă nu și-a citit fișierul — n-avem de unde ști ce buton a ales
# jucătorul. Acțiunile de JOC („interact", „pause") ajung pe drumul celălalt, prin
# `GameSettings._bind()` → `leaga_pad()`, care oricum se cheamă după încărcare.
func aplica_butoane() -> void:
	for action in ["ui_accept", "ui_cancel"]:
		if not InputMap.has_action(action):
			continue
		_sterge_padul(action)
		for cod in coduri(action):
			_adauga_cod(action, cod)

# Scoate de pe o acțiune TOT ce vine de la controller, lăsând tastele pe loc. Fără asta, butonul
# din fabrică (A pe „ui_accept", pus de motor, nu de noi) ar fi rămas legat pe lângă cel nou — și
# ai fi avut două butoane de confirmare, dintre care unul nu scrie nicăieri în meniu.
func _sterge_padul(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			InputMap.action_erase_event(action, ev)

# Un cod (buton sau declanșator) devine eveniment pe acțiune.
func _adauga_cod(action: String, cod: int) -> void:
	if cod < COD_AXA:
		InputMap.action_add_event(action, _buton(cod))
		return
	var ax := InputEventJoypadMotion.new()
	ax.axis = cod - COD_AXA
	ax.axis_value = 1.0
	InputMap.action_add_event(action, ax)
	# ⚠️ Pragul acțiunii, nu doar al evenimentului: `ui_accept` vine din motor cu deadzone 0.2, iar
	# un declanșator care stă la 0.25 în repaus (drivere de clonă) ar fi apăsat „confirmă" singur,
	# la nesfârșit, în orice meniu. Acțiunile din PAD_ACTIONS n-au nimic analogic pe ele, deci
	# pragul ăsta nu strică nimic altceva (mersul e pe alte acțiuni, cu `DEADZONE`).
	InputMap.action_set_deadzone(action, TRAGACI_APASAT)

# Leagă un buton pe o acțiune. Aici stă toată grija remapării: un buton nu poate sta pe două
# acțiuni care se folosesc în același loc, iar nicio acțiune n-are voie să rămână FĂRĂ buton —
# altfel jucătorul ar putea, dintr-o singură apăsare, să rămână închis într-un meniu din care nu
# mai iese (pe controller nu există „mai apasă o tastă", există doar ce e legat).
#
# Regula, în două rânduri:
#   • butonul cerut se ia de la acțiunea care se bătea cu asta — dacă îi mai rămâne unul, gata;
#   • dacă aia rămâne pe zero, primește în schimb butonul pe care tocmai l-am eliberat noi.
# Adică: pui SELECT pe B (unde stătea BACK) → BACK se mută pe A, de unde a plecat SELECT. Iar
# dacă pui PAUSE pe X, INTERACT (care avea A și X) rămâne pur și simplu pe A.
func remapeaza(action: String, cod: int) -> void:
	if not PAD_ACTIONS.has(action) or not e_bun(cod):
		return
	var vechi: Array = coduri(action)
	var noi: Dictionary = GameSettings.padbinds.duplicate(true)
	for alta in PAD_ACTIONS:
		if alta == action or not _se_bat(alta, action):
			continue
		var lista: Array = coduri(alta).duplicate()
		if not lista.has(cod):
			continue
		lista.erase(cod)
		if lista.is_empty():
			lista = [vechi[0]]
		noi[alta] = lista
	noi[action] = [cod]
	GameSettings.set_padbinds(noi)

# Înapoi la butoanele din fabrică (butonul RESET din Settings). Un dicționar gol înseamnă „nimic
# schimbat", deci `coduri()` cade singur pe `implicit` — nu ținem nicăieri o copie a valorilor
# din fabrică, care s-ar putea despărți de ele.
func reseteaza_butoanele() -> void:
	GameSettings.set_padbinds({})

# Două acțiuni se bat doar dacă se folosesc în același loc (vezi `unde` din PAD_ACTIONS).
func _se_bat(a: String, b: String) -> bool:
	for u in PAD_ACTIONS[a]["unde"]:
		if PAD_ACTIONS[b]["unde"].has(u):
			return true
	return false

# Se poate lega butonul ăsta? (crucea și butonul de acasă, nu — vezi INTERZISE)
func e_bun(cod: int) -> bool:
	if cod >= COD_AXA:
		return (cod - COD_AXA) in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
	return cod >= 0 and not INTERZISE.has(cod)

# Primul buton bun apăsat CHIAR ACUM, sau -1. Îl folosește pagina de Settings cât ascultă.
#
# ⚠️ Se citește starea controllerului, nu se așteaptă evenimente — aceeași capcană ca la
# `_asculta_padul`: apăsarea ar fi ajuns întâi la butonul din meniu care are focus (pe pad, A
# înseamnă „apasă butonul focusat") și s-ar fi consumat acolo, iar remaparea ar fi așteptat un
# eveniment care nu mai vine.
func cod_apasat() -> int:
	if _pad_id < 0:
		return -1
	for b in JOY_BUTTON_SDL_MAX:
		if Input.is_joy_button_pressed(_pad_id, b) and e_bun(b):
			return b
	for a in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		if Input.get_joy_axis(_pad_id, a) > TRAGACI_APASAT:
			return COD_AXA + a
	return -1

# Nimic apăsat pe controller? Se cere ÎNAINTE de a începe ascultarea: rândul din meniu se apasă
# tot cu A, deci fără verificarea asta „schimbă butonul" ar fi legat instantaneu A pe el însuși,
# și n-ai fi apucat să vezi nici măcar textul „press a button…".
func pad_liber() -> bool:
	return not _pad_e_atins() and cod_apasat() == -1

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
	return nume_coduri(action)

# Numele butoanelor unei acțiuni, INDIFERENT de ce ține jucătorul în mână (pentru lista din
# Settings, care e despre controller chiar dacă o deschizi cu mouse-ul). Două butoane pe aceeași
# acțiune se scriu „A / X" — adică exact ce e legat, nu doar primul.
func nume_coduri(action: String) -> String:
	var lista: Array = coduri(action)
	if lista.is_empty():
		lista = coduri("ui_accept")   # o acțiune fără buton al ei se arată cu cel de „confirmă"
	var out := PackedStringArray()
	for cod in lista:
		out.append(nume_cod(cod))
	return " / ".join(out)

# Numele unui singur buton, pe felul de controller conectat acum. Unul necunoscut (paletele de pe
# spatele controllerelor scumpe, butoanele în plus de pe clone) se scrie cu numărul lui: mai bine
# „B17" decât un rând gol, care pare stricat.
func nume_cod(cod: int) -> String:
	var tabel: Dictionary = NUME_COD[_fel]
	if tabel.has(cod):
		return String(tabel[cod])
	return "B%d" % cod

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
	var ring: StyleBoxFlat = null
	if hover is StyleBoxFlat:
		# Nu punem hover-ul CA ATARE, ci o copie cu muchia aprinsă și trasă puțin în afara
		# butonului. Motivul se vede pe START: el are deja, în repaus, o muchie de aramă
		# deschisă (e butonul principal), deci un hover copiat exact peste el nu s-ar fi
		# deosebit cu nimic — pe controller n-ai cursor, deci dacă nu se vede unde ești, nu
		# știi ce apeși. Inelul ăsta se vede pe ORICE buton din joc, oricât de luminos ar fi.
		ring = hover.duplicate()
		ring.border_color = FOCUS_MUCHIE
		ring.set_border_width_all(maxi(3, ring.border_width_top))
	else:
		# ⚠️ Butoanele care poartă o PLĂCUȚĂ de aramă (`menu.gd`, de pe 2026-08-24) au hover-ul
		# un `StyleBoxTexture` — n-ai ce duplica și ce colora. Fără ramura asta rămâneau complet
		# fără inel, adică pe controller nu se vedea deloc pe ce buton stai: exact meniul
		# principal, exact butonul START. Deci desenăm inelul singuri, o ramă goală pe dinăuntru
		# care se așază peste orice, indiferent din ce e făcut butonul.
		ring = StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.border_color = FOCUS_MUCHIE
		ring.set_border_width_all(3)
		ring.set_corner_radius_all(0)
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
