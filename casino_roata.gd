extends Control

# ROATA DE RULETĂ a cazinoului: discul care se învârte, BILA care aleargă pe rama de aur și
# tot sunetul învârtirii. Stă peste roata desenată în poza mesei (`casino.gd` o așază exact
# peste ea), deci discul rotit acoperă fix roata din fundal.
#
# De ce fișier separat: `casino.gd` are deja 80 KB și trei ecrane. Aici e DOAR mișcarea și
# sunetul ei; cazinoul cere o învârtire (`invarte`) și primește înapoi un semnal când bila s-a
# oprit (`gata`). Numărul îl trage tot cazinoul, ÎNAINTE, ca până acum — roata nu decide nimic.
#
# ---------------------------------------------------------------------------
# CE FACE BILA, PAS CU PAS (2026-08-19)
# ---------------------------------------------------------------------------
#  1. DERIVĂ — între învârtiri roata nu stă moartă, plutește foarte încet (`W_DERIVA`). O masă
#     înghețată arată ca o poză; una care se mișcă abia-abia arată ca un aparat pornit.
#  2. ANTICIPARE (0,22 s) — roata se dă puțin ÎNAPOI înainte să plece. Prima regulă din manualul
#     de animație: ca să pară că pornirea are forță, arată întâi mișcarea inversă. Fără ea,
#     învârtirea începe „din pix".
#  3. PISTĂ (~3,3 s) — bila aleargă în SENS INVERS roții (ca la masa adevărată) pe rama de aur și
#     încetinește cu frecare constantă. Sunetul aici e patul (huruitul, cu tonul legat de viteză)
#     plus un tic la fiecare din cele 4 brațe ale butucului pe lângă care trece.
#  4. POTRIVIREA — când bila a coborât sub viteza de cădere, se uită UNDE ar pica din viteza pe
#     care o are și alege cel mai apropiat buzunar de culoarea cerută. Nu invers! Dacă buzunarul
#     s-ar alege la început, bila ar trebui împinsă până la el, adică s-ar vedea că e trasă de
#     sfoară. Așa, corectura e mai mică de un buzunar (≤0,22 rad la roșu/negru) și aterizarea
#     arată exact ca fizica. La VERDE, care e unul singur pe toată roata, chiar se mai dă o
#     tură-două de târcoale până când vine el sub bilă — se întâmplă la o învârtire din 37.
#  5. CĂDEREA (1,15 s) — bila părăsește rama, sare de trei ori (săriturile scad) și se înfige în
#     buzunar cu viteza fix 0. Aici intră riser-ul, pocnetele și ticăitul care rărește.
#  6. LIPITĂ — de acum bila se rotește ÎMPREUNĂ cu roata, în buzunarul ei. Ea e rezultatul care
#     se vede pe roată; numărul scris în butuc (`casino.gd`) e rezultatul care se citește.
#
# ⚠️ ROATA TOT NU POATE ARĂTA NUMĂRUL. Arta are 28 de buzunare, nu 37, deci nu există buzunar
# „al lui 17". Ce se poate — și se face — e CULOAREA: bila se oprește într-un buzunar roșu dacă
# a ieșit un număr roșu, negru dacă a ieșit negru, în cel verde dacă a ieșit 0. Deci roata nu
# minte niciodată, doar nu spune tot. (Înainte de 2026-08-19 arta avea numere scrise pe ea, și
# alea greșite — „38", „29" de două ori — de-aia roata era pur și simplu decor.)

signal gata(n: int)

const DISC_TEX := "res://harta/EGT/wheel.png"
const BILA_TEX := "res://harta/EGT/ball.png"

# ---------------------------------------------------------------------------
# GEOMETRIA, în pixelii pozei mesei (ca tot ce e în `casino.gd`). Se înmulțește cu scara mesei.
# ---------------------------------------------------------------------------
const RAZA_DISC := 174.0      # jumătate din wheel.png (348 px) — vezi `tool_egt_assets.gd`
const RAZA_PISTA := 160.0     # pe ce rază aleargă bila cât e pe rama de aur
# Inelul de buzunare are un cerc de aur pe la 125 care îl taie în două; buzunarele adevărate
# (cele largi) sunt în banda de AFARĂ, 128–164. Deci bila se așază pe la mijlocul ei, nu pe
# mijlocul întregului inel — acolo ar sta călare pe cercul de aur.
const RAZA_BUZUNAR := 146.0   # unde se așază, în mijlocul buzunarelor propriu-zise
const RAZA_BILA := 11.0       # ball.png e 22×22

