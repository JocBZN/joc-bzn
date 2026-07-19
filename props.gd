extends Node2D

# Copaci generați procedural în jurul player-ului, la infinit.
# Lumea e împărțită în "chunk-uri" (pătrate). Fiecare chunk își generează copacii
# DETERMINIST (după poziția lui) → același loc are mereu aceiași copaci, chiar
# dacă pleci și te întorci. Chunk-urile depărtate se descarcă automat (performanță).

const TREES := [
	preload("res://harta/trees/Tree Variant 1.png"),
	preload("res://harta/trees/Tree Variant 2.png"),
	preload("res://harta/trees/Tree Variant 3.png"),
	preload("res://harta/trees/Tree Variant 4.png"),
	preload("res://harta/trees/Tree Variant 5.png"),
	preload("res://harta/trees/Tree Variant 6.png"),
	preload("res://harta/trees/Tree Variant 7.png"),
]

@export var chunk_size: int = 512       # mărimea unui pătrat de lume (px)
@export var load_radius: int = 3        # câte pătrate în jurul player-ului ținem încărcate
@export var trees_per_chunk: int = 1    # câți copaci (maxim) într-un pătrat (înjumătățit de la 2)
@export var min_gap_hitboxes: float = 2.0  # distanța minimă între copaci, măsurată în „hitbox-uri" (2 = nu se apropie mai mult de 2 hitbox-uri)
# `tree_scale` e singura valoare încă legată de dimensiunea texturii, deci SINGURA care
# trebuie recalculată dacă mai schimbi arta. Vechii copaci (64x64) mergeau la 4.5; nu se
# împarte pur și simplu la raportul canvasului, fiindcă contează cât din canvas ocupă
# desenul: vechii aveau ~40x49px vizibili din 64, noii ~97x120px din 128 → raport ~1.85.
#
# Hitbox-ul și umbra NU mai depind de canvas: se măsoară din trunchiul desenat (`_trunk`),
# deci se potrivesc singure la orice artă nouă.
@export var tree_scale: float = 1.85    # cât de mari sunt copacii
@export var hitbox_factor: float = 0.85   # lățimea hitbox-ului, ca fracție din TRUNCHI (1.0 = exact trunchiul)
@export var hitbox_vertical: float = 0.55 # înălțimea hitbox-ului față de lățime: 1.0 = pătrat, mai mic = mai scund
@export var hitbox_shift_y: float = 0.0   # urcă/coboară cutia față de rădăcină (negativ = mai sus)
# Cele 4 laturi — fiecare mișcă DOAR marginea ei (pozitiv = extinde afară, negativ = trage înăuntru):
@export var hitbox_north: float = 0.0      # marginea de SUS (Nord)
@export var hitbox_south: float = 0.0      # marginea de JOS (Sud)
@export var hitbox_east: float = 0.0       # marginea din DREAPTA (Est)
@export var hitbox_west: float = 0.0       # marginea din STÂNGA (Vest)
@export var sort_anchor: float = 0.35     # de la ce % din înălțime (măsurat de la bază) copacul începe să te acopere
@export var leaf_chance: float = 0.10     # ce șansă are un copac să-i cadă frunze (0.10 = 10%)
# --- umbra de la baza copacului ---
@export var shadow_alpha: float = 0.42    # cât de închisă e (0 = invizibilă, 1 = negru plin)
@export var shadow_width: float = 0.60    # lățimea ei, ca fracție din lățimea vizibilă a copacului
@export var shadow_squash: float = 0.28   # cât e de turtită: înălțime / lățime (1.0 = cerc)
@export var shadow_shift_y: float = -6.0  # o urcă/coboară față de bază (negativ = mai sus)

const LEAFFALL := preload("res://leaffall.gd")

# Zona în care cad frunzele, măsurată din dreptunghiurile roșii pe care le-a desenat
# Răzvan peste doi copaci în `harta/Tree Leaf Area.png`. Fracții din conturul VIZIBIL
# al copacului (nu din canvas — texturile au margini transparente).
# Cei doi copaci desenați au dat 0.99 și 1.10 lățime, 0.34/0.29 sus, 1.12/1.11 jos.
const LEAF_ZONE_W := 1.0        # lățimea zonei = lățimea copacului
const LEAF_ZONE_TOP := 0.31     # de unde începe, 0 = vârful copacului, 1 = baza lui
const LEAF_ZONE_BOTTOM := 1.11  # unde se termină (>1 = puțin sub rădăcină)

