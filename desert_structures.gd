extends Node2D

# Structuri de deșert (cactuși, case abandonate, monumente) generate procedural în jurul player-ului.
# Apar DOAR în deșert. Model de generare:
#   • CACTUS   = împrăștiat per-chunk (mulți), în deșert + gradient de la DESERT_MIN în sus.
#   • HOUSE    = garantat houses_min..houses_max PER DEȘERT, doar în deșertul plin (≥ min_inset_px de gradient).
#   • MONUMENT = cu șansa monument_chance PER DEȘERT (0.5 = unul la 2 deșerturi), doar în deșertul plin.
# Casele/monumentele sunt legate de „identitatea" deșertului (macro-celula lui) → deterministe și
# independente de chunk. FIECARE structură are propriul scale + hitbox (vezi CONFIG). Totul se auto-descarcă.

const GroundShadow := preload("res://ground_shadow.gd")  # umbra de la bază, comună cu copacii

const STRUCT_DIR := "res://harta/desert structures/"
const SEED_CACTUS := 0xCAC705   # sămânța împrăștierii de cactuși (per-chunk)
const SEED_SPECIAL := 0x5DEC1A  # sămânța caselor/monumentelor (per-deșert)
const DESERT_MIN := 0.7         # deșert-ime minimă pentru cactuși (1.0 = deșert plin; 0.7 = 70% din gradient)

# --- Config PER STRUCTURĂ: scale + hitbox propriu pentru fiecare tip. Reglează aici cum vrei. ---
# Cheia = o bucată din numele fișierului (cactus / house / monument). Câmpuri:
#   scale, hitbox_factor, hitbox_vertical, sort_anchor, north/south/east/west (ca la copaci/pietre).
#   min_inset_px (opțional) = structura stă la ≥ atâția px în deșertul plin, față de marginea gradientului.
const CONFIG := {
	"cactus": {
		"scale": 1.5, "hitbox_factor": 0.22, "hitbox_vertical": 0.35, "sort_anchor": 0.30,
		"north": 0.0, "south": 0.0, "east": 0.0, "west": 0.0,
		# umbră la bază, ca la copaci (vezi `shadow` mai jos). Cactusul e mult mai îngust decât un
		# copac, deci lățimea e o fracție mai mare din conturul lui — altfel iese o pată de nimic.
		"shadow": {"alpha": 0.42, "width": 0.85, "squash": 0.30, "shift_y": -2.0},
	},
	"house": {
		"scale": 3.5, "hitbox_factor": 0.42, "hitbox_vertical": 0.55, "sort_anchor": 0.55,
		"north": 0.05, "south": -0.3, "east": 0.0, "west": 0.0,
		"min_inset_px": 20.0,  # la ≥20px de marginea gradientului (nu pe gradient)
	},
	"monument": {
		"scale": 3.5, "hitbox_factor": 0.35, "hitbox_vertical": 0.50, "sort_anchor": 0.50,
		"north": 0.08, "south": -0.2, "east": 0.1, "west": 0.1,
		"min_inset_px": 1.0,  # niciodată pe gradient — doar în deșertul plin
	},
}
const DEFAULT_CFG := {
	"scale": 1.0, "hitbox_factor": 0.35, "hitbox_vertical": 0.50, "sort_anchor": 0.35,
	"north": 0.0, "south": 0.0, "east": 0.0, "west": 0.0,
}

@export var chunk_size: int = 512          # mărimea unui pătrat de lume (px) — ca în props.gd/rocks.gd
@export var load_radius: int = 3           # câte pătrate în jurul player-ului ținem încărcate
@export var cacti_per_chunk: int = 2       # câți cactuși (maxim) pe chunk de deșert (mai mult = deșert mai plin)
@export var houses_min: int = 1            # case GARANTATE per deșert
@export var houses_max: int = 2            # case maxim per deșert
@export var monument_chance: float = 0.5   # șansa ca un deșert să aibă un monument (0.5 = unul la 2 deșerturi)
@export var min_gap_hitboxes: float = 3.0  # distanța minimă cactus-cactus (și cactus-structură), în „hitbox-uri"

