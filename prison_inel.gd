extends Node2D

# ATACUL 1 al lui SIR JOHN: UNDA care se lărgește din el când înfige sabia în lespezi.
#
# 🔑 REFĂCUT PE 2026-08-22 (seara), la cererea lui Răzvan: „atacurile să rămână același size,
# își pierd din calitate dacă le mărești — fă-le mai complicate în loc de mai mari".
# Unda are ACEEAȘI rază (380) și exact aceleași reguli de damage ca înainte. S-a schimbat CUM se
# obține suprafața aia: până acum era O poză de 96 px întinsă de opt ori (de aia avea nevoie de
# filtrare liniară — la NEAREST ieșeau blocuri de 8 px). Acum e COMPUSĂ din multe piese desenate
# aproape la mărimea lor:
#   • PECETEA (`atac_inel/`) — se aprinde o clipă sub el, acolo unde a intrat sabia. Nu crește.
#   • FRONTUL (`atac_stropi/`) — evantaie de resturi NĂSCUTE PE FRONT în timp ce el se lărgește.
#     Fiecare își trăiește viața lui de trei zecimi de secundă și moare în urmă, deci frontul e
#     mereu proaspăt, iar în spatele lui rămâne o dâră care se stinge. Cu cât inelul e mai larg,
#     cu atât se nasc MAI MULTE, nu mai mari — asta e „mai complicat în loc de mai mare", la propriu.
#   • CRĂPĂTURILE (`atac_crapatura/`) — rămân pe lespezi în urma frontului și se sting.
# Toate la scări între 1,1 și 2,4 — adică sub cât e mărit boss-ul însuși (2,9) — deci pixelul
# efectului e cât pixelul lumii, iar filtrul a putut să se întoarcă la NEAREST, ca în restul jocului.
#
# Îl are din faza 1, deci e atacul „de bază". Ideea lui e „dă-te de pe mine": nu te urmărește,
# dar te prinde dacă stai lipit.
#
# 🔑 DAMAGE-UL SE DĂ CÂND FRONTUL AJUNGE LA TINE, nu la începutul animației și nici o dată pe
# cadru. Inelul crește, deci `distanța <= raza curentă` devine adevărat EXACT în clipa în care
# unda te atinge; `_lovit` face să se întâmple o singură dată. Dacă apuci să fugi în afara razei
# maxime, nu te atinge deloc — asta e tot rostul atacului.
#
# ⚠️ Nu e Area2D și nu trece prin fizică: verific distanța în `_process`. Un Area2D adăugat în
# timpul pasului de fizică dă „Can't change this state while flushing queries" (vezi `enemy.gd`),
# iar boss-ul îl naște fix din `_physics_process`.
#
# ⚠️ Se desenează cu `_draw`, nu cu zeci de `AnimatedSprite2D`. Un nod pe fiecare bucată ar
# însemna vreo șaizeci de noduri născute și omorâte la fiecare undă, la fiecare patru secunde,
# toată lupta. `_draw` face aceleași zeci de desene fără să atingă arborele de scenă.

const ART_PECETE := "res://harta/castle/boss/atac_inel/"
const ART_STROPI := "res://harta/castle/boss/atac_stropi/"
const ART_CRAPATURA := "res://harta/castle/boss/atac_crapatura/"
const CADRE := 4
const PANZA := 96.0

# --- cât de mari sunt piesele (boss-ul e la 2,9; sub atât înseamnă „nemărite") ---
const SCARA_PECETE := 2.4
const SCARA_STROP := 1.8
const SCARA_CRAPATURA := 1.1

# --- frontul ---
const EMISIE_PAS := 52.0      # la câți pixeli parcurși de front se mai naște un rând de stropi
const SPATIU := 245.0         # cât de rar stau pe circumferință (de aici iese CÂȚI sunt)
const STROPI_PE_RAND_MIN := 4
const STROPI_PE_RAND_MAX := 12
const STROP_VIATA := 0.26     # cât trăiește un strop, de la ghem la fire subțiri
const STROP_DERIVA := 34.0    # cât mai fuge în afară cât trăiește
# Unde cade MIJLOCUL pânzei față de front, în pixeli de artă. Bucata e desenată cu ghemul de
# resturi în stânga pânzei și cu dârele spre dreapta (vezi contururile tipărite de
# `tool_taie_atacuri.gd`: de la x=0 în primul cadru la x=75 în ultimul), deci mijlocul stă puțin
# ÎN SPATELE frontului: masa strălucitoare pe linia care lovește, firele subțiri înaintea ei.
const STROP_DECALAJ := -10.0
# Cât se rotește rândul următor față de cel dinainte. Fără asta, stropii ar ieși aliniați pe raze
# și unda ar arăta a roată cu spițe, nu a suflare.
const ROTIRE_RAND := 0.61

