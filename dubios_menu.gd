extends CanvasLayer

# MENIUL DUBIOSULUI — marfa pe care ți-o scoate omul în palton (`dubiosu.gd`) când apeși E pe el.
#
# De pe 2026-08-13 NU mai alegi: DAI CU ZARURILE. Două zaruri 3D se rostogolesc pe masă, se
# opresc, iar perechea care iese îți dă unul din cele patru iteme de aici — iteme care NU există
# în tragerea de la level up, în cufere, în cazinou sau la statuia Ender. (Înainte îți scotea 3
# din 4 cartonașe și alegeai unul, în chenarele verzi din folderul lui.)
#
# Cum se leagă: E pe om → `dubiosu.gd::invoca()` → `open()` de aici. Jocul se OPREȘTE
# (`get_tree().paused`), iar meniul merge mai departe fiindcă nodul e `PROCESS_MODE_ALWAYS`.
# Un om îți scoate marfa o SINGURĂ dată (vezi `dubiosu.gd::consuma`).
#
# ⚠️ Toate patru sunt de ACEEAȘI calitate, iar calitatea aia NU se scrie nicăieri pe ecran (cerut
# de Răzvan) — de aia cartonașul n-are rând de raritate, spre deosebire de cele de la level up.
# Tot de aia nu există nici câmp „rar" în lista de mai jos: „aceeași calitate" înseamnă, la
# Arcane Magic, „tot din lista asta", și n-are nevoie de un nume ca s-o știe.
#
# ⚠️ Itemele astea sunt INVIZIBILE pentru cazinou (`casino.gd`) și pentru masa de schimb a
# statuii Ender (`trade.gd`): amândouă caută id-ul cu `levelup.item_dupa_id`, care întoarce null
# pentru ele, și sar peste. Așa și trebuie — nu se pariază și nu se schimbă pe altceva.

const ICON_DIR := "res://harta/Upgrade Dubios/"

# "desc" = ce scrie sub nume. Efectele reale sunt în `_apply`.
var UPGRADES := [
	{"id": "cursed_tome", "nume": "Cursed Tome", "icon": "Upgrade Dubios 1.png",
		"desc": "Increase Spawnrate by 25%"},
	{"id": "iron_helmet", "nume": "Iron Helmet", "icon": "Upgrade Dubios 2.png",
		"desc": "Take 100% Less Damage, Deal 25% Less Damage"},
	{"id": "blame_circle", "nume": "Blame Circle", "icon": "Upgrade Dubios 3.png",
		"desc": "Double one random stat, -25% of a random stat"},
	{"id": "arcane_magic", "nume": "Arcane Magic", "icon": "Upgrade Dubios 4.png",
		"desc": "Reset all your items with ones of the same quality"},
]

# Statusurile pe care le poate atinge Blame Circle. Numele sunt EXACT cele din panoul de statusuri
# (`player.stat_lines`), deci se traduc singure și îți spun în aceiași termeni ce ai pățit.
#
# ⚠️ Sunt doar statusuri care NU pot fi zero la începutul rundei. Crit și Luck pornesc de la 0, iar
# „dublu" din 0 tot 0 face — ai fi luat un item care nu face nimic și ai fi crezut că e stricat.
const BLAME_STATS := ["Damage", "Attack Speed", "Move Speed", "Max HP", "Weapon Size"]
const BLAME_UP := 2.0     # „double one random stat"
const BLAME_DOWN := 0.75  # „-25% of a random stat"

# ---------------------------------------------------------------------------
# CINE IESE LA ZARURI
# ---------------------------------------------------------------------------
# Zarurile se dau CINSTIT: fiecare are 1…6 cu șanse egale, deci cele 36 de perechi sunt egal
# probabile. Itemul îl dă PERECHEA, nu suma — și asta e important:
#
# ⚠️ După SUMĂ nu se poate împărți drept în patru. Sumele 2…12 nu ies egal de des (1, 2, 3, 4, 5,
# 6, 5, 4, 3, 2, 1 din 36), iar 36 ÷ 4 = 9 — nu există nicio tăietură în sume care să dea patru
# felii de câte 9. Orice hartă „suma 2-4 → itemul X" face un item de trei ori mai rar decât altul,
# ceea ce bate fix regula casei de mai sus (toate patru sunt de aceeași calitate).
#
# Perechea, în schimb, se împarte perfect: numerotăm cele 36 de perechi 0…35 și luăm restul la 4,
# deci fiecare item primește exact 9 perechi = 25% fix. Zarurile rămân zaruri adevărate (ce vezi
# pe masă chiar a fost tras), iar pe ecran îți scriem și suma, ca la barbut.
func _item_din_zaruri(d1: int, d2: int) -> Dictionary:
	var perechea := (d1 - 1) * 6 + (d2 - 1)     # 0…35, egal probabile
	return UPGRADES[perechea % UPGRADES.size()]

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
const CH_CARD := Vector2i(1, 1)      # cartonașul itemului (dublă, simplă)
const CH_ITEM := Vector2i(0, 1)      # chenarul din jurul iconiței (ține locul rarității)
const CH_BUTON := Vector2i(1, 3)     # butonul (subțire, cu bumbi în colțuri)

