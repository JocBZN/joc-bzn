extends Node2D

# Poteci (paths) generate procedural, la infinit, în jurul player-ului — la fel ca la copaci
# (props.gd): lumea e împărțită în chunk-uri pătrate, fiecare își decide DETERMINIST poteca
# (după poziția lui), deci același loc are mereu aceeași potecă chiar dacă pleci și te întorci.
#
# Reguli cerute de Răzvan (2026-07-23):
#  - potecă DOAR în pădure: nu în deșert și nici pe gradientul unde deșertul se îmbină cu pădurea
#    (verificăm `BiomeMap.desertness_at_chunk` == 0 pe FIECARE tile — 0 = iarbă pură);
#  - lățime mereu de 1 pathblock normal, cu câte un tile de margine în stânga și în dreapta,
#    ales dintre cele care se îmbină cu iarba (poate fi verticală SAU orizontală);
#  - lungime aleatoare între 4 și 20 de tile-uri;
#  - cam 1 potecă la 5 chunk-uri.

# Tile-ul de centru + cele 4 de margine. NUMELE = latura pe care e PATH-ul (iarba e pe opusul):
#   ...east  → path pe Est,  iarbă pe Vest      ...west  → path pe Vest, iarbă pe Est
#   ...north → path pe Nord, iarbă pe Sud       ...south → path pe Sud,  iarbă pe Nord
const PATH_NORMAL := preload("res://harta/pathblocks/pathblock normal.png")
const PATH_EAST := preload("res://harta/pathblocks/pathblock x grassblock east.png")
const PATH_WEST := preload("res://harta/pathblocks/pathblock x grassblock west.png")
const PATH_NORTH := preload("res://harta/pathblocks/pathblock x grassblock north.png")
const PATH_SOUTH := preload("res://harta/pathblocks/pathblock x grassblock south.png")

@export var chunk_size: int = 512       # mărimea unui chunk (px) — CA în props.gd/rocks.gd/ground.gd
@export var tile_px: int = 64           # cât ocupă un tile de potecă pe ecran (64 = exact grila de iarbă)
@export var load_radius: int = 4        # câte chunk-uri în jur ținem încărcate (mai mult ca la copaci:
                                        # o potecă de 20 tile-uri se întinde pe ~2.5 chunk-uri)
@export var spawn_chance: float = 0.1   # șansa ca un chunk să pornească o potecă (0.1 = ~1 la 10 chunk-uri)
@export var min_len: int = 4            # lungimea minimă, în tile-uri
@export var max_len: int = 20           # lungimea maximă, în tile-uri
@export var path_z: int = -5            # peste iarbă (Ground e la z=-10), sub umbre (z=-1) și copaci

var _loaded := {}  # Vector2i (chunk) -> Node2D (containerul potecii lui, sau gol dacă n-are)

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

	# Fiecare pas al potecii e o „felie" de 3 tile-uri, pusă de-a latul. Verificăm în paralel că
	# TOATE sunt în pădure; dacă vreunul atinge deșert/gradient, renunțăm la potecă în întregime.
	#
	# Blend pe TOATE cele 4 laturi (n-avem tile de colț, deci facem cel mai curat lucru posibil):
	#  - feliile din mijloc au marginile laterale blenduite (E/W la verticală, S/N la orizontală);
	#  - prima și ultima felie sunt CAPETE: TOT rândul devine tile-ul de capăt, ca marginea de la
	#    capăt să iasă dreaptă și curată (dacă blenduiam doar centrul, lateralele rămâneau maro și
	#    ieșea o crenelură). Colțurile rămân ușor pătrate — inevitabil fără un tile de colț.
	# Așa se folosesc toate 4 direcțiile.
	var placements := []  # { "tx", "ty", "tex" }
	for i in length:
		var is_first := i == 0
		var is_last := i == length - 1
		# cele 3 poziții de-a latul feliei + textura fiecăreia
		var slice := []  # [ {tx, ty}, {tx, ty}, {tx, ty} ] în ordinea: margine1, centru, margine2
		var texs := []
		if vertical:
			var yy := sty + i
			slice = [{"tx": stx - 1, "ty": yy}, {"tx": stx, "ty": yy}, {"tx": stx + 1, "ty": yy}]
			if is_first:     texs = [PATH_SOUTH, PATH_SOUTH, PATH_SOUTH]   # capul de SUS: iarbă la nord
			elif is_last:    texs = [PATH_NORTH, PATH_NORTH, PATH_NORTH]   # capul de JOS: iarbă la sud
			else:            texs = [PATH_EAST, PATH_NORMAL, PATH_WEST]    # stânga=iarbă V, dreapta=iarbă E
		else:
			var xx := stx + i
			slice = [{"tx": xx, "ty": sty - 1}, {"tx": xx, "ty": sty}, {"tx": xx, "ty": sty + 1}]
			if is_first:     texs = [PATH_EAST, PATH_EAST, PATH_EAST]      # capul de VEST: iarbă la vest
			elif is_last:    texs = [PATH_WEST, PATH_WEST, PATH_WEST]      # capul de EST: iarbă la est
			else:            texs = [PATH_SOUTH, PATH_NORMAL, PATH_NORTH]  # sus=iarbă N, jos=iarbă S
		for t in slice:
			if not _is_forest(t["tx"], t["ty"]):
				return container  # atinge deșert/gradient → fără potecă
		for j in 3:
			placements.append({"tx": slice[j]["tx"], "ty": slice[j]["ty"], "tex": texs[j]})

	for p in placements:
		var s := Sprite2D.new()
		s.texture = p["tex"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_index = path_z
		s.z_as_relative = false  # z absolut → mereu peste iarbă, indiferent de părinte
		s.scale = Vector2.ONE * (float(tile_px) / float(p["tex"].get_width()))
		s.position = _tile_center(p["tx"], p["ty"])
		container.add_child(s)
	return container
