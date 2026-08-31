extends Node

# UNEALTĂ (se rulează ca SCENĂ, în fereastră normală — headless randează negru):
#
#   godot --path <proiect> res://tool_saratalin_contur.tscn --quit-after 900
#
# CONTURUL MOV AL LUI SARATALIN (cerut pe 2026-08-31). Îl pune în lumea lui — atmosfera și
# podeaua de Nether — și face DOUĂ capturi din același loc: una cu materialul din `saratalin.tscn`
# și una cu `material = null`, adică exact arta lui Răzvan, neatinsă. Diferența dintre ele e
# conturul și nimic altceva.
#
# ⚠️ Conturul se măsoară în pixeli de ECRAN (`contur_1px.gdshader`), iar boss-ul se afișează la
# scale 3.4 — deci într-o captură de 1920×1080 (jocul desenează la 1152×648 și se întinde ×1.667)
# un „1px" iese ~1,7 px în poză. Nu e un contur gros, e captura mai mare decât ecranul de bază.
#
# ⚠️ Punem jocul pe PAUZĂ înainte de capturi: altfel boss-ul continuă să lovească player-ul, iar
# o rulare mai lungă l-ar omorî — moartea scrie în leaderboard-ul REAL (`user://scores.save`).

const ASTEPTARE := 2.8   # coborârea din tavan ține 1.9 s; îi lăsăm marjă să atingă pământul

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var ground: Node = main.get_node_or_null("Ground")
	if ground != null and player != null:
		ground.set_nether(true)
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null:
		atm.set_dimension("nether")

	# ⚠️ Player-ul NEMURITOR cât ține unealta. Fără asta, boss-ul îl bate cât coboară și atacă, iar
	# o rulare care nimerește prost îl OMOARĂ — iar moartea trece prin `gameover.gd`, care scrie în
	# salvarea adevărată (`add_score` + `bank_run_coins`). S-a și întâmplat, pe 2026-08-31, la una
	# din primele două rulări: scorul fals a fost tăiat de plafonul de 10 (cel mai mic din
	# leaderboard e de 671 s), dar fișierul a fost rescris. `hp`/`max_hp` sunt doar în RAM, nu se
	# salvează nicăieri, deci umflatul lor n-are cum să lase urme.
	player.max_hp = 999999
	player.hp = player.max_hp
	var boss: Node2D = load("res://saratalin.tscn").instantiate() as Node2D
	boss.global_position = player.global_position + Vector2(0, -40)
	player.get_parent().add_child(boss)
	await get_tree().create_timer(ASTEPTARE).timeout
	get_tree().paused = true

	var anim := boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	await _captura("saratalin_contur")
	var mat := anim.material
	anim.material = null
	await _captura("saratalin_fara_contur")
	anim.material = mat
	get_tree().quit()

func _captura(nume: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://%s.png" % nume))
	print("scris user://%s.png" % nume)