const ACCENT := Color8(198, 118, 80)
const ACCENT_CLAR := Color8(222, 152, 116)
const ACCENT_STINS := Color8(116, 62, 42)
const OS_ALB := Color8(232, 224, 214)
const CENUSA := Color8(150, 142, 138)
const FUNDAL := Color8(17, 14, 20)

const PANOU_W := 780.0
const PANOU_H := 560.0
const MASA_W := 560.0      # fereastra prin care se vede masa de zaruri
const MASA_H := 190.0
const CARD_H := 100.0      # cartonașul itemului câștigat
const CELL := 76.0         # latura chenarului cu iconița

# ⚠️ Cartonașul NU e ascuns de tot cât aștepți, ci lăsat stins: locul lui e ținut oricum (altfel
# panoul și-ar schimba înălțimea la jumătatea aruncării), iar gol de tot lăsa o gaură mare între
# masă și buton, de parcă meniul era neterminat. Stins, se citește ca „aici o să cadă itemul".
const CARD_ASTEPTARE := 0.22

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

# Unde se opresc. NU sunt în oglindă dinadins: două zaruri așezate perfect simetric arată a poză
# de catalog, nu a masă pe care tocmai s-a aruncat. Unul stă mai în față, altul mai în spate, și
# peste locurile astea se mai pune o zvâcnitură la fiecare aruncare (`_arunca`).
#
# ⚠️ Depărtarea pe Z (0.42 față de −0.40, adică aproape o lățime de zar) nu e doar de frumusețe:
# al doilea zar trebuie să treacă pe deasupra locului primului ca s-ajungă în dreapta, iar cu
# culoare apropiate cele două se suprapuneau pe ecran fix la mijlocul aruncării, de parcă unul
# intra prin celălalt.
const LOCURI := [Vector3(-1.06, 0.0, 0.50), Vector3(1.02, 0.0, -0.48)]

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
const T_ORIZONTAL := [0.68, 0.82]   # cât ține drumul lateral al fiecăruia, din mână până pe loc
const T_ASEZARE := 0.34        # răsturnarea finală pe fața care a ieșit

# Fiecare zar pleacă altfel: altă înălțime, altă întârziere, altă rotație. Diferențele sunt mici,
# dar ele fac ca zarurile să nu se oprească în același cadru — și tocmai oprirea decalată e ce
# deosebește o aruncare de o animație.
#
# ⚠️ `X_PORNIRE` stă LIPIT de marginea din stânga a cadrului (care e pe la −3.2), nu departe în
# afara lui: prima încercare le trimitea de la −4.9 și zarurile intrau în ecran abia după o treime
# din aruncare — te uitai o treime de secundă la o masă goală.
const X_PORNIRE := [-3.3, -3.95]  # de unde vin aruncate (din stânga, ca din mână)
const H_PORNIRE := [1.15, 1.32]
const INTARZIERE := [0.0, 0.13]
const SPIN := [14.5, 12.5]     # rad/s la plecare
const SPIN_LOVIT := 0.62       # cât din rotație rămâne după o ciocnitură de masă
const HOP_ASEZARE := 0.09      # cât se ridică zarul cât se răstoarnă pe ultima față
const PAUZA_REZULTAT := 0.16   # o clipă de liniște după ce s-au oprit, înainte de cartonaș

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
var _stare := "gata"       # gata (aștept să dai) | rostogolire | rezultat
var _npc: Node = null
var _sheet_img: Image = null

var _lbl_stare: Label
var _lbl_suma: Label
var _card: Control
var _card_icon: TextureRect
var _card_nume: Label
var _card_desc: Label
var _btn: Button

