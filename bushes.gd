extends Node2D

# Tufe (Bush / Tall Bush) — DECOR PUR, generat procedural în jurul player-ului, la infinit.
# Nu fac nimic: n-au loot, n-au interacțiune, nu dau damage. Sunt exact ca niște copaci mici.
#
# Lumea e împărțită în „chunk-uri" (pătrate). Fiecare își generează tufele DETERMINIST (din
# poziția lui) → același loc are mereu aceleași tufe, chiar dacă pleci și te întorci. Chunk-urile
# depărtate se descarcă automat (performanță). Același tipar ca la copaci (`props.gd`) și pietre
# (`rocks.gd`), dar independent și cu propriile reglaje.
#
# ⚠️ DIFERENȚA FAȚĂ DE COPACI ȘI PIETRE (cerut de Răzvan pe 2026-08-15): tufele NU se construiesc
# din cod, ci sunt SCENE gata făcute — `bush.tscn` și `tall_bush.tscn`. Le deschizi în editor și
# muți cu mouse-ul ce vrei. Generatorul ăsta doar le instanțiază și le pune la locul lor.
# Ce e în scenă și de ce:
#   • rădăcina (StaticBody2D) — ORIGINEA ei e „linia de sortare pe Y": player-ul trece prin fața
#     tufei sub linia asta și pe după ea deasupra. E pusă la ~35% din înălțimea tufei, de la pământ.
#   • `Sprite2D` — desenul. `offset` îl așază față de origine, `scale` (0.6) îi dă mărimea.
#   • `Umbra` — pata de sub tufă, `z_index = -1` ca să stea pe pământ, sub tot.
#   • `CollisionShape2D` — cutia în care te blochezi; mică, doar la bază.
# Dacă schimbi `scale` la Sprite2D, mărimea coliziunii și a umbrei NU se iau după el — le potrivești
# tot de mână. Ăsta e prețul faptului că scena e editabilă în loc de calculată.
#
# DOAR ÎN PĂDURE: tufele cresc numai pe iarbă. Ca la copaci, verificarea nu e „e chunk-ul în
# deșert?", ci „arată podeaua vreun pic de deșert AICI?" (`desertness_at_chunk > 0`) — așa nu apar
# tufe nici pe gradientul de tranziție spre nisip.

const BUSHES := [
	preload("res://bush.tscn"),
	preload("res://tall_bush.tscn"),
]
const SEED_SALT := 0xB05  # sămânță diferită de a copacilor/pietrelor → tufele n-au același tipar

# Măsurătorile de contur ale texturilor (conturul opac, banda de bază) — aceleași pe care le
# folosesc copacii, cactușii și pietrele. Aici doar CITIM din ele, ca să știm cât de lată e o tufă.
const GroundShadow := preload("res://ground_shadow.gd")

@export var chunk_size: int = 512          # mărimea unui pătrat de lume (px)
@export var load_radius: int = 3           # câte pătrate în jurul player-ului ținem încărcate
# Câte tufe (maxim) încercăm într-un pătrat. E o ÎNCERCARE, nu o garanție: cele care ar cădea peste
# altceva se aruncă. Urcat de la 3 la 6 pe 2026-08-15, odată cu regula strictă de suprapunere —
# altfel pădurea rămânea prea goală, fiindcă un copac blochează acum o suprafață mare în jurul lui.
@export var bushes_per_chunk: int = 6
# Tufa te blochează, ca un copac. Pe `false` stinge cutia de coliziune din scenă (poți trece prin ele).
# ⚠️ MĂRIMEA nu mai e aici: o dai din `bush.tscn` / `tall_bush.tscn` (scale la Sprite2D sau la rădăcină).
@export var solid: bool = true

