extends Node2D

# Portaluri generate procedural, exact ca statuile (`statues.gd`): lumea e împărțită în
# chunk-uri, fiecare chunk are o șansă să conțină UN SINGUR portal.
#
# Determinist: sămânța vine din cheia chunk-ului → același loc are mereu același portal,
# chiar dacă pleci și te întorci.
#
# Diferența față de statui: `portal_chance` e 1.5% (față de 3% la statui), deci portalul
# apare de DOUĂ ORI mai rar. Vrei să-l vezi mai des/mai rar? Schimbi doar cifra aia.
#
# Generatorul are DOUĂ vârste: portaluri Nether până cade Saratalin, fântâni Ender după
# (`treci_pe_ender`), apoi `opreste()` la ieșirea învingătoare din Ender.
#
# ⚠️ VÂRSTELE NU MAI ÎMPART ACELEAȘI LOCURI (2026-08-28, cerut de Răzvan: „vreau ca portalul de
# Ender să nu se spawneze fix în locul celor de Nether"). Până acum fântâna răsărea EXACT unde
# stătuse portalul — aceeași poziție, doar altă scenă, fiindcă poziția se calcula fără să se uite
# la vârstă. Acum fiecare vârstă are sămânța ei (`SEED_SALT` / `SEED_SALT_ENDER`) și șansa ei
# (`portal_chance` / `ender_chance`), deci harta fântânilor e cu totul alta decât harta
# portalurilor: locurile pe care le știai din prima parte a rundei nu-ți mai spun nimic.
#
# ⚠️ Și, tot de-atunci: NICIO fântână nu se naște în raza în care ai vedea-o apărând, socotită din
# portalul prin care tocmai ai ieșit din Nether. Vezi `_iesire` / `_raza_ferita` / `ferire_ecrane`
# și `treci_pe_ender`. Ieși, portalul tău intră în pământ, iar în jur nu se schimbă nimic la
# vedere — fântânile există, dar dincolo de marginea ecranului, și trebuie găsite.
#
# ⚠️ PORȚILE DE CASTEL NU SUNT AICI, deși din nou vin după Celesto (2026-08-31). Între 2026-08-17
# și 2026-08-18 ele erau chiar A TREIA VÂRSTĂ a generatorului ăstuia: aceleași locuri, altă ușă.
# Apoi (08-18) au ieșit de tot, cu generator propriu aprins din minutul zero, iar acum (08-31) s-au
# întors la capătul lanțului — dar tot pe generatorul lor (`prison_gates.gd`, aprins din
# `ender.gd::boss_invins`). Diferența care contează: au SĂMÂNȚA lor, deci nu răsar în locurile
# portalurilor și ale fântânilor. Aici rămân două vârste, cu opririle lor.

const PORTAL := preload("res://portal.tscn")
const FANTANA := preload("res://portal_ender.tscn")   # ce naște chunk-ul după Saratalin
# Semințe proprii, ca să nu iasă la fel ca la statui/copaci/pietre. A DOUA e cea care desparte
# fântânile de portaluri: aceeași cheie de chunk, alt sare → alt zar și alte poziții.
const SEED_SALT := 0x9C4E         # vârsta NETHER
const SEED_SALT_ENDER := 0x3F2B   # vârsta ENDER

@export var chunk_size: int = 512
@export var load_radius: int = 3
@export var portal_chance: float = 0.015    # 1.5% din chunk-uri au un portal (statuile: 3%)
@export var ender_chance: float = 0.015     # cât de dese sunt fântânile Ender (buton separat)
@export var margin: float = 140.0           # cât de departe stă de marginea chunk-ului (e lat)
@export var min_dist_tree: float = 220.0    # cât de departe stă de un copac
@export var min_dist_rock: float = 180.0    # cât de departe stă de o piatră
@export var min_dist_statue: float = 260.0  # cât de departe stă de o statuie (să nu se încalece)
@export var tries: int = 12                 # câte poziții încearcă până renunță la fereală
# Cât de mare e golul din jurul portalului prin care ai ieșit din Nether, măsurat în „raze de
# ecran" (jumătatea de diagonală a zonei vizibile, calculată din viewport și zoom în `_raza_ecran`;
# la 1152×648 cu zoom 0.7 iese ~944 px).
#
# De ce 2 și nu 1: fântânile nu apar în clipa ieșirii, ci după ~1,1 s (`FANTANA_INTARZIERE` din
# `nether.gd`, cât ține scufundarea portalului), iar în timpul ăla TU mergi. Cu viteză mare (250
# de bază, dar cu Rabbit's Foot / Alex's Protection / Weird Concoction se trece lejer de 600) faci
# până la ~700-800 px. Golul trebuie să fie mai mare decât „cât fugi + cât vezi": 2 × 944 = 1888,
# minus 800 de fugă, tot rămân 1088 > 944, deci nici așa nu prinzi vreuna ivindu-se.
# 0 = fântânile se nasc oriunde, ca înainte de 2026-08-28.
@export var ferire_ecrane: float = 2.0

