extends Node2D

# Pietre (props de mediu) generate procedural în jurul player-ului, la infinit —
# EXACT ca sistemul de copaci (props.gd), dar independent și cu propriile reglaje.
# Imaginile se încarcă la RULARE din folderul de mai jos (nu preload), ca să nu crape
# dacă adaugi un PNG nou care încă n-a fost importat de Godot.

const ROCKS_DIR := "res://stones/"
const SEED_SALT := 0x51ED  # sămânță diferită de a copacilor → pietrele nu urmează același tipar

# Măsurătorile de contur (conturul opac și cel al trunchiului), cu cache — aceleași pe care le
# folosesc copacii și cactușii. De aici iese cât de lată e o piatră și cât de gros un trunchi.
const GroundShadow := preload("res://ground_shadow.gd")

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
# Câtă iarbă rămâne între marginea pietrei și marginea trunchiului (px de lume). Distanța reală
# se socotește din mărimile lor adevărate, nu dintr-o cifră fixă — vezi `_langa_copac`.
@export var tree_clearance: float = 30.0

var _rocks: Array[Texture2D] = []
var _loaded := {}  # Vector2i (chunk) -> Node2D (containerul cu pietrele lui)
var _props: Node2D = null  # nodul Props (copacii) — pietrele se feresc de ei

func _ready() -> void:
	_rocks = _load_dir(ROCKS_DIR)
	print("Pietre încărcate: %d" % _rocks.size())
	# fratele „Props" din main.tscn — îl folosim ca să nu punem pietre în trunchiuri
	var p := get_parent()
	if p != null:
		_props = p.get_node_or_null("Props") as Node2D

# Numele de fișier dintr-un folder `res://`, curățate de cozile pe care le adaugă exportul.
#
# ⚠️ În jocul EXPORTAT, `get_files()` nu întoarce numele de pe disc: în `.pck` stă resursa
# importată, nu PNG-ul original, iar fișierele apar cu `.import` / `.remap` la coadă. Un filtru
# pe `.png` trece în editor și nu prinde NIMIC în build. `preload_all.gd` știa asta de mult
# (`_aduna`); rocks.gd și desert_structures.gd nu — de aici cele 459 de erori pe secundă din
# primul build de Steam (2026-08-25): `_rocks` gol → `_rocks[-1]` la prima piatră.
#
# Dicționarul e pentru DUBLURI: în `.pck` aceeași piatră apare sub ambele forme, iar încărcată
# de două ori ar strica și determinismul (aceeași cheie de chunk ar alege altă piatră).
func _nume_png(dir: DirAccess) -> Array:
	var nume := {}
	for f in dir.get_files():
		for coada in [".import", ".remap"]:
			if f.ends_with(coada):
				f = f.substr(0, f.length() - coada.length())
		if f.to_lower().ends_with(".png"):
			nume[f] = true
	var out := nume.keys()
	out.sort()  # ordine fixă → aceleași pietre în același loc de fiecare dată
	return out

# Încarcă toate imaginile .png dintr-un folder, în ordine STABILĂ (sortată) → determinist.
func _load_dir(path: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Rocks: nu găsesc folderul " + path)
		return out
	for f in _nume_png(dir):
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
		if _langa_copac(mine[i]["pos"], mine[i]["tex"], key):
			continue  # ar ieși înfiptă într-un trunchi → n-o punem
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

# ---------------------------------------------------------------------------
# PIETRELE SE FERESC DE COPACI (2026-07-30)
# ---------------------------------------------------------------------------
# Cele două generatoare sunt independente (fiecare cu sămânța lui) și, până acum, NICIUNUL nu se
# uita la celălalt: copacii verificau distanța doar față de copaci, pietrele doar față de pietre.
# Se vedea în joc — o piatră crescută fix în trunchiul unui copac.
#
# Fiindcă amândouă sunt DETERMINISTE (poziția depinde doar de cheia chunk-ului, nu de ordinea în
# care se încarcă lumea), e destul ca UNA din părți să cedeze — aici piatra. Dacă s-ar feri și
# copacii de pietre, aceeași ciocnire i-ar șterge pe amândoi și ar rămâne o pată goală.
#
# ⚠️ `_chunk_trees_raw()` întoarce copacii BRUȚI, inclusiv pe cei care vor fi refuzați mai încolo
# (prea aproape de alt copac, sau pe o potecă). Deci ne ferim și de locuri unde până la urmă nu
# crește nimic. E aceeași aproximare pe care o fac deja statuile și aparatele EGT, și e partea
# sigură a greșelii: pierdem câteva pietre, dar nu punem niciuna în copac.
func _langa_copac(pos: Vector2, tex: Texture2D, key: Vector2i) -> bool:
	if _props == null or not _props.has_method("_chunk_trees_raw"):
		return false
	var raza_piatra := _raza_piatra(tex)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for t in _props._chunk_trees_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(t["pos"]) < raza_piatra + _raza_trunchi(t["tex"]) + tree_clearance:
					return true
	return false

# Cât se întinde arta pietrei în lateral, față de originea nodului (px de lume). `Sprite2D` e
# centrat pe textură și n-are offset pe X, deci marginile vizibile se măsoară din mijlocul ei.
# Contează conturul OPAC, nu canvasul: pietrele au 32×32 sau 64×64, dar arta din ele variază.
func _raza_piatra(tex: Texture2D) -> float:
	var u := GroundShadow.used_rect(tex)
	var mijloc := float(tex.get_width()) * 0.5
	return maxf(mijloc - float(u.position.x), float(u.end.x) - mijloc) * rock_scale

# Cât se întinde TRUNCHIUL copacului în lateral, față de originea lui. Trunchiul, nu coroana:
# o piatră sub coroană arată firesc, una prin trunchi nu — iar coroanele au 186–269px lățime,
# adică ar fi măturat jumătate din pietrele pădurii. Trunchiul poate fi descentrat față de nod
# (arta nu e simetrică), de-aia intră și deplasarea lui în socoteală.
func _raza_trunchi(tex: Texture2D) -> float:
	var tr := GroundShadow.trunk_rect(tex)
	var mijloc := float(tex.get_width()) * 0.5
	var centru_trunchi := float(tr.position.x) + float(tr.size.x) * 0.5 - mijloc
	var scara: float = _props.tree_scale
	return (absf(centru_trunchi) + float(tr.size.x) * 0.5) * scara

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
