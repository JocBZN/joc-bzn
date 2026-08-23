extends CanvasLayer

# BARBUT CU DUBIOSU — 1v1 la zaruri cu omul în palton (`dubiosu.gd`), în Nether.
#
# De pe 2026-08-14 omul nu mai vinde NIMIC: cele patru iteme ale lui (Cursed Tome, Iron Helmet,
# Blame Circle, Arcane Magic) au fost scoase de tot din joc, iar în locul lor a rămas un pariu.
# Cum decurge:
#   1. dă EL primul, cu două zaruri — nu-l întreabă nimeni, el ține banca;
#   2. îți spune miza și te lasă să alegi: ROLL sau WALK AWAY;
#   3. dai și tu două zaruri. Sumă mai mare = câștigi, mai mică = pierzi, egal = se dă din nou.
#
# Miza:
#   • câștigi → un status la întâmplare crește cu 25%;
#   • pierzi  → un status la întâmplare scade cu 25% ȘI jocul devine cu 10% mai greu
#     (`Difficulty.add_trade_penalty`, exact mecanismul de la Alba-Neagra și de la statuia Ender).
#
# ⚠️ WALK AWAY e GRATIS — cerut așa de Răzvan pe 2026-08-14, după ce i-am arătat gaura: îi vezi
# zarul ÎNAINTE să te hotărăști, deci poți să joci doar când el a dat mic și să pleci când a dat
# mare. Jucat perfect, pariul iese aproape mereu în favoarea ta. Dacă vrei să-l închizi, sunt două
# schimbări mici: ori scoți butonul (vezi `_pe_pleaca`), ori îi pui un preț (ex. numai `PEDEAPSA`,
# fără minusul pe stat).
#
# Cum se leagă: E pe om → `dubiosu.gd::invoca()` → `open()` de aici. Jocul se OPREȘTE
# (`get_tree().paused`), iar meniul merge mai departe fiindcă nodul e `PROCESS_MODE_ALWAYS`.
# Un om joacă o SINGURĂ dată (vezi `dubiosu.gd::consuma`) — dacă pleci fără să dai, l-ai ars.

# --- MIZA (schimbă-le liniștit) ---
const CASTIG := 1.25       # +25% la un status, dacă îl bați
const PIERDERE := 0.75     # -25% la un status, dacă pierzi
const PEDEAPSA := 0.10     # +10% dificultate pe deasupra, dacă pierzi (aceeași cifră ca la Alba-Neagra)

# Statusurile pe care le poate atinge pariul. Numele sunt EXACT cele din panoul de statusuri
# (`player.stat_lines`), deci se traduc singure și îți spun în aceiași termeni ce ai pățit.
#
# ⚠️ Sunt doar statusuri care NU pot fi zero la începutul rundei. Crit și Luck pornesc de la 0, iar
# +25% din 0 tot 0 face — ai fi câștigat un pariu care nu-ți dă nimic și ai fi crezut că e stricat.
const STATS := ["Damage", "Attack Speed", "Move Speed", "Max HP", "Weapon Size"]

# Pe masă sunt PATRU zaruri: 0 și 1 sunt ale lui (stânga), 2 și 3 ale tale (dreapta). Constantele
# astea două sunt indexul primului zar din fiecare pereche și se plimbă peste tot ca „cine dă acum".
const EL := 0
const TU := 2

# ---------------------------------------------------------------------------
# ASPECTUL
# ---------------------------------------------------------------------------
# De pe 2026-08-13 meniul e îmbrăcat în ARAMA CASEI, nu în verdele lui: aceeași planșă
# `Border EGT.png` și aceeași paletă ca la meniul principal, pauză, cazinou, Alba-Neagra și level
# up (cerut de Răzvan). Planșa veche `harta/Upgrade Dubios/Border Dubios.png` a rămas pe disc,
# nefolosită — dacă vrei verdele înapoi, schimbi `SHEET` și cele patru culori de mai jos.
#
# Planșa e 5×4 celule de 64px; fiecare celulă e o ramă întreagă, deci se folosește ca NinePatch:
# colțurile rămân întregi, laturile se întind.
const SHEET := "res://harta/EGT/Border EGT.png"
const CELULA := 64
const CH_PANOU := Vector2i(2, 0)     # rama mare din jurul ecranului (spirale în colțuri)
const CH_MASA := Vector2i(3, 2)      # rama din jurul mesei de zaruri (dublă, colțuri tăiate)
const CH_SCOR := Vector2i(1, 1)      # cele două cutii de scor, HIM și YOU (dublă, simplă)
const CH_BUTON := Vector2i(1, 3)     # butonul (subțire, cu bumbi în colțuri)

const ACCENT := Color8(198, 118, 80)
const ACCENT_CLAR := Color8(222, 152, 116)
const ACCENT_STINS := Color8(116, 62, 42)
const ROSU := Color8(206, 78, 62)      # rândul de rezultat când ai pierdut pariul
const OS_ALB := Color8(232, 224, 214)
const CENUSA := Color8(150, 142, 138)
const FUNDAL := Color8(17, 14, 20)

const PANOU_W := 780.0
const PANOU_H := 560.0
const MASA_W := 560.0      # fereastra prin care se vede masa de zaruri
const MASA_H := 190.0
const SCOR_H := 88.0       # cutiile cu sumele de pe masă (HIM | YOU)

# ⚠️ Cutia de scor a cui n-a dat încă NU e ascunsă de tot, ci lăsată stinsă: locul ei e ținut
# oricum (altfel panoul și-ar schimba înălțimea la jumătatea aruncării), iar goală de tot lăsa o
# gaură mare între masă și buton, de parcă meniul era neterminat.
const SCOR_ASTEPTARE := 0.22

# ---------------------------------------------------------------------------
# MASA DE ZARURI (3D)
# ---------------------------------------------------------------------------
# Zarurile sunt 3D adevărat, randate într-un `SubViewport` cu lumea LUI și lipite ca textură în
# panoul 2D. Jocul e 2D, deci lumea asta nu atinge nimic din restul lui.
#
# ⚠️ Viewport-ul se randează la DUBLU (`SUPRA`) și se strânge la loc în `TextureRect`: fără asta
# muchiile zarurilor ies zimțate, fiindcă fereastra e mică.
#
# ⚠️ `render_target_update_mode` stă pe DISABLED cât meniul e închis. Altfel jocul ar plăti o
# randare 3D în fiecare cadru, tot timpul rundei, pentru un ecran pe care nu-l vede nimeni.
const SUPRA := 2

# Modelul lui Răzvan, exportat din 3ds Max ca glTF binar. Dacă fișierul NU există, zarurile se
# construiesc în cod (cub cu bulinele desenate) — jocul merge la fel, doar arată mai simplu.
#
# ⚠️ `Dice.max` NU se poate folosi direct: e format 3ds Max, pe care Godot nu-l citește (și nici
# Blender). Trebuie exportat: 3ds Max → File → Export → glTF Binary (.glb), aici.
#
# ⚠️ Când apare modelul, VERIFICĂ pe ce direcție cade fiecare față: `_baza_pentru()` de mai jos
# presupune 1 sus, 6 jos, 3 pe +X, 4 pe −X, 5 pe +Z, 2 pe −Z. Dacă modelul e numerotat altfel,
# zarurile se opresc pe cifra greșită — itemul rămâne corect (el vine din pereche), dar cifra de
# pe masă nu se mai potrivește cu ce scrie dedesubt.
const MODEL_ZAR := "res://harta/Upgrade Dubios/Dice.glb"

const MARIME_ZAR := 0.9        # latura cubului, în unități 3D
const PODEA_Y := -MARIME_ZAR * 0.5

# Unde se opresc cele PATRU zaruri: două în stânga (ale LUI), două în dreapta (ale TALE). Masa e
# împărțită în două tabere, ca la orice 1v1 — de pe ce jumătate stau zarurile știi a cui e suma,
# fără să mai citești nimic.
#
# În fiecare pereche zarurile NU sunt în oglindă dinadins: două zaruri așezate perfect simetric
# arată a poză de catalog, nu a masă pe care tocmai s-a aruncat. Unul stă mai în față, altul mai în
# spate, și peste locurile astea se mai pune o zvâcnitură la fiecare aruncare (`_arunca`).
#
# ⚠️ Depărtarea pe Z (0.50 față de −0.48, adică aproape o lățime de zar) nu e doar de frumusețe:
# al doilea zar trebuie să treacă pe deasupra locului primului ca s-ajungă la al lui, iar cu
# culoare apropiate cele două se suprapuneau pe ecran fix la mijlocul aruncării, de parcă unul
# intra prin celălalt.
#
# ⚠️ Nu le împinge mai în lături de ±2.1: camera vede ±3.2 unități pe orizontală (`CAM_FOV` cu
# `KEEP_WIDTH`, de la distanța ei), iar zarul e lat de 0.9 — de pe la ±2.8 muchia lui iese din cadru.
const LOCURI := [
	Vector3(-2.02, 0.0, 0.50), Vector3(-0.98, 0.0, -0.48),   # ale lui
	Vector3(0.98, 0.0, -0.48), Vector3(2.02, 0.0, 0.50),     # ale tale
]

