extends Node

# UNEALTĂ DE VERIFICARE (se rulează ca SCENĂ, în fereastră normală — headless randează negru):
#
#   godot --path <proiect> res://tool_iris_identic.tscn
#
# Diafragma morții (`gameover.gd` + `moarte_iris.gdshader`) urmează să fie MUTATĂ într-un nod de
# sine stătător, ca s-o poată folosi și intrarea în rundă (aceeași animație, pe invers). Mutarea
# unui cod care merge e locul clasic în care se strecoară o diferență pe care n-o vede nimeni
# până când nu moare cineva în joc. Deci: fotografiem diafragma ÎNAINTE, o mutăm, o fotografiem
# DUPĂ, și comparăm bit cu bit.
#
# Ce face: pornește `main.tscn`, îngheață lumea și trece diafragma prin `RAZE` — de la raza de
# pornire până la zero — fotografiind fiecare pas. Nu doar „se vede negru": pașii sunt aleși ca să
# prindă și scurgerea culorii (`stins`) și inelul care arde (`rama`), care se calculează AMÂNDOUĂ
# din rază, deci o greșeală în oricare din ele iese la iveală aici.
#
# ⚠️ NU cheamă `show_gameover()`. Aia SCRIE în leaderboard-ul real (`add_score` + `bank_run_coins`)
# și ar lăsa o rundă falsă de câteva secunde în salvarea lui Răzvan. Chemăm direct cele două lucruri
# care ne interesează — așezarea cercului și setarea razei.
#
# ⚠️ Se scot de pe ecran lucrurile care se MIȘCĂ singure (frunzele care cad din copaci, barele din
# HUD) și se îngheață arborele după un număr FIX de cadre. Altfel două rulări ar diferi din motive
# care n-au nimic de-a face cu diafragma, iar comparația n-ar mai dovedi nimic — vezi pățania de la
# `tool_biome_identic.gd`, unde camera care încă aluneca trecea drept „shader stricat".

# Pașii prin care trece cercul. Nu sunt egal depărtați: primii doi sunt din faza de „înghițire"
# (culoarea abia începe să se scurgă), ultimii trei din strângere și închidere, unde inelul arde
# cel mai tare și unde se vede orice greșeală de rotunjire.
const RAZE := [0.60, 0.35, 0.22, 0.18, 0.13, 0.05, 0.0]

# Un cadru de pornire ales, nu cel implicit: la (0,0) player-ul e fix în mijlocul ecranului, deci
# `centru` iese (0.5, 0.5) și raza de pornire e mereu aceeași cifră. Comparația vrea repetabilitate.
const POZITIE := Vector2(2500, 1700)

const CADRE_DE_ASEZARE := 20   # cadre lăsate să treacă înainte de îngheț (număr FIX, nu secunde)

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var go := get_tree().get_first_node_in_group("gameover_screen")
	if player == null or go == null:
		print("LIPSESTE PLAYER SAU GAMEOVER")
		get_tree().quit()
		return

	# afară tot ce se mișcă singur
	var props := main.get_node_or_null("World/Props") as CanvasItem
	if props != null:
		props.visible = false
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var sp := main.get_node_or_null("Spawner")
	if sp != null and sp.timer != null:
		sp.timer.stop()
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node).queue_free()

	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.global_position = POZITIE
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.position_smoothing_enabled = false

	for cadru in CADRE_DE_ASEZARE:
		await get_tree().process_frame
	get_tree().paused = true

	# Diafragma, fără cinematică: o așezăm pe player și îi dăm razele cu mâna.
	go.visible = true
	go._center.visible = false
	go._aseaza_cercul()
	print("raza_start = %.6f" % go._raza_start)

	for i in RAZE.size():
		go._seteaza_raza(float(RAZE[i]))
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://iris_%d.png" % i)
		print("raza %.2f -> iris_%d.png" % [RAZE[i], i])

	print("Gata.")
	get_tree().quit()
