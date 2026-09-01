extends Node2D

# UNEALTĂ — cum arată sigiliul hoardei (`swarm_ring.gd`) ÎN JOC, nu pe un fundal inventat.
# Pornește lumea adevărată (`main.tscn`), aprinde cercul lângă player și face poze la mai multe
# valori ale ceasului, întâi pe IARBĂ, apoi pe NISIP.
#
# De ce neapărat amândouă solurile: lecția din `poarta_castel.gd` — un efect luminos care arată
# bine pe iarbă poate ieși ALB pe nisip (canalele solului sunt deja aproape pline). Cercul e
# construit anume ca să nu pățească asta (bandă închisă sub linie, `blend_mix`, nu `blend_add`),
# dar „construit anume" nu e o dovadă; pozele sunt.
#
# ⚠️ Player-ul e ținut NEMURITOR (`hp = max_hp` în fiecare cadru). Fără asta, o unealtă care îl
# lasă să moară scrie în clasamentul ADEVĂRAT (`user://scores.save`).
#
# Rulează CU FEREASTRĂ (fără `--headless`): headless randează negru și pozele ies goale.
#   "<godot.exe>" --path . res://tool_cerc_swarm.tscn
# Pozele: %APPDATA%\Godot\app_userdata\JOC-BZN-Mobile\cerc_*.png

const CERC := preload("res://swarm_ring.gd")
const MAIN := preload("res://main.tscn")
const BiomeMap := preload("res://biome_map.gd")
const MONUMENT := preload("res://monument.tscn")

const CHUNK := 512

var _player: Node2D
var _lume: Node
var _cerc: Node2D
var _progres := 1.0
var _hraneste := false

func _ready() -> void:
	add_child(MAIN.instantiate())
	await get_tree().process_frame
	# Runda începe cu un cinematic care pune arborele pe PAUZĂ ~2s. Așteptăm să se ridice, altfel
	# facem poze la un ecran înghețat și tragem concluzii din el.
	while get_tree().paused:
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(1.0).timeout

	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		push_error("nu găsesc player-ul")
		get_tree().quit()
		return
	_lume = _player.get_parent()

	await _serie("iarba")

	# --- același cerc, pe nisipul deșertului ---
	var d := _cauta_desert()
	if d == Vector2i(999999, 999999):
		print("n-am găsit chunk de deșert în raza căutată — sar peste proba de nisip")
	else:
		print("deșert găsit la chunk %s" % [d])
		_player.global_position = Vector2(d) * float(CHUNK) + Vector2(CHUNK, CHUNK) * 0.5
		await get_tree().create_timer(2.0).timeout   # lasă chunk-urile să se genereze
		await _serie("nisip")


	await _invocare_adevarata()

	print("gata — pozele sunt în user://")
	get_tree().quit()

# Player-ul nu moare în timpul probei (vezi nota de sus), iar cercul e hrănit de AICI, cadru cu
# cadru, exact cum îl hrănește monumentul în joc.
func _process(_delta: float) -> void:
	if _player != null:
		_player.hp = _player.max_hp
	if _hraneste and is_instance_valid(_cerc):
		_cerc.alimenteaza(_progres)

# O serie de poze pe solul de sub player: deschiderea, ceasul la trei sferturi, la un sfert, și
# clipirea de închidere.
func _serie(unde: String) -> void:
	_cerc = CERC.new()
	_cerc.raza = 400.0
	_lume.add_child(_cerc)
	_cerc.global_position = _player.global_position
	_progres = 1.0
	_hraneste = true

	await get_tree().create_timer(0.7).timeout    # cât ține deschiderea (APARITIE = 0.45)
	await _poza("%s_1_plin" % unde)
	_progres = 0.62
	await get_tree().create_timer(0.25).timeout
	await _poza("%s_2_ceas62" % unde)
	_progres = 0.18
	await get_tree().create_timer(0.25).timeout
	await _poza("%s_3_ceas18" % unde)

	_hraneste = false
	_cerc.inchide()
	await get_tree().create_timer(0.10).timeout
	await _poza("%s_4_clipire" % unde)
	await get_tree().create_timer(0.8).timeout
	await _poza("%s_5_dupa" % unde)   # trebuie să nu mai fie NIMIC pe jos

