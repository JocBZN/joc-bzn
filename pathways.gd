extends Node2D

# Poteci (paths) generate procedural, la infinit, în jurul player-ului — la fel ca la copaci
# (props.gd): lumea e împărțită în chunk-uri pătrate, fiecare își decide DETERMINIST poteca
# (după poziția lui), deci același loc are mereu aceeași potecă chiar dacă pleci și te întorci.
#
# Reguli cerute de Răzvan (2026-07-23):
#  - potecă DOAR în pădure: nu în deșert și nici pe gradientul unde deșertul se îmbină cu pădurea
#    (verificăm `BiomeMap.desertness_at_chunk` == 0 pe FIECARE tile — 0 = iarbă pură);
#  - lățime mereu de 1 pathblock normal, cu câte un tile pe fiecare parte (poate fi verticală SAU
#    orizontală); lungime aleatoare 4..20 tile-uri; cam 1 potecă la 10 chunk-uri.
#
# BLEND făcut în Godot, nu cu tile-uri prefabricate (cerut pe 2026-07-23): folosim DOAR
# `pathblock normal` peste tot, iar `path_blend.gdshader` estompează spre iarbă doar laturile
# EXPUSE ale fiecărui tile (cele fără vecin-potecă). Așa marginile și capetele se estompează lin,
# colțurile ies rotunjite (min pe două laturi), fără crenelură și fără „capete" ieșite în afară.

const PATH_NORMAL := preload("res://harta/pathblocks/pathblock normal.png")
const PATH_SHADER := preload("res://path_blend.gdshader")

@export var chunk_size: int = 512       # mărimea unui chunk (px) — CA în props.gd/rocks.gd/ground.gd
@export var tile_px: int = 64           # cât ocupă un tile de potecă pe ecran (64 = exact grila de iarbă)
@export var load_radius: int = 4        # câte chunk-uri în jur ținem încărcate (mai mult ca la copaci:
                                        # o potecă de 20 tile-uri se întinde pe ~2.5 chunk-uri)
@export var spawn_chance: float = 0.1   # șansa ca un chunk să pornească o potecă (0.1 = ~1 la 10 chunk-uri)
@export var min_len: int = 4            # lungimea minimă, în tile-uri
@export var max_len: int = 20           # lungimea maximă, în tile-uri
@export var path_z: int = -5            # peste iarbă (Ground e la z=-10), sub umbre (z=-1) și copaci
@export_range(0.05, 0.5) var edge_fade: float = 0.4  # cât de lat e blend-ul spre iarbă (fracție din tile)

@export_range(0.0, 0.6) var dark_floor: float = 0.32  # ridică pixelii sub pragul ăsta de luminozitate
@export var path_gap: int = 3           # distanța minimă (tile-uri) între două poteci; sub ea, una cedează

# Cât de departe (chunk-uri) poate ajunge o potecă de la chunk-ul ei de origine. Folosit la verificarea
# suprapunerii dintre poteci ȘI la `is_on_path` (copacii). O potecă de max_len tile-uri se întinde pe
# ceil(max_len / tile-uri_per_chunk) chunk-uri; punem cu marjă.
var _reach := 4

var _loaded := {}    # Vector2i (chunk) -> Node2D (containerul potecii lui, sau gol dacă n-are)
var _raw_cache := {} # Vector2i -> Array[Vector2i] (tile-urile BRUTE ale potecii, înainte de rezolvarea suprapunerii)
var _mat: ShaderMaterial
var _tex: Texture2D  # `pathblock normal` curățat de pixelii negri (vezi _clean_texture)

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = PATH_SHADER
	_mat.set_shader_parameter("fade_w", edge_fade)
	_tex = _clean_texture()
	_reach = int(ceil(float(max_len) / float(maxi(1, chunk_size / tile_px)))) + 1
	add_to_group("paths")  # ca props.gd (copacii) să ne găsească și să evite potecile

# Textura de pământ are pixeli aproape negri care, estompați peste iarbă, ies ca puncte negre pe
# margine. Îi ridicăm la un prag de luminozitate (`dark_floor`), păstrând nuanța (scalăm RGB) →
# cel mai întunecat pământ devine un maro-închis, nu negru. O facem O SINGURĂ DATĂ, la pornire.
func _clean_texture() -> Texture2D:
	var img := PATH_NORMAL.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var dirt_dark := Color(0.34, 0.20, 0.15)  # cu ce înlocuim negrul PUR (n-are nuanță de scalat)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			var lum: float = max(c.r, max(c.g, c.b))
			if lum >= dark_floor:
				continue
			if lum > 0.04:
				var f: float = dark_floor / lum  # scalăm în sus, păstrând nuanța
				img.set_pixel(x, y, Color(minf(c.r * f, 1.0), minf(c.g * f, 1.0), minf(c.b * f, 1.0), c.a))
			else:
				img.set_pixel(x, y, Color(dirt_dark.r, dirt_dark.g, dirt_dark.b, c.a))  # negru pur → pământ închis
	return ImageTexture.create_from_image(img)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _mat != null:
		_mat.set_shader_parameter("fade_w", edge_fade)  # ca să poți regla din Inspector în timp real
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
	if _raw_cache.size() > 4000:  # se recalculează la nevoie, deci putem goli fără griji
		_raw_cache.clear()

func _chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(chunk_size)), floori(pos.y / float(chunk_size)))

