extends Node2D

# Tufe (Bush / Tall Bush) — DECOR PUR, generat procedural în jurul player-ului, la infinit.
# Nu fac nimic: n-au loot, n-au interacțiune, nu dau damage. Sunt exact ca niște copaci mici.
#
# Sistemul e copiat după copaci (`props.gd`) și pietre (`rocks.gd`), dar e INDEPENDENT și cu
# propriile reglaje: lumea e împărțită în „chunk-uri" (pătrate), fiecare își generează tufele
# DETERMINIST (din poziția lui) → același loc are mereu aceleași tufe, chiar dacă pleci și te
# întorci. Chunk-urile depărtate se descarcă automat (performanță).
#
# DOAR ÎN PĂDURE: tufele cresc numai pe iarbă. La fel ca la copaci, verificarea nu e „e chunk-ul
# în deșert?", ci „arată podeaua vreun pic de deșert AICI?" (`desertness_at_chunk > 0`) — așa
# nu apar tufe nici pe gradientul de tranziție spre nisip.

const BUSHES := [
	preload("res://harta/Bush.png"),
	preload("res://harta/Tall_Bush.png"),
]
const SEED_SALT := 0xB05  # sămânță diferită de a copacilor/pietrelor → tufele n-au același tipar

# Măsurătorile de contur (conturul opac, banda de bază) și umbra de la sol — aceleași pe care le
# folosesc copacii, cactușii și pietrele.
const GroundShadow := preload("res://ground_shadow.gd")

@export var chunk_size: int = 512          # mărimea unui pătrat de lume (px)
@export var load_radius: int = 3           # câte pătrate în jurul player-ului ținem încărcate
@export var bushes_per_chunk: int = 3      # câte tufe (maxim) într-un pătrat — mai dese decât copacii
@export var min_gap_hitboxes: float = 1.2  # distanța minimă între tufe, în „hitbox-uri" (mai mic decât la copaci: tufele pot crește în pâlcuri)
# `bush_scale`: singura valoare legată de dimensiunea artei. Ambele imagini au canvas 128×128, cu
# desenul vizibil 102×90 (Bush) și 75×112 (Tall_Bush). Player-ul are ~62px vizibili înălțime, iar
# copacii ajung la ~258px. La 0.6 ies tufe de ~54px și ~67px — adică sub/lângă statura player-ului,
# clar mai mici decât copacii. Dacă desenezi tufe de altă mărime, ajustează aici.
@export var bush_scale: float = 0.6
# Tufa te blochează, ca un copac. Pune-l pe `false` din inspector dacă vrei să treci prin ele.
@export var solid: bool = true
@export var hitbox_factor: float = 0.45    # lățimea cutiei, ca fracție din lățimea VIZIBILĂ a tufei
@export var hitbox_vertical: float = 0.5   # înălțimea cutiei față de lățime: 1.0 = pătrat, mai mic = mai scundă
@export var hitbox_shift_y: float = 0.0    # urcă/coboară cutia față de bază (negativ = mai sus)
@export var sort_anchor: float = 0.35      # de la ce % din înălțime (măsurat de la bază) tufa începe să te acopere
# --- umbra de la baza tufei (aceeași elipsă turtită ca la copaci) ---
@export var shadow_alpha: float = 0.32
@export var shadow_width: float = 0.62     # fracție din lățimea vizibilă
@export var shadow_squash: float = 0.30    # înălțime / lățime (1.0 = cerc)
@export var shadow_shift_y: float = -2.0   # o urcă/coboară față de bază

@export var path_clearance: int = 1  # câte tile-uri de potecă (64px) ținem libere în jur — nicio tufă pe potecă
@export var tree_clearance: float = 16.0    # iarbă lăsată între tufă și trunchiul unui copac (px)
@export var rock_clearance: float = 10.0    # idem, față de o piatră
@export var struct_clearance: float = 90.0  # cât ținem tufele la distanță de structuri (statui, EGT, monumente, portaluri...)

var _loaded := {}          # Vector2i (chunk) -> Node2D (containerul cu tufele lui)
var _paths: Node = null    # nodul Paths (pathways.gd) — nicio tufă pe poteci
var _props: Node2D = null  # nodul Props (copacii) — tufele se feresc de trunchiuri
var _rocks: Node2D = null  # nodul Rocks (pietrele) — idem
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

