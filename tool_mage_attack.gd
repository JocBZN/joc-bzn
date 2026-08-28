extends Node2D

# UNEALTĂ DE VERIFICARE pentru PROIECTILUL Mage Staff-ului: izbucnirea galbenă care zboară
# (`fx/mage_attack`) plus sunetul de tragere (`mage_attack` din `Audio.SFX`). Nu face parte din joc.
#
# ⚠️ Se rulează cu FEREASTRĂ, nu headless — headless nu desenează nimic și captura iese goală:
#
#   "<godot.exe>" --path "<proiect>" res://tool_mage_attack.tscn
#
# Probează pe PLAYER-UL ADEVĂRAT (instanțiat din `player.tscn`) și pe GLOANȚE ADEVĂRATE
# (`bullet.tscn`), nu pe copii ale codului, ca să nu treacă testul în timp ce jocul e stricat:
#   1. `_mage_attack_frames` chiar s-a încărcat: 4 cadre, toate de aceeași mărime, și e în BUCLĂ
#      (dacă animația n-ar fi `loop`, proiectilul s-ar stinge la jumătatea drumului);
#   2. sunetul `mage_attack` e în `Audio.SFX` și pornește;
#   3. ORIENTAREA: opt gloanțe trase în stea. Arta are miezul în față și limbile în spate, deci
#      fiecare trebuie să lase limbile spre CENTRU, de unde a plecat. Dacă toate arată la fel sau
#      toate sunt întoarse cu 90°, corecția de `-PI/2` din `_make_mage_projectile` e greșită;
#   4. glonțul normal e ascuns dedesubt (`Sprite2D.visible == false`).

const CADRE_ASTEPTATE := 4
const RAZA := 210.0          # cât de departe de centru se face captura
const VITEZA := 520.0        # ca să ajungă acolo în ~0,4 s

var _player: Node2D
var _bullet_scene: PackedScene = preload("res://bullet.tscn")
var _erori: Array[String] = []

func _ready() -> void:
	var fundal := ColorRect.new()
	fundal.color = Color(0.13, 0.16, 0.12)
	fundal.size = get_viewport_rect().size
	fundal.z_index = -100
	add_child(fundal)

	# player-ul adevărat, cu arma pe mage; îl ținem nevăzut și în afara cadrului — de la el luăm
	# cadrele încărcate și tot el construiește proiectilele, prin `_make_mage_projectile`.
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
	if f != null and not f.get_animation_loop("fx"):
		_erori.append("animatia proiectilului NU e in bucla; s-ar stinge in zbor")

	var s := Audio.stream_for("mage_attack")
	if s == null:
		_erori.append("sunetul `mage_attack` NU e in Audio.SFX")
	else:
		print("sunet mage_attack: %.3f s" % s.get_length())
	Audio.play("mage_attack", -16.0)
	_ruleaza()

# Un glonț de mage adevărat, construit exact ca în joc: `_make_mage_projectile` din player.
func _glont(centru: Vector2, dir: Vector2) -> Node:
	var b := _bullet_scene.instantiate()
	add_child(b)
	b.global_position = centru
	b.speed = VITEZA
	b.damage = 1
	b.set_direction(dir)
	_player._make_mage_projectile(b)
	return b

func _ruleaza() -> void:
	var centru := Vector2(576, 324)
	var gloante: Array = []
	for k in 8:
		var dir := Vector2.RIGHT.rotated(TAU * k / 8.0)
		gloante.append(_glont(centru, dir))

	# glonțul normal trebuie să fie ascuns sub proiectil
	var spr = gloante[0].get_node_or_null("Sprite2D")
	if spr != null and spr.visible:
		_erori.append("`Sprite2D`-ul glontului a ramas vizibil sub proiectil")

	# îi lăsăm să zboare până se depărtează bine de centru, apoi facem poza
	await get_tree().create_timer(RAZA / VITEZA).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://mage_attack.png"))

	if _erori.is_empty():
		print("REZULTAT: OK")
	else:
		for e in _erori:
			print("EROARE: ", e)
		print("REZULTAT: PICAT")
	get_tree().quit()
