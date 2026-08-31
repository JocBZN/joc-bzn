extends Node

# UNEALTĂ (se rulează ca SCENĂ, în fereastră normală — headless randează negru):
#
#   godot --path <proiect> res://tool_ender_lumina.tscn --quit-after 900
#
# LUMINOZITATEA ENDER-ULUI. Făcută pe 2026-08-31, când Răzvan a cerut „să fie puțin mai bright
# în Ender": ochiul nu poate compara două rulări la o zi distanță, dar o cifră poate.
#
# Ce face: pornește `main.tscn`, îmbracă lumea în hainele Ender-ului (podeaua de nebuloasă,
# marginea, atmosfera), pune doi inamici de Ender lângă player ca să se vadă dacă mai sunt
# lizibili pe fundalul ăla, apoi salvează captura în `user://ender_final.png` și tipărește
# LUMINANȚA MEDIE a ecranului (0..1).
#
# ⚠️ NU trece prin `ender.gd::enter()` dinadins: aia ar cere o fântână adevărată și ar porni
# cinematica lui Celesto, cu benzi negre și vinietă peste tot ecranul — adică exact ce nu vrei
# să măsori. Punem numai straturile vizuale, cele trei apeluri pe care le face și `enter()`.
#
# ⚠️ Inamicii primesc `damage_mult = 0`: altfel, la a treia captură, player-ul ajungea pe la 20 HP
# și o rulare puțin mai lungă l-ar fi omorât — iar moartea scrie în leaderboard-ul REAL
# (`user://scores.save`). Vezi avertismentul din CLAUDE.md.
#
# Ca să compari mai multe reglaje într-o singură rulare (pe ACEEAȘI scenă, deci fără nimic
# schimbat în afară de culoare), umple `VARIANTE`. Gol = se măsoară exact ce scrie în cod acum.

const VARIANTE: Array[Dictionary] = []
# Exemplu de sweep:
# const VARIANTE: Array[Dictionary] = [
# 	{"nume": "acum", "tint": Color(0.68, 0.80, 1.12), "vig": 0.55},
# 	{"nume": "mediu", "tint": Color(0.82, 0.92, 1.18), "vig": 0.44},
# ]

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var ground: Node = main.get_node_or_null("Ground")
	if ground != null and player != null:
		ground.set_ender(true)
		ground.set_margine(player.global_position)
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null:
		atm.set_dimension("ender")
	# decorul lumii normale n-are ce căuta dincolo (și copacii verzi ar umfla media)
	var ender_node: Node = main.get_node_or_null("Ender")
	if ender_node != null:
		ender_node._set_world_enabled(false)
	if player != null:
		for i in 2:
			var e: Node2D = load("res://enemy_ender.tscn").instantiate() as Node2D
			e.damage_mult = 0.0
			e.global_position = player.global_position + Vector2(260 - 520 * i, -120)
			player.get_parent().add_child(e)

	await get_tree().create_timer(1.6).timeout   # cât ține intrarea atmosferei (DIM_FADE = 0.8)
	if VARIANTE.is_empty():
		_captura(atm, "final")
	else:
		for v in VARIANTE:
			atm._dim_modulate.color = v["tint"]
			atm._dim_mat.set_shader_parameter("vignette_strength", v["vig"])
			await get_tree().create_timer(0.35).timeout
			_captura(atm, v["nume"])
	get_tree().quit()

func _captura(_atm: Node, nume: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://ender_%s.png" % nume))
	print("%s: lumina medie %.4f" % [nume, _medie(img)])

# Luminanța medie a capturii (0..1). Din 16 în 16 pixeli (pas 4 pe fiecare axă) — destul pentru o
# comparație, și nu ține jocul pe loc o secundă la fiecare captură.
func _medie(img: Image) -> float:
	var s := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return s / maxf(1.0, float(n))