# Cât de rotunjite sunt muchiile (0 = cub tăios, ca înainte; 0.5 = bilă). Un zar adevărat are
# colțurile tocite, iar tocitura e cea care prinde lumina și îi dă volum — cubul tăios de dinainte
# ieșea o pată plată, oricâtă lumină puneai pe el.
const ROTUNJIME := 0.17
const DIVIZIUNI := 7           # câte pătrățele are latura unei fețe (mai multe = rotunjire mai fină)

# Camera: privește masa de sus-față. `KEEP_WIDTH` = `fov` e pe ORIZONTALĂ, deci încadrarea nu se
# strică dacă schimbi `MASA_W`/`MASA_H`.
#
# ⚠️ Camera stă DEPARTE (≈11 unități) cu unghi mic, nu aproape cu unghi mare. Prima încercare era
# la 6.8 și tăia zarurile de jos: fereastra e o fâșie lată de tot (560×190), deci pe verticală
# încape foarte puțin — la `fov` 33 și distanța 11 se văd ~2.2 unități pe înălțime, adică zarul
# (0.9) plus saltul lui, cu aer împrejur. Muți camera mai aproape → tai zarurile.
const CAM_POZ := Vector3(0.0, 5.2, 9.6)
const CAM_TINTA := Vector3(0.0, 0.15, 0.0)
const CAM_FOV := 33.0

# ---------------------------------------------------------------------------
# CUM SE ARUNCĂ
# ---------------------------------------------------------------------------
# Prima variantă (dimineața lui 2026-08-13) muta zarurile de la stânga la locul lor cu o singură
# frânare de 0.35s și le rotea cu viteză fixă, apoi le răsucea brusc pe fața care a ieșit. Ieșea
# rău din trei motive, toate vizibile dacă filmezi aruncarea cadru cu cadru:
#   1. ajungeau pe loc în prima treime și pe urmă STĂTEAU o jumătate de secundă, tremurând;
#   2. nu atingeau niciodată masa — „săritura" era un sinus care le ridica, nu o cădere;
#   3. făceau amândouă exact același lucru, în același moment.
#
# Acum: pe VERTICALĂ e gravitație adevărată, cu ciocnituri de masă și restituție (fiecare săritură
# e mai mică și mai deasă decât cea de dinainte — ăsta e ritmul „tac … tac .. tac.tac" pe care
# urechea îl știe de la barbut). Ciocnitura se calculează pe COLȚUL cel mai de jos al zarului
# rotit, nu pe centrul lui, deci zarul chiar cade pe un colț și se răstoarnă de pe el.
#
# Pe ORIZONTALĂ, în schimb, drumul e desenat de mână (de la mână până la locul lui, cu frânare),
# nu simulat. Motivul e practic: o simulare adevărată se oprește unde vrea ea, iar fereastra e o
# fâșie îngustă — un zar care iese din cadru sau se urcă peste celălalt strică tot ecranul. Ce dă
# senzația de fizică e săritura și rotația, nu traiectoria laterală; așa avem și una, și alta.
const GRAVITATIE := 24.0       # unități/s²; masa e mică, deci „greutatea" e mai mare decât 9.8
const RESTITUTIE := 0.52       # cât din viteza pe verticală se întoarce după o ciocnitură
const OPRIRE := 1.95           # sub atâta nu mai sare: se lasă pe fața care a ieșit
const SARITURI_MAX := 4        # plasă de siguranță, ca aruncarea să nu se lungească niciodată
const T_ORIZONTAL := [0.68, 0.82, 0.68, 0.82]   # cât ține drumul lateral al fiecăruia, din mână până pe loc
const T_ASEZARE := 0.34        # răsturnarea finală pe fața care a ieșit

# Fiecare zar pleacă altfel: altă înălțime, altă întârziere, altă rotație. Diferențele sunt mici,
# dar ele fac ca zarurile să nu se oprească în același cadru — și tocmai oprirea decalată e ce
# deosebește o aruncare de o animație.
#
# ⚠️ `X_PORNIRE` stă LIPIT de marginea cadrului (care e pe la ±3.2), nu departe în afara lui:
# prima încercare le trimitea de la −4.9 și zarurile intrau în ecran abia după o treime din
# aruncare — te uitai o treime de secundă la o masă goală.
#
# Fiecare aruncă de la el de-acasă: EL din stânga, TU din dreapta. Al doilea zar al fiecăruia
# pleacă de mai departe și zboară peste locul primului — de aia perechea nu cade „în bloc".
const X_PORNIRE := [-3.6, -4.0, 3.6, 4.0]   # de unde vin aruncate, ca din mână
const H_PORNIRE := [1.15, 1.32, 1.15, 1.32]
const INTARZIERE := [0.0, 0.13, 0.0, 0.13]
const SPIN := [14.5, 12.5, -14.5, -12.5]   # rad/s la plecare (ale tale se rostogolesc invers, vin din partea cealaltă)
const SPIN_LOVIT := 0.62       # cât din rotație rămâne după o ciocnitură de masă
const HOP_ASEZARE := 0.09      # cât se ridică zarul cât se răstoarnă pe ultima față
const PAUZA_REZULTAT := 0.16   # o clipă de liniște după ce s-au oprit, înainte de sumă
# Cât stai cu masa goală în față până ia el zarurile. Fără pauza asta meniul se deschide DEJA cu
# zarurile lui în aer, iar tu nu apuci să vezi că el a fost primul — pare că ai dat tu.
const PAUZA_EL := 0.55

# Fața zarului: ce cifră stă pe ce direcție. Fețele opuse fac 7, ca la zarul adevărat.
const FETE := [
	{"val": 1, "n": Vector3.UP,      "u": Vector3.RIGHT},
	{"val": 6, "n": Vector3.DOWN,    "u": Vector3.RIGHT},
	{"val": 3, "n": Vector3.RIGHT,   "u": Vector3.BACK},
	{"val": 4, "n": Vector3.LEFT,    "u": Vector3.FORWARD},
	{"val": 5, "n": Vector3.BACK,    "u": Vector3.RIGHT},
	{"val": 2, "n": Vector3.FORWARD, "u": Vector3.LEFT},
]

# Bulinele, ca poziții într-un caroiaj 3×3 (0 = sus/stânga, 2 = jos/dreapta).
const BULINE := {
	1: [Vector2i(1, 1)],
	2: [Vector2i(0, 0), Vector2i(2, 2)],
	3: [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)],
	4: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)],
	5: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 2)],
	6: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(2, 2)],
}
const CELULA_ZAR := 96         # cât de mare e o față în planșa desenată în cod
const FILDES := Color8(238, 227, 205)
const NEGRU_BULINA := Color8(24, 16, 13)    # peretele scobiturii, dinspre lumină
const BULINA_FUND := Color8(88, 56, 41)     # fundul ei, unde se mai întoarce un pic de lumină

# ---------------------------------------------------------------------------
# asteapta = masa goală, el ia zarurile | rostogolire = zboară perechea cuiva |
# alegi = i-ai văzut suma, ROLL sau WALK AWAY | rezultat = s-a socotit mâna (sau a ieșit egal și
# se dă din nou) | inchis = meniul nu e pe ecran
var _stare := "inchis"
var _cine := EL            # a cui pereche e în aer acum
var _npc: Node = null
var _sheet_img: Image = null

var _lbl_stare: Label
var _lbl_risc: Label       # rândul de sub scor: ce pățești dacă pierzi
var _lbl_el: Label         # suma lui, în cutia din stânga
var _lbl_tu: Label         # a ta, în cea din dreapta
var _cutie_el: Control
var _cutie_tu: Control
var _btn: Button           # ROLL THE DICE / ROLL AGAIN / CONTINUE
var _btn_pleaca: Button    # WALK AWAY (numai cât alegi)