# Cele 28 de buzunare ale artei: unghiul CENTRULUI (grade, 0 = la dreapta, crește în jos, ca în
# Godot) și culoarea. MĂSURATE pe poză, nu împărțite egal: buzunarele sunt desenate de mână și
# au între 11,3° și 14,2°. Dacă se schimbă arta roții, se remăsoară (vezi CLAUDE.md, 2026-08-19).
const BUZUNARE := [
	[3.81, "RED"], [16.69, "BLACK"], [29.00, "RED"], [40.50, "BLACK"], [52.00, "RED"],
	[64.44, "BLACK"], [77.31, "RED"], [90.44, "BLACK"], [103.50, "RED"], [116.31, "BLACK"],
	[128.63, "RED"], [139.94, "BLACK"], [151.31, "RED"], [163.50, "BLACK"], [176.44, "RED"],
	[189.31, "BLACK"], [202.25, "RED"], [215.31, "BLACK"], [228.75, "RED"], [242.75, "BLACK"],
	[256.31, "RED"], [270.00, "GREEN"], [283.25, "RED"], [296.75, "BLACK"], [310.94, "RED"],
	[324.56, "BLACK"], [337.75, "RED"], [350.88, "BLACK"],
]

# ---------------------------------------------------------------------------
# MIȘCAREA. Vitezele sunt în rad/s, frecările în rad/s². Semnul: + = în sensul acelor de
# ceasornic pe ecran (roata), − = invers (bila).
# ---------------------------------------------------------------------------
const W_DERIVA := 0.30        # plutirea dintre învârtiri (o tură la ~21 s)
const T_ANTICIPARE := 0.22    # cât ține pasul înapoi
const W_ANTICIPARE := -1.5    # cât de tare se dă înapoi (vârful)
const W_ROATA0 := 3.6         # viteza roții la lansare
const W_BILA0 := -11.6        # viteza bilei la lansare (invers)
const FREC_ROATA := 0.62      # roata e grea: încetinește lent
const FREC_BILA := 2.40       # bila e ușoară și freacă rama: încetinește de 4 ori mai repede
const W_BILA_CADE := 3.8      # sub viteza asta bila nu se mai ține pe rama înclinată
const T_CADERE := 1.15        # cât ține căderea (fix: pe el e croit riser-ul de 1,10 s)
# Cât de aproape de un buzunar bun trebuie să pice bila ca să-i dea drumul. La roșu/negru
# buzunarele bune sunt din două în două, deci fereastra se nimerește în cel mult 0,13 s. Numai
# verdele (unul singur) poate să ceară o tură întreagă — de-aia și răbdarea de mai jos.
const FEREASTRA := 0.16
const ASTEPTARE_MAX := 2.2    # peste atât cade oricum (nu se atinge decât la verde)
const SARITURI := 3           # câte sărituri face bila până se potolește
const SARITURA := 15.0        # cât de sus sare prima dată (pixeli de poză)

# --- sunet (decibeli relativi; echilibrul e AICI, nu în fișiere — vezi audio.gd) ---
const DB_LANSARE := -3.0
const DB_PAT_MIN := -24.0     # patul când roata abia se mai mișcă
const DB_PAT_MAX := -13.0     # patul la viteză maximă
const DB_TIC_PISTA := -13.0
const DB_TIC_CADERE := -17.0
const DB_RISER := -8.0
const DB_CADERE := -2.0       # cel mai tare sunet din toată învârtirea: momentul
const DB_POCNET := -8.0       # primul pocnet; următoarele scad cu 4 dB
const DB_ASEZARE := -4.0

enum { DERIVA, ANTICIPARE, PISTA, POTRIVIRE, CADERE, LIPITA }

var _tex_disc: Texture2D
var _tex_bila: Texture2D
var _pat: AudioStreamPlayer          # boxa proprie pentru huruit (e BUCLĂ, nu poate trece prin Audio.play)

