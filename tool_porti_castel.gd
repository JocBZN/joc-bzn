extends Node

# UNEALTĂ (se rulează ca SCENĂ; merge și headless — nu se uită la imagine, la cifre):
#
#   godot --headless --path <proiect> res://tool_porti_castel.tscn --quit-after 900
#
# PORȚILE DE CASTEL: verifică cele trei lucruri cerute pe 2026-08-31 —
#   1. cât ține runda până cade Celesto, generatorul NU produce nimic (`activ = false`);
#   2. lanțul real `ender.boss_invins()` → `_deschide_portile_castelului()` → `porneste()`
#      chiar aprinde generatorul (asta prinde și o greșeală de nume de nod, care altfel ar
#      trece în tăcere: `_generator("PrisonGates")` întoarce `null` și nu se plânge nimeni);
#   3. șansa pe chunk e ACEEAȘI cu a portalurilor Nether și a fântânilor Ender.
#
# ⚠️ Măsurăm rata pe MULTE chunk-uri, nu pe cele din jurul player-ului: la 1.5%, cele 49 de
# chunk-uri încărcate deodată scot în medie 0,7 porți — adică de obicei niciuna. Din 6400 de
# chunk-uri ies ~380, iar o abatere reală se vede peste zgomotul de eșantionare (±20).
#
# ⚠️ Cifra măsurată iese puțin SUB 1.5% la toate trei, dinadins: `_loc_in_chunk` / `chunk_gate_pos`
# renunță la ușă dacă toate cele 12 încercări cad lângă un copac, o piatră sau o statuie. Contează
# că cele trei ies la fel, nu că nimeresc exact 1.5%.

const LATURA := 160   # 160×160 = 25600 de chunk-uri măsurate

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout

	var world := main.get_node_or_null("World")
	var porti: Node = world.get_node_or_null("PrisonGates")
	var portaluri: Node = world.get_node_or_null("Portals")
	var ender: Node = main.get_node_or_null("Ender")
	var player := get_tree().get_first_node_in_group("player") as Node2D

	# 1. înainte de Celesto: nimic
	print("1) activ=%s  chunk-uri incarcate=%d  (ambele trebuie sa fie false/0)"
		% [porti.activ, porti._loaded.size()])

	# 2. lanțul adevărat, chemat ca în joc
	ender.active = true          # `boss_invins()` iese din prima linie dacă nu ești dincolo
	ender._player = player
	ender.boss_invins()
	print("2) dupa boss_invins(): activ=%s  (trebuie true)" % porti.activ)
	ender.active = false         # îl lăsăm cum l-am găsit, altfel `_process`-ul lui pornește

	await get_tree().create_timer(0.6).timeout
	print("   chunk-uri incarcate acum=%d  (7x7 = 49)" % porti._loaded.size())

	# 3. rata, pe același teren pentru toate trei
	var n_porti := 0
	var n_portal := 0
	var n_fantana := 0
	for x in LATURA:
		for y in LATURA:
			var k := Vector2i(x - LATURA / 2, y - LATURA / 2)
			if porti.chunk_gate_pos(k) != Vector2.INF:
				n_porti += 1
			if portaluri.chunk_portal_pos(k) != Vector2.INF:
				n_portal += 1
			if portaluri.chunk_fantana_pos(k) != Vector2.INF:
				n_fantana += 1
	var total := float(LATURA * LATURA)
	print("3) din %d chunk-uri: porti %d (%.2f%%) | portaluri Nether %d (%.2f%%) | fantani Ender %d (%.2f%%)"
		% [int(total), n_porti, n_porti / total * 100.0,
			n_portal, n_portal / total * 100.0, n_fantana, n_fantana / total * 100.0])

	# 3b. proba de la capăt: mutăm player-ul într-un chunk despre care ȘTIM că are poartă și ne
	# uităm dacă nodul chiar apare pe hartă, cu pielea de castel (`prison = true`). Fără asta,
	# pașii de sus ar dovedi doar că generatorul „se învârte", nu că iese o ușă din el.
	var cheie := Vector2i.ZERO
	for x in LATURA:
		for y in LATURA:
			var k := Vector2i(x - LATURA / 2, y - LATURA / 2)
			if porti.chunk_gate_pos(k) != Vector2.INF:
				cheie = k
				break
		if cheie != Vector2i.ZERO:
			break
	player.global_position = porti.chunk_gate_pos(cheie)
	await get_tree().create_timer(0.8).timeout
	var gasite := 0
	for c in porti.get_children():
		for n in c.get_children():
			if n.get("prison") == true:
				gasite += 1
	print("3b) mutat in chunk-ul %s: porti pe harta=%d (trebuie >=1), toate cu prison=true" % [cheie, gasite])

	# 4. după SIR JOHN nu se mai redeschid
	porti.opreste()
	porti.porneste()
	print("4) opreste() apoi porneste(): activ=%s oprit=%s  (trebuie false/true)"
		% [porti.activ, porti.oprit])
	get_tree().quit()
