extends Node2D

# ATACUL 2 al lui SIR JOHN: LOVITURA care cade din cer peste locul în care ești.
# Arta: `harta/castle/boss/atac_lovitura/` — 6 cadre, tăiate din `Attacks.gif` de
# `tool_taie_atacuri.gd`: 0..3 = cometa care cade (celula 0,1 din atlas, ROTITĂ ca să pice, nu să
# zboare) și 4..5 = izbucnirea din pământ (celula 5,8).
#
# 🔑 REFĂCUT PE 2026-08-22 (seara), la cererea lui Răzvan: „atacurile să rămână același size,
# își pierd din calitate dacă le mărești — fă-le mai complicate în loc de mai mari".
# Suprafața lovită e ACEEAȘI (`raza_impact` = 130) și damage-ul se dă exact ca înainte. Dar până
# acum cercul ăla era acoperit de UN singur desen de 96 px întins de 2,8 ori; acum cad CINCI
# bucăți: patru cioburi împrăștiate prin cerc, care ating pământul pe rând, și lovitura mare, în
# mijloc, care cade ULTIMA. Aceeași arie, spartă în cinci — iar ordinea lor face din atac o
# prăbușire care se strânge spre centru, nu o poză care apare.
#
# O are din faza 2. Spre deosebire de undă, asta te CAUTĂ: se aruncă spre locul unde ești în
# clipa lansării. Dar are un telegraf lung (căderea) — deci se evită mergând, ceea ce e și ideea:
# în faza 2 nu mai poți sta pe loc.
#
# 🔑 DAMAGE-UL E LA IMPACTUL DIN MIJLOC, nu la cioburi și nu în timpul căderii. Cioburile sunt
# spectacol și avertisment; ce doare e ce cade în mijlocul cercului. Așa atacul are un răspuns
# clar (pleacă de acolo) în loc să fie o taxă pe care o plătești orice ai face.
#
# ⚠️ Ținta se îngheață la lansare (nu urmărește player-ul în cădere): o lovitură care te urmărește
# până aterizează n-ar mai putea fi evitată deloc, deci n-ar mai fi un atac, ar fi o pedeapsă.

const ART := "res://harta/castle/boss/atac_lovitura/"
const ART_CRAPATURA := "res://harta/castle/boss/atac_crapatura/"
const CADRE_CADERE := 4     # frame_0 .. frame_3
const CADRE_IMPACT := 2     # frame_4, frame_5
# Latura pânzei efectelor din atlas. Efectele sunt desenate cu PĂMÂNTUL PE MARGINEA DE JOS a
# pânzei, nu la mijloc — de aia înălțimea se socotește față de marginea de jos. Fără asta, cometa
# ar fi intrat în pământ cu jumătate de corp înainte să atingă ținta, iar izbucnirea ar fi ieșit
# sub ea.
const PANZA := 96.0

# Scările pieselor. Boss-ul e mărit de 2,9 ori, deci și la 2,0 desenul rămâne „la mărimea lui" —
# și e mai mic decât cei 2,77 de dinainte, când o singură izbucnire trebuia să umple tot cercul.
const SCARA_MARE := 2.0
const SCARA_CIOB := 1.15
const SCARA_CRAPATURA := 1.3

@export var damage: int = 42
@export var raza_impact: float = 130.0
@export var inaltime: float = 460.0     # de la ce înălțime pleacă
@export var timp_cadere: float = 0.75
@export var timp_impact: float = 0.55
@export var cioburi: int = 4            # câte cad în jurul loviturii mari
# Cât întârzie lovitura din mijloc față de primul ciob. Ea dă damage-ul, deci ea e „bătaia" —
# cioburile sunt numărătoarea, ea e sfârșitul.
@export var intarziere_mare: float = 0.30

var _cadere: Array[Texture2D] = []
var _impact: Array[Texture2D] = []
var _crapaturi: Array[Texture2D] = []
# fiecare bucată: {"p", "start", "scara", "mare", "atins", "rot_crap"}
var _bucati: Array = []
var _t := 0.0
var _gata := false
var _sus: Node2D   # stratul de deasupra tuturor: ce cade și ce sare

func _ready() -> void:
	_cadere = _incarca(ART, 0, CADRE_CADERE)
	_impact = _incarca(ART, CADRE_CADERE, CADRE_IMPACT)
	_crapaturi = _incarca(ART_CRAPATURA, 0, 4)
	if _cadere.is_empty() and _impact.is_empty():
		queue_free()
		return
	# Cercul de avertizare de pe jos stă SUB tot (z = -1), dar ce cade din cer trebuie să treacă
	# peste tot. Un singur `_draw` n-are cum să fie și dedesubt și deasupra, deci stratul de sus e
	# un nod separat, cu z-ul lui ABSOLUT (`z_as_relative` fals), care își desenează partea prin
	# semnalul `draw`. Tot un nod în plus, nu douăzeci.
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sus = Node2D.new()
	_sus.z_as_relative = false
	_sus.z_index = 61
	_sus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sus.draw.connect(_deseneaza_sus)
	add_child(_sus)
	# lovitura mare, în mijloc, cade ultima
	_bucati.append({"p": Vector2.ZERO, "start": intarziere_mare, "scara": SCARA_MARE, "mare": true,
		"atins": false, "rot_crap": randf() * TAU})
	# cioburile: împrăștiate prin cerc, la unghiuri depărtate unul de altul, aterizând pe rând
	var cate := maxi(0, cioburi)
	var unghi0 := randf() * TAU
	for i in cate:
		var unghi := unghi0 + TAU * float(i) / float(cate) + randf_range(-0.35, 0.35)
		var raza := raza_impact * randf_range(0.50, 0.92)
		_bucati.append({
			"p": Vector2.RIGHT.rotated(unghi) * raza,
			"start": intarziere_mare * (float(i) / float(cate)) * 0.85,
			"scara": SCARA_CIOB * randf_range(0.85, 1.15),
			"mare": false, "atins": false, "rot_crap": randf() * TAU,
		})