var _stare := DERIVA
var _t := 0.0                        # cronometrul fazei curente
var _a_roata := 0.0
var _w_roata := W_DERIVA
var _a_bila := 0.0
var _w_bila := 0.0
var _r_bila := RAZA_PISTA
var _bila_vizibila := false
var _numar := 0                      # numărul tras de cazinou, dat înapoi la final
var _culoare := "RED"                # ce culoare trebuie să aibă buzunarul în care aterizează
var _buzunar := 0                    # în care anume — se alege abia la cădere (vezi pasul 4)
var _ultim_tic := 0.0                # unghiul relativ la ultimul tic (ca să știm când mai dăm unul)
var _cad_rel0 := 0.0                 # unghiul relativ de la care începe căderea
var _cad_delta := 0.0                # cât mai are de mers, cu semn
var _pocnete := 0                    # câte sărituri au sunat deja
var _asezat := false                 # a sunat „s-a așezat"?
var _pat_stins := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art, fără muiere
	_tex_disc = load(DISC_TEX)
	_tex_bila = load(BILA_TEX)
	_pat = AudioStreamPlayer.new()
	_pat.bus = "Master"
	add_child(_pat)
	var s := Audio.stream_for("roulette_bed")
	if s is AudioStreamWAV:
		# Bucla se pune AICI, pe o copie, nu în fișierul importat: `.import`-ul e rescris de
		# Godot la fiecare reimport și ar pierde setarea în tăcere. Fișierul e deja croit ca să
		# se închidă în buclă (coada stinsă peste cap) — vezi CLAUDE.md, 2026-08-19.
		var w: AudioStreamWAV = s.duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		_pat.stream = w

# ---------------------------------------------------------------------------
# CE CHEAMĂ CAZINOUL
# ---------------------------------------------------------------------------

# Așază roata peste roata din poză. `centru` și `raza` sunt în pixeli de ECRAN (deja înmulțiți
# cu scara mesei de `casino.gd`), ca să nu știe fișierul ăsta nimic despre cât e de mare masa.
func aseaza(centru: Vector2, raza: float) -> void:
	position = centru - Vector2(raza, raza)
	size = Vector2(raza, raza) * 2.0
	queue_redraw()

# Masa se redeschide / ai pus alt pariu: bila dispare, roata rămâne în plutire.
func reseteaza() -> void:
	_stare = DERIVA
	_bila_vizibila = false
	_w_roata = W_DERIVA
	_opreste_patul()
	queue_redraw()

# Pornește învârtirea pentru numărul `n`, care are culoarea `culoare` („RED"/„BLACK"/„GREEN").
# Bila va ateriza într-un buzunar de FIX culoarea aia, ales la întâmplare dintre cele care o au.
func invarte(n: int, culoare: String) -> void:
	_numar = n
	_culoare = culoare
	_buzunar = 0
	_stare = ANTICIPARE
	_t = 0.0
	_bila_vizibila = false
	_pocnete = 0
	_asezat = false
	_r_bila = RAZA_PISTA

# Cel mai apropiat buzunar de culoarea cerută față de unghiul `unghi` (în sistemul roții).
func _buzunar_apropiat(unghi: float, culoare: String) -> int:
	var bun := -1
	var cea_mai_mica := TAU
	for i in BUZUNARE.size():
		if BUZUNARE[i][1] != culoare:
			continue
		var d: float = absf(wrapf(deg_to_rad(BUZUNARE[i][0]) - unghi, -PI, PI))
		if d < cea_mai_mica:
			cea_mai_mica = d
			bun = i
	return maxi(bun, 0)

# ---------------------------------------------------------------------------
# MIȘCAREA
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _pat.playing:
			_opreste_patul()
		return
	match _stare:
		DERIVA:
			_w_roata = W_DERIVA
		ANTICIPARE:
			_t += delta
			# un arc de sinus: pleacă din 0, se dă înapoi, se întoarce în 0 — apoi ȚÂȘNEȘTE
			_w_roata = W_ANTICIPARE * sin(PI * clampf(_t / T_ANTICIPARE, 0.0, 1.0))
			if _t >= T_ANTICIPARE:
				_lanseaza()
		PISTA, POTRIVIRE:
			_freaca(delta)
			_ticaie_pista()
			if _stare == PISTA and absf(_w_bila) <= W_BILA_CADE:
				_stare = POTRIVIRE
				_t = 0.0
			if _stare == POTRIVIRE:
				_t += delta
				_incearca_caderea()
		CADERE:
			_t += delta
			_freaca_roata(delta)
			_cade()
		LIPITA:
			_freaca_roata(delta)
			_a_bila = _a_roata + deg_to_rad(BUZUNARE[_buzunar][0])
	_a_roata += _w_roata * delta
	_suna_patul(delta)
	queue_redraw()