# --- pecetea din mijloc ---
const PECETE_VIATA := 0.40

# --- crăpăturile ---
const CRAP_PAS := 96.0        # la câți pixeli de front mai lasă un rând de crăpături
const CRAP_PE_PAS := 1        # câte, pe rând
const CRAP_VIATA := 0.80

# Cât din durată se stinge frontul la coadă: o undă se pierde, nu se oprește brusc.
const STINGERE := 0.25

@export var damage: int = 30
@export var raza_max: float = 380.0     # până unde ajunge frontul
@export var durata: float = 0.85        # în cât timp ajunge acolo
@export var grosime_lovire: float = 46.0   # cât de „gros" e frontul care lovește
# Cinematica de intrare cheamă unda DOAR ca desen, cu jocul pe pauză (`final_boss.gd::unda_de_spectacol`).
# Fără steagul ăsta ar fi lovit player-ul cu 1 damage (`maxi(1, ...)` nu lasă niciodată zero) —
# adică boss-ul te-ar fi ciupit din filmuleț, înainte să înceapă lupta.
@export var fara_damage: bool = false

var _t := 0.0
var _lovit := false
var _pecete: Array[Texture2D] = []
var _stropi_art: Array[Texture2D] = []
var _crapaturi_art: Array[Texture2D] = []
# stropi vii: {"dir": Vector2, "r0": float, "rot": float, "t": float, "s": float, "a": float}
var _stropi: Array = []
# crăpături: {"p": Vector2, "rot": float, "t": float, "s": float}
var _crapaturi: Array = []
var _urmatoarea_emisie := 0.0
var _urmatoarea_crapatura := CRAP_PAS
var _unghi_rand := 0.0

func _ready() -> void:
	z_index = -1   # pe jos, sub boss și sub player (e o undă pe pământ, nu un obiect)
	# ⚠️ NEAREST, ca tot restul jocului. Până azi era LINIAR, fiindcă poza de 96 px era întinsă de
	# opt ori și la NEAREST se vedeau blocurile. Acum nimic nu trece de 2,4× — deci filtrul „corect"
	# pentru pixel art se poate întoarce, iar efectul e din nou clar.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pecete = _incarca(ART_PECETE)
	_stropi_art = _incarca(ART_STROPI)
	_crapaturi_art = _incarca(ART_CRAPATURA)
	if _stropi_art.is_empty():
		queue_free()
		return
	_unghi_rand = randf() * TAU

func _incarca(folder: String) -> Array[Texture2D]:
	var iesire: Array[Texture2D] = []
	for i in CADRE:
		var tex := load("%sframe_%d.png" % [folder, i]) as Texture2D
		if tex != null:
			iesire.append(tex)
	if iesire.size() < CADRE:
		push_warning("Unda: lipsesc cadre din %s (rulează --headless --import)" % folder)
	return iesire

func _process(delta: float) -> void:
	_t += delta
	var k := _t / durata
	for s in _stropi:
		s["t"] += delta
	for c in _crapaturi:
		c["t"] += delta
	_stropi = _stropi.filter(func(s): return s["t"] < STROP_VIATA)
	_crapaturi = _crapaturi.filter(func(c): return c["t"] < CRAP_VIATA)
	if k < 1.0:
		var raza := raza_max * k
		_naste_stropi(raza)
		_lasa_crapaturi(raza)
	elif _stropi.is_empty() and _crapaturi.is_empty():
		queue_free()
		return
	queue_redraw()
	if _lovit or fara_damage or k >= 1.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	var d := global_position.distance_to(player.global_position)
	if d <= raza_max * k + grosime_lovire * 0.5:
		_lovit = true
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))

