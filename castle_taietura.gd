extends Node2D

# ATACUL 3 al lui SIR JOHN: TĂIETURA — semiluna de sabie care zboară spre tine.
# Arta: `harta/castle/boss/atac_taietura/` — 4 cadre, tăiate din `Attacks.gif` de
# `tool_taie_atacuri.gd` (celula 3,4 din atlas, oglindită ca să zboare cu burta înainte).
#
# A luat locul RAZEI Warden-ului (`prison_laser.gd`, șters pe 2026-08-22) și nu doar fiindcă arta
# veche nu mai există: o rază instantanee e arma unui turn, nu a unui cavaler cu sabie. Semiluna
# spune din desen cine a aruncat-o.
#
# 🔑 REFĂCUTĂ PE 2026-08-22 (seara), la cererea lui Răzvan: „atacurile să rămână același size,
# își pierd din calitate dacă le mărești — fă-le mai complicate în loc de mai mari".
# Până acum era UN desen de 96 px mărit de 1,7 ori. Acum e o LAMĂ COMPUSĂ: trei semiluni la 1,05
# (adică practic la mărimea lor), așezate una peste alta de-a lungul tăișului și rotite fiecare cu
# câteva sutimi de radian, plus o dâră de patru umbre în urmă, tot mai mici și mai stinse. Ocupă
# cam aceeași bucată de ecran ca înainte — dar e un tăiș cu grosime și cu urmă, nu o poză întinsă.
#
# 🔑 CE O FACE CINSTITĂ: zboară cu viteză FINITĂ, deci se vede venind și se poate ocoli — spre
# deosebire de rază, care lovea tot ce era pe linie în clipa în care pleca. În schimb în faza 3
# vin TREI deodată, în evantai: un pas lateral nu mai ajunge, trebuie să te miști din timp.
#
# ⚠️ Nu e Area2D și nu trece prin fizică: verific distanța în `_process`. Un Area2D adăugat în
# timpul pasului de fizică dă „Can't change this state while flushing queries" (vezi `enemy.gd`),
# iar boss-ul o naște fix din `_physics_process`.

const ART := "res://harta/castle/boss/atac_taietura/"
const CADRE := 4
# Cât de „groasă" e o semilună desenată, în pixeli de artă (jumătatea înălțimii conturului: 54/2,
# tipărit de `tool_taie_atacuri.gd`). Din ea iese raza de lovire, ca hitbox-ul să fie MĂSURAT DIN
# ARTĂ, nu nimerit din ochi — aceeași regulă ca la sabia blestemată și la coasa lui Celesto.
const RAZA_ARTA := 27.0

# --- lama compusă ---
const LAME := 3            # câte semiluni una peste alta
const DECALAJ := 40.0      # cât de departe una de alta, PERPENDICULAR pe zbor (px de lume)
# Cât se răsucește fiecare lamă față de cea din mijloc. 🔑 Nu e cosmetic: răsucite, cele trei se
# leagă într-un ARC MARE — o semilună de trei ori mai lată, făcută din trei desene nemărite.
# Neresucite (prima încercare, 0,09) se încolăceau una în alta și ieșea un ghem, nu un tăiș.
const ROTIRE := 0.28
const RETRAGERE := 14.0    # cât rămân în urmă lamele de la capete, ca arcul să fie curbat
# --- dâra ---
const DARE := 3            # câte umbre ale formației rămân în urmă
const DARA_PAS := 30.0     # la câți pixeli în urmă e fiecare

@export var damage: int = 55
@export var viteza: float = 430.0
@export var marime: float = 1.05         # ⚠️ era 1,7 — acum desenul e aproape la mărimea lui
@export var lifetime: float = 2.2        # cât zboară până se stinge singură
@export var fps: float = 14.0

var _t := 0.0
var _dir := Vector2.RIGHT
var _lovit := false
var _cadre: Array[Texture2D] = []

# Se cheamă DUPĂ `add_child` și după ce i-ai pus poziția — ca la `prison_laser.gd::porneste`.
func porneste(directie: Vector2) -> void:
	if directie.length() > 0.001:
		_dir = directie.normalized()
	rotation = _dir.angle()   # 0 rad = est, exact cum e desenată semiluna

func _ready() -> void:
	z_index = 40   # trece peste tot: e în aer, nu pe jos ca unda
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in CADRE:
		var tex := load("%sframe_%d.png" % [ART, i]) as Texture2D
		if tex != null:
			_cadre.append(tex)
	if _cadre.is_empty():
		push_warning("Tăietura: lipsesc cadrele din %s (rulează --headless --import)" % ART)
		queue_free()
		return

func _process(delta: float) -> void:
	_t += delta
	position += _dir * viteza * delta
	queue_redraw()
	if _t >= lifetime:
		queue_free()
		return
	if _lovit:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	# 🔑 HITBOX DE CAPSULĂ, nu de cerc: lama nu mai e un ghem, e un tăiș lung de `2 × DECALAJ`
	# perpendicular pe zbor. Deci se măsoară distanța până la SEGMENTUL tăișului, nu până la
	# mijlocul lui — altfel colțurile lamei ar fi trecut prin tine fără să te atingă.
	var perp := Vector2(-_dir.y, _dir.x)
	var rel := player.global_position - global_position
	var pe_tais := clampf(rel.dot(perp), -DECALAJ, DECALAJ)
	if rel.distance_to(perp * pe_tais) <= RAZA_ARTA * marime:
		_lovit = true
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))
		# Trece MAI DEPARTE după ce a lovit (nu dispare): o tăietură de sabie nu se oprește în
		# tine. `_lovit` are grijă să nu te mai atingă a doua oară în același zbor.

# ⚠️ Se desenează în sistemul ROTIT al nodului (`rotation` = direcția de zbor), deci aici „x" e
# înainte și „y" e de-a latul tăișului. Așa dâra iese fix în spate și lama fix perpendicular,
# fără niciun calcul de unghiuri.
func _draw() -> void:
	if _cadre.is_empty():
		return
	var f0 := int(_t * fps)
	# 1. dâra: formația întreagă, în urmă, tot mai mică și mai stinsă
	for d in range(DARE, 0, -1):
		var factor := 1.0 - 0.14 * float(d)
		var a := 0.46 * (1.0 - float(d) / float(DARE + 1))
		_formatie(f0 + d, Vector2(-DARA_PAS * float(d), 0.0), factor, a)
	# 2. lama
	_formatie(f0, Vector2.ZERO, 1.0, 1.0)

# Cele trei semiluni, așezate în arc. Fiecare cu ALT cadru (`f0 + i`), ca să nu se vadă că e
# aceeași poză pusă de trei ori.
func _formatie(f0: int, la: Vector2, factor: float, alfa: float) -> void:
	var mijloc := float(LAME - 1) * 0.5
	for i in LAME:
		var o := float(i) - mijloc
		var f := (f0 + i) % _cadre.size()
		var a := alfa if is_zero_approx(o) else alfa * 0.85
		var poz := la + Vector2(-absf(o) * RETRAGERE, o * DECALAJ * factor)
		_pune(_cadre[f], poz, o * ROTIRE, marime * factor, Color(1, 1, 1, a))

func _pune(tex: Texture2D, poz: Vector2, rot: float, scara: float, culoare: Color) -> void:
	draw_set_transform(poz, rot, Vector2.ONE * scara)
	draw_texture(tex, -tex.get_size() * 0.5, culoare)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