func _lanseaza() -> void:
	_stare = PISTA
	_w_roata = W_ROATA0
	_w_bila = W_BILA0
	_a_bila = _a_roata + randf() * TAU     # bila e aruncată de unde nimerește croupierul
	_r_bila = RAZA_PISTA
	_bila_vizibila = true
	_ultim_tic = _relativ()
	Audio.play_ex("roulette_launch", DB_LANSARE, randf_range(0.98, 1.02))
	_pat_stins = false
	if _pat.stream != null and not _pat.playing:
		_pat.volume_db = DB_PAT_MIN + Audio.sfx_db()
		_pat.play()

func _freaca(delta: float) -> void:
	_freaca_roata(delta)
	# Cât dă târcoale (POTRIVIRE) bila NU mai încetinește, se ține pe viteza de cădere. Și în
	# realitate bila mai aleargă o vreme aproape constant înainte să pice. Aici e și o nevoie:
	# dacă ar încetini mai departe, s-ar apropia de viteza roții, punctul în care ar ateriza
	# aproape că n-ar mai mișca față de roată — și buzunarul verde n-ar mai ajunge niciodată sub
	# ea (la prima variantă chiar așa se întâmpla: 6,8 s și o smucitură la final).
	if _stare != POTRIVIRE:
		# bila merge invers (viteză negativă), deci frecarea o URCĂ spre 0
		_w_bila = minf(_w_bila + FREC_BILA * delta, -0.2)
	_a_bila += _w_bila * delta

func _freaca_roata(delta: float) -> void:
	_w_roata = maxf(_w_roata - FREC_ROATA * delta, W_DERIVA)

# Unghiul bilei FAȚĂ DE ROATĂ. Buzunarele sunt fixe pe roată, deci numai unghiul ăsta contează
# pentru „în ce buzunar pică" și pentru ticăit.
func _relativ() -> float:
	return _a_bila - _a_roata

# Cât se învârte bila față de roată (mereu negativ cât e pe pistă: merg în sensuri opuse).
func _viteza_relativa() -> float:
	return _w_bila - _w_roata

# Un tic la fiecare din cele 4 brațe ale butucului pe lângă care trece bila. NU unul pe buzunar:
# la lansare ar ieși 67 pe secundă, adică un bâzâit. Patru pe tură e și adevărat (pe masa
# adevărată bila zăngăne în deflectoare, nu în fiecare despărțitor), și se aude ca un ritm care
# rărește — exact ce ține omul cu ochii pe roată.
func _ticaie_pista() -> void:
	var pas := TAU / 4.0
	var rel := _relativ()
	while _ultim_tic - rel >= pas:
		_ultim_tic -= pas
		var v: float = clampf(absf(_viteza_relativa()) / 15.0, 0.0, 1.0)
		Audio.play_ex("roulette_tick", DB_TIC_PISTA - 4.0 * (1.0 - v), 0.94 + 0.30 * v)

# Dă drumul căderii NUMAI când buzunarul ales ajunge sub locul în care ar pica bila. Predicția:
# la o încetinire constantă până la 0 în `T_CADERE` secunde, bila mai face `v*T/2` radiani.
func _incearca_caderea() -> void:
	var v := _viteza_relativa()
	var delta_nom := v * T_CADERE * 0.5                   # cu semn (negativ)
	var prezis := _relativ() + delta_nom
	_buzunar = _buzunar_apropiat(prezis, _culoare)
	var tinta := deg_to_rad(BUZUNARE[_buzunar][0])
	var corectie := wrapf(tinta - prezis, -PI, PI)
	# Fereastra se LĂRGEȘTE dacă bila tot dă târcoale (adică: e verde, singurul buzunar rar).
	# Altfel zeroul ar ține 6,5 s cât alte numere țin 4,7. Cu ea, plata e o împingere ceva mai
	# mare la aterizare — dar tot sub jumătate de buzunar — în loc de încă două ture de așteptare.
	var fereastra := FEREASTRA + 0.45 * maxf(0.0, _t - 0.8)
	# și tot ținem o limită tare, ca să nu existe niciun drum prin care să se învârtă la nesfârșit
	if absf(corectie) <= fereastra or _t >= ASTEPTARE_MAX:
		_cad_rel0 = _relativ()
		_cad_delta = delta_nom + corectie
		_stare = CADERE
		_t = 0.0
		Audio.play_ex("roulette_drop", DB_CADERE, randf_range(0.97, 1.03))
		Audio.play_ex("roulette_riser", DB_RISER, 1.0)