var _vp: SubViewport
var _cam: Camera3D
var _zaruri := []          # Node3D × 4 (0,1 ale lui; 2,3 ale tale)
var _umbre := []           # pata de umbră de sub fiecare zar (MeshInstance3D × 4)
var _d := [1, 1, 1, 1]     # ce a ieșit pe fiecare zar
var _z := []               # starea aruncării, câte un dicționar de zar ARUNCAT ACUM (vezi `_arunca`)
var _t := 0.0              # cât e de când s-au oprit toate
var _pauza := 0.0          # cât mai are de așteptat până dă el (starea „asteapta")
var _suma_el := 0          # sumele mâinii de acum; 0 = n-a dat încă
var _suma_tu := 0
var _egalitate := false    # ultima mână a ieșit egal → butonul dă din nou, nu închide
var _zguduie := 0.0        # cât mai tremură camera după ultima ciocnitură
var _boxe := []            # boxele pentru ciocnituri (vezi `_bufnitura`)
var _boxa := 0

func _ready() -> void:
	add_to_group("dubios_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12                # peste HUD și Level Up (10), sub meniul de pauză (15)
	visible = false

	var overlay := ColorRect.new()
	overlay.color = Color(FUNDAL.r, FUNDAL.g, FUNDAL.b, 0.985)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build()

# ---------------------------------------------------------------------------
# DESCHIDERE / ÎNCHIDERE
# ---------------------------------------------------------------------------
func open(npc: Node = null) -> void:
	if visible:
		return
	_npc = npc
	_zguduie = 0.0
	# Zarurile stau cuminți pe masă până se aruncă, pe fețe la întâmplare — altfel te-ar întâmpina
	# de fiecare dată aceeași masă și ar arăta a poză, nu a masă de joc. Ce se vede acum nu
	# înseamnă nimic: contează doar ce e scris în cutiile de scor.
	_d = [randi_range(1, 6), randi_range(1, 6), randi_range(1, 6), randi_range(1, 6)]
	_z.clear()
	for i in _zaruri.size():
		var z: Node3D = _zaruri[i]
		z.position = LOCURI[i]
		z.basis = Basis(Vector3.UP, randf() * TAU) * _baza_pentru(_d[i])
		_aseaza_umbra(i)
	_mana_noua()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = true
	get_tree().paused = true
	Audio.pause_forest_ambient()
	Audio.enter_menu_muffle("dubios")   # muzica lumii curge mai departe, dar se aude prin filtru
	Audio.play("levelup", -4.0, 0.0)

# Începutul unei MÂINI: masa se șterge (nicio sumă nu mai contează), butoanele se ascund și el se
# pregătește să dea. Se cheamă și la deschidere, și la egalitate („ROLL AGAIN").
#
# Nu întoarcem zarurile pe alte fețe: ele rămân unde au căzut, doar cutiile de scor se sting. Un
# zar care își schimbă singur fața stând pe masă se vede ca o eroare, iar cutia stinsă spune deja
# limpede că ce e pe masă nu mai e în joc.
func _mana_noua() -> void:
	_stare = "asteapta"
	_pauza = PAUZA_EL
	_t = 0.0
	_egalitate = false
	_suma_el = 0
	_suma_tu = 0
	_lbl_el.text = ""
	_lbl_tu.text = ""
	for c in [_cutie_el, _cutie_tu]:
		c.modulate = Color(1, 1, 1, SCOR_ASTEPTARE)
		c.scale = Vector2.ONE          # un „pumn" rămas de la mâna trecută (vezi `_pumn`)
	# masa se golește DE TOT: zarurile care n-au fost aruncate în mâna asta nu se văd. Lăsate pe
	# masă, arătau niște fețe care nu însemnau nimic (rămase din mâna trecută sau de la deschidere),
	# iar ochiul le citea ca pe o sumă care contează.
	for i in _zaruri.size():
		_arata_zar(i, false)
	_spune("He rolls first", CENUSA)
	_lbl_risc.text = ""
	_btn.visible = false
	_btn_pleaca.visible = false

# Un zar pe masă sau luat de pe ea. Umbra lui merge la fel — altfel ar rămâne o pată de umbră sub
# un zar care nu se vede.
func _arata_zar(i: int, on: bool) -> void:
	if i < _zaruri.size():
		(_zaruri[i] as Node3D).visible = on
	if i < _umbre.size():
		(_umbre[i] as MeshInstance3D).visible = on

# Rândul de sub linia de titlu: ce ai de făcut acum, sau ce ai pățit.
func _spune(text: String, culoare: Color) -> void:
	_lbl_stare.text = text
	_lbl_stare.add_theme_color_override("font_color", culoare)

func _inchide() -> void:
	visible = false
	_stare = "inchis"
	# ⚠️ oprim randarea 3D: altfel masa de zaruri se desenează în continuare, în fiecare cadru,
	# în spatele jocului
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_tree().paused = false
	Audio.resume_forest_ambient()
	Audio.exit_menu_muffle("dubios")   # gata meniul → filtrul se deschide la loc

# ⚠️ Ca să nu se deschidă meniul de pauză PESTE noi, `pause.gd::_blocked()` întreabă și de grupul
# „dubios_menu".
#
# ESC nu face nimic: ieșirea e butonul WALK AWAY, care există doar cât ai de ales. Cât zboară
# zarurile n-ai ce anula — ai intrat în mână.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# ARUNCAREA
# ---------------------------------------------------------------------------
func _pe_buton() -> void:
	match _stare:
		"alegi":
			_arunca(TU)
		"rezultat":
			if _egalitate:
				_mana_noua()     # a ieșit egal: mâna se dă de la capăt, el primul
			else:
				_inchide()

# WALK AWAY: pleci fără să dai. Nu te costă nimic (vezi avertismentul din capul fișierului) — dar
# omul rămâne consumat, fiindcă s-a consumat când ai apăsat E pe el (`dubiosu.gd::invoca`).
func _pe_pleaca() -> void:
	if _stare != "alegi":
		return
	_inchide()

# Aruncă perechea lui `cine` (EL sau TU). Cealaltă pereche rămâne exact unde e.
func _arunca(cine: int) -> void:
	_cine = cine
	_stare = "rostogolire"
	_t = 0.0
	_btn.visible = false
	_btn_pleaca.visible = false
	# cutia celui care dă se stinge: cifra din ea era din mâna trecută
	var cutie: Control = _cutie_el if cine == EL else _cutie_tu
	var lbl: Label = _lbl_el if cine == EL else _lbl_tu
	lbl.text = ""
	cutie.modulate = Color(1, 1, 1, SCOR_ASTEPTARE)
	cutie.scale = Vector2.ONE

	_z.clear()
	for k in 2:
		var i: int = cine + k
		_arata_zar(i, true)          # intră pe masă chiar acum, din mâna lui / a ta
		_d[i] = randi_range(1, 6)
		var loc: Vector3 = LOCURI[i] + Vector3(randf_range(-0.09, 0.09), 0.0, randf_range(-0.12, 0.12))
		var z: Node3D = _zaruri[i]
		z.position = Vector3(X_PORNIRE[i], H_PORNIRE[i], loc.z + randf_range(-0.18, 0.18))
		_z.append({
			"i": i,                           # care zar de pe masă e ăsta (0…3)
			"faza": "asteapta",
			"t": 0.0,
			"intarziere": INTARZIERE[i],
			"t_oriz": T_ORIZONTAL[i],
			"loc": loc,
			"x0": z.position.x,
			"z0": z.position.z,
			"vy": randf_range(0.1, 0.8),      # plecă ușor în sus, ca aruncat din palmă
			"ax": _axa_de_rostogol(),
			"spin": SPIN[i] * randf_range(0.9, 1.12),
			"lovituri": 0,
			"q_start": Quaternion.IDENTITY,
			"q_tinta": Quaternion.IDENTITY,
			"unghi": 0.0,
			"p_start": Vector3.ZERO,
		})
	Audio.play("button", -3.0, 0.0)

# Axă de rostogolire la întâmplare, dar niciodată aproape de verticală: un zar care se învârte
# doar în jurul lui Y arată a titirez, nu a zar aruncat.
func _axa_de_rostogol() -> Vector3:
	var ax := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0))
	if ax.length() < 0.2:
		ax = Vector3(1.0, 0.1, 0.6)
	return ax.normalized()

