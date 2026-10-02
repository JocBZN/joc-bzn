extends Node2D

# UNEALTĂ: ecranul YOU WIN! (`victory.gd`). Rulează cu FEREASTRĂ (face poze):
#   godot --path . res://tool_victorie.tscn
#
# Probează:
#   [1] contoarele de gambles (`GameSettings.add_gamble`) și ștersul lor la `reset_run`
#   [2] ecranul NU apare cât ține animația de moarte, nici cât jocul e pe pauză (Level Up-ul de la
#       premiu) — apare abia după
#   [3] poza ecranului, cu cifrele deja numărate → user://victorie.png
#   [4] CONTINUE dă drumul jocului și scoate ecranul
#
# Nu apasă MAIN MENU: ăla scrie în leaderboard-ul adevărat. Nu salvează nimic; verifică totuși
# md5-ul lui `scores.save` după rulare.

const VICTORIE := preload("res://victory.gd")

var _esecuri := 0

func _cer(ok: bool, text: String) -> void:
	print(("  ok  " if ok else "  XX  ") + text)
	if not ok:
		_esecuri += 1

func _ready() -> void:
	var fundal := ColorRect.new()
	fundal.color = Color(0.18, 0.2, 0.16)
	fundal.size = Vector2(4000, 4000)
	fundal.position = Vector2(-2000, -2000)
	fundal.z_index = -100
	add_child(fundal)

	print("--- [1] contoarele de gambles ---")
	GameSettings.reset_run()
	GameSettings.add_gamble(true)
	GameSettings.add_gamble(true)
	GameSettings.add_gamble(false)
	_cer(GameSettings.run_gambles_won == 2 and GameSettings.run_gambles_lost == 1,
		"2 castigate, 1 pierdut (%d / %d)" % [GameSettings.run_gambles_won, GameSettings.run_gambles_lost])
	GameSettings.reset_run()
	_cer(GameSettings.run_gambles_won == 0 and GameSettings.run_gambles_lost == 0, "reset_run le sterge")

	# o rundă „jucată"
	GameSettings.run_kills = 4821
	GameSettings.run_chests = 7
	for i in 9:
		GameSettings.add_gamble(true)
	for i in 4:
		GameSettings.add_gamble(false)
	Difficulty.time = 1394.0   # 23:14

	var p: Node = load("res://player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	p.max_hp = 100000000
	p.hp = p.max_hp
	p.level = 87
	p.bullet_damage = 140
	p.crit_chance = 0.35
	p.luck = 12.0
	p.pierce = 3

	print("--- [2] asteapta animatia si Level Up-ul ---")
	var v := CanvasLayer.new()
	v.set_script(VICTORIE)
	add_child(v)
	v.porneste()
	await get_tree().create_timer(1.0).timeout
	_cer(not v.visible, "la 1.0s (animatia de moarte) inca ascuns")
	get_tree().paused = true    # ca un Level Up deschis
	await get_tree().create_timer(2.0, true).timeout
	_cer(not v.visible, "cat jocul e pe pauza (Level Up) ramane ascuns")
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	_cer(v.visible, "dupa ce se inchide Level Up-ul, apare")
	_cer(get_tree().paused, "si pune jocul pe pauza")

	print("--- [3] poza ---")
	await get_tree().create_timer(1.6, true).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://victorie.png"))
	_cer(v._randuri_run.size() == 6, "6 randuri in THIS RUN")
	_cer((v._randuri_run[2]["lbl"] as Label).text == "4821", "kills numarate pana la capat (%s)" % (v._randuri_run[2]["lbl"] as Label).text)
	# ceasul rundei a mers cât a stat ecranul ascuns, deci comparăm cu cifra pe care a prins-o EL
	var t_prins: int = v._randuri_run[0]["tinta"]
	_cer(t_prins >= 1394 and (v._randuri_run[0]["lbl"] as Label).text == v._fmt_timp(t_prins),
		"timpul (%s)" % (v._randuri_run[0]["lbl"] as Label).text)
	_cer(v._splash != null and v._splash.visible and v._splash.text == "More content coming soon",
		"splash-ul din colt e pe ecran")
	_cer(v._splash.scale.x >= 1.0 and v._splash.scale.x <= 1.0 + v.SPLASH_PULS + 0.001,
		"si pulseaza intre 100%% si %d%% (acum %.3f)" % [int(round((1.0 + v.SPLASH_PULS) * 100.0)), v._splash.scale.x])
	_cer(v._randuri_stat.size() == p.stat_lines().size(), "toate statusurile din stat_lines (%d)" % v._randuri_stat.size())

	print("--- [4] CONTINUE ---")
	v._btn_continua.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_cer(not get_tree().paused, "jocul merge mai departe")
	_cer(not is_instance_valid(v), "ecranul a disparut")

	# [5] drumul ADEVĂRAT: Sir John moare → `final_boss.gd::_die` → ecranul. Fără asta, proba de
	# mai sus ar fi trecut și cu cârligul din boss șters de tot.
	print("--- [5] Sir John moare de-adevaratelea ---")
	var boss: Node = load("res://final_boss.tscn").instantiate()
	add_child(boss)
	boss.global_position = p.global_position + Vector2(600, 0)
	await get_tree().process_frame
	boss.take_damage(boss.max_hp + 1)
	await get_tree().process_frame
	var v2 := get_tree().get_first_node_in_group("victory_screen")
	_cer(v2 != null, "moartea lui a creat ecranul de victorie")
	boss.take_damage(5)   # o lovitură în plus pe cadavru (încă în animație) nu face un al doilea ecran
	await get_tree().process_frame
	_cer(get_tree().get_nodes_in_group("victory_screen").size() == 1, "un singur ecran")
	await get_tree().create_timer(3.0, true).timeout
	_cer(v2 != null and is_instance_valid(v2) and v2.visible, "si ecranul a aparut dupa animatie")
	if v2 != null and is_instance_valid(v2):
		v2._btn_continua.pressed.emit()

	GameSettings.reset_run()
	print("\nGATA: %s" % ("TOTUL OK" if _esecuri == 0 else "%d ESECURI" % _esecuri))
	get_tree().quit()