var _vp: SubViewport
var _cam: Camera3D
var _zaruri := []          # Node3D × 2
var _umbre := []           # pata de umbră de sub fiecare zar (MeshInstance3D × 2)
var _d := [1, 1]           # ce a ieșit pe fiecare zar
var _z := []               # starea aruncării, câte un dicționar de zar (vezi `_arunca`)
var _t := 0.0              # cât e de când s-au oprit amândouă
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
	_stare = "gata"
	_t = 0.0
	_lbl_stare.text = "Roll for your item"
	_lbl_stare.add_theme_color_override("font_color", CENUSA)
	_lbl_suma.text = ""
	_card.modulate = Color(1, 1, 1, CARD_ASTEPTARE)
	_card.scale = Vector2.ONE          # un „pumn" rămas de la aruncarea trecută (vezi `_pumn`)
	_lbl_suma.scale = Vector2.ONE
	_card_icon.texture = null
	_card_nume.text = ""
	_card_desc.text = ""
	_btn.text = "ROLL THE DICE"
	_btn.disabled = false
	# Zarurile stau cuminți pe masă până dai, pe fețe la întâmplare — altfel te-ar întâmpina de
	# fiecare dată aceeași pereche și ar arăta a poză, nu a masă de joc. Ce se vede acum nu
	# înseamnă nimic: `_arunca()` trage din nou.
	_d = [randi_range(1, 6), randi_range(1, 6)]
	_z.clear()
	_zguduie = 0.0
	for i in 2:
		var z: Node3D = _zaruri[i]
		z.position = LOCURI[i]
		z.basis = Basis(Vector3.UP, randf() * TAU) * _baza_pentru(_d[i])
		_aseaza_umbra(i)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = true
	get_tree().paused = true
	Audio.pause_forest_ambient()
	Audio.play("levelup", -4.0, 0.0)

func _inchide() -> void:
	visible = false
	_stare = "gata"
	# ⚠️ oprim randarea 3D: altfel masa de zaruri se desenează în continuare, în fiecare cadru,
	# în spatele jocului
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_tree().paused = false
	Audio.resume_forest_ambient()

# ⚠️ Ca să nu se deschidă meniul de pauză PESTE noi, `pause.gd::_blocked()` întreabă și de grupul
# „dubios_menu".
#
# ESC NU închide meniul, spre deosebire de Alba-Neagra: acolo poți pleca fără să joci, aici omul
# s-a consumat deja când a scos marfa, deci un ESC ar fi însemnat un om irosit din greșeală.
# Trebuie să dai cu zarurile.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# ARUNCAREA
# ---------------------------------------------------------------------------
func _pe_buton() -> void:
	match _stare:
		"gata":
			_arunca()
		"rezultat":
			_inchide()