func _process(delta: float) -> void:
	if not visible:
		return
	# ⚠️ delta se plafonează: dacă jocul înțepenește un sfert de secundă (un shader compilat, o
	# fereastră mutată), un pas de 0.25s ar trece zarul prin masă și l-ar arunca pe sub ea.
	delta = minf(delta, 0.05)
	_misca_camera(delta)
	if _stare == "asteapta":
		# clipa de dinaintea aruncării lui. Numărăm aici, nu cu un `Timer`/tween: jocul e pe pauză,
		# iar nodul ăsta e singurul care mai merge.
		_pauza -= delta
		if _pauza <= 0.0:
			_arunca(EL)
		return
	if _stare != "rostogolire":
		return

	var toate_stau := true
	for s in _z:
		_pas_zar(s, delta)
		_aseaza_umbra(int(s["i"]))
		if s["faza"] != "stat":
			toate_stau = false
	if not toate_stau:
		_t = 0.0
		return
	# s-au oprit amândouă: o clipă de liniște, cât să apuci să citești ce a ieșit
	_t += delta
	if _t >= PAUZA_REZULTAT:
		_gata_aruncarea()

# Un cadru din viața unui zar. `s` e dicționarul lui din `_z`, iar `s["i"]` spune care zar de pe
# masă e — `_z` ține doar perechea care zboară ACUM, nu toate patru.
func _pas_zar(s: Dictionary, delta: float) -> void:
	var nod: Node3D = _zaruri[int(s["i"])]
	var loc: Vector3 = s["loc"]
	match s["faza"]:
		"asteapta":
			s["intarziere"] = float(s["intarziere"]) - delta
			if float(s["intarziere"]) <= 0.0:
				s["faza"] = "zbor"

		"zbor":
			s["t"] = float(s["t"]) + delta
			# ⚠️ înmulțim baze la fiecare cadru, iar erorile de virgulă se adună: după o mie de
			# cadre zarul ar începe să se turtească. `orthonormalized()` îl ține cub.
			nod.basis = (Basis(s["ax"], float(s["spin"]) * delta) * nod.basis).orthonormalized()

			var p := clampf(float(s["t"]) / float(s["t_oriz"]), 0.0, 1.0)
			var e := 1.0 - pow(1.0 - p, 2.0)   # frânare, dar nu atât de tare încât să se oprească devreme
			var poz := nod.position
			poz.x = lerpf(float(s["x0"]), loc.x, e)
			poz.z = lerpf(float(s["z0"]), loc.z, e)
			s["vy"] = float(s["vy"]) - GRAVITATIE * delta
			poz.y += float(s["vy"]) * delta

			# ciocnitura: se măsoară pe colțul cel mai de jos al zarului AȘA CUM E ROTIT ACUM
			var jos := _cel_mai_jos(nod.basis)
			if poz.y + jos <= PODEA_Y and float(s["vy"]) < 0.0:
				poz.y = PODEA_Y - jos
				var tarie := absf(float(s["vy"]))
				s["vy"] = tarie * RESTITUTIE
				s["lovituri"] = int(s["lovituri"]) + 1
				s["spin"] = float(s["spin"]) * SPIN_LOVIT
				# masa îi schimbă și axa: un zar lovit nu se mai învârte pe unde se învârtea
				s["ax"] = _axa_de_rostogol()
				_bufnitura(tarie)
				nod.position = poz
				if float(s["vy"]) < OPRIRE or int(s["lovituri"]) >= SARITURI_MAX:
					_incepe_asezarea(s)
					return
			nod.position = poz

		"asezare":
			s["t"] = float(s["t"]) + delta
			var p := clampf(float(s["t"]) / T_ASEZARE, 0.0, 1.0)
			nod.basis = Basis((s["q_start"] as Quaternion).slerp(s["q_tinta"], _rasturnare(p)))
			var neted := p * p * (3.0 - 2.0 * p)
			var de_la: Vector3 = s["p_start"]
			# se ridică un pic cât se răstoarnă — un zar care cade pe fața lui se salt-ă pe muchie
			# înainte să se lase. Cu cât are mai mult de răsturnat, cu atât mai vizibil.
			var salt := sin(p * PI) * HOP_ASEZARE * clampf(float(s["unghi"]) / 0.9, 0.12, 1.0)
			nod.position = Vector3(
				lerpf(de_la.x, loc.x, neted),
				lerpf(de_la.y, 0.0, neted) + salt,
				lerpf(de_la.z, loc.z, neted))
			if p >= 1.0:
				nod.basis = Basis(s["q_tinta"])
				nod.position = Vector3(loc.x, 0.0, loc.z)
				s["faza"] = "stat"
				_bufnitura(1.1)   # ticul moale cu care se lasă pe față

# Trecerea de la rostogolit la stat. Aici se hotărăște CUM se oprește zarul, și tot aici era
# greșeala cea mare de dinainte: rotația finală se alegea la începutul aruncării, cu o răsucire
# oarecare, deci zarul avea de multe ori de făcut o jumătate de tură ÎNAPOI ca s-o prindă — de
# aia părea că se smucește și se oprește brusc.
#
# Acum se alege abia acum, dintre toate așezările care arată cifra cerută, cea mai APROPIATĂ de
# cum stă zarul în clipa asta. Așa ultima mișcare e mereu scurtă: zarul se lasă pe fața pe care
# oricum era gata să cadă.
func _incepe_asezarea(s: Dictionary) -> void:
	var i: int = int(s["i"])
	var nod: Node3D = _zaruri[i]
	s["faza"] = "asezare"
	s["t"] = 0.0
	s["q_start"] = nod.basis.get_rotation_quaternion()
	s["q_tinta"] = _cea_mai_apropiata(s["q_start"], _d[i])
	s["unghi"] = _unghi_intre(s["q_start"], s["q_tinta"])
	s["p_start"] = nod.position

# Dintre toate felurile în care zarul poate sta cu fața `val` în sus (adică `_baza_pentru(val)`
# răsucit oricât pe verticală), îl alege pe cel mai apropiat de rotația de acum. 48 de încercări
# = din 7,5 în 7,5 grade: mai fin decât poate să vadă ochiul pe o mișcare de trei zecimi de secundă.
func _cea_mai_apropiata(q_acum: Quaternion, val: int) -> Quaternion:
	var baza := _baza_pentru(val)
	var cea_buna := baza.get_rotation_quaternion()
	var scor := -1.0
	for k in 48:
		var cand := (Basis(Vector3.UP, TAU * k / 48.0) * baza).get_rotation_quaternion()
		var d := absf(q_acum.dot(cand))     # |dot| = cât de aproape sunt, indiferent de semn
		if d > scor:
			scor = d
			cea_buna = cand
	return cea_buna

func _unghi_intre(a: Quaternion, b: Quaternion) -> float:
	return 2.0 * acos(clampf(absf(a.dot(b)), 0.0, 1.0))

# Cât de jos ajunge colțul cel mai de jos al zarului, rotit cu baza `b`. Culcat pe o față dă
# −jumătate de latură; căzut pe un colț dă jumătate de diagonală, adică mult mai jos — de aia
# zarul care cade pe colț se oprește mai sus și se răstoarnă de acolo.
func _cel_mai_jos(b: Basis) -> float:
	var s := MARIME_ZAR * 0.5
	var jos := INF
	for sx in [-s, s]:
		for sy in [-s, s]:
			for sz in [-s, s]:
				jos = minf(jos, (b * Vector3(sx, sy, sz)).y)
	return jos

# Răsturnarea finală: ajunge la capăt și trece un pic peste, apoi se întoarce. Fix cât face un
# zar adevărat când se lasă pe ultima față — fără asta se oprește ca o poză.
func _rasturnare(p: float) -> float:
	var c1 := 1.1
	var x := clampf(p, 0.0, 1.0) - 1.0
	return 1.0 + (c1 + 1.0) * x * x * x + c1 * x * x

# O ciocnitură de masă: sunetul ei și zguduitura de cameră. `tarie` = viteza cu care a lovit.
#
# ⚠️ Nu merge prin `Audio.play`: acolo același sunet nu se pornește mai des de `MIN_GAP_MS`, iar
# ultimele săriturile vin la o zecime de secundă una după alta — s-ar fi auzit doar prima. Și mai
# avem nevoie de ton, ca ciocniturile mici să sune mai subțire decât căderea grea de la început.
func _bufnitura(tarie: float) -> void:
	var t := clampf(tarie / 7.5, 0.0, 1.0)
	_zguduie = minf(0.085, _zguduie + 0.012 + 0.055 * t)
	if _boxe.is_empty():
		return
	var p: AudioStreamPlayer = _boxe[_boxa]
	_boxa = (_boxa + 1) % _boxe.size()
	p.pitch_scale = randf_range(1.26, 1.5) - 0.3 * t
	p.volume_db = -21.0 + 13.0 * t + _db_sfx()
	p.play()

