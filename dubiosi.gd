extends Node2D

# DUBIOȘII generați procedural, după același tipar ca oamenii de Alba-Neagra (`albas.gd`): lumea
# e împărțită în chunk-uri, iar fiecare chunk are `dubios_chance` să conțină UNUL.
#
# Determinist: sămânța vine din cheia chunk-ului → același loc are mereu același om, chiar dacă
# pleci și te întorci. Ce diferă de la o rundă la alta e PUNCTUL DE START al player-ului.
#
# Se ferește de copaci, de pietre, de statuia chunk-ului, de aparatul EGT ȘI de omul de
# Alba-Neagra — altfel generatoare care nu știu unele de altele pot pune două lucruri mari exact
# în același loc.
#
# ⚠️ Spre deosebire de `albas.gd`, aici NU există listă de „folosiți": dubiosul nu face nimic
# (vezi `dubiosu.gd`), deci nu are cum să se consume. Dacă vreodată primește o treabă care se
# consumă, copiază de la `albas.gd` `_folosite` + `marcheaza_folosit` + filtrul din `_build_chunk`
# — fără ele ar reveni întreg de fiecare dată când chunk-ul se descarcă și se regenerează.

const DUBIOSU := preload("res://dubiosu.tscn")
const SEED_SALT := 0xD0B1  # altul decât la copaci/pietre/statui/EGT/Alba, ca să nu iasă aceleași numere

@export var chunk_size: int = 512
@export var load_radius: int = 3
@export var dubios_chance: float = 0.02   # 2% din chunk-uri au unul (cât oamenii de Alba-Neagra)
@export var margin: float = 120.0         # cât de departe stă de marginea chunk-ului
@export var min_dist_tree: float = 190.0
@export var min_dist_rock: float = 150.0
@export var min_dist_statue: float = 220.0
@export var min_dist_egt: float = 260.0
@export var min_dist_alba: float = 260.0  # nu stă lipit de omul cu paharele
@export var tries: int = 12               # câte poziții încearcă până renunță la fereală

var _loaded := {}
var _props: Node2D = null
var _rocks: Node2D = null
var _statues: Node2D = null
var _egts: Node2D = null
var _albas: Node2D = null

func _ready() -> void:
	var p := get_parent()
	if p != null:
		_props = p.get_node_or_null("Props") as Node2D
		_rocks = p.get_node_or_null("Rocks") as Node2D
		_statues = p.get_node_or_null("Statues") as Node2D
		_egts = p.get_node_or_null("EGTs") as Node2D
		_albas = p.get_node_or_null("AlbaNeagras") as Node2D

func _process(_delta: float) -> void:
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

# Unde e dubiosul chunk-ului (dacă are unul)? Vector2.INF = chunk-ul n-are.
func chunk_dubios_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= dubios_chance:
		return Vector2.INF
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key) and not _langa_piatra(p, key) \
				and not _langa_statuie(p, key) and not _langa_egt(p, key) \
				and not _langa_alba(p, key):
			return p
	# Chunk prea aglomerat → renunțăm. Preferăm asta unui om înfipt într-un copac.
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

# Ca la statui: generatoarele astea își pot spune poziția fără să existe încă nodul, deci ne putem
# feri de un aparat sau de un om care nici măcar nu s-a născut.
func _langa_egt(pos: Vector2, key: Vector2i) -> bool:
	if _egts == null or not _egts.has_method("chunk_egt_pos"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var e: Vector2 = _egts.chunk_egt_pos(Vector2i(key.x + dx, key.y + dy))
			if e != Vector2.INF and pos.distance_to(e) < min_dist_egt:
				return true
	return false

func _langa_alba(pos: Vector2, key: Vector2i) -> bool:
	if _albas == null or not _albas.has_method("chunk_alba_pos"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var a: Vector2 = _albas.chunk_alba_pos(Vector2i(key.x + dx, key.y + dy))
			if a != Vector2.INF and pos.distance_to(a) < min_dist_alba:
				return true
	return false

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_dubios_pos(key)
	if pos != Vector2.INF:
		var d := DUBIOSU.instantiate()
		d.position = pos
		container.add_child(d)
	return container
