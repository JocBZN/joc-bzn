extends Node2D

# Generatorul statuilor Ender — pe chunk-uri, ca `statues.gd` și `monuments.gd`, dar cu o
# deosebire care e tot rostul lui: MERGE PE DOS față de toate celelalte.
#
# Restul generatoarelor (Props, Rocks, Statues, Portals, Chests, EGTs, Monuments) sunt aprinse în
# lumea normală și STINSE cât ești într-o altă dimensiune — de-aia Ender-ul e o câmpie de stele
# goală (vezi `ender.gd::WORLD_NODES`). Ăsta e invers: stă stins tot timpul și se aprinde numai
# cât `ender.active`. De-aia NU e în `WORLD_NODES`; dacă îl treceai acolo, ar fi făcut exact pe dos
# decât trebuie — statui Ender pe iarbă și niciuna în Ender.
#
# Aprinderea și stingerea le face `ender.gd` (`_set_ender_only`), cu aceeași unealtă cu care le
# stinge pe celelalte: la stingere copiii sunt eliberați și `_loaded` se golește, deci la
# următoarea intrare în Ender lumea se naște din nou, curată.
#
# Determinist, ca frații lui: sămânța vine din cheia chunk-ului, deci aceeași bucată de Ender are
# mereu aceeași statuie. Nu se ferește de nimic — în Ender nu există copaci și pietre de care să
# se ferească, e gol.

const ENDER_STATUE := preload("res://ender_statue.tscn")
const SEED_SALT := 0x5E17   # altă sămânță decât copacii/pietrele/statuile/monumentele

@export var chunk_size: int = 512
@export var load_radius: int = 3
# 6% din chunk-uri. Mai des decât statuia normală (3%) și decât monumentul (1%), fiindcă Ender-ul
# ține 6 minute și e gol: dacă erau la fel de rare, puteai ieși din dimensiune fără să vezi una.
@export var statue_chance: float = 0.06
@export var margin: float = 110.0

var _loaded := {}

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

# Unde e statuia chunk-ului (sau Vector2.INF dacă n-are). Determinist, fără să creeze noduri.
func chunk_statue_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= statue_chance:
		return Vector2.INF
	return Vector2(
		key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
		key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
	)

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_statue_pos(key)
	if pos != Vector2.INF:
		var s := ENDER_STATUE.instantiate()
		s.position = pos
		container.add_child(s)
	return container