# Reglajul „SOUND FX" din Settings, în decibeli (ca în `audio.gd`).
func _db_sfx() -> float:
	var v: float = GameSettings.sfx_volume
	return -60.0 if v <= 0.001 else linear_to_db(v)

# Camera nu stă în cui: la fiecare ciocnitură primește un ghiont care se stinge repede. E mic
# dinadins (sub o zecime de unitate) — cât să simți masa, nu cât să-ți fugă ecranul.
func _misca_camera(delta: float) -> void:
	if _cam == null:
		return
	_zguduie *= exp(-delta * 9.0)
	if _zguduie < 0.0005:
		_zguduie = 0.0
	_cam.position = CAM_POZ + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.4, 0.4)) * _zguduie
	_cam.look_at(CAM_TINTA, Vector3.UP)

# Pata de umbră de sub zar. Umbra „adevărată" (din lumina cu shadow_enabled) cade oblic și rămâne
# la fel de moale oricât de sus e zarul, deci nu-ți spune niciodată dacă zarul ATINGE masa. Pata
# asta face exact asta: se strânge și se întunecă pe măsură ce zarul coboară.
func _aseaza_umbra(i: int) -> void:
	if i >= _umbre.size():
		return
	var nod: Node3D = _zaruri[i]
	var umbra: MeshInstance3D = _umbre[i]
	var h := clampf((nod.position.y - PODEA_Y) / 1.3, 0.0, 1.0)
	umbra.position = Vector3(nod.position.x, PODEA_Y + 0.004, nod.position.z)
	var k := 0.9 + h * 1.3
	umbra.scale = Vector3(k, 1.0, k)
	var mat := umbra.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color.a = (1.0 - h) * 0.5

# ---------------------------------------------------------------------------
# CE A IEȘIT
# ---------------------------------------------------------------------------
# S-a oprit perechea care zbura. Scriem suma în cutia celui care a dat, apoi mergem mai departe:
# după el urmează alegerea ta, după tine urmează socoteala.
func _gata_aruncarea() -> void:
	var i := _cine
	var suma: int = int(_d[i]) + int(_d[i + 1])
	var cutie: Control = _cutie_el if _cine == EL else _cutie_tu
	var lbl: Label = _lbl_el if _cine == EL else _lbl_tu
	# ⚠️ pur numeric, nu se traduce (vezi lista IGNORATE din `tool_check_i18n.gd`)
	lbl.text = "%d + %d = %d" % [_d[i], _d[i + 1], suma]
	cutie.modulate = Color(1, 1, 1, 1)
	_pumn(cutie, 1.12, 0.3)     # suma sare o clipă în ochi: ea e vestea
	if _cine == EL:
		_suma_el = suma
		_ofera_pariul()
	else:
		_suma_tu = suma
		_judeca()

# I-ai văzut suma. De aici încolo hotărăști tu: dai sau pleci.
func _ofera_pariul() -> void:
	_stare = "alegi"
	_spune(tr("Beat him: +%d%% to a random stat") % _procent(CASTIG), ACCENT_CLAR)
	# aceeași formulare ca la Alba-Neagra, ca să se citească drept ce e: prețul pierderii
	_lbl_risc.text = tr("Lose: -%d%% to a random stat, +%d%% Difficulty") \
		% [_procent(PIERDERE), int(round(PEDEAPSA * 100.0))]
	_btn.text = "ROLL THE DICE"
	_btn.visible = true
	_btn_pleaca.visible = true

# Cine a dat mai mult. Egalitatea nu e nici câștig, nici pierdere: se dă mâna din nou, ca la
# barbutul adevărat (cerut de Răzvan pe 2026-08-14).
func _judeca() -> void:
	_stare = "rezultat"
	_btn.visible = true
	_btn_pleaca.visible = false
	_lbl_risc.text = ""
	if _suma_tu == _suma_el:
		_egalitate = true
		_spune("A tie. Roll again", CENUSA)
		_btn.text = "ROLL AGAIN"
		Audio.play("button", -3.0, 0.0)
		return

	_egalitate = false
	_btn.text = "CONTINUE"
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		_inchide()
		return
	var stat: String = STATS[randi() % STATS.size()]
	if _suma_tu > _suma_el:
		_scaleaza_stat(p, stat, CASTIG)
		# tr() explicit: textul e ASAMBLAT, deci nici el, nici numele statusului din el nu mai trec
		# singure prin traducere (vezi i18n.gd).
		_spune(tr("You win — %s up %d%%") % [tr(stat), _procent(CASTIG)], ACCENT_CLAR)
		Audio.play("chest_anim", -3.0, 0.0)
	else:
		_scaleaza_stat(p, stat, PIERDERE)
		# +10% dificultate, exact mecanismul de la Alba-Neagra și de la statuia Ender
		Difficulty.add_trade_penalty(PEDEAPSA)
		_spune(tr("You lose — %s down %d%%") % [tr(stat), _procent(PIERDERE)], ROSU)
		_lbl_risc.text = tr("The game got %d%% harder") % int(round(PEDEAPSA * 100.0))
		Audio.play("hurt", -2.0, 0.0)

# Cât la sută înseamnă un factor de miză: 1.25 → 25, 0.75 → 25. Scris o dată, ca cifra de pe ecran
# să nu poată rămâne în urma constantei.
func _procent(factor: float) -> int:
	return int(round(absf(factor - 1.0) * 100.0))

# Un „pumn" de mărime: sare la `cat` și se lasă înapoi la 1. E cel mai ieftin fel de a spune „uite
# aici" fără să muți nimic din loc.
#
# ⚠️ `pivot_offset` se pune ACUM, nu la construire: până nu se așază containerele, `size` e zero,
# iar creșterea ar porni din colțul de sus-stânga și ar arăta ca o alunecare.
func _pumn(ctrl: Control, cat: float, durata: float) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2(cat, cat)
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(ctrl, "scale", Vector2.ONE, durata)

# ---------------------------------------------------------------------------
# EFECTELE
# ---------------------------------------------------------------------------
# Tot ce poate ieși din pariu trece pe aici: `CASTIG` dacă l-ai bătut, `PIERDERE` dacă nu.
#
# ⚠️ Nu se scrie nimic în `player.run_items`: pariul NU e un item, deci n-are ce căuta nici la masa
# de schimb a statuii Ender, nici în contractele cazinoului — ele arată lista aia.
#
# Înmulțește un status cu `f`. Numele sunt cele din panoul de statusuri, ca să se potrivească cu
# ce scrie pe ecran după aceea.
#
# ⚠️ Attack Speed merge INVERS: statul din player e pauza dintre lovituri, deci „de două ori mai
# multe lovituri pe secundă" înseamnă jumătate de pauză. De aia se împarte, nu se înmulțește.
func _scaleaza_stat(p, stat: String, f: float) -> void:
	match stat:
		"Damage":
			p.bullet_damage = maxi(1, int(round(p.bullet_damage * f)))
		"Attack Speed":
			p.upgrade_fire_rate(1.0 / f)
		"Move Speed":
			# aceeași plasă ca la restul jocului: sub 60 nu mai poți fugi de nimic
			p.speed = maxf(60.0, p.speed * f)
		"Max HP":
			var nou := maxi(10, int(round(p.max_hp * f)))
			var delta: int = nou - p.max_hp
			if delta > 0:
				p.upgrade_max_hp(delta)   # te și vindecă cu cât a crescut, ca la Beer
			else:
				p.max_hp = nou
				p.hp = mini(p.hp, p.max_hp)
		"Weapon Size":
			p.weapon_size_mult *= f

