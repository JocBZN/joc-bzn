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
const ZAR_X := 0.9             # cât de departe de mijloc se opresc (±)
const PODEA_Y := -MARIME_ZAR * 0.5

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

# Cât ține aruncarea: întâi se rostogolesc, apoi se așază pe fața care a ieșit.
const T_ROSTOGOL := 0.95
const T_ASEZARE := 0.5
const SALT_MAX := 0.45         # cât de sus sar între rostogoliri
const X_PORNIRE := [-4.6, -5.6]  # de unde vin aruncate (din stânga, ca din mână)

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
const FILDES := Color8(236, 230, 218)
const NEGRU_BULINA := Color8(38, 24, 18)

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
var _zaruri := []          # Node3D × 2
var _d := [1, 1]           # ce a ieșit pe fiecare zar
var _q_start := []         # rotația de la care începe așezarea
var _q_tinta := []         # rotația pe care trebuie s-o aibă la final
var _ax := []              # axa pe care se rostogolește fiecare
var _viteza := []          # rad/s
var _t := 0.0
var _asezarea_pornita := false

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
	_asezarea_pornita = false
	_lbl_stare.text = "Roll for your item"
	_lbl_stare.add_theme_color_override("font_color", CENUSA)
	_lbl_suma.text = ""
	_card.modulate = Color(1, 1, 1, CARD_ASTEPTARE)
	_card_icon.texture = null
	_card_nume.text = ""
	_card_desc.text = ""
	_btn.text = "ROLL THE DICE"
	_btn.disabled = false
	# Zarurile stau cuminți pe masă până dai, pe fețe la întâmplare — altfel te-ar întâmpina de
	# fiecare dată aceeași pereche și ar arăta a poză, nu a masă de joc. Ce se vede acum nu
	# înseamnă nimic: `_arunca()` trage din nou.
	_d = [randi_range(1, 6), randi_range(1, 6)]
	for i in 2:
		var z: Node3D = _zaruri[i]
		z.position = Vector3(ZAR_X * (1 if i == 1 else -1), 0.0, 0.0)
		z.basis = Basis(Vector3.UP, randf() * TAU) * _baza_pentru(_d[i])
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
	_asezarea_pornita = false
	_btn.disabled = true
	_lbl_stare.text = ""
	_lbl_suma.text = ""

	_d = [randi_range(1, 6), randi_range(1, 6)]
	_q_start = [Quaternion.IDENTITY, Quaternion.IDENTITY]
	_q_tinta = []
	_ax = []
	_viteza = []
	for i in 2:
		# rotația de la final: fața care a ieșit ajunge în sus, plus o răsucire oarecare pe
		# verticală (nu schimbă ce cifră e sus, doar așază zarul altfel pe masă)
		_q_tinta.append((Basis(Vector3.UP, randf() * TAU) * _baza_pentru(_d[i])).get_rotation_quaternion())
		# axă de rostogolire la întâmplare, dar niciodată aproape de verticală: un zar care se
		# învârte doar în jurul lui Y arată ca un titirez, nu ca un zar aruncat
		var ax := Vector3(randf_range(-1.0, 1.0), randf_range(-0.25, 0.25), randf_range(-1.0, 1.0))
		if ax.length() < 0.2:
			ax = Vector3(1.0, 0.1, 0.6)
		_ax.append(ax.normalized())
		_viteza.append(randf_range(13.0, 18.0))
		var z: Node3D = _zaruri[i]
		z.position = Vector3(X_PORNIRE[i], SALT_MAX, randf_range(-0.25, 0.25))
	Audio.play("button", -3.0, 0.0)

func _process(delta: float) -> void:
	if not visible or _stare != "rostogolire":
		return
	_t += delta

	if _t < T_ROSTOGOL:
		var p := _t / T_ROSTOGOL
		for i in 2:
			var z: Node3D = _zaruri[i]
			z.basis = Basis(_ax[i], _viteza[i] * delta) * z.basis
			z.position.x = lerpf(X_PORNIRE[i], ZAR_X * (1 if i == 1 else -1), _franare(p))
			z.position.y = _saltul(p)
		return

	# gata rostogolitul: se așază pe fața care a ieșit
	if not _asezarea_pornita:
		_asezarea_pornita = true
		for i in 2:
			_q_start[i] = (_zaruri[i] as Node3D).basis.get_rotation_quaternion()
		# ⚠️ „ticul" de zar căzut pe masă. Sunetele de zaruri (`dice_roll_*.wav`) au existat cândva
		# în proiect și s-au pierdut — până revin, împrumutăm ciocănitul cheii de cufăr.
		Audio.play("key_pickup", -6.0, 0.12)

	var q := clampf((_t - T_ROSTOGOL) / T_ASEZARE, 0.0, 1.0)
	for i in 2:
		var z: Node3D = _zaruri[i]
		z.basis = Basis(_q_start[i].slerp(_q_tinta[i], _franare(q)))
		z.position.y = lerpf(z.position.y, 0.0, minf(1.0, delta * 14.0))
	if q >= 1.0:
		for i in 2:
			var z: Node3D = _zaruri[i]
			z.basis = Basis(_q_tinta[i])
			z.position.y = 0.0
		_arata_rezultatul()

# Cât din drum s-a făcut, cu frânare la capăt (începe repede, se oprește moale).
func _franare(p: float) -> float:
	return 1.0 - pow(1.0 - clampf(p, 0.0, 1.0), 3.0)