# Centrul unui tile (indici de tile globali) în coordonate de lume.
func _tile_center(tx: int, ty: int) -> Vector2:
	return Vector2((tx + 0.5) * tile_px, (ty + 0.5) * tile_px)

# Un tile e „în pădure pură" doar dacă podeaua nu arată nimic de deșert acolo (nici gradient).
func _is_forest(tx: int, ty: int) -> bool:
	return BiomeMap.desertness_at_chunk(_tile_center(tx, ty) / float(chunk_size)) <= 0.0

# Tile-urile BRUTE ale potecii unui chunk (dreptunghi 3×length, toate `pathblock normal`), calculate
# DETERMINIST din cheia chunk-ului, FĂRĂ a crea noduri și FĂRĂ rezolvarea suprapunerii cu vecinii.
# Întoarce [] dacă chunk-ul n-are potecă sau dacă ar atinge deșert/gradient. Cache-uit (se cere des:
# la construire, la vecini pentru suprapunere, și de copaci prin is_on_path).
func _raw_path(key: Vector2i) -> Array:
	if _raw_cache.has(key):
		return _raw_cache[key]
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ 0x9E3779B9  # salt propriu, ca poteca să nu se coreleze cu copacii
	if rng.randf() < spawn_chance:
		var vertical := rng.randf() < 0.5
		var length := rng.randi_range(min_len, max_len)
		var per_chunk := maxi(1, chunk_size / tile_px)  # câte tile-uri intră pe latura unui chunk
		var stx := key.x * per_chunk + rng.randi_range(0, per_chunk - 1)
		var sty := key.y * per_chunk + rng.randi_range(0, per_chunk - 1)
		var ok := true
		var tiles: Array = []
		for i in length:
			for k in [-1, 0, 1]:
				# vertical: potecă pe Y, cele 3 tile-uri pe X (stx-1..stx+1); orizontal: invers
				var pos := Vector2i(stx + k, sty + i) if vertical else Vector2i(stx + i, sty + k)
				if not _is_forest(pos.x, pos.y):
					ok = false
					break
				tiles.append(pos)
			if not ok:
				break
		if ok:
			out = tiles
	_raw_cache[key] = out
	return out

# Departajare deterministă între poteci care s-ar apropia prea mult: cheia „mai mică" câștigă.
func _key_smaller(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

# Poteca lui `key` cedează (nu se desenează) dacă vreun tile de-al ei e la ≤ `path_gap` de o potecă
# dintr-un chunk vecin cu cheia MAI MICĂ → două poteci nu ajung niciodată lipite/suprapuse (fără
# umflături în lateral). Doar față de cheile mai mici, ca decizia să nu depindă de ordinea generării.
func _yields_to_neighbor(key: Vector2i, my_set: Dictionary) -> bool:
	for dy in range(-_reach, _reach + 1):
		for dx in range(-_reach, _reach + 1):
			if dx == 0 and dy == 0:
				continue
			var nk := Vector2i(key.x + dx, key.y + dy)
			if not _key_smaller(nk, key):
				continue
			var nt := _raw_path(nk)
			for t in nt:
				for oy in range(-path_gap, path_gap + 1):
					for ox in range(-path_gap, path_gap + 1):
						if my_set.has(t + Vector2i(ox, oy)):
							return true
	return false

# E poziția de lume `world_pos` pe o potecă (sau la ≤ `margin` tile-uri de ea)? Folosit de copaci
# (props.gd) ca să NU crească pe potecă / pe blend-ul ei. Determinist, nu depinde de ce e încărcat.
func is_on_path(world_pos: Vector2, margin: int = 0) -> bool:
	var t := Vector2i(floori(world_pos.x / tile_px), floori(world_pos.y / tile_px))
	var c0 := _chunk_of(world_pos)
	for dy in range(-_reach, _reach + 1):
		for dx in range(-_reach, _reach + 1):
			for pt in _raw_path(Vector2i(c0.x + dx, c0.y + dy)):
				if absi(pt.x - t.x) <= margin and absi(pt.y - t.y) <= margin:
					return true
	return false

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	add_child(container)
	var tiles := _raw_path(key)
	if tiles.is_empty():
		return container  # chunk-ul ăsta n-are potecă
	var tset := {}  # Vector2i -> true (apartenență, pentru estomparea marginilor)
	for pos in tiles:
		tset[pos] = true
	if _yields_to_neighbor(key, tset):
		return container  # prea aproape de altă potecă → cedăm, ca să nu iasă umflături în lateral

	for pos in tiles:
		var s := Sprite2D.new()
		s.texture = _tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.material = _mat
		s.z_index = path_z
		s.z_as_relative = false  # z absolut → mereu peste iarbă, indiferent de părinte
		s.scale = Vector2.ONE * (float(tile_px) / float(_tex.get_width()))
		s.position = _tile_center(pos.x, pos.y)
		# Estompăm DOAR laturile expuse (fără vecin-potecă). Codificate în self_modulate,
		# citite de shader ca R=stânga, G=sus, B=dreapta, A=jos (1 = estompează).
		s.self_modulate = Color(
			0.0 if tset.has(pos + Vector2i(-1, 0)) else 1.0,
			0.0 if tset.has(pos + Vector2i(0, -1)) else 1.0,
			0.0 if tset.has(pos + Vector2i(1, 0)) else 1.0,
			0.0 if tset.has(pos + Vector2i(0, 1)) else 1.0)
		container.add_child(s)
	return container