# SPAȚIUL LIBER DIN JURUL FIECĂREI TUFE (cerut de Răzvan pe 2026-08-15: „nu vreau să se suprapună
# cu alte obiecte, vreau să aibă un spațiu între ele de spawnare"). E o singură cifră, în PIXELI de
# lume, și se măsoară **de la marginea desenului la marginea desenului** — nu de la centru la centru.
# Adică: între tufă și ORICE altceva (altă tufă, copac, piatră, structură) rămâne atâta iarbă goală.
# O crești → tufe mai rare, dar mai aerisite; o scazi → cresc în pâlcuri.
#
# Comparăm DREPTUNGHIURILE VIZIBILE, nu distanțe între centre: două cercuri pe lățime ziceau „e
# bine" pentru o tufă înaltă care intra cu vârful peste ce era deasupra ei. Acum umflăm dreptunghiul
# tufei cu `spatiu_liber` în toate părțile și cerem să nu atingă dreptunghiul nimănui.
@export var spatiu_liber: float = 24.0
@export var path_clearance: int = 2  # câte tile-uri de potecă (64px) ținem libere în jur — nicio tufă pe potecă
# Cât de mare socotim o structură (statuie, EGT, monument, portal, Alba, Dubiosu), măsurat de la
# centrul ei. Generatoarele lor spun doar POZIȚIA, nu și mărimea, deci nu putem să le măsurăm ca pe
# copaci — cifra asta e „raza" cu care le tratăm pe toate. Peste ea se adaugă tufa + `spatiu_liber`.
@export var struct_clearance: float = 140.0

var _loaded := {}          # Vector2i (chunk) -> Node2D (containerul cu tufele lui)
var _paths: Node = null    # nodul Paths (pathways.gd) — nicio tufă pe poteci
var _props: Node2D = null  # nodul Props (copacii) — tufele se feresc de trunchiuri
var _rocks: Node2D = null  # nodul Rocks (pietrele) — idem
# DREPTUNGHIUL VIZIBIL al fiecărei scene de tufă, față de punctul în care o plantăm — măsurat O
# SINGURĂ DATĂ la pornire (vezi `_masoara_scenele`). Verificarea suprapunerilor are nevoie de
# mărime FĂRĂ să construiască noduri, iar mărimea stă acum în scenă (scale la Sprite2D și la
# rădăcină), nu într-un `@export` de aici — deci o citim de acolo.
var _cutii: Array[Rect2] = []
# Frații din World care își pot spune poziția fără să construiască noduri: orice metodă
# `chunk_<ceva>_pos(key) -> Vector2` (Vector2.INF = chunk-ul n-are nimic). Convenția e deja
# folosită de statui, EGT, monumente, portaluri, Alba-Neagra și Dubiosu — o descoperim singuri,
# ca să prindem automat și generatoarele adăugate mai târziu.
var _structuri: Array = []  # [[nod, "chunk_x_pos"], ...]

# „Chests" are și el `chunk_chest_pos`, dar îl sărim: (1) cuferele stau lângă poteci, iar de
# poteci ne ferim oricum; (2) funcția lui cere nodul Paths, pe care el îl caută abia la primul
# `_process` — dacă l-am întreba mai devreme, ar crăpa.
const FARA_STRUCTURI := ["Chests"]

func _ready() -> void:
	_masoara_scenele()
	var p := get_parent()
	if p == null:
		return
	_props = p.get_node_or_null("Props") as Node2D
	_rocks = p.get_node_or_null("Rocks") as Node2D
	for n in p.get_children():
		if n == self or FARA_STRUCTURI.has(String(n.name)):
			continue
		for m in n.get_method_list():
			var nume: String = m["name"]
			if nume.begins_with("chunk_") and nume.ends_with("_pos") and m["args"].size() == 1:
				_structuri.append([n, nume])

