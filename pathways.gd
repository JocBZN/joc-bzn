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

var _loaded := {}  # Vector2i (chunk) -> Node2D (containerul potecii lui, sau gol dacă n-are)
var _mat: ShaderMaterial
var _tex: Texture2D  # `pathblock normal` curățat de pixelii negri (vezi _clean_texture)

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = PATH_SHADER
	_mat.set_shader_parameter("fade_w", edge_fade)
	_tex = _clean_texture()

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

func _chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(chunk_size)), floori(pos.y / float(chunk_size)))

# Centrul unui tile (indici de tile globali) în coordonate de lume.
func _tile_center(tx: int, ty: int) -> Vector2:
	return Vector2((tx + 0.5) * tile_px, (ty + 0.5) * tile_px)

# Un tile e „în pădure pură" doar dacă podeaua nu arată nimic de deșert acolo (nici gradient).
func _is_forest(tx: int, ty: int) -> bool:
	return BiomeMap.desertness_at_chunk(_tile_center(tx, ty) / float(chunk_size)) <= 0.0

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	add_child(container)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ 0x9E3779B9  # salt propriu, ca poteca să nu se coreleze cu copacii
	if rng.randf() >= spawn_chance:
		return container  # chunk-ul ăsta n-are potecă
	var vertical := rng.randf() < 0.5
	var length := rng.randi_range(min_len, max_len)
	# tile-ul de start, undeva în chunk (indici de tile GLOBALI)
	var per_chunk := maxi(1, chunk_size / tile_px)  # câte tile-uri intră pe latura unui chunk
	var stx := key.x * per_chunk + rng.randi_range(0, per_chunk - 1)
	var sty := key.y * per_chunk + rng.randi_range(0, per_chunk - 1)

	# Poteca = un dreptunghi de tile-uri, 3 late × `length` lung (toate `pathblock normal`).
	# Strângem întâi toate coordonatele (și un set pentru căutarea vecinilor) și verificăm că TOT e
	# pădure; dacă vreun tile atinge deșert/gradient, renunțăm la potecă în întregime.
	var tiles := []      # Array[Vector2i]
	var tset := {}       # Vector2i -> true (apartenență, pentru estomparea marginilor)
	for i in length:
		for k in [-1, 0, 1]:
			# vertical: potecă pe Y, cele 3 tile-uri se întind pe X (stx-1..stx+1)
			# orizontal: potecă pe X, cele 3 tile-uri se întind pe Y (sty-1..sty+1)
			var pos := Vector2i(stx + k, sty + i) if vertical else Vector2i(stx + i, sty + k)
			if not _is_forest(pos.x, pos.y):
				return container  # atinge deșert/gradient → fără potecă
			tiles.append(pos)
			tset[pos] = true

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