# ---------------------------------------------------------------------------
# INTERFAȚA
# ---------------------------------------------------------------------------
func _build() -> void:
	_construieste_masa()

	var panel := _cadru(CH_PANOU, 2)
	panel.custom_minimum_size = Vector2(PANOU_W, PANOU_H)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANOU_W / 2.0
	panel.offset_right = PANOU_W / 2.0
	panel.offset_top = -PANOU_H / 2.0
	panel.offset_bottom = PANOU_H / 2.0
	add_child(panel)

	# ⚠️ Marginile trebuie să treacă de grosimea ramei desenate (15 × zoom 2 = 30), altfel
	# conținutul se urcă pe ornament.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SHADY DEAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", OS_ALB)
	title.add_theme_color_override("font_outline_color", ACCENT_STINS)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	box.add_child(_linie(320.0, 12))

	# Rândul de sub linie are TREI vieți: „el dă primul", apoi miza, apoi ce ți-a ieșit. Un rând
	# pentru fiecare, gol cât nu-i vremea lui, ar fi lăsat găuri în panou.
	_lbl_stare = Label.new()
	_lbl_stare.text = "He rolls first"
	_lbl_stare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_stare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_stare.add_theme_font_size_override("font_size", 18)
	_lbl_stare.add_theme_color_override("font_color", CENUSA)
	_add_outline(_lbl_stare)
	box.add_child(_lbl_stare)

	box.add_child(_spatiu(4))
	box.add_child(_fereastra_masa())
	box.add_child(_spatiu(6))
	box.add_child(_tabela())

	# Rândul de risc: ce te costă dacă pierzi. Stă sub tabelă (nu lângă miză) fiindcă e vorba
	# despre ACEEAȘI aruncare, doar despre partea urâtă a ei — la fel ca la Alba-Neagra.
	_lbl_risc = Label.new()
	_lbl_risc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_risc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_risc.add_theme_font_size_override("font_size", 15)
	_lbl_risc.add_theme_color_override("font_color", CENUSA)
	_add_outline(_lbl_risc)
	box.add_child(_lbl_risc)

	box.add_child(_spatiu(6))

	# butoanele, centrate: singure într-un VBox s-ar fi întins pe toată lățimea panoului
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	rand.add_theme_constant_override("separation", 18)
	box.add_child(rand)
	_btn = _buton("ROLL THE DICE", _pe_buton)
	rand.add_child(_btn)
	_btn_pleaca = _buton("WALK AWAY", _pe_pleaca)
	rand.add_child(_btn_pleaca)
	_btn.visible = false
	_btn_pleaca.visible = false

# Fereastra prin care se vede masa de zaruri: postavul, imaginea din viewport și rama peste ele.
func _fereastra_masa() -> Control:
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	rand.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(MASA_W, MASA_H)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rand.add_child(wrap)

	# postavul de sub zaruri (viewport-ul e transparent, deci fundalul se vede prin el)
	var postav := ColorRect.new()
	postav.color = Color8(24, 17, 22)
	postav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	postav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(postav)

	var poza := TextureRect.new()
	poza.texture = _vp.get_texture()
	poza.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	poza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poza.stretch_mode = TextureRect.STRETCH_SCALE
	poza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(poza)

	# ⚠️ `centru = false` e OBLIGATORIU: celulele din planșă NU au mijlocul transparent, au un
	# bleumarin închis — o ramă cu mijloc desenat ar acoperi complet masa de zaruri.
	var rama := _cadru(CH_MASA, 1, false)
	rama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(rama)
	return rand

# TABELA: două cutii lipite, HIM în stânga și YOU în dreapta — în aceeași ordine în care stau
# zarurile pe masă, ca să nu trebuiască să te gândești a cui e suma.
#
# Cutia celui care n-a dat încă stă STINSĂ, nu goală: locul ei e ținut oricum (altfel panoul și-ar
# schimba înălțimea la jumătatea aruncării), iar stinsă se citește ca „aici o să cadă suma".
func _tabela() -> Control:
	var rand := HBoxContainer.new()
	rand.add_theme_constant_override("separation", 14)
	rand.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_cutie_el = _cutie("HIM")
	_lbl_el = _cutie_el.get_meta("suma") as Label
	rand.add_child(_cutie_el)

	_cutie_tu = _cutie("YOU")
	_lbl_tu = _cutie_tu.get_meta("suma") as Label
	rand.add_child(_cutie_tu)
	return rand

# O cutie de scor: rama, capul de tabel (HIM / YOU) și suma de dedesubt. Label-ul sumei se dă
# înapoi prin `set_meta`, ca să nu întoarcem două lucruri dintr-o funcție.
func _cutie(cap: String) -> Control:
	var cutie := Control.new()
	cutie.custom_minimum_size = Vector2(0, SCOR_H)
	cutie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cutie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutie.modulate = Color(1, 1, 1, SCOR_ASTEPTARE)

	var rama := _cadru(CH_SCOR, 1, false)
	rama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutie.add_child(rama)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutie.add_child(vb)

	var lbl_cap := Label.new()
	lbl_cap.text = cap
	lbl_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cap.add_theme_font_size_override("font_size", 15)
	lbl_cap.add_theme_color_override("font_color", CENUSA)
	lbl_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(lbl_cap)
	vb.add_child(lbl_cap)

	var lbl_suma := Label.new()
	lbl_suma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_suma.add_theme_font_size_override("font_size", 30)
	lbl_suma.add_theme_color_override("font_color", ACCENT_CLAR)
	lbl_suma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(lbl_suma)
	vb.add_child(lbl_suma)

	cutie.set_meta("suma", lbl_suma)
	return cutie

# ---------------------------------------------------------------------------
# MASA DE ZARURI: lumea 3D
# ---------------------------------------------------------------------------
func _construieste_masa() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(MASA_W) * SUPRA, int(MASA_H) * SUPRA)
	_vp.transparent_bg = true
	_vp.own_world_3d = true              # lumea zarurilor e a lor, nu atinge jocul
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)

	_cam = Camera3D.new()
	_cam.position = CAM_POZ
	_cam.keep_aspect = Camera3D.KEEP_WIDTH   # `fov` e pe orizontală (vezi CAM_FOV)
	_cam.fov = CAM_FOV
	_cam.environment = _mediul()
	_vp.add_child(_cam)
	_cam.look_at(CAM_TINTA, Vector3.UP)

	# Lumina e pusă „ca la studio", pe trei surse cu roluri diferite. Cu una singură zarul iese o
	# pată plată — se vede în filmul aruncării de dinainte.
	#
	# 1. CHEIA: din stânga-sus-față, caldă, ea face umbra pe postav.
	var lum := DirectionalLight3D.new()
	lum.light_energy = 1.9
	lum.light_color = Color8(255, 246, 232)
	lum.shadow_enabled = true
	# ⚠️ Umbra NEATINSĂ iese un triunghi negru cu muchii tăiate cu cuțitul, care arată a greșeală,
	# nu a umbră. Înmuiată și lăsată să se vadă postavul prin ea, zarul pare așezat pe masă.
	lum.shadow_blur = 1.6
	lum.shadow_opacity = 0.66
	lum.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	# ⚠️ ASTA e reglajul fără de care zarurile arată bolnave. Din fabrică, umbra unei lumini
	# direcționale se întinde pe 100 de unități, tăiate în patru felii — iar noi avem o masă de
	# două unități. Pe atâta întindere un pixel din harta de umbră e mai mare decât o față de zar,
	# așa că fața se umbrește singură: ies pete cenușii cu muchie dreaptă peste fețele luminate (se
	# vedea limpede pe fața de sus). Strânsă pe 16 unități și pe o singură felie, aceiași pixeli cad
	# toți pe masă, iar umbra iese curată.
	lum.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	lum.directional_shadow_max_distance = 16.0
	lum.shadow_bias = 0.02
	lum.shadow_normal_bias = 0.8
	_vp.add_child(lum)

	# 2. UMPLUTURA: slabă și caldă, din dreapta, ca fețele din umbră să nu iasă plate.
	#
	# ⚠️ NU pune aici `ACCENT` (arama plină) și nici energie mare: prima încercare a scos zaruri
	# CĂRĂMIZII, nu de os. Zarul trebuie să rămână fildeș, iar arama doar să-l atingă.
	var lum2 := DirectionalLight3D.new()
	lum2.light_energy = 0.22
	lum2.light_color = Color8(214, 168, 138)
	lum2.rotation_degrees = Vector3(-18.0, 128.0, 0.0)
	_vp.add_child(lum2)

	# 3. CONTURUL: din spate, rece, razant. Nu luminează zarul, doar îi aprinde muchiile de sus —
	# fără ea zarul de os se pierde în postavul întunecat exact acolo unde ar trebui să iasă în
	# față. E lumina care face diferența dintre „un cub" și „un obiect".
	var lum3 := DirectionalLight3D.new()
	lum3.light_energy = 0.55
	lum3.light_color = Color8(216, 218, 230)
	lum3.rotation_degrees = Vector3(-12.0, 168.0, 0.0)
	_vp.add_child(lum3)

	# Becul de deasupra mesei: face o baltă de lumină în mijloc și lasă marginile în întuneric.
	# Tot el ascunde locul unde se termină postavul, și dă senzația de masă pe care se joacă
	# noaptea, la lumina unui bec chior. Fără umbre — ar costa degeaba, cheia le face deja.
	var bec := SpotLight3D.new()
	bec.position = Vector3(0.0, 4.2, 1.1)
	bec.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	bec.light_color = Color8(255, 226, 190)
	bec.light_energy = 4.0
	bec.spot_range = 14.0
	# ⚠️ Unghiul a crescut de la 40° la 58° odată cu a doua pereche de zaruri: becul stă la ~4.65
	# deasupra postavului, iar la 40° balta lui de lumină avea raza `tan(20°) × 4.65 ≈ 1.7` — adică
	# zarurile de la marginile mesei (±2.02) cădeau COMPLET în afara ei și se vedeau mult mai
	# întunecate decât cele din mijloc, de parcă erau de altă culoare.
	bec.spot_angle = 58.0
	bec.spot_angle_attenuation = 1.6
	bec.spot_attenuation = 1.4
	_vp.add_child(bec)

	var podea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	# ⚠️ Mare de tot dinadins: dacă marginea din spate a postavului intră în cadru se vede o dungă
	# unde se termină masa și începe transparența.
	pm.size = Vector2(40.0, 30.0)
	podea.mesh = pm
	podea.position.y = PODEA_Y
	podea.material_override = _material_postav()
	_vp.add_child(podea)

	var mesh := _mesh_zar()
	var mat := _material_zar()
	var umbra_tex := _textura_umbra()
	for i in LOCURI.size():
		# pata de umbră stă SUB zar și e desenată prima (vezi `_aseaza_umbra`)
		var umbra := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(MARIME_ZAR * 1.5, MARIME_ZAR * 1.5)
		qm.orientation = PlaneMesh.FACE_Y
		umbra.mesh = qm
		var mat_u := StandardMaterial3D.new()
		mat_u.albedo_texture = umbra_tex
		mat_u.albedo_color = Color(0, 0, 0, 0.0)
		mat_u.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_u.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_u.cull_mode = BaseMaterial3D.CULL_DISABLED
		umbra.material_override = mat_u
		umbra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vp.add_child(umbra)
		_umbre.append(umbra)

		var z := Node3D.new()
		var corp := _corpul_zarului(mesh, mat)
		z.add_child(corp)
		z.position = LOCURI[i]
		_vp.add_child(z)
		_zaruri.append(z)
		_aseaza_umbra(i)

	# trei boxe pentru ciocnituri: ultimele sărituri vin la o zecime de secundă una după alta, iar
	# o singură boxă și-ar tăia singură sunetul din urmă (vezi `_bufnitura`)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.stream = load("res://audio/Key Pickup.wav")
		add_child(p)
		_boxe.append(p)