# Două salturi care se sting: zarul lovește masa, sare mai puțin, se potolește.
func _saltul(p: float) -> float:
	return absf(sin(p * PI * 2.4)) * SALT_MAX * (1.0 - p)

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

	# cartonașul apare crescând, nu pocnește pe ecran
	_btn.text = "CONTINUE"
	_btn.disabled = false
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # jocul e pe pauză, altfel n-ar curge
	t.tween_interval(0.22)
	t.tween_callback(func(): Audio.play("chest_anim", -3.0, 0.0))
	t.tween_property(_card, "modulate", Color(1, 1, 1, 1), 0.3)

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

	var cam := Camera3D.new()
	cam.position = CAM_POZ
	cam.keep_aspect = Camera3D.KEEP_WIDTH   # `fov` e pe orizontală (vezi CAM_FOV)
	cam.fov = CAM_FOV
	cam.environment = _mediul()
	_vp.add_child(cam)
	cam.look_at(CAM_TINTA, Vector3.UP)

	# lumina principală, din stânga-sus-față, cu umbre pe postav
	var lum := DirectionalLight3D.new()
	lum.light_energy = 1.6
	lum.light_color = Color8(255, 248, 238)
	lum.shadow_enabled = true
	# ⚠️ Umbra NEATINSĂ iese un triunghi negru cu muchii tăiate cu cuțitul, care arată a greșeală,
	# nu a umbră. Înmuiată și lăsată să se vadă postavul prin ea, zarul pare așezat pe masă.
	lum.shadow_blur = 2.0
	lum.shadow_opacity = 0.62
	lum.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	_vp.add_child(lum)

	# o a doua lumină, slabă și caldă, din dreapta: fără ea fețele din umbră ies plate
	#
	# ⚠️ NU pune aici `ACCENT` (arama plină) și nici energie mare: prima încercare a scos zaruri
	# CĂRĂMIZII, nu de os. Zarul trebuie să rămână fildeș, iar arama doar să-l atingă.
	var lum2 := DirectionalLight3D.new()
	lum2.light_energy = 0.25
	lum2.light_color = Color8(214, 168, 138)
	lum2.rotation_degrees = Vector3(-18.0, 128.0, 0.0)
	_vp.add_child(lum2)

	var podea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	# ⚠️ Mare de tot dinadins: dacă marginea din spate a postavului intră în cadru se vede o dungă
	# unde se termină masa și începe transparența.
	pm.size = Vector2(40.0, 30.0)
	podea.mesh = pm
	podea.position.y = PODEA_Y
	var mat_podea := StandardMaterial3D.new()
	mat_podea.albedo_color = Color8(28, 19, 24)
	mat_podea.roughness = 0.95
	podea.material_override = mat_podea
	_vp.add_child(podea)

	var mesh := _mesh_zar()
	var mat := _material_zar()
	for i in 2:
		var z := Node3D.new()
		var corp := _corpul_zarului(mesh, mat)
		z.add_child(corp)
		z.position = Vector3(ZAR_X * (1 if i == 1 else -1), 0.0, 0.0)
		_vp.add_child(z)
		_zaruri.append(z)

func _mediul() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	# ⚠️ Fără lumină ambientală fețele care nu prind lumină ies NEGRE, iar zarul pare o gaură.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(148, 142, 156)
	env.ambient_light_energy = 0.4
	return env

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

# Cubul desenat în cod: șase fețe, fiecare cu bucata ei din planșa cu buline.
#
# ⚠️ Fețele se construiesc de mână (nu cu `BoxMesh`) fiindcă `BoxMesh` își împarte UV-urile cum
# vrea el, iar noi trebuie să știm EXACT ce cifră stă pe ce direcție — altfel n-am putea să
# oprim zarul pe fața care a ieșit.
func _mesh_zar() -> ArrayMesh:
	var s := MARIME_ZAR * 0.5
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
		var m := 0.002
		var u0 := cx / 3.0 + m
		var u1 := (cx + 1) / 3.0 - m
		var v0 := cy / 2.0 + m
		var v1 := (cy + 1) / 2.0 - m
		var p := [n * s - u * s - v * s, n * s + u * s - v * s,
			n * s + u * s + v * s, n * s - u * s + v * s]
		var uv := [Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uv[idx])
			st.add_vertex(p[idx])
	return st.commit()

func _material_zar() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _plansa_buline()
	mat.roughness = 0.42
	mat.metallic = 0.0
	# ⚠️ `CULL_DISABLED`: nu ne batem capul cu ordinea vârfurilor din `_mesh_zar`. Cubul e închis
	# și luminat din afară, iar normalele sunt puse de mână, deci arată la fel de bine.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

# Planșa cu cele șase fețe, 3×2 celule, desenată în cod: fildeș, chenar arămiu, buline negre.
# Bulinele au marginea netezită (se calculează cât din pixel intră în cerc), altfel la mărimea de
# pe ecran ies în trepte.
func _plansa_buline() -> ImageTexture:
	var c := CELULA_ZAR
	var img := Image.create(c * 3, c * 2, true, Image.FORMAT_RGBA8)
	var raza := c * 0.093
	for val in range(1, 7):
		var cx := (val - 1) % 3
		var cy := (val - 1) / 3
		for y in c:
			for x in c:
				var culoare := FILDES
				# chenarul arămiu de pe muchia feței
				var d_marg: int = mini(mini(x, y), mini(c - 1 - x, c - 1 - y))
				if d_marg < 4:
					culoare = culoare.lerp(ACCENT_STINS, 1.0 - d_marg / 4.0)
				for b in BULINE[val]:
					var centru := Vector2((b.x + 1) * c / 4.0, (b.y + 1) * c / 4.0)
					var d := (Vector2(x + 0.5, y + 0.5) - centru).length()
					var a := clampf(raza - d + 0.5, 0.0, 1.0)
					if a > 0.0:
						culoare = culoare.lerp(NEGRU_BULINA, a)
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
