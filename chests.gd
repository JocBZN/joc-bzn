extends Node2D

# Cufere puse LÂNGĂ POTECI (vezi `chest.gd` pentru ce face unul și `pathways.gd` pentru poteci).
#
# Reguli cerute de Răzvan (2026-07-27):
#  - cufărul stă la `gap_px` (20px) de marginea potecii — atât rămâne gol între potecă și lada lui;
#  - NU lângă fiecare potecă: `chest_chance` din poteci primesc unul. Era 10% la prima variantă,
#    urcat la **35%** pe 2026-07-27 fiindcă ieșeau prea rar ca să le vezi într-o rundă.
#
# Procentul se numără pe POTECI, nu pe chunk-uri: întâi întrebăm `Paths` dacă chunk-ul ăsta chiar
# are o potecă desenată, și abia apoi dăm cu zarul. Cum potecile apar la ~1 din 10 chunk-uri, la
# 35% iese un cufăr cam la 30 de chunk-uri.
#
# Determinist, ca tot decorul: sămânța vine din cheia chunk-ului → aceeași potecă are mereu
# cufărul în același loc, chiar dacă pleci și te întorci. (Ce se schimbă de la o rundă la alta
# e punctul de START al player-ului, ales aleator în `spawner.gd`.)

const CHEST := preload("res://chest.tscn")
const SEED_SALT := 0xC4E5  # sămânță proprie → cufărul nu urmează tiparul potecilor/pietrelor

@export var load_radius: int = 4          # CA la poteci: cufărul trebuie să apară odată cu poteca lui
@export var chest_chance: float = 0.35    # ce parte din poteci primesc un cufăr (0.35 = 35%)
@export var gap_px: float = 20.0          # spațiul gol dintre marginea potecii și marginea cufărului
@export var min_dist_rock: float = 130.0  # cât de departe stă de o piatră (pietrele nu se feresc de poteci)
@export var tries: int = 8                # câte laturi de potecă încercăm până renunțăm la cufăr

var _loaded := {}
# Cuferele DESCHISE, ținute minte pe toată runda (ca la `monuments.gd::_folosite`). Fără ele, un
# cufăr golit se întorcea închis de fiecare dată când chunk-ul lui se descărca și se regenera —
# adică dacă te îndepărtai `load_radius` chunk-uri și reveneai, sau dacă intrai și ieșeai dintr-o
# dimensiune (Nether/Ender/Limbo golesc TOATE generatoarele). Cerut de Răzvan pe 2026-08-06:
# „când revii din limbo sau orice altă dimensiune nu vreau să se reseteze lucrurile deja folosite".
#
# Cheia e POZIȚIA rotunjită, nu chunk-ul: cufărul se pune lângă poteca chunk-ului, iar o potecă
# lungă iese din el, deci cufărul poate cădea în alt chunk decât cel care l-a generat — cu cheia
# de chunk am fi stins cufărul greșit. Poziția, în schimb, e deterministă și e chiar a lui.
var _folosite := {}
var _paths: Node = null   # nodul Paths (pathways.gd) — el știe unde sunt tile-urile potecilor
var _rocks: Node2D = null # nodul Rocks — ca să nu înfigem cufărul într-o piatră
var _cutie := Rect2()     # mărimea reală a cufărului, măsurată o dată (vezi `_cutie_cufar`)

func _ready() -> void:
	var p := get_parent()
	if p != null:
		_rocks = p.get_node_or_null("Rocks") as Node2D

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _paths == null:
		# căutat leneș, ca la copaci (props.gd): la `_ready` s-ar putea să nu fie încă în grup
		_paths = get_tree().get_first_node_in_group("paths")
	if _paths == null:
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

# Mărimea chunk-ului și a tile-ului le luăm de la Paths, nu le scriem a doua oară: dacă acolo
# se schimbă `tile_px`, cufărul trebuie să se miște odată cu poteca.
func _chunk_px() -> float:
	return float(_paths.chunk_size)

func _tile_px() -> float:
	return float(_paths.tile_px)

func _chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / _chunk_px()), floori(pos.y / _chunk_px()))

func _tile_center(t: Vector2i) -> Vector2:
	return Vector2((t.x + 0.5) * _tile_px(), (t.y + 0.5) * _tile_px())

