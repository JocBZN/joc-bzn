extends Node2D

# PORȚILE DE CASTEL — generator PROPRIU, separat de `portals.gd`.
#
# ⚠️ CÂND SE APRINDE — SCHIMBAT pe 2026-08-31 (cerut de Răzvan: „vreau să se spawneze Castle
# Dimension după ce termină playerul de bătut pe Celesto și vreau să aibă spawn rate la fel ca
# celelalte"). Generatorul pornește STINS (`activ = false`) și îl aprinde `ender.gd::boss_invins()`,
# adică fix în clipa în care cade CELESTO, boss-ul Ender-ului. Cât e stins, `_process` iese din
# prima linie: zero chunk-uri calculate, zero porți pe hartă.
#
# Deci lanțul dimensiunilor e din nou unul singur, dar acum are patru verigi:
#      portal Nether → (cade Saratalin) → fântână Ender → (cade Celesto) → poartă de castel
# Castelul redevine CAPĂTUL drumului, cum era între 2026-08-17 și 2026-08-18. Diferența față de
# atunci — și motivul pentru care generatorul rămâne separat — e că porțile NU mai sunt „a treia
# vârstă" a locurilor din `portals.gd`: au sămânța lor (`SEED_SALT`) și harta lor, deci nu răsar
# unde stăteau portalurile Nether sau fântânile Ender. Aceeași regulă pe care au primit-o și
# fântânile pe 2026-08-28: fiecare ușă are locurile ei, iar ce știai din partea de dinainte a
# rundei nu-ți mai spune nimic.
#
# 🔑 De ce la MOARTEA lui Celesto și nu la ieșirea din Ender: „termină de bătut" înseamnă boss-ul
# căzut. Sunt și două motive practice. Unul, la ieșire porțile s-ar naște oricum abia atunci —
# generatorul e stins cât ești dincolo, iar `ender.gd::_set_world_enabled(true)` îl aprinde la loc
# în aceeași clipă cu tot restul decorului, deci nu vezi nicio poartă „pocnind" lângă tine, apare
# odată cu copacii și pietrele. Doi, dacă îl bați pe Celesto și MORI acolo, ieșirea victorioasă
# (`_inchide_fantana`) nu se mai cheamă niciodată — legat de ea, castelul ar fi rămas închis pe
# rundă deși boss-ul căzuse.
#
# Între 2026-08-18 și 2026-08-31 porțile erau aprinse DE LA ÎNCEPUTUL rundei, cu 1% pe chunk
# (atunci ceruse Răzvan asta), și puteai intra în castel din minutul zero. Nu era o greșeală, era
# altă alegere de design; dacă se vrea înapoi, se șterge `activ` și garda din `_process`.
#
# Restul e tiparul obișnuit de generator (`portals.gd`, `statues.gd`): lumea e împărțită în
# chunk-uri, fiecare chunk are `gate_chance` să conțină O SINGURĂ poartă, iar sămânța vine din
# cheia chunk-ului → același loc are mereu aceeași poartă, chiar dacă pleci și te întorci.
#
# ⚠️ ARTA: de pe 2026-09-01 poarta are SCENA EI, `poarta_castel.tscn` (arcadă de piatră cu ușă
# dublă de lemn, din `harta/castle/Castle_Door_Portal.png`). Până atunci era `portal_ender.tscn`
# cu un steag `prison` pus înainte de `add_child` — adică fântâna Ender spălată în verde. Steagul
# a dispărut cu totul din `portal_ender.gd`; aici nu se mai pune nimic la naștere.

const POARTA := preload("res://poarta_castel.tscn")
# Sămânță proprie, ALTA decât a portalurilor (0x9C4E) și a statuilor: altfel porțile ar cădea
# exact în aceleași chunk-uri ca portalurile Nether, iar harta ar arăta ca și cum ar fi legate.
const SEED_SALT := 0x51B7

@export var chunk_size: int = 512
# 1.5% din chunk-uri au o poartă — ACEEAȘI cifră ca portalurile Nether și fântânile Ender
# (`portals.gd::portal_chance` / `ender_chance`), cerut de Răzvan pe 2026-08-31 („vreau să aibă
# spawn rate la fel ca celelalte"). Era 1% de pe 2026-08-18, când porțile existau de la începutul
# rundei și erau al treilea fel de ușă pe hartă în același timp cu celelalte; acum ele apar SINGURE
# pe hartă (portalurile și fântânile sunt deja închise când cade Celesto), deci n-are ce să
# aglomereze și n-are de ce să fie mai rară.
@export var gate_chance: float = 0.015
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

# ⚠️ PORNIT DIN AFARĂ, NU DE LA ÎNCEPUT (2026-08-31). Cât e `false` nu se naște nicio poartă și
# `_process` iese din prima linie — adică nici nu se calculează nimic. Îl aprinde `porneste()`,
# chemată de `ender.gd` în clipa în care cade CELESTO. Vezi capul fișierului.
var activ := false

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
	if not activ or oprit:
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
# ci în locul ei. Amândouă se pot întreba oricând — pozițiile lor sunt geometrie, nu depind de
# vârsta generatorului lor.
#
# 🔑 De ce mai are rost fereala asta, de când noi ne naștem abia după Celesto (2026-08-31), adică
# după ce portalurile și fântânile s-au închis: fiindcă „s-au închis" nu e garantat. Închiderea lor
# (`portals.opreste()`) se cheamă din ieșirea VICTORIOASĂ din Ender. Dacă îl bați pe Celesto și
# apoi MORI acolo, ieșirea aia nu se mai cheamă niciodată, iar fântânile rămân pe hartă — lângă
# porțile care tocmai s-au aprins. Costă ~8% din porți (aruncate ca prea apropiate) și cumpără
# liniștea că nu se încalecă două uși.
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

# CELESTO A CĂZUT → de aici încolo lumea scoate porți de castel. Chemată din `ender.gd::boss_invins()`,
# în clipa în care moare boss-ul Ender-ului (vezi capul fișierului pentru „de ce atunci").
#
# Nu ne uităm NOI, în fiecare cadru, dacă a căzut (`ender.celesto_invins`) — cine schimbă starea ne
# spune. Aceeași regulă ca la `portal_ender.gd::set_cosmic` și `portals.gd::treci_pe_ender`.
#
# ⚠️ Se cheamă în timp ce suntem STINȘI (`process_mode = DISABLED`, ne-a stins `ender.gd` la
# intrarea în dimensiune). E în regulă: un nod stins nu-și mai rulează `_process`, dar metodele lui
# se pot chema normal. Steagul rămâne pus, iar porțile se nasc la ieșire, în clipa în care
# `_set_world_enabled(true)` aprinde la loc tot decorul.
func porneste() -> void:
	if oprit:
		return   # castelul s-a consumat deja în runda asta (a căzut SIR JOHN)
	activ = true

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
		s.position = pos
		container.add_child(s)
	return container