func _poza(nume: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cale := "user://cerc_%s.png" % nume
	img.save_png(ProjectSettings.globalize_path(cale))
	print("  poză: %s (%dx%d)" % [cale, img.get_width(), img.get_height()])

# Primul chunk de deșert PUR (nu gradientul de îmbinare) dintr-o spirală pătrată în jurul originii.
func _cauta_desert() -> Vector2i:
	for r in range(1, 60):
		for cx in range(-r, r + 1):
			for cy in range(-r, r + 1):
				if absi(cx) != r and absi(cy) != r:
					continue
				if BiomeMap.desertness_at_chunk(Vector2(cx, cy)) >= 0.999:
					return Vector2i(cx, cy)
	return Vector2i(999999, 999999)

# --- PROBA ADEVĂRATĂ: apăsăm chiar monumentul ---------------------------------------------
#
# Până aici am pus cercul cu mâna, ca să-l pot vedea pe amândouă solurile. Asta nu dovedește că
# JOCUL îl aprinde: legătura trece prin `monument.gd::_scoate_hoarda`, care e o corutină de 10
# secunde cu `await` în ea. Aici apăsăm butonul de-adevăratelea și ne uităm ce iese.
#
# Monumentul e încuiat până cade Celesto (`ender.gd::celesto_invins`) — îi ridicăm noi steagul,
# fiindcă altfel proba ar însemna două dimensiuni și un boss.
func _invocare_adevarata() -> void:
	var e := get_tree().get_first_node_in_group("ender")
	if e == null:
		print("nu găsesc nodul Ender — sar peste proba adevărată")
		return
	e.set("celesto_invins", true)
	# Fără asta, primul Level Up oprește arborele în mijlocul hoardei (ecranul de upgrade) și proba
	# se termină cu cercul încă aprins — corect din partea jocului, dar nu ăsta e lucrul de măsurat.
	# (Prima rulare a picat exact așa; e dovada că ceasul cercului chiar stă pe pauză.)
	_player.xp_to_next = 999999999

	# Monumentele se nasc chunk cu chunk și sunt rare — nu ne bazăm pe noroc, punem noi unul în
	# lume, exact scena din joc. Diferența față de unul născut de `monuments.gd`: n-are peste el
	# generatorul cu `marcheaza_folosit`, iar `invoca()` trece pe lângă asta (are `if gen != null`).
	await get_tree().create_timer(1.0).timeout
	var mon: Node2D = MONUMENT.instantiate()
	_lume.add_child(mon)
	mon.global_position = _player.global_position + Vector2(0, -260)
	await get_tree().create_timer(1.2).timeout
	print("invoc monumentul de la %s (eticheta: '%s')" % [mon.global_position, mon.eticheta()])
	mon.invoca()

	await get_tree().create_timer(1.2).timeout
	await _poza("real_1_start")
	await get_tree().create_timer(4.0).timeout
	await _poza("real_2_mijloc")
	await get_tree().create_timer(4.2).timeout
	await _poza("real_3_final")
	await get_tree().create_timer(2.0).timeout
	await _poza("real_4_dupa")   # hoarda s-a terminat: cercul trebuie să nu mai fie
	print("  cercuri rămase în scenă: %d (trebuie 0)" % _cercuri_ramase())

# Câte sigilii mai există în arbore — proba că se sting singure, nu se adună de la o hoardă la alta.
func _cercuri_ramase() -> int:
	var n := 0
	for c in _lume.get_children():
		if c is Sprite2D and c.get_script() == CERC:
			n += 1
	return n