# Pozițiile (și textura) tufelor unui pătrat, calculate DETERMINIST din cheia lui, FĂRĂ a crea
# noduri. Folosit atât la construire, cât și la verificarea distanței față de pătratele vecine.
# Ordinea apelurilor rng (întâi textura, apoi x, apoi y) trebuie păstrată dacă modifici ceva.
func _chunk_bushes_raw(key: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT  # determinist: același pătrat → aceleași tufe
	var count := rng.randi_range(0, bushes_per_chunk)
	var out := []
	for i in count:
		var tex: Texture2D = BUSHES[rng.randi_range(0, BUSHES.size() - 1)]
		var pos := Vector2(
			key.x * chunk_size + rng.randf_range(0.0, chunk_size),
			key.y * chunk_size + rng.randf_range(0.0, chunk_size)
		)
		# NUMAI ÎN PĂDURE: nimic pe nisip și nici pe gradientul spre deșert.
		# (RNG-ul a fost deja consumat mai sus → determinismul se păstrează; doar filtrăm.)
		if BiomeMap.desertness_at_chunk(pos / float(chunk_size)) > 0.0:
			continue
		out.append({"pos": pos, "tex": tex, "key": key})
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
		if _langa_copac(me["pos"], me["tex"], key):
			continue  # ar ieși înfiptă într-un trunchi
		if _langa_piatra(me["pos"], me["tex"], key):
			continue
		if _langa_structura(me["pos"], structuri):
			continue
		var bush := _make_bush(me["tex"])
		bush.position = me["pos"]
		bush.position.y -= bush.get_meta("sort_shift")  # compensăm ca imaginea să rămână „plantată"
		container.add_child(bush)
	return container

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

func _langa_copac(pos: Vector2, tex: Texture2D, key: Vector2i) -> bool:
	if _props == null or not _props.has_method("_chunk_trees_raw"):
		return false
	var raza := _raza(tex) + tree_clearance
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for t in _props._chunk_trees_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(t["pos"]) < raza + _raza_trunchi(t["tex"]):
					return true
	return false

func _langa_piatra(pos: Vector2, tex: Texture2D, key: Vector2i) -> bool:
	if _rocks == null or not _rocks.has_method("_chunk_rocks_raw"):
		return false
	var raza := _raza(tex) + rock_clearance
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for r in _rocks._chunk_rocks_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(r["pos"]) < raza + _raza_tex(r["tex"], _scara(_rocks, "rock_scale")):
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

func _langa_structura(pos: Vector2, structuri: Array) -> bool:
	for p in structuri:
		if pos.distance_to(p) < struct_clearance:
			return true
	return false

# Un reglaj numeric al altui generator (`rock_scale`, `tree_scale`, `chunk_size`), citit prin
# `get()` ca să nu depindem de tipul lui. Dacă nodul lipsește sau n-are proprietatea, `implicit`.
func _scara(nod: Node, prop: String, implicit: float = 1.0) -> float:
	if nod == null or nod.get(prop) == null:
		return implicit
	return float(nod.get(prop))

# Cât se întinde tufa în lateral, față de originea nodului (px de lume). Contează conturul OPAC,
# nu canvasul: ambele imagini au 128×128, dar desenul din ele e mai îngust.
func _raza(tex: Texture2D) -> float:
	return _raza_tex(tex, bush_scale)

# Aceeași măsurătoare, dar pentru arta altui generator (care are altă scară).
func _raza_tex(tex: Texture2D, scara: float) -> float:
	return float(GroundShadow.used_rect(tex).size.x) * 0.5 * scara

# Cât se întinde TRUNCHIUL unui copac în lateral (nu coroana — o tufă sub coroană arată firesc,
# una prin trunchi nu). Aceeași socoteală ca în `rocks.gd::_raza_trunchi`.
func _raza_trunchi(tex: Texture2D) -> float:
	var tr := GroundShadow.trunk_rect(tex)
	var mijloc := float(tex.get_width()) * 0.5
	var centru_trunchi := float(tr.position.x) + float(tr.size.x) * 0.5 - mijloc
	return (absf(centru_trunchi) + float(tr.size.x) * 0.5) * _scara(_props, "tree_scale")

# Distanța minimă (centru-centru) admisă între două tufe = min_gap_hitboxes × media lățimilor lor.
func _min_dist(a: Texture2D, b: Texture2D) -> float:
	return min_gap_hitboxes * (_raza(a) + _raza(b))

# O tufă e „prea aproape" dacă se suprapune cu una deja acceptată. Departajare stabilă (aceeași
# decizie indiferent de ordinea generării): în același pătrat renunțăm la indicele mai mare;
# față de vecini renunțăm doar dacă vecinul are cheia „mai mică" lexicografic.
func _too_close(me: Dictionary, my_index: int, mine: Array, neighbors: Array) -> bool:
	for j in my_index:
		var other: Dictionary = mine[j]
		if me["pos"].distance_to(other["pos"]) < _min_dist(me["tex"], other["tex"]):
			return true
	var my_key: Vector2i = me["key"]
	for other in neighbors:
		var ok: Vector2i = other["key"]
		var key_smaller := ok.x < my_key.x or (ok.x == my_key.x and ok.y < my_key.y)
		if key_smaller and me["pos"].distance_to(other["pos"]) < _min_dist(me["tex"], other["tex"]):
			return true
	return false

func _make_bush(tex: Texture2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	var h := float(tex.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar
	sprite.scale = Vector2(bush_scale, bush_scale)
	# Originea nodului = „linia de sortare" Y, ridicată la sort_anchor din înălțime, măsurat de la
	# bază → player-ul e acoperit de tufă doar când trece de acel prag spre Nord.
	sprite.offset = Vector2(0, h * (sort_anchor - 0.5))
	body.add_child(sprite)
	if solid:
		var col := CollisionShape2D.new()
		# Dreptunghi (nu cerc turtit), ca la copaci și pietre: un cerc scalat non-uniform devine
		# elipsă, iar motorul de coliziune se strică și te teleportează.
		var shape := RectangleShape2D.new()
		var base_w := float(GroundShadow.used_rect(tex).size.x) * bush_scale * hitbox_factor
		var base_h := base_w * hitbox_vertical
		shape.size = Vector2(base_w, base_h)
		col.shape = shape
		# Cutia stă pe baza tufei: centrată pe ea, cu marginea de jos pe pământ.
		col.position = Vector2(
			GroundShadow.trunk_center_x(tex, sprite, bush_scale),
			GroundShadow.base_y(tex, sprite, bush_scale) - base_h * 0.5 + hitbox_shift_y
		)
		body.add_child(col)
	body.add_child(GroundShadow.make(tex, sprite, bush_scale,
		shadow_alpha, shadow_width, shadow_squash, shadow_shift_y))
	# cât s-a ridicat originea față de bază → compensăm poziția ca imaginea să rămână „plantată"
	body.set_meta("sort_shift", sort_anchor * h * bush_scale)
	return body