func _arunca() -> void:
	_stare = "rostogolire"
	_t = 0.0
	_btn.disabled = true
	_lbl_stare.text = ""
	_lbl_suma.text = ""

	_d = [randi_range(1, 6), randi_range(1, 6)]
	_z.clear()
	for i in 2:
		var loc: Vector3 = LOCURI[i] + Vector3(randf_range(-0.09, 0.09), 0.0, randf_range(-0.12, 0.12))
		var z: Node3D = _zaruri[i]
		z.position = Vector3(X_PORNIRE[i], H_PORNIRE[i], loc.z + randf_range(-0.18, 0.18))
		_z.append({
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
	if _stare != "rostogolire":
		return

	var toate_stau := true
	for i in _z.size():
		_pas_zar(i, delta)
		_aseaza_umbra(i)
		if _z[i]["faza"] != "stat":
			toate_stau = false
	if not toate_stau:
		_t = 0.0
		return
	# s-au oprit amândouă: o clipă de liniște, cât să apuci să citești ce a ieșit
	_t += delta
	if _t >= PAUZA_REZULTAT:
		_arata_rezultatul()

# Un cadru din viața unui zar.
func _pas_zar(i: int, delta: float) -> void:
	var s: Dictionary = _z[i]
	var nod: Node3D = _zaruri[i]
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
					_incepe_asezarea(i)
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
func _incepe_asezarea(i: int) -> void:
	var s: Dictionary = _z[i]
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
func _arata_rezultatul() -> void:
	_stare = "rezultat"
	var u := _item_din_zaruri(_d[0], _d[1])
	# ⚠️ pur numeric, nu se traduce (vezi lista IGNORATE din `tool_check_i18n.gd`)
	_lbl_suma.text = "%d + %d = %d" % [_d[0], _d[1], _d[0] + _d[1]]

	_card_icon.texture = load(ICON_DIR + String(u["icon"]))
	_card_nume.text = String(u["nume"])
	_card_desc.text = String(u["desc"])

	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		_inchide()
		return
	var mesaj := _apply(String(u["id"]), p)
	# Blame Circle și Arcane Magic au ceva de POVESTIT (ce stat s-a dublat, câte iteme s-au
	# schimbat); restul n-au — ce fac scrie deja pe cartonaș.
	if mesaj != "":
		_lbl_stare.text = mesaj
		_lbl_stare.add_theme_color_override("font_color", ACCENT_CLAR)

	# suma sare o clipă în ochi: ea e vestea, ea primește accentul
	_pumn(_lbl_suma, 1.35, 0.28)

	# cartonașul apare crescând, nu pocnește pe ecran
	_btn.text = "CONTINUE"
	_btn.disabled = false
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # jocul e pe pauză, altfel n-ar curge
	t.tween_interval(0.22)
	t.tween_callback(func():
		Audio.play("chest_anim", -3.0, 0.0)
		_pumn(_card, 1.06, 0.34))
	t.tween_property(_card, "modulate", Color(1, 1, 1, 1), 0.3)

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
# Întoarce textul care se arată după aruncare, sau "" dacă itemul n-are nimic de povestit (ce face
# scrie deja pe cartonaș).
#
# Registrul rundei (`player.run_items`) se scrie ȘI de aici, exact ca în `levelup.gd::_apply` —
# altfel Arcane Magic n-ar ști că ai luat vreodată itemele astea.
func _apply(id: String, p) -> String:
	if p != null and "run_items" in p:
		p.run_items.append(id)
	match id:
		"cursed_tome":
			# mai mulți inamici pe secundă: și mai mult XP, și mai multe dinți. Se compune, deci
			# două tomuri fac ×1.5625, nu ×1.5.
			p.spawn_rate_mult *= 1.25
			return ""
		"iron_helmet":
			# ⚠️ „Take 100% Less Damage" e chiar 100%: cu casca pe cap nu mai încasezi NIMIC (vezi
			# `player.take_damage`). Dacă vrei doar o reducere, pune aici cât să rămână — 0.25
			# înseamnă „încasezi un sfert". Prețul e damage-ul tău, care se compune la fiecare
			# luare (0.75 × 0.75 = 0.5625 la a doua cască).
			p.damage_taken_mult = 0.0
			p.damage_dealt_mult *= 0.75
			return ""
		"blame_circle":
			return _blame_circle(p)
		"arcane_magic":
			return _arcane_magic(p)
	return ""

# Blame Circle: un stat se dublează, altul scade cu 25%. Cele două sunt mereu DIFERITE — altfel
# ai fi putut nimeri „dublu și minus 25% pe damage", adică un item care face ×1.5 pe un singur
# rând și pare că nu s-a întâmplat nimic.
func _blame_circle(p) -> String:
	var lista := BLAME_STATS.duplicate()
	lista.shuffle()
	var sus: String = lista[0]
	var jos: String = lista[1]
	_scaleaza_stat(p, sus, BLAME_UP)
	_scaleaza_stat(p, jos, BLAME_DOWN)
	# tr() explicit: textul e ASAMBLAT, deci nici el, nici numele statusurilor din el nu mai trec
	# singure prin traducere (vezi i18n.gd).
	return tr("%s doubled, %s down 25%%") % [tr(sus), tr(jos)]

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

# Arcane Magic: fiecare item pe care îl ai se schimbă pe ALTUL de aceeași calitate, din același
# pool — cele de la level up rămân în lista de la level up, cele de la dubios în lista de aici.
#
# ⚠️ NU se poate face desfăcând efectele: `_apply` scrie direct în statusuri, iar din „viteza e
# 275" nu mai afli ce a adunat-o acolo. Deci player-ul se întoarce la starea de la începutul
# rundei (`reset_la_start`, copia luată la capătul lui `player._ready`) și se rejoacă peste ea o
# listă nouă, item cu item. Singurul efect care NU se desface e XP-ul necesar pe nivel — vezi
# `NU_SE_RESETEAZA` în `player.gd`.
func _arcane_magic(p) -> String:
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if lu == null or not ("run_items" in p):
		return ""
	var vechi: Array = p.run_items.duplicate()
	vechi.pop_back()      # ultimul e chiar Arcane Magic, pus de `_apply` acum o clipă
	if vechi.is_empty():
		return tr("%d items rerolled") % 0
	# Itemele „unice" (Undying Spirit, Mike's Hedgehog) ies din carantina lor: nu le mai ai, deci
	# au voie să reintre în tragere. Fără asta, un unic pierdut aici n-ar mai fi putut fi luat
	# niciodată în runda aia.
	for id in vechi:
		lu.uita_unic(String(id))
	p.reset_la_start()
	p.run_items.clear()
	var cate := 0
	for id in vechi:
		var nou = _acelasi_fel(String(id), lu)
		if nou == null:
			continue
		if _item_dupa_id(String(nou["id"])) != null:
			_apply(String(nou["id"]), p)   # item de-al dubiosului → trece prin `_apply`-ul de aici
		else:
			lu.da_item(nou, p)             # item de level up → prin al lui, ca să țină „unicele"
		cate += 1
	p.run_items.append("arcane_magic")
	return tr("%d items rerolled") % cate

# Alt item, de aceeași calitate și din același pool ca `id`.
func _acelasi_fel(id: String, lu):
	if _item_dupa_id(id) != null:
		# de la dubios. ⚠️ Arcane Magic iese din tragere: altfel s-ar rechema pe el însuși, la
		# nesfârșit (aceeași regulă ca la Lucky Die în cufere, vezi `levelup.da_random_acum`).
		var pool := []
		for u in UPGRADES:
			if u["id"] != "arcane_magic" and u["id"] != id:
				pool.append(u)
		return pool[randi() % pool.size()] if not pool.is_empty() else null
	var vechi = lu.item_dupa_id(id)
	if vechi == null:
		return null    # id necunoscut (item șters între timp) — îl lăsăm pierdut, nu ghicim
	return lu.item_random_de_raritate(String(vechi["rar"]), [id])

func _item_dupa_id(id: String):
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return null

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

	# Rândul de sub linie are DOUĂ vieți: până dai cu zarurile scrie ce ai de făcut, după aceea
	# scrie ce ți-a ieșit (Blame Circle, Arcane Magic). Un al doilea rând, gol tot timpul cât
	# aștepți, ar fi lăsat o gaură în panou.
	_lbl_stare = Label.new()
	_lbl_stare.text = "Roll for your item"
	_lbl_stare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_stare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_stare.add_theme_font_size_override("font_size", 16)
	_lbl_stare.add_theme_color_override("font_color", CENUSA)
	_add_outline(_lbl_stare)
	box.add_child(_lbl_stare)

	box.add_child(_spatiu(4))
	box.add_child(_fereastra_masa())

	_lbl_suma = Label.new()
	_lbl_suma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_suma.add_theme_font_size_override("font_size", 22)
	_lbl_suma.add_theme_color_override("font_color", ACCENT_CLAR)
	_add_outline(_lbl_suma)
	box.add_child(_lbl_suma)

	box.add_child(_card_item())
	box.add_child(_spatiu(6))

	# butonul, centrat: singur într-un VBox s-ar fi întins pe toată lățimea panoului
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(rand)
	_btn = _buton("ROLL THE DICE", _pe_buton)
	rand.add_child(_btn)

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

# Cartonașul itemului câștigat. Se construiește o dată și stă invizibil (alpha 0) până cad
# zarurile — locul lui e ținut oricum, ca panoul să nu-și schimbe înălțimea la jumătatea aruncării.
func _card_item() -> Control:
	_card = Control.new()
	_card.custom_minimum_size = Vector2(0, CARD_H)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate = Color(1, 1, 1, CARD_ASTEPTARE)

	var rama := _cadru(CH_CARD, 1, false)
	rama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.add_child(rama)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hb)

	# celula cu iconița. La level up chenarul ei spune raritatea; aici raritatea nu se scrie, deci
	# chenarul e mereu același — o celulă din aceeași planșă, ca să nu plutească iconița în aer.
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(cell)

	var rama_item := _cadru(CH_ITEM, 1, false)
	rama_item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cell.add_child(rama_item)

	_card_icon = TextureRect.new()
	_card_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_icon.offset_left = 15
	_card_icon.offset_top = 15
	_card_icon.offset_right = -15
	_card_icon.offset_bottom = -15
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(_card_icon)

	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(text)

	_card_nume = Label.new()
	_card_nume.add_theme_font_size_override("font_size", 24)
	_card_nume.add_theme_color_override("font_color", OS_ALB)
	_card_nume.clip_text = true
	_card_nume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(_card_nume)
	text.add_child(_card_nume)

	_card_desc = Label.new()
	_card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_desc.add_theme_font_size_override("font_size", 16)
	_card_desc.add_theme_color_override("font_color", CENUSA)
	_card_desc.max_lines_visible = 2
	_card_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(_card_desc)
	text.add_child(_card_desc)

	return _card

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
	bec.spot_range = 12.0
	bec.spot_angle = 40.0
	bec.spot_angle_attenuation = 1.8
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
	for i in 2:
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