# Mărimea fiecărei scene: instanțiem o dată fiecare tufă, măsurăm și aruncăm nodul. Contează
# conturul OPAC al texturii, nu canvasul (ambele imagini au 128×128, dar desenul din ele e mai
# îngust), trecut prin `offset` și prin AMBELE scale-uri din scenă (Sprite2D și rădăcină — Răzvan
# le folosește pe amândouă). Iese un dreptunghi față de originea scenei, adică față de locul în
# care plantăm tufa.
func _masoara_scenele() -> void:
	for scena in BUSHES:
		var n: Node2D = scena.instantiate()
		var sp := _sprite_din(n)
		var cutie := Rect2(-20, -20, 40, 40)  # plasă de siguranță, dacă cineva scoate sprite-ul
		if sp != null and sp.texture != null:
			var u := GroundShadow.used_rect(sp.texture)
			var t := Vector2(sp.texture.get_width(), sp.texture.get_height())
			# un pixel din textură ajunge la: rădăcină.scale × (sprite.position + sprite.scale × pixel)
			var colt := n.scale * (sp.position + sp.scale * (Vector2(u.position) + sp.offset - t * 0.5))
			cutie = Rect2(colt, n.scale * sp.scale * Vector2(u.size))
		_cutii.append(cutie)
		n.free()

# Desenul tufei = primul Sprite2D care nu e umbra. Căutat pe nume, cu căutare de rezervă, ca
# scena să rămână editabilă (dacă Răzvan redenumește nodul, tot îl găsim).
func _sprite_din(n: Node) -> Sprite2D:
	var sp := n.get_node_or_null("Sprite2D") as Sprite2D
	if sp != null:
		return sp
	for c in n.get_children():
		if c is Sprite2D and String(c.name) != "Umbra":
			return c
	return null

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _paths == null:
		# căutat leneș (ca la copaci): la `_ready` s-ar putea să nu fie încă în grup
		_paths = get_tree().get_first_node_in_group("paths")
	if _paths == null:
		return  # fără Paths am planta tufe pe potecă — mai bine așteptăm un cadru
	var pc := _chunk_of(player.global_position)
	# încarcă pătratele din jur care încă nu sunt generate
	for cx in range(pc.x - load_radius, pc.x + load_radius + 1):
		for cy in range(pc.y - load_radius, pc.y + load_radius + 1):
			var key := Vector2i(cx, cy)
			if not _loaded.has(key):
				_loaded[key] = _build_chunk(key)
	# descarcă pătratele prea depărtate
	for key in _loaded.keys():
		if absi(key.x - pc.x) > load_radius or absi(key.y - pc.y) > load_radius:
			_loaded[key].queue_free()
			_loaded.erase(key)

func _chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(chunk_size)), floori(pos.y / float(chunk_size)))