# 🔑 AICI E TOATĂ IDEEA. Frontul nu e o poză care se mărește, ci un rând de bucăți născute pe el
# la fiecare `EMISIE_PAS` pixeli. Câte anume — atâtea cât încap pe circumferință la distanța
# `SPATIU`. Deci un inel de două ori mai larg are de două ori mai multe bucăți, la aceeași mărime.
func _naste_stropi(raza: float) -> void:
	while raza >= _urmatoarea_emisie:
		var r := maxf(_urmatoarea_emisie, 22.0)
		var cate := clampi(int(round(TAU * r / SPATIU)), STROPI_PE_RAND_MIN, STROPI_PE_RAND_MAX)
		_unghi_rand += ROTIRE_RAND
		for i in cate:
			var unghi := _unghi_rand + TAU * float(i) / float(cate) + randf_range(-0.10, 0.10)
			_stropi.append({
				"dir": Vector2.RIGHT.rotated(unghi),
				"r0": r + randf_range(-12.0, 12.0),
				"rot": unghi,
				"t": 0.0,
				"s": SCARA_STROP * randf_range(0.82, 1.12),
				"a": randf_range(0.58, 0.86),
			})
		_urmatoarea_emisie += EMISIE_PAS

# Urma de pe lespezi: la fiecare `CRAP_PAS` pixeli parcurși de front, mai rămân în urmă câteva
# crăpături. Nu lovesc nimic — sunt semnul că pe acolo a trecut ceva greu.
func _lasa_crapaturi(raza: float) -> void:
	if _crapaturi_art.is_empty():
		return
	while raza >= _urmatoarea_crapatura:
		for i in CRAP_PE_PAS:
			var unghi := randf() * TAU
			_crapaturi.append({
				"p": Vector2.RIGHT.rotated(unghi) * (_urmatoarea_crapatura + randf_range(-16.0, 4.0)),
				"rot": randf() * TAU,
				"t": 0.0,
				"s": SCARA_CRAPATURA * randf_range(0.7, 1.1),
			})
		_urmatoarea_crapatura += CRAP_PAS

func _draw() -> void:
	var k := clampf(_t / durata, 0.0, 1.0)
	# stingerea de la coadă a undei întregi (aceeași ca înainte)
	var p_stins := (k - (1.0 - STINGERE)) / STINGERE
	var alfa_unda := 1.0 - clampf(p_stins, 0.0, 1.0)
	# 1. crăpăturile, dedesubt. Sunt urma, nu efectul: stau șterse, ca să nu fure ochiul frontului.
	for c in _crapaturi:
		var vt: float = clampf(float(c["t"]) / CRAP_VIATA, 0.0, 1.0)
		var f: int = clampi(int(vt * float(_crapaturi_art.size()) * 1.6), 0, _crapaturi_art.size() - 1)
		var a := 0.34 * (1.0 - smoothstep(0.30, 1.0, vt))
		_pune(_crapaturi_art[f], c["p"], float(c["rot"]), float(c["s"]), Color(0.72, 0.86, 1.0, a))
	# 2. pecetea din mijloc: se aprinde și se stinge, nu crește
	if not _pecete.is_empty() and _t < PECETE_VIATA:
		var vp := _t / PECETE_VIATA
		var fp := clampi(int(vp * float(_pecete.size())), 0, _pecete.size() - 1)
		_pune(_pecete[fp], Vector2.ZERO, 0.0, SCARA_PECETE, Color(1, 1, 1, 1.0 - vp * vp))
	# 3. frontul: fiecare strop la vârsta LUI, nu la vârsta undei
	for s in _stropi:
		var vs: float = clampf(float(s["t"]) / STROP_VIATA, 0.0, 1.0)
		var f2: int = clampi(int(vs * float(_stropi_art.size())), 0, _stropi_art.size() - 1)
		var r: float = float(s["r0"]) + STROP_DERIVA * vs + STROP_DECALAJ * float(s["s"])
		var a2: float = float(s["a"]) * alfa_unda * smoothstep(0.0, 0.12, vs) * (1.0 - smoothstep(0.55, 1.0, vs))
		if a2 <= 0.01:
			continue
		_pune(_stropi_art[f2], s["dir"] * r, float(s["rot"]), float(s["s"]), Color(1, 1, 1, a2))

# Un desen, la poziția și rotația lui, cu mijlocul pânzei în punct.
func _pune(tex: Texture2D, poz: Vector2, rot: float, scara: float, culoare: Color) -> void:
	draw_set_transform(poz, rot, Vector2.ONE * scara)
	draw_texture(tex, -tex.get_size() * 0.5, culoare)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
