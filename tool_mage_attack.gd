extends Node2D

# UNEALTĂ DE VERIFICARE pentru ATACUL Mage Staff-ului: izbucnirea galbenă din vârful toiagului
# (`fx/mage_attack`) plus sunetul ei (`mage_attack` din `Audio.SFX`). Nu face parte din joc.
#
# ⚠️ Se rulează cu FEREASTRĂ, nu headless — headless nu desenează nimic și captura iese goală:
#
#   "<godot.exe>" --path "<proiect>" res://tool_mage_attack.tscn
#
# Probează pe PLAYER-UL ADEVĂRAT (instanțiat din `player.tscn`), nu pe o copie a codului, ca să
# nu treacă testul în timp ce jocul e stricat:
#   1. `_mage_attack_frames` chiar s-a încărcat: 4 cadre, toate de aceeași mărime;
#   2. sunetul `mage_attack` e în `Audio.SFX` și pornește;
#   3. ROTAȚIA: opt izbucniri pe un cerc, fiecare trasă spre exterior. Arta are limbile în spate,
#      deci fiecare trebuie să împroaște ÎNAPOI spre centrul cercului. Dacă toate arată la fel,
#      rotația nu s-a aplicat;
#   4. cadrele animației unul lângă altul, pe rândul de jos (pornite decalat cu exact un cadru).

const FPS := 18.0                   # cât pune `player.gd` pentru `fx/mage_attack`
const CADRU := 1.0 / FPS            # 55,6 ms
const CADRE_ASTEPTATE := 4

var _player: Node2D
var _erori: Array[String] = []

func _ready() -> void:
	var fundal := ColorRect.new()
	fundal.color = Color(0.13, 0.16, 0.12)
	fundal.size = get_viewport_rect().size
	fundal.z_index = -100
	add_child(fundal)

	# player-ul adevărat, cu arma pe mage; îl ținem nevăzut și în afara cadrului — ne interesează
	# doar efectul pe care îl NAȘTE el, iar `_play_effect` îl pune oricum în părintele lui (noi).
	_player = preload("res://player.tscn").instantiate()
	_player.weapon_type = "mage"
	add_child(_player)
	_player.global_position = Vector2(-4000, -4000)
	_player.visible = false
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.enabled = false   # altfel camera player-ului duce vederea la (-4000,-4000) si captura iese goala
	await get_tree().process_frame

	var f: SpriteFrames = _player._mage_attack_frames
	var n := 0 if f == null else f.get_frame_count("fx")
	print("cadre incarcate: ", n)
	if n != CADRE_ASTEPTATE:
		_erori.append("astept %d cadre, am gasit %d" % [CADRE_ASTEPTATE, n])
	var w0 := 0
	for i in n:
		var t := f.get_frame_texture("fx", i)
		print("  cadru %d: %dx%d" % [i, t.get_width(), t.get_height()])
		if i == 0:
			w0 = t.get_width()
		elif t.get_width() != w0:
			_erori.append("cadrul %d are alta latime (%d) decat cadrul 0 (%d)" % [i, t.get_width(), w0])

	var s := Audio.stream_for("mage_attack")
	if s == null:
		_erori.append("sunetul `mage_attack` NU e in Audio.SFX")
	else:
		print("sunet mage_attack: %.3f s" % s.get_length())
	Audio.play("mage_attack", -16.0)
	_ruleaza()

# O izbucnire exact ca la tragere: chemăm chiar funcția din player, nu o copie.
func _izbucnire(poz: Vector2, dir: Vector2) -> void:
	_player._mage_attack_fx(poz, dir)

func _ruleaza() -> void:
	var centru := Vector2(576, 235)
	var raza := 190.0
	var jos := 545.0
	var x_rand := [190.0, 445.0, 700.0, 955.0]

	# rândul de jos: pornite decalat cu un cadru, ca la POZĂ să se vadă stadiile una lângă alta.
	# Ultima pleacă prima, ca cea din stânga să fie tot pe cadrul 0 când se face captura.
	_izbucnire(Vector2(x_rand[3], jos), Vector2.RIGHT)
	await get_tree().create_timer(CADRU).timeout
	_izbucnire(Vector2(x_rand[2], jos), Vector2.RIGHT)
	await get_tree().create_timer(CADRU).timeout
	_izbucnire(Vector2(x_rand[1], jos), Vector2.RIGHT)
	# cercul pleacă acum, ca la poză să fie pe cadrul plin (al doilea)
	for k in 8:
		var unghi := TAU * k / 8.0
		var dir := Vector2.RIGHT.rotated(unghi)
		_izbucnire(centru + dir * raza, dir)
	await get_tree().create_timer(CADRU).timeout
	_izbucnire(Vector2(x_rand[0], jos), Vector2.RIGHT)
	await get_tree().create_timer(CADRU * 0.4).timeout

	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://mage_attack.png"))
	if _erori.is_empty():
		print("REZULTAT: OK")
	else:
		for e in _erori:
			print("EROARE: ", e)
		print("REZULTAT: PICAT")
	get_tree().quit()
