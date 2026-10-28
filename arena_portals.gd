extends Node2D

# PORTALURILE ARENEI — al cincilea generator de uși, copiat după `prison_gates.gd` (citește-l
# întâi pe el, comentariile lungi de acolo sunt valabile și aici).
#
# Cerut de Răzvan pe 2026-10-28, când a cerut lupta cu toți trei boșii: portalul apare „pe hartă,
# ca celelalte". Deci lanțul are acum cinci verigi:
#      portal Nether → (Saratalin) → fântână Ender → (Celesto) → poartă de castel
#      → (SIR JOHN) → PORTAL DE ARENĂ → (toți trei) → YOU WIN!
#
# Pornește STINS și îl aprinde `prison.gd::boss_invins()`, în clipa în care cade Sir John — din
# același motiv pentru care porțile castelului se aprind la moartea lui Celesto, nu la ieșire (vezi
# „De ce la MOARTEA lui Celesto" în `prison_gates.gd`). Se oprește de tot la ieșirea victorioasă
# din arenă (`arena.gd::_inchide_portalul`).
#
# Sămânța e a LUI (`SEED_SALT`), deci portalurile nu răsar unde stăteau porțile sau fântânile.
# Arta e `portal_arena.tscn`: arcada Nether-ului cu vâltoarea roșie.

const PORTAL := preload("res://portal_arena.tscn")
const SEED_SALT := 0xA7E3

# 1.5% din chunk-uri, ca toate celelalte uși.
@export var chunk_size: int = 512
@export var portal_chance: float = 0.015
@export var load_radius: int = 3
@export var margin: float = 140.0
@export var min_dist_tree: float = 220.0
@export var min_dist_rock: float = 180.0
@export var min_dist_statue: float = 260.0
@export var min_dist_usa: float = 320.0     # de o poartă de castel
@export var tries: int = 12

var _loaded := {}

# Aprins de `prison.gd::boss_invins()` (cade Sir John). Cât e `false`, `_process` iese din prima linie.
var activ := false
# Gata pe rundă: ai ieșit învingător din arenă (`arena.gd`).
var oprit := false

var _props: Node2D = null
var _rocks: Node2D = null
var _statues: Node2D = null
var _porti: Node2D = null      # PrisonGates — ca să nu ne punem peste o poartă de castel

func _ready() -> void:
	var p := get_parent()
	if p != null:
		_props = p.get_node_or_null("Props") as Node2D
		_rocks = p.get_node_or_null("Rocks") as Node2D
		_statues = p.get_node_or_null("Statues") as Node2D
		_porti = p.get_node_or_null("PrisonGates") as Node2D

func _process(_delta: float) -> void:
	if not activ or oprit:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var pc := _chunk_of(player.global_position)
	for cx in range(pc.x - load_radius, pc.x + load_radius + 1):
		for cy in range(pc.y - load_radius, pc.y + load_radius + 1):
			var key := Vector2i(cx, cy)
			if not _loaded.has(key):
				_loaded[key] = _build_chunk(key)
	for key in _loaded.keys():
		if absi(key.x - pc.x) > load_radius or absi(key.y - pc.y) > load_radius:
			_loaded[key].queue_free()
			_loaded.erase(key)

func _chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(chunk_size)), floori(pos.y / float(chunk_size)))

# Unde e portalul chunk-ului (dacă are unul)? Determinist, fără noduri. Vector2.INF = n-are.
func chunk_portal_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= portal_chance:
		return Vector2.INF
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key) and not _langa_piatra(p, key) \
				and not _langa_statuie(p, key) and not _langa_poarta(p, key):
			return p
	return Vector2.INF

func _langa_copac(pos: Vector2, key: Vector2i) -> bool:
	if _props == null or not _props.has_method("_chunk_trees_raw"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for t in _props._chunk_trees_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(t["pos"]) < min_dist_tree:
					return true
	return false

func _langa_piatra(pos: Vector2, key: Vector2i) -> bool:
	if _rocks == null or not _rocks.has_method("_chunk_rocks_raw"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for r in _rocks._chunk_rocks_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(r["pos"]) < min_dist_rock:
					return true
	return false

func _langa_statuie(pos: Vector2, key: Vector2i) -> bool:
	if _statues == null or not _statues.has_method("chunk_statue_pos"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var s: Vector2 = _statues.chunk_statue_pos(Vector2i(key.x + dx, key.y + dy))
			if s != Vector2.INF and pos.distance_to(s) < min_dist_statue:
				return true
	return false

# De obicei porțile castelului sunt deja oprite când ne aprindem noi (ieșirea victorioasă din castel
# le stinge), dar dacă mori acolo după Sir John și te întorci prin Limbo, rămân amândouă pe hartă.
func _langa_poarta(pos: Vector2, key: Vector2i) -> bool:
	if _porti == null or not _porti.has_method("chunk_gate_pos"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var q: Vector2 = _porti.chunk_gate_pos(Vector2i(key.x + dx, key.y + dy))
			if q != Vector2.INF and pos.distance_to(q) < min_dist_usa:
				return true
	return false

# SIR JOHN A CĂZUT → de aici încolo lumea scoate portaluri de arenă.
func porneste() -> void:
	if oprit:
		return
	activ = true

func opreste() -> void:
	oprit = true
	_goleste()

func _goleste() -> void:
	for key in _loaded.keys():
		if is_instance_valid(_loaded[key]):
			_loaded[key].queue_free()
	_loaded.clear()
	_cache_busola.clear()

# BUSOLA (Third Eye): cel mai apropiat portal, din chunk-uri, nu din noduri — vezi
# `prison_gates.gd::cel_mai_apropiat`. Vector2.INF cât suntem stinși sau consumați.
const SCAN_CHUNKS := 8

var _cache_busola := {}

func cel_mai_apropiat(de_la: Vector2) -> Vector2:
	if not activ or oprit:
		return Vector2.INF
	var pc := _chunk_of(de_la)
	var best := Vector2.INF
	var best_d := INF
	for cx in range(pc.x - SCAN_CHUNKS, pc.x + SCAN_CHUNKS + 1):
		for cy in range(pc.y - SCAN_CHUNKS, pc.y + SCAN_CHUNKS + 1):
			var key := Vector2i(cx, cy)
			var p: Vector2 = Vector2.INF
			if _cache_busola.has(key):
				p = _cache_busola[key]
			else:
				p = chunk_portal_pos(key)
				_cache_busola[key] = p
			if p == Vector2.INF:
				continue
			var d := de_la.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = p
	return best

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_portal_pos(key)
	if pos != Vector2.INF:
		var s: Node2D = PORTAL.instantiate()
		s.position = pos
		container.add_child(s)
	return container
