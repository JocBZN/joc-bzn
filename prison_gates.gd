extends Node2D

# PORȚILE DE PUȘCĂRIE — generator PROPRIU, separat de `portals.gd`.
#
# ⚠️ SCHIMBAT pe 2026-08-18 (cerut de Răzvan: „la dimensiunea prison nu vreau ca portalele să se
# spawneze după ce termini Ender. Vreau să fie de la început random pe hartă cu 1% șansă de spawn
# per chunk"). Până acum poarta era A TREIA VÂRSTĂ a locurilor de portal din `portals.gd`:
#      portal Nether → (cade Saratalin) → fântână Ender → (cade Celesto) → poartă de pușcărie
# adică nu exista niciuna până nu terminai celelalte două dimensiuni. Acum lanțul ăla s-a rupt:
# `portals.gd` are din nou DOUĂ vârste (Nether → Ender) și se oprește la ieșirea din Ender, iar
# porțile de pușcărie sunt un generator de sine stătător, aprins DE LA ÎNCEPUTUL RUNDEI.
#
# Deci pușcăria nu mai e „ultima dimensiune, după toate celelalte": poți intra în ea din minutul
# zero, dacă dai peste o poartă. Inamicii de acolo rămân cei îngroșați (`prison.gd`), deci e tot
# cea mai grea — doar că acum e o alegere, nu un capăt de drum.
#
# Restul e tiparul obișnuit de generator (`portals.gd`, `statues.gd`): lumea e împărțită în
# chunk-uri, fiecare chunk are `gate_chance` să conțină O SINGURĂ poartă, iar sămânța vine din
# cheia chunk-ului → același loc are mereu aceeași poartă, chiar dacă pleci și te întorci.
#
# Arta e tot `portal_ender.tscn`, cu steagul `prison` pus ÎNAINTE de `add_child` (își citește
# pielea — culoarea verde-piatră și eticheta — în `_ready`). N-avem artă separată de poartă.

const POARTA := preload("res://portal_ender.tscn")
# Sămânță proprie, ALTA decât a portalurilor (0x9C4E) și a statuilor: altfel porțile ar cădea
# exact în aceleași chunk-uri ca portalurile Nether, iar harta ar arăta ca și cum ar fi legate.
const SEED_SALT := 0x51B7

@export var chunk_size: int = 512
@export var gate_chance: float = 0.01       # 1% din chunk-uri au o poartă (portalurile: 1.5%)
@export var load_radius: int = 3
@export var margin: float = 140.0           # cât de departe stă de marginea chunk-ului (e lată)
@export var min_dist_tree: float = 220.0    # cât de departe stă de un copac
@export var min_dist_rock: float = 180.0    # cât de departe stă de o piatră
@export var min_dist_statue: float = 260.0  # cât de departe stă de o statuie
@export var min_dist_portal: float = 320.0  # cât de departe stă de un portal/fântână (vezi mai jos)
@export var tries: int = 12                 # câte poziții încearcă până renunță la fereală

# ⚠️ Numele ăsta e citit din AFARĂ: `prison.gd::_toggle_generator` golește `_loaded` prin
# `node.set("_loaded", {})` când intri într-o dimensiune. Dacă îl redenumești, generatorul rămâne
# cu chunk-urile marcate ca încărcate și nu mai reconstruiește nimic la întoarcere.
var _loaded := {}

# Gata cu porțile în runda asta: după ce cade SIR JOHN și ieși din castel
# (`prison.gd::_inchide_poarta`). O pușcărie pe rundă, ca la celelalte dimensiuni.
var oprit := false

var _props: Node2D = null      # nodul Props (copacii)
var _rocks: Node2D = null      # nodul Rocks (pietrele)
var _statues: Node2D = null    # nodul Statues
var _portals: Node2D = null    # nodul Portals (ca să nu punem poarta peste un portal Nether)

func _ready() -> void:
	# frații din main.tscn — îi folosim ca să nu punem porți peste ei
	var p := get_parent()
	if p != null:
		_props = p.get_node_or_null("Props") as Node2D
		_rocks = p.get_node_or_null("Rocks") as Node2D
		_statues = p.get_node_or_null("Statues") as Node2D
		_portals = p.get_node_or_null("Portals") as Node2D

func _process(_delta: float) -> void:
	if oprit:
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

