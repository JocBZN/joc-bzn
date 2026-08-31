extends Node

# UNEALTĂ DE VERIFICARE (se rulează ca SCENĂ, în fereastră normală — headless randează negru):
#
#   godot --path <proiect> res://tool_biome_identic.tscn
#
# Pe 2026-08-31 `biome.gdshader` a fost optimizat: bucla peste cele 9 macro-celule vecine sare
# acum peste vecinii care nu pot contribui (vezi comentariul lung de acolo). Argumentul e
# matematic — un petic de deșert nu iese din macro-celula lui, deci de dincolo de graniță nu
# poate ajunge mai aproape de tine decât granița însăși, iar de la `blend_chunks` încolo aportul
# lui e fix 0. Dar un argument nu e o dovadă: unealta asta o face.
#
# Ce face: pune podeaua în `POZITII` locuri din lume (colțuri de macro-celulă, mijloc de celulă,
# coordonate mari și negative), o fotografiază O DATĂ cu shaderul NOU și O DATĂ cu cel VECHI
# (scos din git în `biome_vechi.gdshader`), pe ACELAȘI cadru, și le compară.
#
# ⚠️ Se ascunde tot în afară de podea (decor, player, inamici, HUD, vinieta): orice altceva pe
# ecran ar putea să se miște între cele două capturi și diferența n-ar mai însemna nimic.
#
# ⚠️ Pozițiile nu sunt la întâmplare: o macro-celulă are 20 de chunk-uri × 512 px = 10240 px,
# iar ecranul acoperă vreo 1920. Dacă am fotografia doar în mijloc de celulă, N-AM VEDEA NICIODATĂ
# granițele — adică exact locurile unde optimizarea are voie să greșească. De-aia jumătate din
# poziții sunt fix pe colțuri și pe muchii de macro-celulă.

const MACRO_PX := 20.0 * 512.0   # o macro-celulă: MACRO (20) chunk-uri × chunk_size (512)

const POZITII := [
	Vector2(0, 0),                              # colț de macro-celulă
	Vector2(MACRO_PX, MACRO_PX),                # alt colț
	Vector2(MACRO_PX * 0.5, MACRO_PX * 0.5),    # mijloc de celulă (aici optimizarea sare tot)
	Vector2(MACRO_PX * 3.0, MACRO_PX * 2.0),    # colț, mai departe
	Vector2(-MACRO_PX * 2.0, MACRO_PX * 7.0),   # coordonate negative
	Vector2(MACRO_PX * 10.0, -MACRO_PX * 4.0),  # departe de origine, pe muchie
	Vector2(1234, 56789),                       # oarecare
	Vector2(-98765, -4321),                     # oarecare, negativ
]

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var ground := main.get_node_or_null("Ground") as Sprite2D
	if player == null or ground == null:
		print("LIPSESTE PLAYER SAU GROUND")
		get_tree().quit()
		return

	# Golim ecranul de tot ce nu e podea.
	for nume in ["World", "Paths", "HUD", "InteractUI", "BossBar"]:
		var n := main.get_node_or_null(nume)
		if n is CanvasItem:
			(n as CanvasItem).visible = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null and atm._vignette != null:
		atm._vignette.visible = false
	# Spawner-ul ar umple ecranul cu inamici între cele două capturi.
	var sp := main.get_node_or_null("Spawner")
	if sp != null and sp.timer != null:
		sp.timer.stop()

	# ⚠️ Player-ul se ÎNGHEAȚĂ și camera rămâne fără alunecare. Altfel el continuă să se miște
	# puțin după teleportare (viteza rămasă), camera aleargă lin după el, iar fiecare captură
	# prinde altă bucată de lume. Prima variantă a uneltei aștepta 2 cadre și ieșeau diferențe în
	# 2 din 8 poziții; cu 60 de cadre ieșeau în 8 din 8 — dovadă că se mișca ceva, nu că greșea
	# shaderul. Cu ăstea două, cadrul stă locului și comparația chiar înseamnă ceva.
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.position_smoothing_enabled = false

	var nou: Shader = ground._mat.shader
	var vechi := load("res://biome_vechi.gdshader") as Shader
	if vechi == null:
		print("LIPSESTE biome_vechi.gdshader (scoate-l din git: git show HEAD:biome.gdshader)")
		get_tree().quit()
		return

	for i in POZITII.size():
		var poz: Vector2 = POZITII[i]
		player.global_position = poz
		# ⚠️ Zece cadre, nu două — și abia după ce player-ul a fost înghețat mai sus. Cât camera
		# aluneca spre poziția nouă, fiecare captură prindea ALTĂ bucată de lume: la 2 cadre ieșeau
		# diferențe în 2 din 8 poziții, la 60 în 8 din 8. Martorul de mai jos a arătat că diferența
		# era a uneltei, nu a shaderului — altfel treceam optimizarea drept stricată.
		for cadru in 10:
			await get_tree().process_frame
		ground._mat.shader = nou
		await RenderingServer.frame_post_draw
		_captura("biome_nou_%d.png" % i)
		ground._mat.shader = vechi
		await RenderingServer.frame_post_draw
		_captura("biome_vechi_%d.png" % i)
		# MARTORUL: încă o captură cu shaderul NOU, în aceleași condiții. Dacă „nou" și „martor"
		# ies diferite, atunci diferența nu vine din shader, ci din unealtă (camera care încă
		# alunecă spre poziția nouă, un cadru necopt) — și comparația nou/vechi n-ar dovedi nimic.
		# Fără martor, prima rulare ar fi trecut drept „shaderul strică pixeli".
		ground._mat.shader = nou
		await RenderingServer.frame_post_draw
		_captura("biome_martor_%d.png" % i)
		print("poz %d: %s — capturi gata" % [i, poz])

	print("Gata. Compară cu ffmpeg: biome_nou_N.png vs biome_vechi_N.png")
	get_tree().quit()

func _captura(nume: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://" + nume)