# Unde stă cufărul potecii din chunk-ul `key`? Determinist, fără a crea noduri.
# Vector2.INF = n-are (fără potecă, zarul n-a picat pe cei 10%, sau peste tot sunt pietre).
func chunk_chest_pos(key: Vector2i) -> Vector2:
	var tiles: Array = _paths.path_tiles(key)
	if tiles.is_empty():
		return Vector2.INF        # chunk-ul ăsta n-are potecă → n-are nici cufăr
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= chest_chance:
		return Vector2.INF        # poteca asta n-a picat în cei 10%

	# Toate laturile EXPUSE ale potecii (tile de margine + direcția în care iese din potecă).
	# Poteca e o fâșie de 3 tile-uri, deci ies laturile lungi și cele două capete.
	var tset := {}
	for t in tiles:
		tset[t] = true
	var laturi: Array = []
	for t in tiles:
		for n in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if not tset.has(t + n):
				laturi.append({"tile": t, "n": n})
	if laturi.is_empty():
		return Vector2.INF

	var box := _cutie_cufar()
	for i in tries:
		var l: Dictionary = laturi[rng.randi_range(0, laturi.size() - 1)]
		var pos := _pozitie_langa(l["tile"], l["n"], box)
		if not _langa_piatra(pos):
			return pos
	return Vector2.INF

# Cât de mare e un cufăr, în pixeli de lume. Îl măsurăm pe un exemplar de probă, făcut o
# singură dată și aruncat imediat, în loc să scriem cifrele aici: `chest.tscn` are `scale`
# reglat cu mâna (0.7 acum), iar `cutie()` îl bagă deja în calcul. Așa, dacă Răzvan mai
# schimbă scara din editor, distanța până la potecă rămâne corectă fără să umblu în cod.
func _cutie_cufar() -> Rect2:
	if _cutie.size == Vector2.ZERO:
		var proba := CHEST.instantiate()
		_cutie = proba.cutie()
		proba.free()
	return _cutie

# Poziția cufărului pentru un tile de potecă și o direcție de ieșire, astfel încât între
# MARGINEA potecii și MARGINEA desenată a cufărului să rămână exact `gap_px`.
# De aia avem nevoie de `cutie()`: dacă am măsura de la originea nodului, cufărul (~100px lat)
# ar intra cu jumătate peste potecă.
func _pozitie_langa(t: Vector2i, n: Vector2i, box: Rect2) -> Vector2:
	# cât se întinde cufărul ÎNSPRE potecă, adică pe latura opusă direcției de ieșire
	var spre_poteca := 0.0
	if n.x > 0:
		spre_poteca = -box.position.x     # iese spre est → îl atinge cu latura din stânga
	elif n.x < 0:
		spre_poteca = box.end.x           # spre vest → cu latura din dreapta
	elif n.y > 0:
		spre_poteca = -box.position.y     # spre sud → cu marginea de sus (arta urcă mult peste origine)
	else:
		spre_poteca = box.end.y           # spre nord → cu talpa
	return _tile_center(t) + Vector2(n) * (_tile_px() * 0.5 + gap_px + spre_poteca)

# Aceeași fereală ca la statui (statues.gd): pietrele NU se feresc de poteci, deci pot sta
# fix acolo unde am pune cufărul.
# ⚠️ Ne uităm în jurul chunk-ului în care CADE cufărul, nu al celui care a pornit poteca:
# o potecă lungă se întinde pe 2-3 chunk-uri, deci capătul ei (și cufărul de lângă el) poate
# fi deja în alt chunk, cu alte pietre.
func _langa_piatra(pos: Vector2) -> bool:
	if _rocks == null or not _rocks.has_method("_chunk_rocks_raw"):
		return false
	var key := _chunk_of(pos)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for r in _rocks._chunk_rocks_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(r["pos"]) < min_dist_rock:
					return true
	return false

# Chemată de `chest.gd` când cufărul e deschis: de aici încolo locul ăsta rămâne gol.
# Primește poziția din LUME (cufărul nu-și știe locul în generator), noi o aducem la noi acasă.
func marcheaza_folosit(pos_lume: Vector2) -> void:
	_folosite[_cheie(to_local(pos_lume))] = true

# Poziția, rotunjită la pixel întreg. Rotunjim ca să nu depindem de virgulele mobile: aceeași
# sămânță dă același `float` de fiecare dată, dar drumul dus-întors prin `global_position` poate
# pierde ultimul bit, iar un dicționar nu iartă nici atât.
func _cheie(p: Vector2) -> Vector2i:
	return Vector2i(p.round())

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_chest_pos(key)
	if pos != Vector2.INF and not _folosite.has(_cheie(pos)):
		var c := CHEST.instantiate()
		c.position = pos
		container.add_child(c)
	return container
