extends Node2D

# UNEALTĂ DE VERIFICARE pentru explozia de la impact a Mage Staff-ului (`fx/mage_impact` +
# `mage_impact` din Audio). Nu face parte din joc; se rulează cu FEREASTRĂ (nu headless),
# fiindcă headless nu desenează nimic și captura ar ieși goală:
#
#   "<godot.exe>" --path "<proiect>" res://tool_mage_impact.tscn
#
# Ce probează:
#   1. arta se încarcă: 4 cadre, toate 32×32 (dacă nu-s la fel, `_play_boom` le-ar scala aiurea,
#      fiindcă mărimea se calculează O SINGURĂ DATĂ, din cadrul 0);
#   2. sunetul e înregistrat în `Audio.SFX` și chiar pornește;
#   3. ROTAȚIA: opt explozii pe un cerc, fiecare trasă spre exterior. Arta are limbile în spate,
#      deci fiecare trebuie să împroaște ÎNAPOI spre centrul cercului. Dacă toate arată la fel,
#      înseamnă că rotația nu s-a aplicat.
#   4. cele patru cadre, unul lângă altul, pe rândul de jos (pornite decalat cu exact un cadru).

const FRAMES_DIR := "res://fx/mage_impact"
const FPS := 18.0
const RAZA_EXPLOZIE := 110.0        # cât pune `player.gd` pentru mage
const CADRU := 1.0 / FPS            # 55,6 ms

var _frames: SpriteFrames
var _bullet_scene: PackedScene = preload("res://bullet.tscn")
var _erori: Array[String] = []

func _ready() -> void:
	var fundal := ColorRect.new()
	fundal.color = Color(0.13, 0.16, 0.12)
	fundal.size = get_viewport_rect().size
	fundal.z_index = -100
	add_child(fundal)

	_frames = _incarca()
	var n := _frames.get_frame_count("fx")
	print("cadre incarcate: ", n)
	if n != 4:
		_erori.append("astept 4 cadre, am gasit %d" % n)
	var w0 := 0
	for i in n:
		var t := _frames.get_frame_texture("fx", i)
		print("  cadru %d: %dx%d" % [i, t.get_width(), t.get_height()])
		if i == 0:
			w0 = t.get_width()
		elif t.get_width() != w0:
			_erori.append("cadrul %d are alta latime (%d) decat cadrul 0 (%d)" % [i, t.get_width(), w0])

	var s := Audio.stream_for("mage_impact")
	if s == null:
		_erori.append("sunetul `mage_impact` NU e in Audio.SFX")
	else:
		print("sunet mage_impact: %.3f s" % s.get_length())
	Audio.play("mage_impact", -14.0)

	await get_tree().process_frame
	_ruleaza()

func _incarca() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("fx")
	sf.set_animation_loop("fx", false)
	sf.set_animation_speed("fx", FPS)
	var i := 0
	while ResourceLoader.exists("%s/frame_%d.png" % [FRAMES_DIR, i]):
		var tex := load("%s/frame_%d.png" % [FRAMES_DIR, i]) as Texture2D
		if tex != null:
			sf.add_frame("fx", tex)
		i += 1
	return sf

# Un glonț ca cel tras de Mage Staff, pus la locul lui, care explodează pe loc.
func _explozie(poz: Vector2, dir: Vector2) -> void:
	var b := _bullet_scene.instantiate()
	add_child(b)
	b.global_position = poz
	b.explosion_radius = RAZA_EXPLOZIE
	b.explosion_damage = 1
	b.explosion_frames = _frames
	b.explosion_sound = "mage_impact"
	b.set_direction(dir)
	b.visible = false            # ne interesează explozia, nu glonțul
	b._explode()

func _ruleaza() -> void:
	var centru := Vector2(576, 235)
	var raza := 190.0
	var jos := 545.0
	var x_rand := [190.0, 445.0, 700.0, 955.0]

	# rândul de jos: pornite decalat cu un cadru, ca la POZĂ să se vadă toate patru stadiile
	_explozie(Vector2(x_rand[3], jos), Vector2.RIGHT)
	await get_tree().create_timer(CADRU).timeout
	_explozie(Vector2(x_rand[2], jos), Vector2.RIGHT)
	await get_tree().create_timer(CADRU).timeout
	_explozie(Vector2(x_rand[1], jos), Vector2.RIGHT)
	# cercul pleacă acum, ca la poză să fie pe cadrul plin (al doilea)
	for k in 8:
		var unghi := TAU * k / 8.0
		var dir := Vector2.RIGHT.rotated(unghi)
		_explozie(centru + dir * raza, dir)
	await get_tree().create_timer(CADRU).timeout
	_explozie(Vector2(x_rand[0], jos), Vector2.RIGHT)
	await get_tree().create_timer(CADRU * 0.5).timeout

	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://mage_impact.png"))
	if _erori.is_empty():
		print("REZULTAT: OK")
	else:
		for e in _erori:
			print("EROARE: ", e)
		print("REZULTAT: PICAT")
	get_tree().quit()