func _mediul() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	# ⚠️ Fără lumină ambientală fețele care nu prind lumină ies NEGRE, iar zarul pare o gaură.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(150, 146, 168)
	env.ambient_light_energy = 0.16
	# ACES în loc de nimic: cu becul de deasupra, fața zarului luminată direct ieșea albă tăiată,
	# ca o hârtie. ACES îndoaie vârfurile, deci osul rămâne os și acolo unde bate lumina tare.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 2.2
	return env

# Postavul: verde-vânăt foarte închis, aspru, cu pete mărunte. Culoarea plată de dinainte arăta a
# fundal de program de desenat; petele nu se văd ca pete, dar se simt când trece umbra peste ele.
func _material_postav() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _textura_postav()
	mat.albedo_color = Color8(26, 18, 23)
	mat.roughness = 0.98
	mat.metallic = 0.0
	# ⚠️ Mărunt de tot: la prima încercare (14×10 pe o masă de 40 de unități) o pată ieșea de trei
	# ori cât zarul, iar planșa se vedea repetându-se, ca o tapiserie ieftină.
	mat.uv1_scale = Vector3(52.0, 39.0, 1.0)
	return mat

func _textura_postav() -> ImageTexture:
	var n := 96
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	var zg := FastNoiseLite.new()
	zg.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	zg.frequency = 0.09
	zg.seed = 7
	for y in n:
		for x in n:
			# ±12% în jurul albului: materialul îl înmulțește cu `albedo_color`, deci asta e doar
			# „cât de tocit e postavul aici", nu o culoare de sine stătătoare
			var v := 1.0 + zg.get_noise_2d(x, y) * 0.12
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# Pata de umbră de contact: un cerc negru cu marginea topită (vezi `_aseaza_umbra`).
func _textura_umbra() -> ImageTexture:
	var n := 96
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			# marginea nu se termină brusc: cade lin, cu coadă lungă, ca o umbră moale adevărată
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a * a * (3.0 - 2.0 * a)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# Corpul unui zar: modelul lui Răzvan dacă există pe disc, altfel cubul desenat în cod.
func _corpul_zarului(mesh: ArrayMesh, mat: StandardMaterial3D) -> Node3D:
	if ResourceLoader.exists(MODEL_ZAR):
		var pachet := load(MODEL_ZAR) as PackedScene
		if pachet != null:
			var model := pachet.instantiate() as Node3D
			if model != null:
				_potriveste_marimea(model)
				return model
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

# Modelul exportat poate veni la ORICE mărime (3ds Max lucrează des în centimetri, deci un zar de
# 2 cm ajunge un bloc de 2 unități, cât jumătate de masă). Îl măsurăm și îl scalăm la MARIME_ZAR,
# ca încadrarea camerei să rămână bună indiferent cum a fost exportat.
func _potriveste_marimea(model: Node3D) -> void:
	var aabb := _cuprinderea(model, Transform3D.IDENTITY)
	var lat := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if lat <= 0.0001:
		return
	var k := MARIME_ZAR / lat
	model.scale = Vector3(k, k, k)
	model.position = -aabb.get_center() * k     # centrat pe originea nodului, ca să se rotească pe loc

func _cuprinderea(nod: Node, tr: Transform3D) -> AABB:
	var rez := AABB()
	var are := false
	if nod is Node3D:
		tr = tr * (nod as Node3D).transform
	if nod is MeshInstance3D and (nod as MeshInstance3D).mesh != null:
		rez = tr * (nod as MeshInstance3D).mesh.get_aabb()
		are = true
	for copil in nod.get_children():
		var a := _cuprinderea(copil, tr)
		if a.size == Vector3.ZERO:
			continue
		rez = a if not are else rez.merge(a)
		are = true
	return rez

# Zarul desenat în cod: șase fețe, fiecare cu bucata ei din planșa cu buline, și cu MUCHIILE
# TOCITE. Nu mai e un cub: e „cutia rotunjită", adică forma pe care o obții plimbând o bilă de rază
# `r` pe dinafara unui cub mai mic. Zarurile adevărate sunt tocmai așa, iar tocitura e ce prinde
# lumina — cubul tăios de dinainte ieșea o pată plată, oricâtă lumină puneai pe el.
#
# ⚠️ Fețele se construiesc de mână (nu cu `BoxMesh`) fiindcă `BoxMesh` își împarte UV-urile cum
# vrea el, iar noi trebuie să știm EXACT ce cifră stă pe ce direcție — altfel n-am putea să
# oprim zarul pe fața care a ieșit.
#
# Fiecare față se taie în DIVIZIUNI×DIVIZIUNI pătrățele, iar fiecare colț de pătrățel se împinge
# pe suprafața rotunjită (`_pe_rotunjit`). Cele șase petice se închid EXACT unul în altul: pe
# mijlocul unei muchii, și fața de sus, și cea din lateral ajung în același punct, la 45°.
func _mesh_zar() -> ArrayMesh:
	var s := MARIME_ZAR * 0.5
	var r := s * ROTUNJIME
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in FETE:
		var n: Vector3 = f["n"]
		var u: Vector3 = f["u"]
		var v := n.cross(u)
		var val: int = f["val"]
		var cx := (val - 1) % 3
		var cy := (val - 1) / 3
		# un pic în interiorul celulei: fără marginea asta se vede o dungă din celula vecină
		var m := 0.004
		for a in DIVIZIUNI:
			for b in DIVIZIUNI:
				# colțurile pătrățelului, în coordonate −1…1 pe fața plată
				var a0 := -1.0 + 2.0 * a / float(DIVIZIUNI)
				var a1 := -1.0 + 2.0 * (a + 1) / float(DIVIZIUNI)
				var b0 := -1.0 + 2.0 * b / float(DIVIZIUNI)
				var b1 := -1.0 + 2.0 * (b + 1) / float(DIVIZIUNI)
				var ab := [Vector2(a0, b0), Vector2(a1, b0), Vector2(a1, b1), Vector2(a0, b1)]
				# ⚠️ Ordinea asta NU e o preferință: de ea atârnă ce e „față" și ce e „spate" pentru
				# placa video. Cu ea pe dos, zarul se randează invers pe dinafară și — mai rău —
				# intră în harta de umbră cu ambele fețe, deci fața lui de sus SE UMBREȘTE SINGURĂ
				# și iese cenușie. Exact așa arătau zarurile până acum: cenușii, cu lumina „lipsă"
				# fix de unde bătea cel mai tare.
				for idx in [0, 2, 1, 0, 3, 2]:
					var t: Vector2 = ab[idx]
					var pn := _pe_rotunjit(n * s + u * (t.x * s) + v * (t.y * s), s, r)
					# UV din coordonata PLATĂ, nu din cea rotunjită: bulinele rămân unde le-am
					# desenat, iar tocitura primește marginea curată a feței
					var ux: float = (cx + clampf((t.x + 1.0) * 0.5, m, 1.0 - m)) / 3.0
					var uy: float = (cy + clampf((1.0 - t.y) * 0.5, m, 1.0 - m)) / 2.0
					st.set_normal(pn[1])
					st.set_uv(Vector2(ux, uy))
					st.add_vertex(pn[0])
	return st.commit()