# Pozițiile (și ce scenă e) tufelor unui pătrat, calculate DETERMINIST din cheia lui, FĂRĂ a crea
# noduri. Folosit atât la construire, cât și la verificarea distanței față de pătratele vecine.
# Ordinea apelurilor rng (întâi scena, apoi x, apoi y) trebuie păstrată dacă modifici ceva.
func _chunk_bushes_raw(key: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT  # determinist: același pătrat → aceleași tufe
	var count := rng.randi_range(0, bushes_per_chunk)
	var out := []
	for i in count:
		var idx := rng.randi_range(0, BUSHES.size() - 1)
		var pos := Vector2(
			key.x * chunk_size + rng.randf_range(0.0, chunk_size),
			key.y * chunk_size + rng.randf_range(0.0, chunk_size)
		)
		# NUMAI ÎN PĂDURE: nimic pe nisip și nici pe gradientul spre deșert.
		# (RNG-ul a fost deja consumat mai sus → determinismul se păstrează; doar filtrăm.)
		if BiomeMap.desertness_at_chunk(pos / float(chunk_size)) > 0.0:
			continue
		out.append({"pos": pos, "idx": idx, "key": key})
	return out

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true  # tufele intră în sortarea pe Y (efect de adâncime)
	add_child(container)
	var mine := _chunk_bushes_raw(key)
	# Pozițiile brute ale tufelor din cele 8 pătrate vecine (pentru verificarea distanței).
	var neighbors := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			neighbors.append_array(_chunk_bushes_raw(Vector2i(key.x + dx, key.y + dy)))
	# Structurile din jur, cerute O SINGURĂ DATĂ pe chunk (nu o dată pe tufă): unele generatoare
	# scanează copacii ca să-și aleagă locul, deci întrebarea nu e chiar ieftină.
	var structuri := _pozitii_structuri(key)
	for i in mine.size():
		if _too_close(mine[i], i, mine, neighbors):
			continue  # prea aproape de altă tufă → n-o punem
		var me: Dictionary = mine[i]
		# nicio tufă pe potecă sau pe blend-ul ei
		if _paths != null and _paths.is_on_path(me["pos"], path_clearance):
			continue
		if _langa_copac(me["pos"], me["idx"], key):
			continue  # ar ieși înfiptă într-un trunchi
		if _langa_piatra(me["pos"], me["idx"], key):
			continue
		if _langa_structura(me["pos"], me["idx"], structuri):
			continue
		var bush: Node2D = BUSHES[me["idx"]].instantiate()
		# Poziția e chiar originea scenei = linia de sortare pe Y. Nicio corecție de făcut aici:
		# unde stă desenul față de punctul ăsta e treaba scenei, nu a generatorului.
		bush.position = me["pos"]
		if not solid:
			_stinge_coliziunea(bush)
		container.add_child(bush)
	return container

# `solid = false` → tufa rămâne doar imagine. Nu ștergem nodul, doar îl dezactivăm: dacă întorci
# reglajul înapoi, scena e neatinsă.
func _stinge_coliziunea(bush: Node) -> void:
	for c in bush.get_children():
		if c is CollisionShape2D:
			c.disabled = true

# ---------------------------------------------------------------------------
# TUFELE CEDEAZĂ ÎN FAȚA TUTUROR
# ---------------------------------------------------------------------------
# Toate generatoarele lumii sunt deterministe și independente, iar regula stabilită în joc e că
# cel mai NOU se ferește de cele vechi (dacă s-ar feri amândouă, aceeași ciocnire i-ar șterge pe
# amândoi și ar rămâne o pată goală). Tufele sunt ultimele venite și cele mai mărunte, deci ele
# cedează: copacilor, pietrelor și oricărei structuri.
#
# ⚠️ Ca peste tot, listele „raw" conțin și obiecte care vor fi refuzate mai încolo (prea aproape
# de altul, pe potecă etc.), deci ne ferim și de locuri unde până la urmă nu crește nimic.
# E partea sigură a greșelii: pierdem câteva tufe, dar nu punem niciuna în trunchi.

# ⚠️ Aici măsurăm COPACUL ÎNTREG (coroana), nu trunchiul. Până pe 2026-08-15 ne feream doar de
# trunchi, ca pietrele — o tufă crescută sub coroană părea firească pe hârtie, dar în joc însemna
# tufe intrate peste desenul copacului, exact ce nu voia Răzvan.
func _langa_copac(pos: Vector2, idx: int, key: Vector2i) -> bool:
	if _props == null or not _props.has_method("_chunk_trees_raw"):
		return false
	var a := _cutie_tufa(idx, pos).grow(spatiu_liber)
	var scara := _scara(_props, "tree_scale")
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for t in _props._chunk_trees_raw(Vector2i(key.x + dx, key.y + dy)):
				if a.intersects(_cutie_prop(t["tex"], scara, t["pos"])):
					return true
	return false

func _langa_piatra(pos: Vector2, idx: int, key: Vector2i) -> bool:
	if _rocks == null or not _rocks.has_method("_chunk_rocks_raw"):
		return false
	var a := _cutie_tufa(idx, pos).grow(spatiu_liber)
	var scara := _scara(_rocks, "rock_scale")
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for r in _rocks._chunk_rocks_raw(Vector2i(key.x + dx, key.y + dy)):
				if a.intersects(_cutie_prop(r["tex"], scara, r["pos"])):
					return true
	return false

# Pozițiile structurilor din chunk-ul ăsta și din cele 8 vecine (fără Vector2.INF = „n-are").
func _pozitii_structuri(key: Vector2i) -> Array:
	var out := []
	for s in _structuri:
		var nod: Node = s[0]
		var metoda: String = s[1]
		# Fiecare generator își are propriile chunk-uri. Toate folosesc 512 azi, dar dacă vreunul
		# și-l schimbă, traducem cheia noastră în a lui prin centrul pătratului.
		var cs := _scara(nod, "chunk_size", float(chunk_size))
		var centru := (Vector2(key) + Vector2(0.5, 0.5)) * float(chunk_size)
		var k0 := Vector2i(floori(centru.x / cs), floori(centru.y / cs))
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var p: Vector2 = nod.call(metoda, Vector2i(k0.x + dx, k0.y + dy))
				if p != Vector2.INF:
					out.append(p)
	return out

func _langa_structura(pos: Vector2, idx: int, structuri: Array) -> bool:
	var raza := _raza(idx) + struct_clearance + spatiu_liber
	for p in structuri:
		if pos.distance_to(p) < raza:
			return true
	return false

# Un reglaj numeric al altui generator (`rock_scale`, `tree_scale`, `chunk_size`), citit prin
# `get()` ca să nu depindem de tipul lui. Dacă nodul lipsește sau n-are proprietatea, `implicit`.
func _scara(nod: Node, prop: String, implicit: float = 1.0) -> float:
	if nod == null or nod.get(prop) == null:
		return implicit
	return float(nod.get(prop))

# Dreptunghiul vizibil al tufei nr. `idx`, plantată la `pos` — vezi `_masoara_scenele`.
func _cutie_tufa(idx: int, pos: Vector2) -> Rect2:
	var c: Rect2 = _cutii[idx] if idx < _cutii.size() else Rect2(-20, -20, 40, 40)
	return Rect2(pos + c.position, c.size)

# Cât se întinde tufa în jurul ei, ca rază (jumătatea celei mai mari laturi). Folosit doar la
# structuri, unde n-avem dreptunghi cu care să comparăm, ci doar poziția lor.
func _raza(idx: int) -> float:
	var c: Rect2 = _cutii[idx] if idx < _cutii.size() else Rect2(-20, -20, 40, 40)
	return maxf(c.size.x, c.size.y) * 0.5

# Dreptunghiul vizibil al unui copac / al unei pietre, în coordonate de lume, calculat din poziția
# lui BRUTĂ (cea din lista „raw"). `props.gd` și `rocks.gd` construiesc la fel: sprite-ul primește
# `offset.y = h*(sort_anchor-0.5)`, iar nodul e apoi ridicat cu `sort_anchor*h*scara` — cele două
# se anulează, așa că rămâne o formulă scurtă, fără `sort_anchor` în ea. Practic: poziția brută e
# chiar punctul în care obiectul atinge pământul.
func _cutie_prop(tex: Texture2D, scara: float, pos: Vector2) -> Rect2:
	var u := GroundShadow.used_rect(tex)
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var colt := Vector2(float(u.position.x) - w * 0.5, float(u.position.y) - h) * scara
	return Rect2(pos + colt, Vector2(u.size) * scara)

# Două tufe se „ating" dacă dreptunghiul uneia, umflat cu `spatiu_liber`, dă peste al celeilalte.
func _se_ating(a: Dictionary, b: Dictionary) -> bool:
	return _cutie_tufa(a["idx"], a["pos"]).grow(spatiu_liber) \
		.intersects(_cutie_tufa(b["idx"], b["pos"]))

# O tufă e „prea aproape" dacă se suprapune cu una deja acceptată. Departajare stabilă (aceeași
# decizie indiferent de ordinea generării): în același pătrat renunțăm la indicele mai mare;
# față de vecini renunțăm doar dacă vecinul are cheia „mai mică" lexicografic.
func _too_close(me: Dictionary, my_index: int, mine: Array, neighbors: Array) -> bool:
	for j in my_index:
		if _se_ating(me, mine[j]):
			return true
	var my_key: Vector2i = me["key"]
	for other in neighbors:
		var ok: Vector2i = other["key"]
		var key_smaller := ok.x < my_key.x or (ok.x == my_key.x and ok.y < my_key.y)
		if key_smaller and _se_ating(me, other):
			return true
	return false
