extends Node2D

# Monumente generate procedural, exact ca statuile (`statues.gd`) și portalurile
# (`portals.gd`): lumea e împărțită în chunk-uri, fiecare chunk are `monument_chance` să
# conțină UN SINGUR monument, la o poziție calculată determinist din cheia chunk-ului.
# Deci același loc are mereu același monument, chiar dacă pleci și te întorci.
#
# `monument_chance` e 1% — sub statuie (3%) și sub portal (1.5%). E cea mai grasă răsplată
# din lume (100 de inamici cu 2× XP) și se deschide abia după Celesto, deci n-are rost să
# calci pe câte unul la fiecare doi pași.
#
# ⚠️ SINGURA diferență de fond față de `statues.gd`: monumentele FOLOSITE se țin minte
# (`_folosite`). Fără asta, un monument trezit s-ar întoarce de fiecare dată când te
# îndepărtezi de el mai mult de `load_radius` chunk-uri și revii — chunk-ul se descarcă și se
# regenerează de la zero — adică ai putea scoate hoarda de 100 la nesfârșit, din același loc.

const MONUMENT := preload("res://monument.tscn")
const SEED_SALT := 0x3B10  # sămânță proprie, ca să nu iasă în aceleași locuri ca statuile/portalurile

@export var chunk_size: int = 512
@export var load_radius: int = 3
@export var monument_chance: float = 0.01   # 1% din chunk-uri au un monument
@export var margin: float = 120.0           # cât de departe stă de marginea chunk-ului
@export var min_dist_tree: float = 200.0    # cât de departe stă de un copac
@export var min_dist_rock: float = 160.0    # cât de departe stă de o piatră
@export var min_dist_statue: float = 280.0  # cât de departe stă de o statuie (să nu se încalece)
@export var tries: int = 12                 # câte poziții încearcă până renunță la fereală

var _loaded := {}
var _folosite := {}          # cheile chunk-urilor al căror monument a fost deja trezit
var _props: Node2D = null
var _rocks: Node2D = null
var _statues: Node2D = null

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

# Chemată de `monument.gd` când monumentul e trezit: chunk-ul lui nu mai naște nimic.
# Primește poziția din lume (monumentul nu-și știe cheia), noi o traducem în cheie.
func marcheaza_folosit(pos: Vector2) -> void:
	_folosite[_chunk_of(pos)] = true

# Unde e monumentul chunk-ului (dacă are unul)? Calculat DETERMINIST, fără a crea noduri.
# Întoarce Vector2.INF dacă chunk-ul n-are monument.
func chunk_monument_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= monument_chance:
		return Vector2.INF
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key) and not _langa_piatra(p, key) and not _langa_statuie(p, key):
			return p
	# Chunk prea aglomerat → renunțăm la monument aici, ca la statui.
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

# Statuile își știu poziția determinist (`chunk_statue_pos`), fără să creeze noduri — deci
# putem întreba și pentru chunk-uri care nu-s încărcate încă.
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
	if _folosite.has(key):
		return container          # monumentul de aici a fost deja trezit în runda asta
	var pos := chunk_monument_pos(key)
	if pos != Vector2.INF:
		var m := MONUMENT.instantiate()
		m.position = pos
		container.add_child(m)
	return container
