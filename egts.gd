extends Node2D

# Aparate EGT generate procedural, exact ca statuile (`statues.gd`): lumea e împărțită în
# chunk-uri, iar fiecare chunk are `egt_chance` să conțină UN SINGUR aparat.
#
# Determinist: sămânța vine din cheia chunk-ului → același loc are mereu același aparat, chiar
# dacă pleci și te întorci. Ce diferă de la o rundă la alta e PUNCTUL DE START al player-ului
# (ales aleator în `spawner.gd`), deci vezi altă bucată de lume de fiecare dată.
#
# Aparatul se ferește de copaci, de pietre ȘI de statuia din același chunk — altfel două
# generatoare independente pot să pună două obiecte mari exact în același loc.

const EGT := preload("res://egt.tscn")
const SEED_SALT := 0xE67A  # altul decât la copaci/pietre/statui, ca să nu iasă aceleași numere

@export var chunk_size: int = 512
@export var load_radius: int = 3
@export var egt_chance: float = 0.02      # 2% din chunk-uri au un aparat (mai rar decât statuile)
@export var margin: float = 120.0         # cât de departe stă de marginea chunk-ului
@export var min_dist_tree: float = 190.0  # cât de departe stă de un copac
@export var min_dist_rock: float = 150.0  # cât de departe stă de o piatră
@export var min_dist_statue: float = 220.0  # cât de departe stă de statuia chunk-ului
@export var tries: int = 12               # câte poziții încearcă până renunță la fereală

var _loaded := {}
var _props: Node2D = null     # nodul Props, ca să știm unde sunt copacii
var _rocks: Node2D = null     # nodul Rocks
var _statues: Node2D = null   # nodul Statues

func _ready() -> void:
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

# Unde e aparatul chunk-ului (dacă are unul)? Vector2.INF = chunk-ul n-are aparat.
func chunk_egt_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= egt_chance:
		return Vector2.INF
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key) and not _langa_piatra(p, key) and not _langa_statuie(p, key):
			return p
	# Chunk prea aglomerat → renunțăm la aparat aici. Preferăm asta unui EGT înfipt într-un copac.
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

# Statuile își calculează poziția determinist, fără să creeze noduri (`chunk_statue_pos`),
# deci putem întreba unde ar cădea statuia și să ne ferim de ea chiar dacă nu s-a născut încă.
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
	var pos := chunk_egt_pos(key)
	if pos != Vector2.INF:
		var e := EGT.instantiate()
		e.position = pos
		container.add_child(e)
	return container