var _by_name := {}  # "cactus"/"house"/"monument" -> {"tex": Texture2D, "cfg": Dictionary}
var _loaded := {}   # Vector2i (chunk) -> Node2D (containerul cu structurile lui)

func _ready() -> void:
	_load_dir(STRUCT_DIR)
	print("Structuri deșert încărcate: %d tipuri" % _by_name.size())

# Tipul (cheia din CONFIG) după numele fișierului. "" dacă nu se potrivește cu niciunul.
func _type_key(fname: String) -> String:
	var n := fname.to_lower()
	for k in CONFIG:
		if n.contains(k):
			return k
	return ""

# Încarcă .png din folder (la RULARE, ca la rocks.gd) și le indexează pe tip.
func _load_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Desert structures: nu găsesc folderul " + path)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.to_lower().ends_with(".png"):
			continue
		var tex := load(path + f) as Texture2D
		if tex == null:
			continue
		var k := _type_key(f)
		if k == "":
			continue  # sprite necunoscut → nu-l plasăm (folderul are cactus/house/monument)
		_by_name[k] = {"tex": tex, "cfg": CONFIG.get(k, DEFAULT_CFG)}

func _process(_delta: float) -> void:
	if _by_name.is_empty():
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

func _in_chunk(pos: Vector2, key: Vector2i) -> bool:
	return floori(pos.x / float(chunk_size)) == key.x and floori(pos.y / float(chunk_size)) == key.y

# O poziție aleatoare în dreptunghiul de deșert, retrasă cu inset_px de la margini (→ nu pe gradient).
func _rand_in_rect_inset(rng: RandomNumberGenerator, rect: Rect2i, inset_px: float) -> Vector2:
	var lo_x := rect.position.x * chunk_size + inset_px
	var lo_y := rect.position.y * chunk_size + inset_px
	var hi_x := (rect.position.x + rect.size.x) * chunk_size - inset_px
	var hi_y := (rect.position.y + rect.size.y) * chunk_size - inset_px
	if hi_x < lo_x:
		hi_x = lo_x
	if hi_y < lo_y:
		hi_y = lo_y
	return Vector2(rng.randf_range(lo_x, hi_x), rng.randf_range(lo_y, hi_y))

