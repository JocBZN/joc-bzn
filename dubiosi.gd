extends Node2D

# DUBIOȘII generați procedural, după același tipar ca oamenii de Alba-Neagra (`albas.gd`): lumea
# e împărțită în chunk-uri, iar fiecare chunk are `dubios_chance` să conțină UNUL.
#
# ⚠️ De pe 2026-08-14 apar NUMAI ÎN NETHER (cerut de Răzvan). Generatorul ăsta e singurul din
# `World` care merge pe dos față de toate celelalte: `nether.gd::WORLD_NODES` le stinge pe toate
# la intrarea în Nether, iar „Dubiosi" e scos dinadins din lista aia ca să rămână aprins. Regula
# lui stă aici: se oprește și își golește chunk-urile ori de câte ori NU ești în Nether (vezi
# `_process` și `_goleste`). În Limbo și în Ender e stins ca tot restul lumii — acolo generatoarele
# îl trec în listele lor.
#
# Determinist: sămânța vine din cheia chunk-ului → același loc are mereu același om, chiar dacă
# pleci și te întorci. Ce diferă de la o intrare în Nether la alta e unde te scoate portalul.
#
# Nu se mai ferește de decor (copaci, pietre, statui, EGT, Alba-Neagra): Nether-ul e o câmpie de
# cărămidă goală, iar generatoarele alea sunt și oprite, și golite acolo. Se ferește, în schimb, de
# singurele două lucruri care CHIAR sunt în Nether — portalul de întoarcere și structura care îl
# chemă pe Saratalin (vezi `_prea_aproape`).
#
# ⚠️ Ține minte pe cine ai FOLOSIT deja (`_folosite`), la fel ca `chests.gd` și `albas.gd`: fără
# asta, omul ar reveni întreg de fiecare dată când chunk-ul se descarcă și se regenerează — adică
# ai fi putut juca barbut la nesfârșit cu același om, plimbându-te încolo și-ncoace.
# Vezi `dubiosu.gd::consuma`.

const DUBIOSU := preload("res://dubiosu.tscn")
const SEED_SALT := 0xD0B1  # altul decât la copaci/pietre/statui/EGT/Alba, ca să nu iasă aceleași numere

@export var chunk_size: int = 512
@export var load_radius: int = 3
# 5% din chunk-uri au unul — mai des decât oamenii de Alba-Neagra (2%), fiindcă Nether-ul ține
# 7 minute, nu toată runda, iar în ele umbli pe o bucată mică de hartă. La 2% puteai să faci un
# Nether întreg fără să dai peste niciunul.
@export var dubios_chance: float = 0.05
@export var margin: float = 120.0          # cât de departe stă de marginea chunk-ului
@export var min_dist_portal: float = 320.0 # nu stă în portalul de întoarcere / în structura lui Saratalin

var _loaded := {}
var _folosite := {}           # pozițiile oamenilor cu care ai jucat deja

func _process(_delta: float) -> void:
	if not _in_nether():
		_goleste()
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

# Ești în Nether ACUM? (`nether.gd` se anunță în grupul „nether"; `active` rămâne aprins și cât
# ești în Limbo murit acolo, dar atunci Limbo ne stinge oricum nodul.)
func _in_nether() -> bool:
	var n = get_tree().get_first_node_in_group("nether")
	return n != null and n.active

# Ai ieșit din Nether → nu mai are cine să stea pe câmp. Golim și `_loaded`, ca la următoarea
# intrare chunk-urile să se nască din nou; altfel generatorul ar crede că sunt deja făcute și
# Nether-ul ar rămâne gol pe veci (aceeași capcană ca la `nether.gd::_toggle_generator`).
#
# `_folosite` NU se golește: cu cine ai jucat o dată, ai jucat pe toată runda.
func _goleste() -> void:
	if _loaded.is_empty():
		return
	for key in _loaded:
		_loaded[key].queue_free()
	_loaded.clear()

func _chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(chunk_size)), floori(pos.y / float(chunk_size)))

# Unde e dubiosul chunk-ului (dacă are unul)? Vector2.INF = chunk-ul n-are.
func chunk_dubios_pos(key: Vector2i) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ SEED_SALT
	if rng.randf() >= dubios_chance:
		return Vector2.INF
	return Vector2(
		key.x * chunk_size + rng.randf_range(margin, chunk_size - margin),
		key.y * chunk_size + rng.randf_range(margin, chunk_size - margin)
	)

# Prea aproape de ceva cu care se bate pe „Press E"? În Nether singurele obiecte din grupul
# „interactable" sunt portalul de întoarcere și structura de invocare — restul lumii e stinsă.
#
# ⚠️ Sărim peste oamenii NOȘTRI (`is_ancestor_of`): dacă doi dubioși din chunk-uri vecine ar cădea
# la mai puțin de `min_dist_portal` unul de altul, ar începe să se anuleze pe rând, după ordinea în
# care s-au încărcat chunk-urile — adică unul din ei ar apărea și ar dispărea când te plimbi.
func _prea_aproape(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("interactable"):
		var nod := n as Node2D
		if nod == null or is_ancestor_of(nod):
			continue
		if pos.distance_to(nod.global_position) < min_dist_portal:
			return true
	return false

# Chemată de `dubiosu.gd::consuma` când omul din poziția asta și-a jucat mâna.
func marcheaza_folosit(pos_lume: Vector2) -> void:
	_folosite[_cheie(to_local(pos_lume))] = true

# Poziția, rotunjită la pixel întreg. Rotunjim ca să nu depindem de virgulele mobile: aceeași
# sămânță dă același `float` de fiecare dată, dar drumul dus-întors prin `global_position` poate
# pierde ultimul bit, iar un dicționar nu iartă nici atât. (Copiat din `chests.gd`.)
func _cheie(p: Vector2) -> Vector2i:
	return Vector2i(p.round())

func _build_chunk(key: Vector2i) -> Node2D:
	var container := Node2D.new()
	container.y_sort_enabled = true
	add_child(container)
	var pos := chunk_dubios_pos(key)
	if pos != Vector2.INF and not _folosite.has(_cheie(pos)) and not _prea_aproape(pos):
		var d := DUBIOSU.instantiate()
		d.position = pos
		container.add_child(d)
	return container
