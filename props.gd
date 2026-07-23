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
]

@export var chunk_size: int = 512       # mărimea unui pătrat de lume (px)
@export var load_radius: int = 3        # câte pătrate în jurul player-ului ținem încărcate
@export var trees_per_chunk: int = 1    # câți copaci (maxim) într-un pătrat (înjumătățit de la 2)
@export var min_gap_hitboxes: float = 2.0  # distanța minimă între copaci, măsurată în „hitbox-uri" (2 = nu se apropie mai mult de 2 hitbox-uri)
# `tree_scale` e singura valoare încă legată de dimensiunea texturii, deci SINGURA care
# trebuie recalculată dacă mai schimbi arta. Vechii copaci (64x64) mergeau la 4.5; nu se
# împarte pur și simplu la raportul canvasului, fiindcă contează cât din canvas ocupă
# desenul: vechii aveau ~40x49px vizibili din 64. Seria curentă (2026-07-23, 6 copaci
# 128x128) are ~84-121px lățime × ~112-121px înălțime vizibilă. La 1.85 ieșeau ~215px pe
# ecran; **2.22 = cu 1.2× mai mari** (cerut de Răzvan pe 2026-07-23) → ~258px. Dacă bagi
# copaci de altă mărime, ajustează aici.
#
# Umbra se măsoară în continuare din trunchiul desenat (`_trunk`). Hitbox-ul, în schimb, e
# ACUM ACELAȘI la toți (vezi `hitbox_trunk_px`) — nu se mai măsoară per copac.
@export var tree_scale: float = 2.22    # cât de mari sunt copacii
# Hitbox uniform (cerut pe 2026-07-23): în loc să măsurăm trunchiul fiecărui copac (dădea
# cutii de mărimi diferite), pornim de la o lățime FIXĂ de trunchi, egală pentru toți.
# Poziția cutiei rămâne per-copac: centrată pe trunchiul lui, așezată pe rădăcină.
@export var hitbox_trunk_px: float = 20.0  # lățimea „de trunchi", în px de textură, folosită la TOȚI
@export var hitbox_factor: float = 0.85   # multiplicator global peste lățimea de mai sus (1.0 = exact ea)
@export var hitbox_vertical: float = 0.55 # înălțimea hitbox-ului față de lățime: 1.0 = pătrat, mai mic = mai scund
@export var hitbox_shift_y: float = 0.0   # urcă/coboară cutia față de rădăcină (negativ = mai sus)
# Cele 4 laturi — fiecare mișcă DOAR marginea ei (pozitiv = extinde afară, negativ = trage înăuntru):
@export var hitbox_north: float = 0.2      # marginea de SUS (Nord)
@export var hitbox_south: float = 0.0      # marginea de JOS (Sud)
@export var hitbox_east: float = 0.5       # marginea din DREAPTA (Est)
@export var hitbox_west: float = 0.5       # marginea din STÂNGA (Vest)
@export var sort_anchor: float = 0.35     # de la ce % din înălțime (măsurat de la bază) copacul începe să te acopere
@export var leaf_chance: float = 0.10     # ce șansă are un copac să-i cadă frunze (0.10 = 10%)
# --- umbra de la baza copacului ---
@export var shadow_alpha: float = 0.42    # cât de închisă e (0 = invizibilă, 1 = negru plin)
@export var shadow_width: float = 0.60    # lățimea ei, ca fracție din lățimea vizibilă a copacului
@export var shadow_squash: float = 0.28   # cât e de turtită: înălțime / lățime (1.0 = cerc)
@export var shadow_shift_y: float = -6.0  # o urcă/coboară față de bază (negativ = mai sus)

const LEAFFALL := preload("res://leaffall.gd")
const GroundShadow := preload("res://ground_shadow.gd")  # umbra de la bază, comună cu cactușii

# Zona în care cad frunzele, măsurată din dreptunghiurile roșii pe care le-a desenat
# Răzvan peste doi copaci în `harta/Tree Leaf Area.png`. Fracții din conturul VIZIBIL
# al copacului (nu din canvas — texturile au margini transparente).
# Cei doi copaci desenați au dat 0.99 și 1.10 lățime, 0.34/0.29 sus, 1.12/1.11 jos.
const LEAF_ZONE_W := 1.0        # lățimea zonei = lățimea copacului
const LEAF_ZONE_TOP := 0.31     # de unde începe, 0 = vârful copacului, 1 = baza lui
const LEAF_ZONE_BOTTOM := 1.11  # unde se termină (>1 = puțin sub rădăcină)

# Măsurătorile de contur/trunchi, cache-ul lor și textura de umbră stau acum în `ground_shadow.gd`
# (le folosesc și cactușii). Constantele SHADOW_TEX_SIZE / TRUNK_BAND sunt tot acolo.

@export var path_clearance: int = 2  # câte tile-uri de potecă (64px) ținem liber în jur — niciun copac pe potecă/blend

var _loaded := {}  # Vector2i (chunk) -> Node2D (containerul cu copacii lui)
var _paths: Node = null  # nodul Paths (pathways.gd) — ca să nu punem copaci pe poteci

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _paths == null:
		_paths = get_tree().get_first_node_in_group("paths")
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
		# niciun copac pe potecă sau pe blend-ul ei (+ marjă, ca nici coroana să nu treacă peste)
		if _paths != null and _paths.is_on_path(me["pos"], path_clearance):
			continue
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

# Conturul opac al texturii (fără marginile transparente) și conturul trunchiului.
#
# De ce contează trunchiul: până pe 2026-07-19 hitbox-ul se calcula din lățimea CANVASULUI, iar
# umbra din mijlocul conturului întreg — adică din coroană. Ieșea o bară lată plutind prin frunziș:
# te blocai în frunze și treceai prin trunchi. Trunchiul e ce lovești de fapt.
#
# Măsurătoarea (și cache-ul ei — scanarea pixelilor e scumpă) stă în `ground_shadow.gd`, ca s-o
# poată folosi și cactușii din `desert_structures.gd`. Aici rămân doar scurtăturile.
func _used(tex: Texture2D) -> Rect2i:
	return GroundShadow.used_rect(tex)

func _trunk(tex: Texture2D) -> Rect2i:
	return GroundShadow.trunk_rect(tex)

# Lățimea hitbox-ului în pixeli de lume. UNIFORMĂ: aceeași pentru toți copacii (nu mai depinde
# de `tex`), pornind de la `hitbox_trunk_px`. Un singur loc care o calculează, ca verificarea
# de distanță dintre copaci și cutia de coliziune să folosească aceeași valoare.
func _hitbox_w(_tex: Texture2D) -> float:
	return hitbox_trunk_px * tree_scale * hitbox_factor

# Umbra de la baza copacului: elipsă turtită, așezată pe rădăcină. Vezi `ground_shadow.gd`.
func _make_shadow(tex: Texture2D, sprite: Sprite2D) -> Sprite2D:
	return GroundShadow.make(tex, sprite, tree_scale,
		shadow_alpha, shadow_width, shadow_squash, shadow_shift_y)

# Mijlocul trunchiului și linia solului, în coordonatele nodului. Le folosește și hitbox-ul,
# nu doar umbra — de-aia rămân scurtături aici. Calculul e în `ground_shadow.gd`.
func _trunk_center_x(tex: Texture2D, sprite: Sprite2D) -> float:
	return GroundShadow.trunk_center_x(tex, sprite, tree_scale)

func _base_y(tex: Texture2D, sprite: Sprite2D) -> float:
	return GroundShadow.base_y(tex, sprite, tree_scale)

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