# --- CACTUS: împrăștiere per-chunk (deșert + gradient de la DESERT_MIN) ---
func _cacti_in_chunk(key: Vector2i) -> Array:
	var out := []
	if not _by_name.has("cactus"):
		return out
	var c: Dictionary = _by_name["cactus"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_CACTUS
	var count := rng.randi_range(0, cacti_per_chunk)
	for i in count:
		var pos := Vector2(
			key.x * chunk_size + rng.randf_range(0.0, chunk_size),
			key.y * chunk_size + rng.randf_range(0.0, chunk_size)
		)
		if BiomeMap.desertness_at_chunk(pos / float(chunk_size)) < DESERT_MIN:
			continue
		out.append({"pos": pos, "tex": c["tex"], "cfg": c["cfg"], "key": key, "special": false})
	return out

# --- HOUSE + MONUMENT: legate de deșert (macro-celulă). Deterministe → aceleași poziții din orice chunk;
#     fiecare chunk păstrează doar ce cade în el. Poziționate direct în interiorul valid (inset). ---
func _special_in_chunk(key: Vector2i) -> Array:
	var out := []
	var mc := BiomeMap.macro_of_chunk(key.x, key.y)
	var rect := BiomeMap.desert_rect_of_macro(mc.x, mc.y)
	if rect.size.x == 0:
		return out  # chunk-ul nu e într-o macro-celulă cu deșert
	var drng := RandomNumberGenerator.new()
	drng.seed = hash(mc) ^ SEED_SPECIAL
	# CASE: houses_min..houses_max garantate per deșert
	if _by_name.has("house"):
		var hc: Dictionary = _by_name["house"]
		var inset: float = hc["cfg"].get("min_inset_px", 0.0)
		var n := drng.randi_range(houses_min, houses_max)
		for i in n:
			var p := _rand_in_rect_inset(drng, rect, inset)
			if _in_chunk(p, key):
				out.append({"pos": p, "tex": hc["tex"], "cfg": hc["cfg"], "key": key, "special": true})
	# MONUMENT: monument_chance per deșert (unul la 2 deșerturi la 0.5)
	if _by_name.has("monument"):
		var has_monument := drng.randf() < monument_chance
		if has_monument:
			var mo: Dictionary = _by_name["monument"]
			var inset2: float = mo["cfg"].get("min_inset_px", 0.0)
			var p := _rand_in_rect_inset(drng, rect, inset2)
			if _in_chunk(p, key):
				out.append({"pos": p, "tex": mo["tex"], "cfg": mo["cfg"], "key": key, "special": true})
	return out

# Toate structurile brute ale unui chunk (specialele întâi → cactușii le evită la spacing).
func _chunk_structs_raw(key: Vector2i) -> Array:
	var out := _special_in_chunk(key)
	out.append_array(_cacti_in_chunk(key))
	return out

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var mine := _chunk_structs_raw(key)
	var neighbors := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			neighbors.append_array(_chunk_structs_raw(Vector2i(key.x + dx, key.y + dy)))
	for i in mine.size():
		var s: Dictionary = mine[i]
		# specialele (case/monument) se pun MEREU; doar cactușii sar dacă-s prea aproape de ceva
		if not s.get("special", false) and _too_close(mine[i], i, mine, neighbors):
			continue
		var node := _make_struct(s["tex"], s["cfg"])
		node.position = s["pos"]
		node.position.y -= node.get_meta("sort_shift")
		container.add_child(node)
	return container

# Lățimea de hitbox a unei structuri (pentru distanța minimă), cu scale-ul EI.
func _hitbox_width(item: Dictionary) -> float:
	var tex: Texture2D = item["tex"]
	var cfg: Dictionary = item["cfg"]
	return tex.get_width() * cfg["hitbox_factor"] * cfg["scale"] * 2.0

func _min_dist(a: Dictionary, b: Dictionary) -> float:
	return min_gap_hitboxes * (_hitbox_width(a) + _hitbox_width(b)) * 0.5

func _too_close(me: Dictionary, my_index: int, mine: Array, neighbors: Array) -> bool:
	for j in my_index:
		var other: Dictionary = mine[j]
		if me["pos"].distance_to(other["pos"]) < _min_dist(me, other):
			return true
	var my_key: Vector2i = me["key"]
	for other in neighbors:
		var ok: Vector2i = other["key"]
		var key_smaller := ok.x < my_key.x or (ok.x == my_key.x and ok.y < my_key.y)
		if key_smaller and me["pos"].distance_to(other["pos"]) < _min_dist(me, other):
			return true
	return false

func _make_struct(tex: Texture2D, cfg: Dictionary) -> StaticBody2D:
	var sc: float = cfg["scale"]
	var hf: float = cfg["hitbox_factor"]
	var hv: float = cfg["hitbox_vertical"]
	var sa: float = cfg["sort_anchor"]
	var body := StaticBody2D.new()
	var h := float(tex.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(sc, sc)
	sprite.offset = Vector2(0, h * (sa - 0.5))
	body.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var base_w := tex.get_width() * hf * sc * 2.0
	var base_h := base_w * hv
	var north_extra := base_w * float(cfg["north"])
	var south_extra := base_w * float(cfg["south"])
	var east_extra := base_w * float(cfg["east"])
	var west_extra := base_w * float(cfg["west"])
	shape.size = Vector2(base_w + west_extra + east_extra, base_h + north_extra + south_extra)
	col.shape = shape
	var center_x := (east_extra - west_extra) / 2.0
	var center_y := (south_extra - north_extra) / 2.0
	col.position = Vector2(center_x, (sa - 0.25) * h * sc + center_y)
	body.add_child(col)
	# Umbră la bază, doar pentru tipurile care au cheia „shadow" în CONFIG (deocamdată doar cactusul —
	# casa și monumentul n-au fost cerute, iar la ele o elipsă turtită sub un perete drept arată prost).
	# Aceeași funcție ca la copaci: `ground_shadow.gd`.
	if cfg.has("shadow"):
		var s: Dictionary = cfg["shadow"]
		body.add_child(GroundShadow.make(tex, sprite, sc,
			s["alpha"], s["width"], s["squash"], s["shift_y"]))
	body.set_meta("sort_shift", sa * h * sc)
	return body
