extends Node

# UNEALTĂ (se rulează ca SCENĂ, în FEREASTRĂ — face poze; headless iese negru):
#
#   godot --path <proiect> res://tool_castel_harta.tscn
#
# HARTA CASTELULUI LUI SIR JOHN (`castel_harta.gd`, 2026-09-18). Intră în castel pe drumul
# adevărat (`prison.enter` cu o poartă adevărată), așteaptă cinematica, apoi:
#   1. o poză de SUS cu toată curtea (camera depărtată);
#   2. poze la mărime de joc în locurile care contează: poarta, zidul de nord, turnurile, cele patru sferturi ale curții;
#   3. marginea: player-ul pus dincolo de fiecare zid trebuie să rămână ÎNĂUNTRU;
#   4. ieșirea: harta trebuie să dispară.
# Pozele: `user://castel_*.png` (AppData\Roaming\Godot\app_userdata\JOC-BZN-Mobile\).
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
	_player.get_parent().add_child(poarta)
	poarta.global_position = _player.global_position + Vector2(0, -120)
	var t0 := Time.get_ticks_usec()
	_prison.enter(_player, poarta)
	print("enter() cu tot cu harta: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	t = 0.0
	while _prison._cut_activ and t < 30.0:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	print("cinematica gata dupa %.1f s" % t)
	var harta: Node2D = _prison._harta
	print("harta: %s  copii=%d  rect_joc=%s" % [harta, harta.get_child_count(), harta.rect_joc()])
	var c := harta.global_position

	_cam.position_smoothing_enabled = false
	_cam.zoom = Vector2(0.105, 0.105)
	await _poza(c + Vector2(0, -150), "castel_sus")
	_cam.zoom = Vector2(0.7, 0.7)
	var locuri := {
		"castel_poarta": Vector2(0, 150),
		"castel_nord": Vector2(0, -36 * 64),
		"castel_turn_nv": Vector2(-29 * 64, -35 * 64),
		"castel_curte_nv": Vector2(-22 * 64, -21 * 64),
		"castel_curte_ne": Vector2(22 * 64, -21 * 64),
		"castel_curte_sv": Vector2(-22 * 64, 22 * 64),
		"castel_curte_se": Vector2(22 * 64, 22 * 64),
		"castel_sud_vest": Vector2(-31 * 64, 34 * 64),
		"castel_est": Vector2(34 * 64, 2 * 64),
	}
	for nume in locuri:
		await _poza(c + locuri[nume], nume)

	# marginea: pus dincolo de fiecare zid, trebuie tras înăuntru
	var r: Rect2 = harta.rect_joc()
	for dir in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		_player.global_position = c + dir * 4000.0
		for i in 4:
			await get_tree().physics_frame
		var p := _player.global_position
		print("margine %s -> %s  inauntru=%s" % [dir, p - c, r.grow(1.0).has_point(p)])
	_player.global_position = c + Vector2(0, 150)

	_prison._boss_invins = true
	_prison.exit_prison(true)
	await get_tree().create_timer(0.3).timeout
	print("dupa iesire: harta valida=%s  prison.active=%s" % [is_instance_valid(harta), _prison.active])
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