# Căderea: unghiul e KEYFRAME (ca să nimerească buzunarul la fix), raza e „fizică" (cade spre
# centru și sare de trei ori). Curba `1-(1-p)²` e exact încetinire constantă până la viteză 0 —
# deci bila nu se „oprește din buton", ci se stinge.
func _cade() -> void:
	var p: float = clampf(_t / T_CADERE, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - p, 2.0)
	var rel := _cad_rel0 + _cad_delta * e
	_a_bila = _a_roata + rel
	# viteza n-o mai integrăm, o CITIM din curbă: de ea depind ticăitul și tonul patului
	_w_bila = _w_roata + _cad_delta * 2.0 * (1.0 - p) / T_CADERE

	# raza: coboară spre buzunar, cu sărituri care scad
	var salt := absf(sin(PI * float(SARITURI) * p)) * SARITURA * pow(1.0 - p, 1.8)
	_r_bila = lerpf(RAZA_PISTA, RAZA_BUZUNAR, e) + salt

	# ticăit peste despărțitori, tot mai rar (aici DA, pe fiecare buzunar: bila e printre ele)
	var pas := TAU / float(BUZUNARE.size())
	while _ultim_tic - rel >= pas:
		_ultim_tic -= pas
		Audio.play_ex("roulette_tick", DB_TIC_CADERE, randf_range(1.10, 1.22))

	# pocnetul fiecărei sărituri, exact când atinge fundul
	var atins := int(p * float(SARITURI))
	if atins > _pocnete and atins <= SARITURI:
		_pocnete = atins
		Audio.play_ex("roulette_clack", DB_POCNET - 4.0 * (atins - 1), 1.0 + 0.10 * atins)

	if not _asezat and p >= 0.90:
		_asezat = true
		Audio.play_ex("roulette_settle", DB_ASEZARE, randf_range(0.98, 1.04))

	if p >= 1.0:
		_stare = LIPITA
		_r_bila = RAZA_BUZUNAR
		_w_bila = _w_roata
		_pat_stins = true
		gata.emit(_numar)

# ---------------------------------------------------------------------------
# PATUL (huruitul). O singură boxă, ținută aici: e buclă, iar `Audio.play` nu poate bucla.
# Tonul și volumul urmează viteza — asta face diferența între „merge un fișier" și „se învârte
# ceva greu": urechea aude că încetinește înainte s-o vadă ochiul.
# ---------------------------------------------------------------------------
func _suna_patul(delta: float) -> void:
	if _pat.stream == null or not _pat.playing:
		return
	if _pat_stins:
		_pat.volume_db -= 34.0 * delta       # se stinge în ~0,35 s după ce bila s-a oprit
		if _pat.volume_db <= -60.0:
			_pat.stop()
		return
	var v: float = clampf(absf(_viteza_relativa()) / 15.0, 0.0, 1.0)
	_pat.volume_db = lerpf(DB_PAT_MIN, DB_PAT_MAX, v) + Audio.sfx_db()
	_pat.pitch_scale = 0.80 + 0.45 * v

func _opreste_patul() -> void:
	_pat_stins = true
	if _pat.playing:
		_pat.stop()

# ---------------------------------------------------------------------------
# DESENUL. Tot într-un singur `_draw`, nu în noduri-copil, fiindcă bila trebuie să fie PESTE
# disc, iar un nod-copil s-ar desena oricum peste tot ce desenează părintele — adică ordinea
# n-ar mai fi a mea.
# ---------------------------------------------------------------------------
func _draw() -> void:
	if _tex_disc == null:
		return
	var c := size * 0.5
	var sc := size.x / (RAZA_DISC * 2.0)
	draw_set_transform(c, _a_roata, Vector2(sc, sc))
	draw_texture(_tex_disc, -Vector2(RAZA_DISC, RAZA_DISC))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _bila_vizibila:
		return
	# DÂRA: la lansare bila face ~15 px pe cadru, adică ar clipi din loc în loc. Trei fantome în
	# urma ei, care se sting odată cu viteza, o leagă la loc. Truc vechi de când lumea în 2D și
	# costă trei desene, nu un shader.
	var v: float = clampf(absf(_viteza_relativa()) / 12.0, 0.0, 1.0)
	var r := RAZA_BILA * sc
	if v > 0.05:
		for i in range(3, 0, -1):
			var a := _a_bila - signf(_w_bila) * float(i) * 0.055 * v
			_deseneaza_bila(c + Vector2(cos(a), sin(a)) * _r_bila * sc, r, 0.34 * v / float(i))
	_deseneaza_bila(c + Vector2(cos(_a_bila), sin(_a_bila)) * _r_bila * sc, r, 1.0)

func _deseneaza_bila(p: Vector2, r: float, alpha: float) -> void:
	draw_texture_rect(_tex_bila, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, alpha))