func _incarca(folder: String, de_la: int, cate: int) -> Array[Texture2D]:
	var iesire: Array[Texture2D] = []
	for i in cate:
		var tex := load("%sframe_%d.png" % [folder, de_la + i]) as Texture2D
		if tex != null:
			iesire.append(tex)
	if iesire.size() < cate:
		push_warning("Lovitura: lipsesc cadre din %s (rulează --headless --import)" % folder)
	return iesire

func _process(delta: float) -> void:
	_t += delta
	for b in _bucati:
		if bool(b["atins"]):
			continue
		if _t - float(b["start"]) >= timp_cadere:
			b["atins"] = true
			_ateriza(b)
	queue_redraw()
	if _sus != null:
		_sus.queue_redraw()
	if _t >= intarziere_mare + timp_cadere + timp_impact:
		queue_free()

func _ateriza(b: Dictionary) -> void:
	if bool(b["mare"]):
		_gata = true
		Audio.play("sirjohn_impact", -4.0, 0.0)
		_da_damage()
	else:
		# ⚠️ Cioburile folosesc aceeași probă, deci trebuie ciupite de ton — altfel cinci impacturi
		# la rând sună a mitralieră cu același glonț. Al treilea parametru al lui `play` e CÂT
		# variază tonul, nu tonul (vezi `audio.gd`).
		Audio.play("sirjohn_impact", -14.0, 0.14)

func _da_damage() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	# ⚠️ Ținta se citește ACUM, din `global_position`, NU dintr-o copie luată în `_ready()`.
	# Bug prins rulând (2026-08-17): cine naște bolovanul face `add_child` și ABIA APOI îi pune
	# poziția — adică `_ready()` rula pe poziția veche, iar bolovanul cădea la vedere peste tine
	# dar socotea damage-ul față de alt punct. Rezultat: atacul arăta perfect și nu lovea NICIODATĂ.
	# Nodul nu se mișcă pe orizontală (coboară doar desenul), deci `global_position` E locul
	# impactului. Aceeași capcană ca la `scythe.gd` — vezi comentariul din `celesto.gd::_coasa`.
	if global_position.distance_to(player.global_position) <= raza_impact:
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))

# Stratul de jos: cercul de avertizare cât cade, apoi crăpăturile rămase de la fiecare bucată.
func _draw() -> void:
	for b in _bucati:
		if not bool(b["atins"]) or _crapaturi.is_empty():
			continue
		var vt := clampf((_t - float(b["start"]) - timp_cadere) / maxf(0.01, timp_impact), 0.0, 1.0)
		var f := clampi(int(vt * float(_crapaturi.size()) * 1.4), 0, _crapaturi.size() - 1)
		var a := 0.9 * (1.0 - smoothstep(0.5, 1.0, vt))
		var s := SCARA_CRAPATURA * (float(b["scara"]) / SCARA_CIOB)
		_pune(self, _crapaturi[f], b["p"], float(b["rot_crap"]), s, Color(1, 1, 1, a))
	if _gata:
		return
	# ⚠️ Cercul se strânge până la clipa în care cade lovitura MARE (aia dă damage), nu până la
	# primul ciob. Un telegraf care se termină înaintea loviturii minte.
	var k := clampf(_t / maxf(0.01, timp_cadere + intarziere_mare), 0.0, 1.0)
	var col := Color(0.9, 0.25, 0.15, 0.20 + 0.35 * k)
	draw_arc(Vector2.ZERO, raza_impact, 0.0, TAU, 48, col, 3.0)
	draw_arc(Vector2.ZERO, raza_impact * (1.0 - k), 0.0, TAU, 32, Color(1.0, 0.5, 0.2, 0.5), 2.0)

# Stratul de sus: ce cade din cer și ce sare din pământ.
func _deseneaza_sus() -> void:
	for b in _bucati:
		var tl := _t - float(b["start"])
		if tl < 0.0:
			continue
		var scara := float(b["scara"])
		var punct: Vector2 = b["p"]
		if not bool(b["atins"]):
			if _cadere.is_empty():
				continue
			var k := clampf(tl / timp_cadere, 0.0, 1.0)
			var f := clampi(int(k * float(_cadere.size())), 0, _cadere.size() - 1)
			# accelerat, ca o cădere adevărată (nu liniar — altfel plutește)
			var h := inaltime * (1.0 - k * k)
			_pune(_sus, _cadere[f], punct + Vector2(0, -h - PANZA * 0.5 * scara), 0.0, scara, Color(1, 1, 1, 1))
			continue
		if _impact.is_empty():
			continue
		var ki := clampf((tl - timp_cadere) / maxf(0.01, timp_impact), 0.0, 1.0)
		if ki >= 1.0:
			continue
		var fi := clampi(int(ki * float(_impact.size())), 0, _impact.size() - 1)
		_pune(_sus, _impact[fi], punct + Vector2(0, -PANZA * 0.5 * scara), 0.0, scara, Color(1, 1, 1, 1.0 - smoothstep(0.75, 1.0, ki)))

# Un desen, la poziția și rotația lui, cu mijlocul pânzei în punct.
func _pune(unde: CanvasItem, tex: Texture2D, poz: Vector2, rot: float, scara: float, culoare: Color) -> void:
	unde.draw_set_transform(poz, rot, Vector2.ONE * scara)
	unde.draw_texture(tex, -tex.get_size() * 0.5, culoare)
	unde.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
