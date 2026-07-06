extends Node2D

# Copaci generați procedural în jurul player-ului, la infinit.
# Lumea e împărțită în "chunk-uri" (pătrate). Fiecare chunk își generează copacii
# DETERMINIST (după poziția lui) → același loc are mereu aceiași copaci, chiar
# dacă pleci și te întorci. Chunk-urile depărtate se descarcă automat (performanță).

const TREES := [
	preload("res://harta/trees/spr_tree_1.png"),
	preload("res://harta/trees/spr_tree_2.png"),
	preload("res://harta/trees/spr_tree_3.png"),
	preload("res://harta/trees/spr_tree_4.png"),
	preload("res://harta/trees/spr_tree_5.png"),
	preload("res://harta/trees/spr_tree_6.png"),
	preload("res://harta/trees/spr_tree_7.png"),
	preload("res://harta/trees/spr_tree_8.png"),
	preload("res://harta/trees/spr_tree_9.png"),
	preload("res://harta/trees/spr_tree_10.png"),
	preload("res://harta/trees/spr_tree_11.png"),
	preload("res://harta/trees/spr_tree_12.png"),
	preload("res://harta/trees/spr_tree_13.png"),
	preload("res://harta/trees/spr_tree_14.png"),
	preload("res://harta/trees/spr_tree_15.png"),
	preload("res://harta/trees/spr_tree_16.png"),
]

@export var chunk_size: int = 512       # mărimea unui pătrat de lume (px)
@export var load_radius: int = 3        # câte pătrate în jurul player-ului ținem încărcate
@export var trees_per_chunk: int = 1    # câți copaci (maxim) într-un pătrat (înjumătățit de la 2)
@export var min_gap_hitboxes: float = 2.0  # distanța minimă între copaci, măsurată în „hitbox-uri" (2 = nu se apropie mai mult de 2 hitbox-uri)
@export var tree_scale: float = 4.5     # cât de mari sunt copacii
@export var hitbox_factor: float = 0.20   # cât de mare e hitbox-ul (fracție din lățimea copacului)
@export var hitbox_vertical: float = 0.8  # înălțimea hitbox-ului față de lățime: 1.0 = pătrat, mai mic = mai scund
# Cele 4 laturi — fiecare mișcă DOAR marginea ei (pozitiv = extinde afară, negativ = trage înăuntru):
@export var hitbox_north: float = 0.0      # marginea de SUS (Nord)
@export var hitbox_south: float = 0.0      # marginea de JOS (Sud)
@export var hitbox_east: float = 0.0       # marginea din DREAPTA (Est)
@export var hitbox_west: float = 0.0       # marginea din STÂNGA (Vest)
@export var sort_anchor: float = 0.35     # de la ce % din înălțime (măsurat de la bază) copacul începe să te acopere

var _loaded := {}  # Vector2i (chunk) -> Node2D (containerul cu copacii lui)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
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

# Pozițiile (și textura) copacilor unui pătrat, calculate DETERMINIST din cheia lui,
# FĂRĂ a crea noduri. Folosit atât la construirea pătratului, cât și la verificarea
# distanței față de copacii din pătratele vecine. Ordinea apelurilor rng trebuie să fie
# identică cu cea de la construire (întâi textura, apoi x, apoi y) ca pozițiile să coincidă.
func _chunk_trees_raw(key: Vector2i) -> Array:
	if BiomeMap.is_desert_chunk(key.x, key.y):
		return []  # în deșert NU cresc copaci
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)  # determinist: același pătrat → aceiași copaci
	var count := rng.randi_range(0, trees_per_chunk)
	var out := []
	for i in count:
		var tex: Texture2D = TREES[rng.randi_range(0, TREES.size() - 1)]
		var pos := Vector2(
			key.x * chunk_size + rng.randf_range(0.0, chunk_size),
			key.y * chunk_size + rng.randf_range(0.0, chunk_size)
		)
		out.append({"pos": pos, "tex": tex, "key": key})
	return out

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true  # copacii intră în sortarea pe Y (efect de adâncime)
	add_child(container)
	var my_trees := _chunk_trees_raw(key)
	# Pozițiile brute ale copacilor din cele 8 pătrate vecine (pentru verificarea distanței).
	var neighbors := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			neighbors.append_array(_chunk_trees_raw(Vector2i(key.x + dx, key.y + dy)))
	for i in my_trees.size():
		if _too_close(my_trees[i], i, my_trees, neighbors):
			continue  # prea aproape de alt copac → nu-l plantăm
		var me: Dictionary = my_trees[i]
		var tree := _make_tree(me["tex"])
		tree.position = me["pos"]
		tree.position.y -= tree.get_meta("sort_shift")  # compensăm ca imaginea să rămână „plantată"
		container.add_child(tree)
	return container

