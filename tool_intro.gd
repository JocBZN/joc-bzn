extends Node

# Unealta care verifica CINEMATICA DE INTRARE (`intro.gd` + `iris.gd`), adica moartea rulata
# pe dos. Porneste jocul adevarat (main.tscn) si masoara, cadru cu cadru, ce fac diafragma,
# pauza si filtrul muzicii. Face si poze la momentele importante.
#
# ⚠️ Ruleaza FERESTRUIT — headless nu deseneaza (pozele ies negre):
#   godot --path <proj> res://tool_intro.tscn
#
# ⚠️ Ceasul testului e ceasul MOTORULUI (`_ceas`, adunat din delta), nu `Time.get_ticks_msec`.
# `save_png` blocheaza firul principal cateva sute de ms: pe ceas de perete testul ar cere
# momentele mai devreme decat le poate arata animatia si ar "pica" degeaba. Capcana asta e deja
# in CLAUDE.md, de la cinematica lui Saratalin si de la cea de moarte.
#
# ⚠️ NU moare nimeni aici, deci nu se scrie nimic in `user://scores.save`. Intrarea porneste
# singura, din `_ready`-ul scenei — asta e chiar ce verificam.
#
# Momentele cerute se citesc din constantele lui `gameover.gd`, nu sunt scrise de mana: intrarea
# e oglinda mortii, deci daca se schimba coregrafia mortii, si testul, si intrarea se muta dupa ea.

const MOARTE := preload("res://gameover.gd")

var _erori := 0
var _intro: CanvasLayer
var _mat: ShaderMaterial
var _ceas := 0.0
var _rec := false
var _asezare := 0.0   # cat au tinut cadrele in care lumea s-a asezat, inainte de pauza

