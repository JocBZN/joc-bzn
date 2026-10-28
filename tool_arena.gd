extends Node

# UNEALTĂ: ARENA cu toți trei boșii (`arena.gd`, 2026-10-28). Se rulează ca SCENĂ, în FEREASTRĂ
# (face poze; headless iese negru):
#
#   godot --path <proiect> res://tool_arena.tscn
#
# Probează, pe drumul adevărat (main.tscn, portal adevărat, E apăsat prin `invoca()`):
#   [1] generatorul de portaluri pornește stins și, aprins, scoate portaluri pe hartă + busolă;
#   [2] cinematica: poze la fiecare jumătate de secundă (`user://arena_cut_XX.png`), timp total;
#   [3] după ea: trei boși, fiecare cu 2 000 000 viață, pe NORD / SUD / VEST sau EST, trei bare;
#   [4] niciun inamic normal nu apare (doar boșii);
#   [5] E pe portal înainte să cadă toți → refuzat, rămâi înăuntru;
#   [6] fiecare boss omorât dă UN singur nivel; victoria NU apare până nu cad toți trei;
#   [7] după ultimul: YOU WIN! apare (după Level Up), CONTINUE dă drumul jocului;
#   [8] E pe portal → ieși, podeaua revine, generatorul arenei se oprește.
# Pozele în `AppData\Roaming\Godot\app_userdata\JOC-BZN-Mobile\`.
#
# ⚠️ Player-ul are viață uriașă, ca să nu moară (moartea scrie în clasamentul adevărat). Nu apasă
# MAIN MENU pe victorie (și ăla scrie). Verifică totuși `scores.save` după rulare.

var _esecuri := 0
var _player: Node2D
var _arena: Node

func _cer(ok: bool, text: String) -> void:
	print(("  ok  " if ok else "  XX  ") + text)
	if not ok:
		_esecuri += 1