# Distanța minimă (centru-centru) admisă între doi copaci = min_gap_hitboxes × media lățimilor lor de hitbox.
func _min_dist(tex_a: Texture2D, tex_b: Texture2D) -> float:
	var wa := tex_a.get_width() * hitbox_factor * tree_scale * 2.0
	var wb := tex_b.get_width() * hitbox_factor * tree_scale * 2.0
	return min_gap_hitboxes * (wa + wb) * 0.5

# Un copac e „prea aproape" dacă se suprapune cu unul deja acceptat. Regula de departajare
# (ca decizia să fie aceeași indiferent de ordinea în care se generează pătratele):
#   - în același pătrat: renunțăm la cel cu indice mai mare;
#   - față de vecini: renunțăm doar dacă vecinul are cheia „mai mică" lexicografic.
func _too_close(me: Dictionary, my_index: int, my_trees: Array, neighbors: Array) -> bool:
	for j in my_index:
		var other: Dictionary = my_trees[j]
		if me["pos"].distance_to(other["pos"]) < _min_dist(me["tex"], other["tex"]):
			return true
	var my_key: Vector2i = me["key"]
	for other in neighbors:
		var ok: Vector2i = other["key"]
		var key_smaller := ok.x < my_key.x or (ok.x == my_key.x and ok.y < my_key.y)
		if key_smaller and me["pos"].distance_to(other["pos"]) < _min_dist(me["tex"], other["tex"]):
			return true
	return false

func _make_tree(tex: Texture2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	var h := float(tex.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar când e mărit
	sprite.scale = Vector2(tree_scale, tree_scale)
	# Originea nodului = "linia de sortare" Y-sort, ridicată la sort_anchor (35%) din înălțime,
	# măsurat de la baza copacului → player-ul e acoperit de coroană doar când trece de acel prag spre Nord.
	sprite.offset = Vector2(0, h * (sort_anchor - 0.5))
	body.add_child(sprite)
	var col := CollisionShape2D.new()
	# Dreptunghi (nu cerc turtit): are lățime/înălțime independente, iar fizica îl tratează
	# corect. Un cerc scalat non-uniform devine elipsă → motorul de coliziune se strică și te teleportează.
	var shape := RectangleShape2D.new()
	var base_w := tex.get_width() * hitbox_factor * tree_scale * 2.0  # lățimea de bază (ca vechea rază × 2)
	var base_h := base_w * hitbox_vertical          # înălțimea de bază (simetrică sus/jos)
	# Fiecare latură = fracție din lățimea de bază. Pozitiv extinde marginea AFARĂ, negativ o trage înăuntru.
	var north_extra := base_w * hitbox_north  # DOAR marginea de sus (Nord)
	var south_extra := base_w * hitbox_south  # DOAR marginea de jos (Sud)
	var east_extra := base_w * hitbox_east    # DOAR marginea din dreapta (Est)
	var west_extra := base_w * hitbox_west    # DOAR marginea din stânga (Vest)
	# Mărimea crește cu adaosul fiecărei perechi de laturi opuse.
	shape.size = Vector2(base_w + west_extra + east_extra, base_h + north_extra + south_extra)
	col.shape = shape
	# Fiecare latură își mișcă doar marginea ei → centrul se deplasează cu jumătate din diferența laturilor opuse.
	# +x = spre Est, +y = spre Sud (jos). Nord/Vest trag înapoi (semn minus).
	var center_x := (east_extra - west_extra) / 2.0
	var center_y := (south_extra - north_extra) / 2.0
	col.position = Vector2(center_x, (sort_anchor - 0.25) * h * tree_scale + center_y)
	body.add_child(col)  # nu mai poți trece prin copac (nici player, nici enemy)
	# cât s-a ridicat originea față de bază → compensăm poziția ca imaginea să rămână „plantată" pe loc
	body.set_meta("sort_shift", sort_anchor * h * tree_scale)
	return body