# Unde e poarta chunk-ului (dacă are una)? Calculat DETERMINIST, fără a crea noduri.
# Întoarce Vector2.INF dacă chunk-ul n-are poartă.
func chunk_gate_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= gate_chance:
		return Vector2.INF          # chunk-ul ăsta n-are poartă
	# încercăm câteva poziții până găsim una liberă
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key) and not _langa_piatra(p, key) \
				and not _langa_statuie(p, key) and not _langa_portal(p, key):
			return p
	# Chunk prea aglomerat → renunțăm la poartă aici, mai bine decât una înfiptă într-un copac.
	return Vector2.INF

# E poziția prea aproape de vreun copac din chunk-ul ăsta sau din cele 8 vecine?
func _langa_copac(pos: Vector2, key: Vector2i) -> bool:
	if _props == null or not _props.has_method("_chunk_trees_raw"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for t in _props._chunk_trees_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(t["pos"]) < min_dist_tree:
					return true
	return false

func _langa_piatra(pos: Vector2, key: Vector2i) -> bool:
	if _rocks == null or not _rocks.has_method("_chunk_rocks_raw"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for r in _rocks._chunk_rocks_raw(Vector2i(key.x + dx, key.y + dy)):
				if pos.distance_to(r["pos"]) < min_dist_rock:
					return true
	return false

func _langa_statuie(pos: Vector2, key: Vector2i) -> bool:
	if _statues == null or not _statues.has_method("chunk_statue_pos"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var s: Vector2 = _statues.chunk_statue_pos(Vector2i(key.x + dx, key.y + dy))
			if s != Vector2.INF and pos.distance_to(s) < min_dist_statue:
				return true
	return false

# ⚠️ Fereala asta e într-o SINGURĂ direcție, dinadins: poarta se ferește de portal, portalul nu
# știe de poartă. E de ajuns ca să nu se încalece — poziția portalului e deterministă și nu se
# uită la noi, deci dacă ne mutăm NOI, nu se mai suprapun. Invers (amândoi să se ferească unul de
# altul) ar fi o buclă: fiecare l-ar întreba pe celălalt unde stă, la nesfârșit.
#
# ⚠️ De pe 2026-08-28 sunt DOUĂ locuri de ocolit, nu unul: portalul Nether (`chunk_portal_pos`) ȘI
# fântâna Ender (`chunk_fantana_pos`), fiindcă fântâna nu mai răsare acolo unde stătea portalul,
# ci în locul ei. Le întrebăm pe amândouă de la începutul rundei, deși fântâna apare abia după
# Saratalin: pozițiile lor nu depind de vârstă, iar poarta e pusă o singură dată și nu se mai
# mută după aceea — dacă am întreba doar de vârsta curentă, fântâna ar putea răsări în ea.
func _langa_portal(pos: Vector2, key: Vector2i) -> bool:
	if _portals == null:
		return false
	var are_portal: bool = _portals.has_method("chunk_portal_pos")
	var are_fantana: bool = _portals.has_method("chunk_fantana_pos")
	if not are_portal and not are_fantana:
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var k := Vector2i(key.x + dx, key.y + dy)
			if are_portal:
				var q: Vector2 = _portals.chunk_portal_pos(k)
				if q != Vector2.INF and pos.distance_to(q) < min_dist_portal:
					return true
			if are_fantana:
				var w: Vector2 = _portals.chunk_fantana_pos(k)
				if w != Vector2.INF and pos.distance_to(w) < min_dist_portal:
					return true
	return false

# Chemată din `prison.gd` după ce l-ai bătut pe SIR JOHN și ai ieșit: din clipa aia nu mai există
# porți în runda asta. Poarta prin care ai ieșit e deja mutată în `World` (o scoate `prison.gd`
# la intrare), deci nu e printre cele șterse aici — ea se scufundă la vedere.
func opreste() -> void:
	oprit = true
	_goleste()

func _goleste() -> void:
	for key in _loaded.keys():
		if is_instance_valid(_loaded[key]):
			_loaded[key].queue_free()
	_loaded.clear()

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_gate_pos(key)
	if pos != Vector2.INF:
		var s: Node2D = POARTA.instantiate()
		# ⚠️ `prison` se pune ÎNAINTE de `add_child`: `portal_ender.gd` își citește pielea
		# (culoarea și eticheta) în `_ready()`, adică fix la intrarea în arbore. Pus după, ar
		# rămâne fântână la vedere, deși ar duce în pușcărie.
		s.prison = true
		s.position = pos
		container.add_child(s)
	return container
