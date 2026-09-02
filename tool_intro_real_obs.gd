extends Node

# Observatorul cinematicii de intrare, pe DRUMUL REAL: loading -> meniu -> apasat START ->
# main.tscn. Sta pe `root`, nu in scena, ca sa supravietuiasca lui `change_scene_to_file`.
#
# 🔑 DE CE EXISTA, cand `tool_intro.gd` verifica deja aceeasi cinematica:
# `tool_intro.gd` instantiaza `main.tscn` DIRECT, ca pe un copil al lui. Asa, arta se citeste
# de pe disc, primul cadru al rundei tine peste o secunda, iar netezirea camerei (un singur pas,
# cu delta uriasa) apuca sa acopere tot drumul pana la player. Pe drumul REAL totul e deja
# preincarcat de `PreloadAll`, cadrul e scurt, si camera ramane la mii de pixeli in urma — iar
# cinematica pune jocul pe PAUZA, deci nu mai recupereaza niciodata. Diafragma se deschidea
# atunci pe un colt de lume gol: ecran NEGRU doua secunde. `tool_intro.gd` raporta „TOTUL E BINE"
# cat timp bug-ul era pe ecranul lui Razvan (prins pe 2026-09-02).
#
# Morala, buna pentru orice unealta de aici: o scena instantiata de mana NU e drumul jucatorului.
# Ce depinde de CAT DE REPEDE vine primul cadru se vede numai pe drumul intreg.
#
# ⚠️ Ruleaza FERESTRUIT (headless nu deseneaza, pozele ies negre):
#   godot --path <proj> res://tool_intro_real.tscn

const MOARTE := preload("res://gameover.gd")

var _ceas := 0.0
var _rec := false
var _intro: CanvasLayer
var _mat: ShaderMaterial
var _erori := 0

func _process(delta: float) -> void:
	if _rec:
		_ceas += delta

func porneste() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drumul()

func _drumul() -> void:
	# 1. asteptam meniul
	var menu: Node = null
	for i in range(9000):
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs.has_method("_on_start"):
			menu = cs
			break
	if menu == null:
		print("  x nu am gasit meniul")
		_gata()
		return
	print("  . meniul e pe ecran")
	await get_tree().create_timer(2.0).timeout
	await _poza("real_0_meniu")

	# 2. START, exact cum il apasa jucatorul
	_ceas = 0.0
	_rec = true
	menu._on_start()

	# 3. cinematica
	for i in range(600):
		await get_tree().process_frame
		if _intro == null:
			_intro = get_tree().get_first_node_in_group("intro_screen")
		if _intro != null:
			break
	if _intro == null:
		print("  x cinematica de intrare NU a pornit pe drumul real")
		_gata()
		return
	_mat = _intro.get_child(0).material as ShaderMaterial
	print("  . cinematica a pornit la t=%.2fs de la START" % _ceas)

	# de aici ceasul se numara de la aparitia cinematicii, ca in tool_intro.gd
	_ceas = 0.0
	_cer(get_tree().paused, "lumea sta pe loc")
	_cer(_raza() <= 0.0001, "ecranul e negru la pornire (raza %.4f)" % _raza())
	_cer(_infundat(), "muzica porneste infundata")

	await _pana_la(MOARTE.T_TACERE * 0.5)
	await _poza("real_1_negru")
	_cer(_raza() <= 0.0001, "pe la jumatatea tacerii tot negru e (raza %.4f)" % _raza())

	await _pana_la(MOARTE.T_TACERE + MOARTE.T_INCHIDERE + 0.02)
	await _poza("real_2_deschidere")
	var r1 := _raza()
	_cer(r1 > MOARTE.RAZA_STRANSA * 0.8 and r1 < MOARTE.RAZA_STRANSA * 1.4,
		"dupa smucitura cercul e cat te tine strans (%.3f, asteptat ~%.3f)" % [r1, MOARTE.RAZA_STRANSA])
	var vp := get_viewport().get_visible_rect().size
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl != null:
		var pe_ecran: Vector2 = pl.get_global_transform_with_canvas().origin / vp
		var centru: Vector2 = _mat.get_shader_parameter("centru")
		_cer(centru.distance_to(pe_ecran) < 0.01,
			"cercul se deschide DE PE PLAYER (%.3f,%.3f fata de %.3f,%.3f)"
			% [centru.x, centru.y, pe_ecran.x, pe_ecran.y])
		# Raza „ecran intreg" e si ea o dovada: cu centrul pe player iese ~1.04, cu centrul
		# impins in afara ecranului sare pe la 2.57 (`iris.gd::aseaza_pe_player`).
		_cer(_intro._iris.raza_start < 2.0,
			"raza de acoperire e cea de pe player (%.3f; peste 2.0 = centru in afara ecranului)"
			% _intro._iris.raza_start)
		# 🔑 Proba de la radacina bug-ului din 2026-09-02: camera trebuie sa fie LIPITA pe player
		# inca din primul cadru al rundei. `spawner.gd::_muta_player_aleator` o lipeste stingand
		# netezirea peste `force_update_scroll()`; cu `reset_smoothing()` singur ramaneau ~4.700px,
		# iar pauza cinematicii ii ingheta acolo.
		var cam := pl.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			var decalaj := cam.get_screen_center_position().distance_to(pl.global_position)
			_cer(decalaj < 1.0, "camera e lipita pe player din primul cadru (decalaj %.1f px)" % decalaj)
			print("      player la %s | centrul ecranului %s | netezire %s"
				% [pl.global_position, cam.get_screen_center_position(), cam.position_smoothing_enabled])
	else:
		_cer(false, "player-ul exista")

	await _pana_la(MOARTE.T_TACERE + MOARTE.T_INCHIDERE + MOARTE.T_STRANGERE + 0.02)
	await _poza("real_3_respiratie")

	await _pana_la(MOARTE.T_TACERE + MOARTE.T_CERC - MOARTE.T_LOVITURA - 0.35)
	await _poza("real_4_navala")

	await _pana_la(MOARTE.T_TACERE + MOARTE.T_CERC - MOARTE.T_LOVITURA * 0.5)
	await _poza("real_5_intreg")
	_cer(_raza() >= _intro._iris.raza_start - 0.001,
		"ecranul e intreg (raza %.3f din %.3f)" % [_raza(), _intro._iris.raza_start])
	_cer(get_tree().paused, "inainte de capat lumea inca sta")

	await _pana_la(MOARTE.T_TACERE + MOARTE.T_CERC + 0.25)
	await _poza("real_6_joc")
	_cer(not get_tree().paused, "la capat lumea porneste")
	_cer(not _intro.visible, "diafragma se stinge")
	_cer(not _infundat(), "usa muzicii s-a deschis la loc")
	_gata()

func _raza() -> float:
	return _mat.get_shader_parameter("raza")

func _infundat() -> bool:
	return AudioServer.is_bus_effect_enabled(Audio._bus_muzica, 0)

func _pana_la(t: float) -> void:
	while _ceas < t:
		await get_tree().process_frame

func _poza(nume: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % nume)

func _cer(bun: bool, ce: String) -> void:
	if bun:
		print("  ok  %s" % ce)
	else:
		_erori += 1
		print("  XX  %s   (la t=%.2fs)" % [ce, _ceas])

func _gata() -> void:
	if _erori == 0:
		print("\nTOTUL E BINE (pe drumul real)")
	else:
		print("\n%d PROBLEME" % _erori)
	get_tree().quit()
