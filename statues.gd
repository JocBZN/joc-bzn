extends Node2D

# Statui generate procedural, ca pietrele și copacii: lumea e împărțită în chunk-uri,
# fiecare chunk are `statue_chance` (10%) să conțină O SINGURĂ statuie.
#
# Determinist: sămânța vine din cheia chunk-ului → același loc are mereu aceeași statuie,
# chiar dacă pleci și te întorci. (Ce diferă de la o rundă la alta e PUNCTUL DE START al
# player-ului, ales aleator în `spawner.gd` — deci vezi altă bucată de lume de fiecare dată.)

const STATUE := preload("res://statue.tscn")
const SEED_SALT := 0x57A7  # ca să nu iasă aceleași numere ca la copaci/pietre pe același chunk

@export var chunk_size: int = 512
@export var load_radius: int = 3
@export var statue_chance: float = 0.03   # 3% din chunk-uri au o statuie
@export var margin: float = 110.0         # cât de departe stă de marginea chunk-ului
@export var min_dist_tree: float = 190.0  # cât de departe stă de un copac
@export var tries: int = 12               # câte poziții încearcă până renunță la fereală

var _loaded := {}
var _props: Node2D = null   # nodul Props, ca să știm unde sunt copacii

func _ready() -> void:
	# fratele „Props" din main.tscn — îl folosim ca să nu punem statui peste copaci
	var p := get_parent()
	if p != null:
		_props = p.get_node_or_null("Props") as Node2D

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

# Unde e statuia chunk-ului (dacă are una)? Calculat DETERMINIST, fără a crea noduri.
# Întoarce Vector2.INF dacă chunk-ul n-are statuie.
func chunk_statue_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= statue_chance:
		return Vector2.INF          # chunk-ul ăsta n-are statuie
	# încercăm câteva poziții până găsim una care nu cade peste un copac
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key):
			return p
	# Chunk prea aglomerat de copaci → renunțăm la statuie aici. Preferăm asta în locul unei
	# statui înfipte într-un copac. Costă ~0.4% din cele 10% (măsurat pe ~1000 de statui).
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

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_statue_pos(key)
	if pos != Vector2.INF:
		var s := STATUE.instantiate()
		s.position = pos
		container.add_child(s)
	return container