const SHADOW_TEX_SIZE := 128
const TRUNK_BAND := 0.18    # ce fracție din înălțimea copacului, măsurată de jos, e „trunchi"

var _trunk_cache := {}      # textură -> conturul trunchiului
var _used_rect_cache := {}  # textură -> conturul opac (get_used_rect e scump, îl ținem minte)
var _shadow_cache: GradientTexture2D  # o singură textură de umbră, refolosită de toți copacii

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
		# Aruncăm zarul pentru frunze AICI, din același rng determinist → același copac
		# are (sau n-are) frunze de fiecare dată când reintri în zonă, nu se schimbă la reîncărcare.
		var are_frunze := rng.randf() < leaf_chance
		# copacii NU cresc în deșert și NICI pe gradientul (tranziția) spre deșert:
		# blocăm oriunde podeaua arată vreun pic de deșert (d > 0), exact ca shaderul.
		# (RNG-ul a fost deja consumat mai sus → determinismul se păstrează; doar filtrăm.)
		if BiomeMap.desertness_at_chunk(pos / float(chunk_size)) > 0.0:
			continue
		out.append({"pos": pos, "tex": tex, "key": key, "frunze": are_frunze})
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
		# copacul „norocos" (10%) primește frunze care cad sub el, spre sud
		if me.get("frunze", false):
			var lf := Node2D.new()
			lf.set_script(LEAFFALL)
			lf.setup(tree.get_meta("leaf_zone"))  # ÎNAINTE de add_child: _ready() are nevoie de zonă
			tree.add_child(lf)
	return container

# Distanța minimă (centru-centru) admisă între doi copaci = min_gap_hitboxes × media lățimilor lor de hitbox.
func _min_dist(tex_a: Texture2D, tex_b: Texture2D) -> float:
	return min_gap_hitboxes * (_hitbox_w(tex_a) + _hitbox_w(tex_b)) * 0.5

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
	var base_w := _hitbox_w(tex)                    # lățimea trunchiului × hitbox_factor
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
	# Cutia stă pe trunchi: centrată pe mijlocul lui, cu marginea de jos pe rădăcină.
	# (Înainte era legată de `sort_anchor` și de înălțimea canvasului — de acolo venea
	# bara care plutea prin coroană.)
	col.position = Vector2(
		_trunk_center_x(tex, sprite) + center_x,
		_base_y(tex, sprite) - base_h * 0.5 + hitbox_shift_y + center_y
	)
	body.add_child(col)  # nu mai poți trece prin copac (nici player, nici enemy)
	body.add_child(_make_shadow(tex, sprite))
	# cât s-a ridicat originea față de bază → compensăm poziția ca imaginea să rămână „plantată" pe loc
	body.set_meta("sort_shift", sort_anchor * h * tree_scale)
	body.set_meta("leaf_zone", _leaf_zone(tex, sprite))
	return body

# Conturul opac al texturii (fără marginile transparente). `get_used_rect` citește
# toți pixelii, deci e scump — îl ținem minte per textură.
func _used(tex: Texture2D) -> Rect2i:
	if not _used_rect_cache.has(tex):
		_used_rect_cache[tex] = tex.get_image().get_used_rect()
	return _used_rect_cache[tex]

# Conturul TRUNCHIULUI, în pixeli de textură: scanăm doar banda de jos a copacului
# (ultimele TRUNK_BAND din înălțimea lui vizibilă) și luăm întinderea pixelilor opaci.
#
# De ce: până pe 2026-07-19 hitbox-ul se calcula din lățimea CANVASULUI, iar umbra din
# mijlocul conturului întreg — adică din coroană. Ieșea o bară lată plutind prin frunziș:
# te blocai în frunze și treceai prin trunchi. Trunchiul e ce lovești de fapt.
func _trunk(tex: Texture2D) -> Rect2i:
	if _trunk_cache.has(tex):
		return _trunk_cache[tex]
	var img := tex.get_image()
	var used := _used(tex)
	var banda := maxi(1, int(round(float(used.size.y) * TRUNK_BAND)))
	var y0 := used.end.y - banda
	var min_x := used.end.x
	var max_x := used.position.x
	for y in range(y0, used.end.y):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.03:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	var r := used  # dacă banda iese goală (n-ar trebui), cădem pe conturul întreg
	if max_x >= min_x:
		r = Rect2i(min_x, y0, max_x - min_x + 1, banda)
	_trunk_cache[tex] = r
	return r

