extends Node2D

# Generare procedurală de obiecte (copaci + pietre) în jurul player-ului, la infinit.
# Lumea = chunk-uri (pătrate). Fiecare chunk generează DETERMINIST aceleași obiecte
# (după poziția lui) → un loc are mereu aceleași obiecte. Chunk-urile depărtate se descarcă.
# Încarcă AUTOMAT tot ce e în folderele de mai jos și le folosește egal (copaci + pietre, cu umbră inclusă).

const TREES_DIR := "res://trees/PNG/Assets_separately/Trees_texture_shadow/"
const ROCKS_DIR := "res://stones/PNG/Objects_separately/"

@export_group("Lume")
@export var chunk_size: int = 512        # mărimea unui pătrat de lume (px)
@export var load_radius: int = 3         # câte pătrate în jur ținem încărcate
@export var props_per_chunk: int = 3     # câte obiecte (maxim) într-un pătrat
@export_range(0.0, 1.0) var tree_chance: float = 0.5  # 0.5 = jumate copaci, jumate pietre

@export_group("Mărimi")
@export var tree_scale: float = 4.0      # cât de mari sunt copacii (dublat)
@export var rock_scale: float = 2.5      # cât de mari sunt pietrele

# HITBOX = dreptunghi, ca fracție din mărimea obiectului (reglezi din Inspector):
#   *_hitbox_size   = (lățime, înălțime) ca fracție. 0.3 = 30% din obiect.
#   *_hitbox_offset = (x, y). x mută stânga/dreapta; y RIDICĂ hitbox-ul de la bază în sus (0.2 = 20% din înălțime).
@export_group("Hitbox copaci (dreptunghi)")
@export var tree_hitbox_size := Vector2(0.30, 0.15)
@export var tree_hitbox_offset := Vector2(0.0, 0.20)
@export_group("Hitbox pietre (dreptunghi)")
@export var rock_hitbox_size := Vector2(0.60, 0.35)
@export var rock_hitbox_offset := Vector2(0.0, 0.15)

var _trees: Array[Texture2D] = []
var _rocks: Array[Texture2D] = []
var _loaded := {}

func _ready() -> void:
	_trees = _load_dir(TREES_DIR)
	_rocks = _load_dir(ROCKS_DIR, "shadow")  # sari peste umbrele separate și versiunile _no_shadow
	print("Props încărcate — copaci: %d, pietre: %d" % [_trees.size(), _rocks.size()])

# Încarcă toate imaginile .png dintr-un folder (opțional sărind peste cele cu un cuvânt în nume).
func _load_dir(path: String, skip_contains := "") -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Props: nu găsesc folderul " + path)
		return out
	for f in dir.get_files():
		var low := f.to_lower()
		if not low.ends_with(".png"):
			continue
		if skip_contains != "" and low.contains(skip_contains):
			continue
		var tex := load(path + f) as Texture2D
		if tex != null:
			out.append(tex)
	return out

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

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true  # obiectele intră în sortarea pe Y (adâncime)
	add_child(container)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)  # determinist: același pătrat → aceleași obiecte
	var count := rng.randi_range(0, props_per_chunk)
	for i in count:
		var prop := _make_prop(rng)
		if prop != null:
			prop.position = Vector2(
				key.x * chunk_size + rng.randf_range(0.0, chunk_size),
				key.y * chunk_size + rng.randf_range(0.0, chunk_size)
			)
			container.add_child(prop)
	return container

func _make_prop(rng: RandomNumberGenerator) -> StaticBody2D:
	var is_tree := rng.randf() < tree_chance
	var pool: Array[Texture2D] = _trees if is_tree else _rocks
	if pool.is_empty():
		pool = _rocks if is_tree else _trees   # dacă un folder lipsește, folosește-l pe celălalt
		is_tree = not is_tree
	if pool.is_empty():
		return null
	var tex: Texture2D = pool[rng.randi_range(0, pool.size() - 1)]
	var s: float = tree_scale if is_tree else rock_scale
	var w := tex.get_width() * s    # lățimea pe ecran
	var h := tex.get_height() * s   # înălțimea pe ecran

	var body := StaticBody2D.new()
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar când e mărit
	sprite.scale = Vector2(s, s)
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)  # baza obiectului = originea nodului (jos-centru)
	body.add_child(sprite)

	# Hitbox dreptunghiular, plasat lângă baza obiectului. Totul e reglabil din Inspector.
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var hb_size: Vector2 = tree_hitbox_size if is_tree else rock_hitbox_size
	var hb_off: Vector2 = tree_hitbox_offset if is_tree else rock_hitbox_offset
	shape.size = Vector2(w * hb_size.x, h * hb_size.y)
	col.position = Vector2(w * hb_off.x, -h * hb_off.y)  # y negativ = urcă de la bază în sus
	col.shape = shape
	body.add_child(col)
	return body