const SALVARE := "user://scores.save"
var _salvare_copie := PackedByteArray()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ⚠️ Pasul [0] omoară Sir John în castel → achievement-ul „Dead Chiverly" → `GameSettings._save()`
	# scrie salvarea ADEVĂRATĂ. O ținem în memorie și o punem la loc la final (doar dacă nu e goală).
	if FileAccess.file_exists(SALVARE):
		_salvare_copie = FileAccess.get_file_as_bytes(SALVARE)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_arena = get_tree().get_first_node_in_group("arena")
	var t := 0.0
	while get_tree().paused and t < 10.0:   # diafragma de început de rundă
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	_player.max_hp = 100000000
	_player.hp = _player.max_hp
	var world := _player.get_parent()

	print("--- [1] generatorul de portaluri ---")
	var gen := world.get_node_or_null("ArenaPortals")
	_cer(gen != null, "ArenaPortals exista in World")
	_cer(gen.cel_mai_apropiat(_player.global_position) == Vector2.INF, "stins la inceput: busola n-are ce arata")

	print("--- [0] castelul: Sir John cade -> portalurile se aprind, fara YOU WIN ---")
	var prison := get_tree().get_first_node_in_group("prison")
	var poarta: Node2D = load("res://poarta_castel.tscn").instantiate()
	world.add_child(poarta)
	poarta.global_position = _player.global_position + Vector2(0, -120)
	prison.enter(_player, poarta)
	var tc := 0.0
	while prison._cut_activ and tc < 20.0:
		await get_tree().create_timer(0.2, true).timeout
		tc += 0.2
	var sj = prison._boss
	sj.take_damage(sj.hp + 1)
	await _rezolva_level_up(4.0)
	await get_tree().create_timer(2.5).timeout
	_cer(get_tree().get_first_node_in_group("victory_screen") == null, "fara YOU WIN dupa Sir John")
	_cer(gen.activ, "Sir John cazut: generatorul arenei e aprins")
	prison.exit_prison()
	_cer(not prison.active, "iesit din castel")
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

	var cel: Vector2 = gen.cel_mai_apropiat(_player.global_position)
	_cer(cel != Vector2.INF, "aprins: cel mai apropiat portal la %.0f px" % _player.global_position.distance_to(cel))
	# mergem lângă el ca să-l vedem născut
	_player.global_position = cel + Vector2(0, 260)
	for i in 6:
		await get_tree().process_frame
	var nascute := 0
	for c in gen.get_children():
		for p in c.get_children():
			if p.get_script() == load("res://portal_arena.gd"):
				nascute += 1
	_cer(nascute >= 1, "portaluri nascute pe harta: %d" % nascute)
	var cam := _player.get_node("Camera2D") as Camera2D
	await get_tree().create_timer(0.6).timeout
	await _poza("arena_portal_lume")

	print("--- [2] cinematica ---")
	var portal: Node2D = null
	for c in gen.get_children():
		for p in c.get_children():
			if p.has_method("invoca"):
				portal = p
	_player.global_position = portal.global_position + Vector2(0, 120)
	await get_tree().process_frame
	_cer(portal.eticheta() == "Enter the Arena", "eticheta: %s" % portal.eticheta())
	var poz_intrare := _player.global_position
	portal.invoca()
	_cer(_arena.active, "arena activa dupa E")
	var n := 0
	t = 0.0
	while _arena.in_cinematic() and t < 30.0:
		await get_tree().create_timer(0.5, true).timeout
		t += 0.5
		n += 1
		if n <= 20:
			await _poza("arena_cut_%02d" % n)
	print("  cinematica a tinut ~%.1f s" % t)
	_cer(t > 3.0 and t < 15.0, "durata rezonabila")
	_cer(not get_tree().paused, "jocul a repornit")

	print("--- [3] cei trei ---")
	var bosi: Array = _arena._bosi.duplicate()
	_cer(bosi.size() == 3, "trei bosi (%d)" % bosi.size())
	var directii := []
	for b in bosi:
		_cer(b.max_hp == 2000000 and b.hp == 2000000, "%s: viata %d / %d" % [b.nume, b.hp, b.max_hp])
		_cer(b.bara_arena != null and b.bara_arena.visible, "%s: bara lui e pe ecran" % b.nume)
		var d: Vector2 = (b.global_position - poz_intrare).normalized()
		directii.append(d)
	var are_n := false
	var are_s := false
	var are_lat := 0
	for d in directii:
		if d.y < -0.8: are_n = true
		elif d.y > 0.8: are_s = true
		elif absf(d.x) > 0.8: are_lat += 1
	_cer(are_n and are_s and are_lat == 1, "unul la nord, unul la sud, unul la vest/est: %s" % [directii])
	await get_tree().create_timer(0.8).timeout
	await _poza("arena_lupta")

	print("--- [4] fara inamici normali ---")
	await get_tree().create_timer(3.0).timeout
	var straini := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e in bosi and not e.is_in_group("boss"):
			straini += 1
	_cer(straini == 0, "inamici in afara de bosi: %d" % straini)

	print("--- [5] iesirea e inchisa ---")
	portal.invoca()
	_cer(_arena.active, "E pe portal cu bosii vii: tot inauntru")

	print("--- [6] cate un nivel pe boss ---")
	for i in 3:
		var b = bosi[i]
		var nivel_inainte: int = _player.level
		var nume_b: String = str(b.nume)
		b.take_damage(b.hp + 1)
		await _rezolva_level_up(3.0)
		_cer(_player.level == nivel_inainte + 1, "%s cazut: nivel %d -> %d" % [nume_b, nivel_inainte, _player.level])
		var v := get_tree().get_first_node_in_group("victory_screen")
		if i < 2:
			_cer(v == null, "fara YOU WIN dupa %d din 3" % (i + 1))
		await get_tree().create_timer(0.4).timeout

	print("--- [7] YOU WIN! ---")
	var vic: Node = null
	t = 0.0
	while t < 10.0:
		vic = get_tree().get_first_node_in_group("victory_screen")
		if vic != null and vic.visible:
			break
		await get_tree().create_timer(0.25, true).timeout
		t += 0.25
	_cer(vic != null and vic.visible, "ecranul de victorie a aparut")
	await get_tree().create_timer(2.0, true).timeout
	await _poza("arena_victorie")
	if vic != null:
		vic._on_continua()
	await get_tree().create_timer(0.3, true).timeout
	_cer(not get_tree().paused, "CONTINUE da drumul jocului")

	print("--- [8] iesirea ---")
	_player.global_position = portal.global_position + Vector2(0, 120)
	_cer(portal.eticheta() == "Leave the Arena", "eticheta inauntru: %s" % portal.eticheta())
	portal.invoca()
	_cer(not _arena.active, "afara din arena")
	_cer(gen.oprit, "generatorul arenei s-a oprit pe runda")
	await get_tree().create_timer(1.5).timeout
	await _poza("arena_dupa")

	print("=== %s ===" % ("TOTUL OK" if _esecuri == 0 else "%d ESECURI" % _esecuri))
	if _salvare_copie.size() > 0:
		var f := FileAccess.open(SALVARE, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_salvare_copie)
			f.close()
			print("salvarea pusa la loc (%d octeti)" % _salvare_copie.size())
	get_tree().quit()

# Alege prima carte pe fiecare Level Up care se deschide, până nu mai vine niciunul.
func _rezolva_level_up(cat: float) -> void:
	var t := 0.0
	while t < cat:
		await get_tree().create_timer(0.2, true).timeout
		t += 0.2
		var lu := get_tree().get_first_node_in_group("levelup_menu")
		if lu != null and lu.visible:
			lu._on_choice(0)
			t = maxf(t, cat - 1.0)   # mai așteptăm puțin, poate vine altul

func _poza(nume: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://%s.png" % nume))