func _process(delta: float) -> void:
	if _rec:
		_ceas += delta

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # intrarea pune jocul pe pauza; noi trebuie sa mergem
	_rec = true
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_intro = get_tree().get_first_node_in_group("intro_screen")
	_cer(_intro != null, "nodul de intrare exista")
	if _intro == null:
		_gata()
		return
	_mat = _intro.get_child(0).material as ShaderMaterial
	_cer(_mat != null, "diafragma are shader-ul pe ea")
	_cer(_intro.visible, "intrarea e pe ecran din primul cadru")
	# 🔑 Lumea merge cateva cadre INAINTE de pauza, ca sa apuce sa se aseze pe player: podeaua se
	# muta pe el, copacii/pietrele/tufele isi construiesc patratele, HUD-ul isi scrie cifrele — tot
	# lucruri facute in `_process` (vezi `intro.gd::CADRE_DE_ASEZARE`). Deci nu cer pauza pe loc, ci
	# astept sa vina, si de-abia de acolo pornesc ceasul coregrafiei.
	while not get_tree().paused and _ceas < 2.0:
		await get_tree().process_frame
	_asezare = _ceas
	_cer(get_tree().paused, "lumea a fost inghetata cat se deschide cercul (dupa %.2fs)" % _asezare)
	_cer(_asezare < 1.0, "asezarea lumii tine cat o clipire, nu cat o cinematica (%.2fs)" % _asezare)
	_ceas = 0.0

	# --- t=0: NEGRU ---
	_cer(_raza() <= 0.0001, "ecranul e negru la pornire (raza %.4f)" % _raza())
	_cer(_infundat(), "muzica porneste infundata, ca prin usa")

	# --- TACEREA: cat tine, nu se misca nimic ---
	await _pana_la(MOARTE.T_TACERE * 0.5)
	_poza("negru")
	_cer(_raza() <= 0.0001, "pe la jumatatea tacerii tot negru e (raza %.4f)" % _raza())

	# --- DESCHIDEREA: cercul se smuceste de la zero ---
	await _pana_la(MOARTE.T_TACERE + MOARTE.T_INCHIDERE + 0.02)
	_poza("deschidere")
	var r1 := _raza()
	_cer(r1 > MOARTE.RAZA_STRANSA * 0.8 and r1 < MOARTE.RAZA_STRANSA * 1.4,
		"dupa smucitura cercul e cat te tine strans (%.3f, asteptat ~%.3f)" % [r1, MOARTE.RAZA_STRANSA])
	# ⚠️ Verificarea care a prins bug-ul: cercul trebuie sa se deschida DE PE PLAYER. Prima
	# varianta il aseza in `_ready`, cand camera inca nu-si luase locul, si iesea din coltul
	# ecranului — se vedea doar in `raza_start`, care sarise de la 1.04 la 2.57. O animatie care
	# "merge" nu e neaparat animatia ceruta.
	var vp := get_viewport().get_visible_rect().size
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var pe_ecran: Vector2 = pl.get_global_transform_with_canvas().origin / vp
	var centru: Vector2 = _mat.get_shader_parameter("centru")
	_cer(centru.distance_to(pe_ecran) < 0.01,
		"cercul se deschide DE PE PLAYER (%.3f,%.3f fata de %.3f,%.3f)"
		% [centru.x, centru.y, pe_ecran.x, pe_ecran.y])
	_cer(_mat.get_shader_parameter("rama") > 0.9, "inelul arde cel mai tare cand cercul e mic")
	# Pragul e 0.75, nu 0.9: la raza asta formula din `iris.gd` da pow(1 - 0.130/1.041, 1.6) = 0.81,
	# si da exact aceeasi cifra si la moarte, cand cercul trece prin acelasi loc. Prima varianta
	# a testului cerea 0.9 si "pica" — dar nu animatia era gresita, ci asteptarea mea.
	_cer(_mat.get_shader_parameter("stins") > 0.75,
		"lumea inca n-are culoare (stins %.2f)" % _mat.get_shader_parameter("stins"))

	# --- RESPIRATIA ---
	await _pana_la(MOARTE.T_TACERE + MOARTE.T_INCHIDERE + MOARTE.T_STRANGERE + 0.02)
	_poza("respiratie")
	var r2 := _raza()
	_cer(r2 > MOARTE.RAZA_MICA * 0.85 and r2 < MOARTE.RAZA_MICA * 1.25,
		"s-a largit pana la raza mica (%.3f, asteptat ~%.3f)" % [r2, MOARTE.RAZA_MICA])
	_cer(r2 > r1, "cercul creste, nu scade")

	# --- NAVALA ---
	await _pana_la(MOARTE.T_TACERE + MOARTE.T_CERC - MOARTE.T_LOVITURA - 0.35)
	_poza("navala")
	var r3 := _raza()
	_cer(r3 > r2, "lumea navaleste inauntru (%.3f dupa %.3f)" % [r3, r2])

	# --- ULTIMA CLIPA: ecran intreg, dar lumea inca sta ---
	#
	# ⚠️ Aici merg pe EVENIMENT, nu pe ceas: ceasul meu porneste cand VAD pauza pusa, adica pana la
	# un cadru dupa ce a pornit lantul de tween-uri din `intro.gd`, iar decalajul ala e mai mare
	# decat jumatatea de `T_LOVITURA` la care probam inainte. Ce vrem sa stim n-are oricum nevoie de
	# ceas: cand ecranul s-a facut intreg, lumea trebuie sa mai stea o bataie de inima.
	while _raza() < _intro._iris.raza_start - 0.001 and _ceas < 6.0:
		await get_tree().process_frame
	_poza("intreg")
	_cer(_raza() >= _intro._iris.raza_start - 0.001,
		"ecranul e intreg (raza %.3f din %.3f)" % [_raza(), _intro._iris.raza_start])
	_cer(_mat.get_shader_parameter("stins") < 0.02, "culoarea s-a intors de tot")
	_cer(get_tree().paused, "cand ecranul s-a facut intreg, lumea inca sta (`T_LOVITURA`)")
	# Cat lumea inca sta, luam ceasul rundei ca sa-l probam mai jos: aici e ULTIMA clipa in care
	# el chiar n-avea voie sa fi curs. Luat dupa `_pana_la(... + 0.25)` ar fi cuprins si sfertul
	# ala de secunda de joc adevarat, si-ar fi trebuit sa-l scad de mana din prag.
	var ceas_runda_la_final := Difficulty.time

	# --- GATA ---
	await _pana_la(MOARTE.T_TACERE + MOARTE.T_CERC + 0.25)
	_poza("joc")
	_cer(not get_tree().paused, "la capat lumea porneste")
	# Cronometrul rundei NU trebuie sa curga cat nu vezi si nu poti face nimic. Vine gratis din
	# `get_tree().paused` (autoload-urile sunt pauzabile implicit), dar tocmai fiindca vine gratis
	# merita pazit: daca cineva pune candva `Difficulty` pe PROCESS_MODE_ALWAYS, ai incepe fiecare
	# runda cu doua secunde deja consumate si nimic nu s-ar plange.
	#
	# ⚠️ Pragul nu mai e o cifra rotunda, ci chiar cat a tinut asezarea lumii: singurele cadre in
	# care lumea merge sunt cele de dinaintea pauzei (`intro.gd::CADRE_DE_ASEZARE`), si sunt cele
	# mai scumpe cadre ale rundei — in ele se construiesc toate patratele din jurul player-ului.
	# Costul ala se platea si inainte, doar ca in primul cadru de DUPA cinematica, tot din ceasul
	# rundei. Ce nu trebuie sa se intample e ca cele ~2 secunde de cinematica sa intre si ele.
	_cer(ceas_runda_la_final <= _asezare + 0.05,
		"ceasul rundei a mers doar cat s-a asezat lumea, nu si in cinematica (%.2fs, asezare %.2fs)"
		% [ceas_runda_la_final, _asezare])
	_cer(not _intro.visible, "diafragma se stinge si nu mai deseneaza nimic")
	_cer(not _infundat(), "usa muzicii s-a deschis la loc")

	# Oglinda: aceleasi secunde ca la moarte, in ordine inversa.
	print("  (durata totala: %.2fs = T_TACERE %.2f + T_CERC %.2f, exact cat tine moartea)"
		% [MOARTE.T_TACERE + MOARTE.T_CERC, MOARTE.T_TACERE, MOARTE.T_CERC])
	_gata()

func _raza() -> float:
	return _mat.get_shader_parameter("raza")

# Filtrul de pe magistrala muzicii e aprins = usa inchisa = muzica se aude ca prin perete.
func _infundat() -> bool:
	return AudioServer.is_bus_effect_enabled(Audio._bus_muzica, 0)

func _pana_la(t: float) -> void:
	while _ceas < t:
		await get_tree().process_frame

func _poza(nume: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://intro_%s.png" % nume)

func _cer(bun: bool, ce: String) -> void:
	if bun:
		print("  ✔ %s" % ce)
	else:
		_erori += 1
		print("  ✘ %s   (la t=%.2fs)" % [ce, _ceas])

func _gata() -> void:
	if _erori == 0:
		print("\nTOTUL E BINE")
	else:
		print("\n%d PROBLEME" % _erori)
	get_tree().quit()
