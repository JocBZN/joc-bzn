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
@export var hitbox_factor: float = 0.35 # cât de mare e hitbox-ul (fracție din lățimea copacului)

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
	add_child(container)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)  # determinist: același pătrat → aceiași copaci
	var count := rng.randi_range(0, trees_per_chunk)
	for i in count:
		var tree := _make_tree(rng)
		tree.position = Vector2(
			key.x * chunk_size + rng.randf_range(0.0, chunk_size),
			key.y * chunk_size + rng.randf_range(0.0, chunk_size)
		)
		container.add_child(tree)
	return container

func _make_tree(rng: RandomNumberGenerator) -> StaticBody2D:
	var body := StaticBody2D.new()
	var tex: Texture2D = TREES[rng.randi_range(0, TREES.size() - 1)]
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar când e mărit
	sprite.scale = Vector2(tree_scale, tree_scale)
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)  # așează copacul cu baza pe poziția lui
	body.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = tex.get_width() * hitbox_factor * tree_scale  # hitbox mare = copac solid
	col.shape = shape
	col.position = Vector2(0, -tex.get_height() * 0.25 * tree_scale)  # centrat pe trunchi + coroană
	body.add_child(col)  # nu mai poți trece prin copac (nici player, nici enemy)
	return body
