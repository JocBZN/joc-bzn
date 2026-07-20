extends Node2D

# Pietre (props de mediu) generate procedural în jurul player-ului, la infinit —
# EXACT ca sistemul de copaci (props.gd), dar independent și cu propriile reglaje.
# Imaginile se încarcă la RULARE din folderul de mai jos (nu preload), ca să nu crape
# dacă adaugi un PNG nou care încă n-a fost importat de Godot.

const ROCKS_DIR := "res://stones/"
const SEED_SALT := 0x51ED  # sămânță diferită de a copacilor → pietrele nu urmează același tipar

@export var chunk_size: int = 512          # mărimea unui pătrat de lume (px)
@export var load_radius: int = 3           # câte pătrate în jurul player-ului ținem încărcate
@export var rocks_per_chunk: int = 1       # câte pietre (maxim) într-un pătrat
@export var min_gap_hitboxes: float = 2.0  # distanța minimă între pietre, în „hitbox-uri"
@export var rock_scale: float = 2.5        # cât de mari sunt pietrele
@export var hitbox_factor: float = 0.35    # cât de mare e hitbox-ul (fracție din lățimea pietrei)
@export var hitbox_vertical: float = 0.6   # înălțimea hitbox-ului față de lățime: 1.0 = pătrat, mai mic = mai scund
# Cele 4 laturi — fiecare mișcă DOAR marginea ei (pozitiv = extinde afară, negativ = trage înăuntru):
@export var hitbox_north: float = 0.0      # marginea de SUS (Nord)
@export var hitbox_south: float = 0.0      # marginea de JOS (Sud)
@export var hitbox_east: float = 0.0       # marginea din DREAPTA (Est)
@export var hitbox_west: float = 0.0       # marginea din STÂNGA (Vest)
@export var sort_anchor: float = 0.35      # de la ce % din înălțime (măsurat de la bază) piatra începe să te acopere

var _rocks: Array[Texture2D] = []
var _loaded := {}  # Vector2i (chunk) -> Node2D (containerul cu pietrele lui)

func _ready() -> void:
	_rocks = _load_dir(ROCKS_DIR)
	print("Pietre încărcate: %d" % _rocks.size())

