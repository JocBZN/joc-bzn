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
@export var trees_per_chunk: int = 2    # câți copaci (maxim) într-un pătrat
@export var tree_scale: float = 4.5     # cât de mari sunt copacii
@export var hitbox_factor: float = 0.20   # cât de mare e hitbox-ul (fracție din lățimea copacului)
@export var hitbox_vertical: float = 0.8  # înălțimea hitbox-ului față de lățime: 1.0 = pătrat, mai mic = mai scund
@export var hitbox_south: float = 0.0      # modifică DOAR marginea de jos (Sud): pozitiv = coboară mai mult, negativ = urcă
@export var hitbox_west: float = 0.0       # modifică DOAR marginea din stânga (Vest): pozitiv = mai lat spre stânga, negativ = mai îngust
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

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true  # copacii intră în sortarea pe Y (efect de adâncime)
	add_child(container)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)  # determinist: același pătrat → aceiași copaci
	var count := rng.randi_range(0, trees_per_chunk)
	for i in count:
		var tree := _make_tree(rng)
		tree.position = Vector2(
			key.x * chunk_size + rng.randf_range(0.0, chunk_size),
			key.y * chunk_size + rng.randf_range(0.0, chunk_size) - tree.get_meta("sort_shift")
		)
		container.add_child(tree)
	return container

func _make_tree(rng: RandomNumberGenerator) -> StaticBody2D:
	var body := StaticBody2D.new()
	var tex: Texture2D = TREES[rng.randi_range(0, TREES.size() - 1)]
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
	var half_w := tex.get_width() * hitbox_factor * tree_scale  # jumătate din lățime (ca vechea rază)
	var base_h := half_w * 2.0 * hitbox_vertical    # înălțimea de bază (simetrică sus/jos)
	var south_extra := half_w * 2.0 * hitbox_south  # modificăm DOAR latura de jos (Sud)
	var west_extra := half_w * 2.0 * hitbox_west    # modificăm DOAR latura din stânga (Vest)
	shape.size = Vector2(half_w * 2.0 + west_extra, base_h + south_extra)  # lățime × înălțime
	col.shape = shape
	# marginile de Sus și Dreapta rămân pe loc; schimbăm doar Jos și Stânga → deplasăm centrul cu jumătate din fiecare adaos
	col.position = Vector2(-west_extra / 2.0, (sort_anchor - 0.25) * h * tree_scale + south_extra / 2.0)
	body.add_child(col)  # nu mai poți trece prin copac (nici player, nici enemy)
	# cât s-a ridicat originea față de bază → compensăm poziția ca imaginea să rămână „plantată" pe loc
	body.set_meta("sort_shift", sort_anchor * h * tree_scale)
	return body