var _loaded := {}
# Vârsta a doua: după ce l-ai bătut pe Saratalin și ai ieșit din Nether, `nether.gd` cheamă
# `treci_pe_ender()` și de atunci chunk-urile scot FÂNTÂNI ENDER (`portal_ender.tscn`), în
# locurile LOR, nu în ale portalurilor.
var ender := false
# Închiderea definitivă pentru runda asta: după ce cade Celesto și ai ieșit din Ender (vezi
# `ender.gd::_inchide_fantana`). Cât e `true` nu mai generăm nimic — nici în chunk-urile în care
# ai fi ajuns abia peste zece minute. Porțile de castel NU se opresc odată cu noi: au
# generatorul lor (`prison_gates.gd`), care se aprinde când cade CELESTO și se stinge când cade
# SIR JOHN.
var oprit := false
# Centrul golului fără fântâni: portalul prin care ai ieșit din Nether. Vector2.INF = n-avem gol
# (înainte de ieșire, sau dacă `nether.gd` n-a apucat să ne spună de unde).
var _iesire := Vector2.INF
var _raza_ferita := 0.0       # raza golului, în pixeli de lume; calculată o dată, la ieșire
var _props: Node2D = null     # nodul Props (copacii)
var _rocks: Node2D = null     # nodul Rocks (pietrele)
var _statues: Node2D = null   # nodul Statues (ca să nu punem portalul peste o statuie)

func _ready() -> void:
	# frații din main.tscn — îi folosim ca să nu punem portaluri peste ei
	var p := get_parent()
	if p != null:
		_props = p.get_node_or_null("Props") as Node2D
		_rocks = p.get_node_or_null("Rocks") as Node2D
		_statues = p.get_node_or_null("Statues") as Node2D

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

# Unde e portalul NETHER al chunk-ului (dacă are unul)? Calculat DETERMINIST, fără a crea noduri.
# Întoarce Vector2.INF dacă chunk-ul n-are portal.
# ⚠️ Citită și din AFARĂ: `prison_gates.gd` o întreabă ca să nu pună poarta peste un portal.
func chunk_portal_pos(key: Vector2i) -> Vector2:
	return _loc_in_chunk(key, SEED_SALT, portal_chance)

# Unde e FÂNTÂNA ENDER a chunk-ului — ALT loc decât portalul, fiindcă are altă sămânță și altă
# șansă. Se poate întreba oricând, și înainte să cadă Saratalin: nu se uită la `ender`, e doar
# geometrie. (Așa o poate ocoli `prison_gates.gd`, care de pe 2026-08-31 se aprinde abia când cade
# Celesto — atunci noi suntem de obicei deja opriți, dar NU întotdeauna: dacă îl bați pe Celesto și
# apoi mori în Ender, ieșirea victorioasă nu se mai cheamă, deci fântânile rămân pe hartă lângă
# porțile proaspăt apărute. De-aia fereala trebuie să existe în continuare.)
#
# ⚠️ Golul din jurul ieșirii din Nether se aplică AICI, și SUPRIMĂ fântâna, nu o mută: dacă locul
# calculat cade prea aproape de portalul prin care ai ieșit, chunk-ul rămâne pur și simplu gol.
# Dinadins — dacă am muta-o pe altă încercare din `tries`, poziția s-ar schimba SUB porțile de
# pușcărie, care se feriseră deja de locul vechi și acum s-ar putea trezi cu o fântână în brațe.
func chunk_fantana_pos(key: Vector2i) -> Vector2:
	var p := _loc_in_chunk(key, SEED_SALT_ENDER, ender_chance)
	if p != Vector2.INF and _iesire != Vector2.INF and p.distance_to(_iesire) < _raza_ferita:
		return Vector2.INF
	return p

