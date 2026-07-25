extends Node2D

# Portaluri generate procedural, exact ca statuile (`statues.gd`): lumea e împărțită în
# chunk-uri, fiecare chunk are `portal_chance` să conțină UN SINGUR portal.
#
# Determinist: sămânța vine din cheia chunk-ului → același loc are mereu același portal,
# chiar dacă pleci și te întorci.
#
# Diferența față de statui: `portal_chance` e 1.5% (față de 3% la statui), deci portalul
# apare de DOUĂ ORI mai rar. Vrei să-l vezi mai des/mai rar? Schimbi doar cifra aia.

const PORTAL := preload("res://portal.tscn")
const SEED_SALT := 0x9C4E  # sămânță proprie, ca să nu iasă la fel ca la statui/copaci/pietre

@export var chunk_size: int = 512
@export var load_radius: int = 3
@export var portal_chance: float = 0.015    # 1.5% din chunk-uri au un portal (statuile: 3%)
@export var margin: float = 140.0           # cât de departe stă de marginea chunk-ului (portalul e lat)
@export var min_dist_tree: float = 220.0    # cât de departe stă de un copac
@export var min_dist_rock: float = 180.0    # cât de departe stă de o piatră
@export var min_dist_statue: float = 260.0  # cât de departe stă de o statuie (să nu se încalece)
@export var tries: int = 12                 # câte poziții încearcă până renunță la fereală

var _loaded := {}
var _props: Node2D = null     # nodul Props (copacii)
var _rocks: Node2D = null     # nodul Rocks (pietrele)
var _statues: Node2D = null   # nodul Statues (ca să nu punem portalul peste o statuie)

func _ready() -> void:
	# frații din main.tscn — îi folosim ca să nu punem portaluri peste ei
	var p := get_parent()
	if p != null:
		_props = p.get_node_or_null("Props") as Node2D
		_rocks = p.get_node_or_null("Rocks") as Node2D
		_statues = p.get_node_or_null("Statues") as Node2D

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

# Unde e portalul chunk-ului (dacă are unul)? Calculat DETERMINIST, fără a crea noduri.
# Întoarce Vector2.INF dacă chunk-ul n-are portal.
func chunk_portal_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= portal_chance:
		return Vector2.INF          # chunk-ul ăsta n-are portal
	# încercăm câteva poziții până găsim una liberă
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key) and not _langa_piatra(p, key) and not _langa_statuie(p, key):
			return p
	# Chunk prea aglomerat → renunțăm la portal aici, mai bine decât unul înfipt într-un copac.
	return Vector2.INF

# E poziția prea aproape de vreun copac din chunk-ul ăsta sau din cele 8 vecine?
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

# Statuile își știu poziția fără să existe ca noduri (`chunk_statue_pos`), deci putem
# întreba și pentru chunk-urile vecine, chiar dacă statuia de acolo nu e încă încărcată.
func _langa_statuie(pos: Vector2, key: Vector2i) -> bool:
	if _statues == null or not _statues.has_method("chunk_statue_pos"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var s: Vector2 = _statues.chunk_statue_pos(Vector2i(key.x + dx, key.y + dy))
			if s != Vector2.INF and pos.distance_to(s) < min_dist_statue:
				return true
	return false

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_portal_pos(key)
	if pos != Vector2.INF:
		var s := PORTAL.instantiate()
		s.position = pos
		container.add_child(s)
	return container