# Încarcă toate imaginile .png dintr-un folder, în ordine STABILĂ (sortată) → determinist.
func _load_dir(path: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Rocks: nu găsesc folderul " + path)
		return out
	var files := dir.get_files()
	files.sort()  # ordine fixă → aceleași pietre în același loc de fiecare dată
	for f in files:
		if not f.to_lower().ends_with(".png"):
			continue
		var tex := load(path + f) as Texture2D
		if tex != null:
			out.append(tex)
	return out

func _process(_delta: float) -> void:
	if _rocks.is_empty():
		return
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

# Pozițiile (și textura) pietrelor unui pătrat, calculate DETERMINIST din cheia lui, fără noduri.
# Ordinea apelurilor rng (întâi textura, apoi x, apoi y) trebuie să fie ca la construire.
func _chunk_rocks_raw(key: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	var count := rng.randi_range(0, rocks_per_chunk)
	var out := []
	for i in count:
		var tex: Texture2D = _rocks[rng.randi_range(0, _rocks.size() - 1)]
		var pos := Vector2(
			key.x * chunk_size + rng.randf_range(0.0, chunk_size),
			key.y * chunk_size + rng.randf_range(0.0, chunk_size)
		)
		# Verificare PE POZIȚIE, exact ca la copaci (props.gd) — nu pe chunk. Cu verificarea
		# veche pe chunk (`is_desert_chunk`) rămânea o fâșie pe gradientul de la marginea
		# deșertului unde intrau și pietre, și cactuși → pietre înfipte în cactuși.
		if BiomeMap.desertness_at_chunk(pos / float(chunk_size)) > 0.0:
			continue
		out.append({"pos": pos, "tex": tex, "key": key})
	return out

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true  # pietrele intră în sortarea pe Y (efect de adâncime)
	add_child(container)
	var mine := _chunk_rocks_raw(key)
	# Pozițiile brute ale pietrelor din cele 8 pătrate vecine (pentru verificarea distanței).
	var neighbors := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			neighbors.append_array(_chunk_rocks_raw(Vector2i(key.x + dx, key.y + dy)))
	for i in mine.size():
		if _too_close(mine[i], i, mine, neighbors):
			continue  # prea aproape de altă piatră → n-o punem
		var r: Dictionary = mine[i]
		var rock := _make_rock(r["tex"])
		rock.position = r["pos"]
		rock.position.y -= rock.get_meta("sort_shift")  # compensăm ca imaginea să rămână „plantată"
		container.add_child(rock)
	return container

# Distanța minimă (centru-centru) admisă între două pietre = min_gap_hitboxes × media lățimilor lor de hitbox.
func _min_dist(a: Texture2D, b: Texture2D) -> float:
	var wa := a.get_width() * hitbox_factor * rock_scale * 2.0
	var wb := b.get_width() * hitbox_factor * rock_scale * 2.0
	return min_gap_hitboxes * (wa + wb) * 0.5

# O piatră e „prea aproape" dacă se suprapune cu una deja acceptată. Departajare stabilă
# (aceeași decizie indiferent de ordinea generării): în același pătrat renunțăm la indicele mai mare;
# față de vecini renunțăm doar dacă vecinul are cheia „mai mică" lexicografic.
func _too_close(me: Dictionary, my_index: int, mine: Array, neighbors: Array) -> bool:
	for j in my_index:
		var other: Dictionary = mine[j]
		if me["pos"].distance_to(other["pos"]) < _min_dist(me["tex"], other["tex"]):
			return true
	var my_key: Vector2i = me["key"]
	for other in neighbors:
		var ok: Vector2i = other["key"]
		var key_smaller := ok.x < my_key.x or (ok.x == my_key.x and ok.y < my_key.y)
		if key_smaller and me["pos"].distance_to(other["pos"]) < _min_dist(me["tex"], other["tex"]):
			return true
	return false

func _make_rock(tex: Texture2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	var h := float(tex.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar când e mărit
	sprite.scale = Vector2(rock_scale, rock_scale)
	# Originea nodului = linia de sortare Y, ridicată la sort_anchor din înălțime (de la bază).
	sprite.offset = Vector2(0, h * (sort_anchor - 0.5))
	body.add_child(sprite)
	var col := CollisionShape2D.new()
	# Dreptunghi cu lățime/înălțime independente (ca la copaci) — fizica îl tratează corect.
	var shape := RectangleShape2D.new()
	var base_w := tex.get_width() * hitbox_factor * rock_scale * 2.0  # lățimea de bază
	var base_h := base_w * hitbox_vertical          # înălțimea de bază (simetrică sus/jos)
	# Fiecare latură = fracție din lățimea de bază. Pozitiv extinde marginea AFARĂ, negativ o trage înăuntru.
	var north_extra := base_w * hitbox_north  # DOAR marginea de sus (Nord)
	var south_extra := base_w * hitbox_south  # DOAR marginea de jos (Sud)
	var east_extra := base_w * hitbox_east    # DOAR marginea din dreapta (Est)
	var west_extra := base_w * hitbox_west    # DOAR marginea din stânga (Vest)
	shape.size = Vector2(base_w + west_extra + east_extra, base_h + north_extra + south_extra)
	col.shape = shape
	# Fiecare latură își mișcă doar marginea ei → centrul se deplasează cu jumătate din diferența laturilor opuse.
	var center_x := (east_extra - west_extra) / 2.0
	var center_y := (south_extra - north_extra) / 2.0
	col.position = Vector2(center_x, (sort_anchor - 0.25) * h * rock_scale + center_y)
	body.add_child(col)  # nu mai poți trece prin piatră (nici player, nici enemy)
	# cât s-a ridicat originea față de bază → compensăm poziția ca imaginea să rămână „plantată"
	body.set_meta("sort_shift", sort_anchor * h * rock_scale)
	return body