# Tiparul comun al celor două vârste: sămânță din cheia chunk-ului, o aruncare de zar pentru
# „are sau n-are", apoi câteva poziții încercate până iese una liberă de copaci/pietre/statui.
#
# ⚠️ Aici NU se întreabă de porțile de pușcărie, dinadins: fereala e într-o singură direcție
# (poarta se ferește de noi, noi nu de ea). Vezi `prison_gates.gd::_langa_portal` — invers ar fi
# o buclă fără fund, fiecare întrebându-l pe celălalt unde stă.
func _loc_in_chunk(key: Vector2i, salt: int, sansa: float) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ salt
	if rng.randf() >= sansa:
		return Vector2.INF          # chunk-ul ăsta n-are nimic
	# încercăm câteva poziții până găsim una liberă
	for i in tries:
		var p := Vector2(
			key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
			key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
		)
		if not _langa_copac(p, key) and not _langa_piatra(p, key) and not _langa_statuie(p, key):
			return p
	# Chunk prea aglomerat → renunțăm la portal aici, mai bine decât unul înfipt într-un copac.
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

# Statuile își știu poziția fără să existe ca noduri (`chunk_statue_pos`), deci putem
# întreba și pentru chunk-urile vecine, chiar dacă statuia de acolo nu e încă încărcată.
func _langa_statuie(pos: Vector2, key: Vector2i) -> bool:
	if _statues == null or not _statues.has_method("chunk_statue_pos"):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var s: Vector2 = _statues.chunk_statue_pos(Vector2i(key.x + dx, key.y + dy))
			if s != Vector2.INF and pos.distance_to(s) < min_dist_statue:
				return true
	return false

# Saratalin a căzut și te-ai întors în lume: de aici încolo generatorul scoate fântâni Ender, în
# ALTE locuri decât portalurile (vezi capul fișierului). Golim tot ce e încărcat ca să se refacă
# imediat, cu noua față — la cadrul următor `_process` reconstruiește aceleași chunk-uri.
#
# `loc_iesire` = portalul prin care tocmai ai ieșit, adică locul din care te uiți în clipa asta.
# În jurul lui rămâne un gol de rază `_raza_ferita`, ca să nu apară nicio fântână în câmpul tău
# vizual (cerut de Răzvan pe 2026-08-28). Fără el (Vector2.INF) nu se ferește nimic.
#
# Portalul prin care tocmai ai ieșit NU e printre cele șterse — `nether.gd` îl scoate din
# generator înainte să ne cheme, ca să apuce să intre frumos în pământ.
func treci_pe_ender(loc_iesire: Vector2 = Vector2.INF) -> void:
	if ender or oprit:
		return
	ender = true
	_iesire = loc_iesire
	if loc_iesire == Vector2.INF:
		_raza_ferita = 0.0
	else:
		_raza_ferita = _raza_ecran() * maxf(ferire_ecrane, 0.0)
	_goleste()

# Jumătatea de diagonală a zonei VIZIBILE, în pixeli de lume: viewport-ul împărțit la zoom-ul
# camerei (zoom 0.7 = se vede MAI MULT decât viewport-ul). Calculată, nu o constantă — altfel se
# strică la alt zoom sau altă rezoluție de telefon. Aceeași socoteală ca `player.gd::_raza_ecran`.
func _raza_ecran() -> float:
	var vp := get_viewport_rect().size
	var zoom := Vector2.ONE
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam != null and cam.zoom.x > 0.0 and cam.zoom.y > 0.0:
			zoom = cam.zoom
	return (vp / zoom).length() * 0.5

# Gata cu tot în runda asta: nu mai generăm nimic și ștergem ce e deja pe hartă. Chemată din
# `ender.gd`, după ce ai bătut Undead Executioner-ul și ai ieșit; fântâna prin care ai ieșit
# e și ea scoasă din generator înainte, ca să se scufunde la vedere.
# ⚠️ Nu atinge porțile de pușcărie — ele au generatorul lor (`prison_gates.gd`) și rămân pe hartă.
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
	var pos := chunk_fantana_pos(key) if ender else chunk_portal_pos(key)
	if pos != Vector2.INF:
		var s: Node2D = (FANTANA if ender else PORTAL).instantiate()
		s.position = pos
		container.add_child(s)
	return container