# Lățimea hitbox-ului în pixeli de lume. Un singur loc care o calculează, ca verificarea
# de distanță dintre copaci și cutia de coliziune să nu poată ajunge să nu fie de acord.
func _hitbox_w(tex: Texture2D) -> float:
	return float(_trunk(tex).size.x) * tree_scale * hitbox_factor

# Textura de umbră: un gradient radial negru, făcut o singură dată și refolosit de
# toți copacii. Miez plin până la 55%, apoi margine moale.
func _shadow_texture() -> GradientTexture2D:
	if _shadow_cache == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		g.add_point(0.72, Color(0, 0, 0, 1))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = SHADOW_TEX_SIZE
		t.height = SHADOW_TEX_SIZE
		_shadow_cache = t
	return _shadow_cache

# Umbra de la baza copacului: elipsă turtită, așezată pe rădăcină.
# `z_index = -1` o ține sub copac, sub player și sub ceilalți copaci — adică pe sol,
# indiferent de sortarea pe Y. (Aceeași soluție ca la urmele de foc.)
func _make_shadow(tex: Texture2D, sprite: Sprite2D) -> Sprite2D:
	var used := _used(tex)
	var sh := Sprite2D.new()
	sh.texture = _shadow_texture()
	sh.z_index = -1
	sh.modulate = Color(1, 1, 1, shadow_alpha)
	# Lățimea o dă coroana (ea aruncă umbra), dar POZIȚIA o dă trunchiul — la copacii
	# cu coroana lăsată într-o parte, mijlocul conturului nu e deasupra trunchiului
	# și umbra ieșea pe lângă copac.
	var latime := float(used.size.x) * tree_scale * shadow_width
	var t := float(SHADOW_TEX_SIZE)
	sh.scale = Vector2(latime / t, latime * shadow_squash / t)
	sh.position = Vector2(_trunk_center_x(tex, sprite), _base_y(tex, sprite) + shadow_shift_y)
	return sh

# Mijlocul trunchiului, în coordonatele nodului (Sprite2D e centrat, de aici scăderile).
func _trunk_center_x(tex: Texture2D, sprite: Sprite2D) -> float:
	var trunk := _trunk(tex)
	var w := float(tex.get_width())
	return (sprite.offset.x + float(trunk.position.x) + float(trunk.size.x) * 0.5 - w * 0.5) * tree_scale

# Linia solului: baza vizibilă a copacului, în coordonatele nodului.
func _base_y(tex: Texture2D, sprite: Sprite2D) -> float:
	var h := float(tex.get_height())
	return (sprite.offset.y + float(_used(tex).end.y) - h * 0.5) * tree_scale

# Dreptunghiul în care cad frunzele, în coordonatele copacului.
# Pornim de la conturul VIZIBIL al texturii (`get_used_rect`), nu de la canvas: texturile
# de copaci au margini transparente, iar dreptunghiurile desenate de Răzvan erau raportate
# la copacul care se vede.
func _leaf_zone(tex: Texture2D, sprite: Sprite2D) -> Rect2:
	var used := _used(tex)
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	# Sprite2D e centrat: pixelul (px,py) ajunge la scale * (offset + (px - w/2, py - h/2))
	var vis_st := (sprite.offset.x + float(used.position.x) - w * 0.5) * tree_scale
	var vis_sus := (sprite.offset.y + float(used.position.y) - h * 0.5) * tree_scale
	var vis_lat := float(used.size.x) * tree_scale
	var vis_inalt := float(used.size.y) * tree_scale
	var zona_lat := vis_lat * LEAF_ZONE_W
	return Rect2(
		vis_st + (vis_lat - zona_lat) * 0.5,
		vis_sus + vis_inalt * LEAF_ZONE_TOP,
		zona_lat,
		vis_inalt * (LEAF_ZONE_BOTTOM - LEAF_ZONE_TOP)
	)
