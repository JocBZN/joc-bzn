extends Node2D

# UNEALTĂ DE VERIFICARE pentru regula cerută de Răzvan pe 2026-08-28:
#   1. fântânile Ender NU se mai nasc în locurile portalurilor Nether;
#   2. niciuna nu răsare în câmpul vizual al player-ului, socotit din portalul prin care a ieșit.
#
# Rulează pe LUMEA ADEVĂRATĂ (instanțiază `main.tscn`), ca să folosească generatoarele reale
# (copaci, pietre, statui) și camera reală — cifrele scoase de un `Portals` gol ar fi minciună,
# fiindcă acolo nicio poziție nu e respinsă.
#
#   "<godot.exe>" --headless --path <proiect> res://tool_portale_ender.tscn --quit-after 1500
#
# Trebuie să scrie REZULTAT: OK. Dacă scrie PICAT, s-a stricat una din cele două reguli.

const RAZA := 60          # câte chunk-uri în fiecare direcție măsurăm (121x121 = 14641)
const FUGA := 800.0       # cât apucă să fugă un player rapid în ~1,1 s, cât ține scufundarea
const TOLERANTA := 8.0    # nodul `Portals` stă la global (1, 0), deci poziția iese cu 1 px lângă

func _ready() -> void:
	add_child(load("res://main.tscn").instantiate())
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		print("!! n-am gasit player-ul"); get_tree().quit(); return
	var portals := player.get_parent().get_node_or_null("Portals")
	if portals == null:
		print("!! n-am gasit nodul Portals"); get_tree().quit(); return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	print("zoom camera: ", cam.zoom if cam != null else "fara camera", "   viewport: ", get_viewport_rect().size)
	print("raza ecranului: ", "%.0f" % portals._raza_ecran(), " px")
	# ⚠️ Măsurăm în jurul PLAYER-ului, nu în jurul originii: `main.tscn` te lasă în lume la
	# coordonate mari și diferite de la o rulare la alta, deci o grilă centrată pe (0,0) ar cădea
	# la zeci de mii de px de golul pe care vrem să-l verificăm — și „0 fântâni în gol" ar ieși
	# adevărat degeaba. Prins pe 2026-08-28, la prima rulare a uneltei.
	var pc0: Vector2i = portals._chunk_of(player.global_position)

	# --- 1. Sunt hărți DIFERITE? ---
	var portaluri: Array[Vector2] = []
	var fantani: Array[Vector2] = []
	for cx in range(-RAZA, RAZA + 1):
		for cy in range(-RAZA, RAZA + 1):
			var k := Vector2i(pc0.x + cx, pc0.y + cy)
			var p: Vector2 = portals.chunk_portal_pos(k)
			if p != Vector2.INF:
				portaluri.append(p)
			var f: Vector2 = portals.chunk_fantana_pos(k)
			if f != Vector2.INF:
				fantani.append(f)
	var chunkuri := (2 * RAZA + 1) * (2 * RAZA + 1)
	print("--- harti ---")
	print("chunk-uri masurate: ", chunkuri)
	print("portaluri Nether: ", portaluri.size(), "  fantani Ender: ", fantani.size())
	var suprapuse := 0
	for f in fantani:
		for p in portaluri:
			if f.distance_to(p) < TOLERANTA:
				suprapuse += 1
	print("fantani nascute PE un portal (trebuie 0): ", suprapuse)

	# --- 2. Golul din jurul ieșirii, în cazul cel mai rău ---
	# Ca în joc: locul se reține la ieșire, dar fântânile apar abia după ~1,1 s
	# (`nether.gd::FANTANA_INTARZIERE`), timp în care player-ul FUGE. Îl mutăm `FUGA` px și abia
	# apoi chemăm generatorul, cu poziția PORTALULUI — cum face `nether.gd::_pune_fantanile`.
	#
	# ⚠️ Ieșim DINTR-UN LOC DE FÂNTÂNĂ, dinadins: așa e sigur că golul chiar are ce să suprime.
	# Dacă am ieși dintr-un punct oarecare, de cele mai multe ori n-ar fi nicio fântână în rază
	# (densitatea e ~1 la 17 milioane de px²) și testul ar trece fără să fi verificat nimic.
	var iesire := player.global_position
	var d_i := INF
	for f in fantani:
		if f.distance_to(player.global_position) < d_i:
			d_i = f.distance_to(player.global_position)
			iesire = f
	# câte fântâni ERAU în viitorul gol, înainte să-l cerem
	var raza_viitoare: float = portals._raza_ecran() * portals.ferire_ecrane
	var inainte := 0
	for f in fantani:
		if f.distance_to(iesire) < raza_viitoare:
			inainte += 1
	player.global_position = iesire + Vector2(FUGA, 0)
	portals.treci_pe_ender(iesire)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("--- golul ---")
	print("raza golului: ", "%.0f" % portals._raza_ferita, " px   (player fugit ", FUGA, " px de la iesire)")
	print("fantani care erau in raza aia inainte: ", inainte, "  (trebuie >= 1, altfel n-am testat nimic)")

	var in_gol := 0
	var ramase := 0
	var d_iesire := INF
	for cx in range(-RAZA, RAZA + 1):
		for cy in range(-RAZA, RAZA + 1):
			var f: Vector2 = portals.chunk_fantana_pos(Vector2i(pc0.x + cx, pc0.y + cy))
			if f == Vector2.INF:
				continue
			ramase += 1
			d_iesire = minf(d_iesire, f.distance_to(iesire))
			if f.distance_to(iesire) < portals._raza_ferita:
				in_gol += 1
	print("fantani ramase pe harta: ", ramase, " (erau ", fantani.size(), ", deci ", fantani.size() - ramase, " suprimate)")
	print("fantani IN GOL (trebuie 0): ", in_gol)
	print("cea mai apropiata fantana de iesire: ", "%.0f" % d_iesire, " px = ", "%.2f" % (d_iesire / maxf(portals._raza_ecran(), 1.0)), " ecrane")

	# Și în cadru, de la OCHIUL player-ului (nu de la portal), cu tot cu fuga lui:
	var vizibile := 0
	for f in _fantani(portals):
		if f.global_position.distance_to(player.global_position) < portals._raza_ecran():
			vizibile += 1
	print("fantani incarcate acum: ", _fantani(portals).size(), "   IN CADRU (trebuie 0): ", vizibile)

	# --- 3. Fântânile EXISTĂ totuși ---
	# Fără proba asta, un „0 în cadru" ar trece și dacă generatorul s-ar fi stricat de tot.
	var pc: Vector2i = portals._chunk_of(player.global_position)
	var tinta := Vector2.INF
	var d_tinta := INF
	for cx in range(pc.x - 12, pc.x + 13):
		for cy in range(pc.y - 12, pc.y + 13):
			var q: Vector2 = portals.chunk_fantana_pos(Vector2i(cx, cy))
			if q != Vector2.INF and q.distance_to(player.global_position) < d_tinta:
				d_tinta = q.distance_to(player.global_position)
				tinta = q
	if tinta == Vector2.INF:
		print("!! nicio fantana in 25x25 chunk-uri — suspect"); get_tree().quit(); return
	player.global_position = tinta
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var gasit: Node2D = null
	for f in _fantani(portals):
		if f.global_position.distance_to(tinta) < TOLERANTA:
			gasit = f
	print("--- fantana la fata locului ---")
	if gasit == null:
		print("mers ", "%.0f" % d_tinta, " px pana la ea: NU S-A NASCUT")
	else:
		print("mers ", "%.0f" % d_tinta, " px pana la ea: ", gasit.get_class(), ", interactable: ", gasit.is_in_group("interactable"))

	var ok := suprapuse == 0 and in_gol == 0 and vizibile == 0 and ramase > 0 and inainte >= 1 \
			and gasit != null and gasit.is_in_group("interactable")
	print("REZULTAT: ", "OK" if ok else "PICAT")
	get_tree().quit()

func _fantani(portals: Node) -> Array:
	var out: Array = []
	for c in portals.get_children():
		for f in c.get_children():
			out.append(f)
	return out
