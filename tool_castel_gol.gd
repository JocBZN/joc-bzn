extends Node

# UNEALTĂ (se rulează ca SCENĂ, în FEREASTRĂ — face poze; headless iese negru):
#
#   godot --path <proiect> res://tool_castel_gol.tscn
#
# CASTELUL GOL (2026-09-22). Pe 2026-09-18 castelul primise o hartă făcută de mână
# (`castel_harta.gd`: ziduri, turnuri, arcade, lăzi, butoaie); Răzvan a cerut-o scoasă de tot
# („scoate pereti si structurile din dimensiunea castel, vreau sa fie ca inainte"), deci e din nou
# ce era până atunci: un DISC de lespezi cu raza 3000, gol, cu poarta în mijloc.
#
# Unealta intră în castel pe drumul adevărat (`prison.enter` cu o poartă adevărată) și verifică:
#   1. în `World` nu mai există niciun nod de hartă (`CastelHarta`) și niciun zid;
#   2. marginea e iar DISCUL: `ground.margine_raza == 3000`, `margine_rect` nu mai există;
#   3. player-ul împins în cele patru zări se oprește pe cerc, la 3000 de poartă;
#   4. poze: una de sus cu toată curtea, una la mărime de joc lângă poartă;
#   5. la ieșire, castelul se stinge (`prison.active == false`).
# Pozele: `user://gol_*.png` (AppData\Roaming\Godot\app_userdata\JOC-BZN-Mobile\).
#
# ⚠️ Nu lasă player-ul să moară (ar scrie în clasamentul adevărat): inamicii se șterg la fiecare
# pas, iar SIR JOHN e ținut pe loc.

var _player: Node2D
var _prison: Node
var _cam: Camera2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prison = get_tree().get_first_node_in_group("prison")
	_cam = _player.get_node("Camera2D") as Camera2D
	var t := 0.0
	while get_tree().paused and t < 10.0:
		await get_tree().create_timer(0.2).timeout
		t += 0.2

	var poarta: Node2D = load("res://poarta_castel.tscn").instantiate()
	var world := _player.get_parent()
	world.add_child(poarta)
	poarta.global_position = _player.global_position + Vector2(0, -120)
	_prison.enter(_player, poarta)
	t = 0.0
	while _prison._cut_activ and t < 30.0:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	print("cinematica gata dupa %.1f s" % t)

	# 1. nicio hartă în World
	var gasite: Array[String] = []
	for c in world.get_children():
		if str(c.name).findn("castel") >= 0 or str(c.name).findn("harta") >= 0:
			gasite.append(str(c.name))
	print("noduri de harta in World: %s  (gol = bine)" % [gasite])
	print("prison are _harta: %s  (false = bine)" % ("_harta" in _prison))

	# 2. marginea e discul
	var ground := get_tree().get_first_node_in_group("ground")
	var c0: Vector2 = _prison.portal_pos()
	print("margine_raza=%.0f (astept 3000)  centru=%s  poarta=%s" % [ground.margine_raza, ground.margine_centru, c0])
	print("ground are set_margine_dreptunghi: %s  (false = bine)" % ground.has_method("set_margine_dreptunghi"))

	# 3. oprirea pe cerc
	for dir in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		_player.global_position = c0 + dir * 5000.0
		for i in 4:
			await get_tree().physics_frame
		print("margine %s -> dist=%.0f de poarta" % [dir, _player.global_position.distance_to(c0)])

	# 4. poze
	_cam.position_smoothing_enabled = false
	_cam.zoom = Vector2(0.16, 0.16)
	await _poza(c0, "gol_sus")
	_cam.zoom = Vector2(0.7, 0.7)
	await _poza(c0 + Vector2(0, 150), "gol_poarta")
	await _poza(c0 + Vector2(0, -2600), "gol_nord")

	# 5. ieșirea
	_player.global_position = c0 + Vector2(0, 150)
	_prison._boss_invins = true
	_prison.exit_prison(true)
	await get_tree().create_timer(0.3).timeout
	print("dupa iesire: prison.active=%s  margine_raza=%.0f" % [_prison.active, ground.margine_raza])
	get_tree().quit()

func _poza(unde: Vector2, nume: String) -> void:
	_player.global_position = unde
	_linisteste()
	_cam.force_update_scroll()
	for i in 6:
		await get_tree().process_frame
		_linisteste()
	await get_tree().create_timer(0.25).timeout
	_linisteste()
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://%s.png" % nume))

func _linisteste() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == _prison._boss:
			e.process_mode = Node.PROCESS_MODE_DISABLED
			e.global_position = _prison.portal_pos() + Vector2(700, 300)
		else:
			e.queue_free()
	if "hp" in _player and "max_hp" in _player:
		_player.hp = _player.max_hp