# Împinge punctul `p` (de pe cubul tăios) pe cutia rotunjită și spune și încotro privește acolo.
# Rețeta e cea știută: strângi punctul în cubul mai mic (latura − rotunjire), apoi îl scoți înapoi
# la distanța `r` de el. În mijlocul feței iese fața plată; pe muchie, sfertul de cilindru; în
# colț, optimea de bilă.
func _pe_rotunjit(p: Vector3, s: float, r: float) -> Array:
	var i := s - r
	var q := Vector3(clampf(p.x, -i, i), clampf(p.y, -i, i), clampf(p.z, -i, i))
	var d := p - q
	if d.length() < 0.00001:
		return [p, p.normalized()]
	var nrm := d.normalized()
	return [q + nrm * r, nrm]

func _material_zar() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _plansa_buline()
	# osul e lucios, dar nu lăcuit: reflexia trebuie să fie o pată moale pe tocitură, nu un punct
	mat.roughness = 0.33
	mat.metallic = 0.0
	# ⚠️ `CULL_DISABLED`: nu ne batem capul cu ordinea vârfurilor din `_mesh_zar`. Zarul e închis
	# și luminat din afară, iar normalele sunt puse de mână, deci arată la fel de bine.
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat

# Planșa cu cele șase fețe, 3×2 celule, desenată în cod. Bulinele au marginea netezită (se
# calculează cât din pixel intră în cerc), altfel la mărimea de pe ecran ies în trepte.
#
# Bulinele nu sunt pete negre lipite pe os, sunt SCOBITE: peretele dinspre lumină (stânga-sus) e
# cel mai întunecat, fundul scobiturii se deschide spre dreapta-jos, iar chiar pe buza de jos-
# dreapta osul prinde o dungă de lumină. Sunt trei fire de păr de nuanță, dar ele fac diferența
# dintre „cub cu puncte" și „zar".
#
# Chenarul arămiu de pe muchia feței a dispărut o dată cu cubul tăios: acum muchia e tocită și se
# desenează singură, din lumină, iar dunga de vopsea peste ea arăta a autocolant.
func _plansa_buline() -> ImageTexture:
	var c := CELULA_ZAR
	var img := Image.create(c * 3, c * 2, true, Image.FORMAT_RGBA8)
	var raza := c * 0.1
	var spre_lumina := Vector2(-0.707, -0.707)   # de unde bate cheia, în coordonatele feței
	for val in range(1, 7):
		var cx := (val - 1) % 3
		var cy := (val - 1) / 3
		for y in c:
			for x in c:
				# osul nu e o culoare plată: are un vânt de nuanță, ca fildeșul adevărat
				var n := 1.0 + 0.022 * sin(x * 0.21 + val * 1.7) * cos(y * 0.17 - val)
				var culoare := Color(FILDES.r * n, FILDES.g * n, FILDES.b * n)
				for b in BULINE[val]:
					var centru := Vector2((b.x + 1) * c / 4.0, (b.y + 1) * c / 4.0)
					var dv := Vector2(x + 0.5, y + 0.5) - centru
					var d := dv.length()
					var a := clampf(raza - d + 0.5, 0.0, 1.0)
					if a > 0.0:
						# În scobitură: miezul rămâne întunecat, iar peretele dinspre partea opusă
						# luminii se deschide. ⚠️ Deschiderea crește cu PĂTRATUL distanței de centru,
						# nu liniar: la prima încercare pornea de la jumătate încă din mijlocul
						# bulinei, iar bulinele ieșeau cenușii, ca șterse cu guma.
						var spre := dv.normalized() if d > 0.01 else Vector2.ZERO
						var f := clampf(-spre.dot(spre_lumina), 0.0, 1.0) * pow(d / raza, 2.0) * 0.9
						culoare = culoare.lerp(NEGRU_BULINA.lerp(BULINA_FUND, f), a)
					else:
						# buza de jos-dreapta a scobiturii, cea care prinde lumina
						var buza := clampf(1.0 - (d - raza) / 2.0, 0.0, 1.0)
						if buza > 0.0 and d > 0.01:
							buza *= clampf(dv.normalized().dot(-spre_lumina), 0.0, 1.0)
							culoare = culoare.lerp(Color(1, 1, 1), buza * 0.45)
				img.set_pixel(cx * c + x, cy * c + y, culoare)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# Rotația care aduce fața `val` în sus. Perechea de la `FETE`: 1 sus, 6 jos, 3 pe +X, 4 pe −X,
# 5 pe +Z, 2 pe −Z.
func _baza_pentru(val: int) -> Basis:
	match val:
		6: return Basis(Vector3.RIGHT, PI)
		3: return Basis(Vector3.BACK, PI * 0.5)
		4: return Basis(Vector3.BACK, -PI * 0.5)
		5: return Basis(Vector3.RIGHT, -PI * 0.5)
		2: return Basis(Vector3.RIGHT, PI * 0.5)
	return Basis()   # 1 e deja sus

# ---------------------------------------------------------------------------
# CĂRĂMIZILE DE ASPECT (aceleași ca la `alba_menu.gd` / `casino.gd`)
# ---------------------------------------------------------------------------
# O ramă din planșă, ca NinePatch. `zoom` = de câte ori se mărește celula de 64px înainte de
# întindere (2 = ramă groasă, de ecran).
#
# ⚠️ `centru = false` pentru orice ramă pusă PESTE ceva — celulele au mijlocul plin, nu transparent.
func _cadru(celula: Vector2i, zoom: int, centru: bool = true) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _chenar(celula, zoom)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.draw_center = centru
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := 15 * zoom
	np.patch_margin_left = m
	np.patch_margin_right = m
	np.patch_margin_top = m
	np.patch_margin_bottom = m
	return np

# ⚠️ Celula se MĂREȘTE de `zoom` ori (nearest) înainte să ajungă textură: nine-patch-ul întinde
# doar mijlocul laturilor, nu și grosimea lor, iar o celulă de 64px pusă pe un panou de 780 lăsa
# linii de 1px — un chenar desenat cu pixul.
func _chenar(celula: Vector2i, zoom: int) -> ImageTexture:
	if _sheet_img == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet_img = tex.get_image()
	var bucata := _sheet_img.get_region(Rect2i(celula.x * CELULA, celula.y * CELULA, CELULA, CELULA))
	bucata.resize(CELULA * zoom, CELULA * zoom, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bucata)

func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", OS_ALB)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", _sb_buton(CH_BUTON, Color(1, 1, 1)))
	b.add_theme_stylebox_override("hover", _sb_buton(CH_BUTON, ACCENT_CLAR * Color(1.25, 1.25, 1.25, 1)))
	b.add_theme_stylebox_override("pressed", _sb_buton(CH_BUTON, ACCENT))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _sb_buton(CH_BUTON, Color(0.5, 0.5, 0.5)))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

func _sb_buton(celula: Vector2i, tenta: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _chenar(celula, 1)
	sb.modulate_color = tenta
	sb.set_texture_margin_all(15)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb

func _linie(latime: float, inaltime: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, inaltime)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hb)
	for a in [0.15, 0.55, 0.15]:
		var r := ColorRect.new()
		r.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, a)
		r.custom_minimum_size = Vector2(latime / 3.0, 2)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(r)
	return wrap

func _spatiu(inaltime: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, inaltime)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _add_outline(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
