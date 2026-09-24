extends Node

# UNEALTĂ: CURSORUL DIN MENIURI (2026-09-24). Nu face parte din joc.
#
# Verifică regula din `gamepad.gd` (secțiunea CURSORUL): mâna din `menu/Mouse.png` se vede în
# meniul principal și pe orice ecran cu butoane (pauză, Alba-Neagra, EGT, level up, omul în
# palton), dar NU cât joci și nici pe o cinematică pusă pe pauză (intro-ul). Și nici cu
# controllerul în mână, oriunde ai fi.
#
# Se rulează ca SCENĂ (are nevoie de autoload-uri). Poate și headless: nu face poze — cursorul îl
# desenează sistemul, deci pe o captură din Godot nu apare oricum. Se verifică `Input.mouse_mode`.
#
# ⚠️ Scenele de sub test se pun cu `current_scene = ...` de mână, nu cu `change_scene_to_file`:
# aia ar fi șters și unealta. `in_meniu()` se uită tocmai la `current_scene`.
#
# Salvarea: runda poate chema `_save()` singură, iar asta ar scrie în `scores.save` ce e în RAM.
# Nu schimbăm nimic în `GameSettings`, deci ce se scrie e ce era — dar verifică oricum cu `cmp`.

var _erori := 0

func _cer(ok: bool, m: String) -> void:
	if ok:
		print("  [OK]  " + m)
	else:
		_erori += 1
		print("  [NU]  " + m)

func _cadre(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _vizibil() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_VISIBLE

func _pune_scena(s: Node) -> void:
	get_tree().root.add_child(s)
	get_tree().current_scene = s
	await _cadre(3)

func _scoate(s: Node) -> void:
	get_tree().paused = false
	get_tree().current_scene = null
	s.queue_free()
	await _cadre(3)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # mergem mai departe și cu jocul pe pauză
	await _cadre(2)
	print("\n================ CURSORUL ================")
	Gamepad._schimba_mod("mouse")

	print("\n[1] POZA")
	_cer(Gamepad.CURSOR_POZA != null and Gamepad.CURSOR_POZA.get_width() == 48,
		"menu/Mouse.png s-a încărcat (48x62)")
	var img: Image = Gamepad.CURSOR_POZA.get_image()
	var v: Vector2i = Vector2i(Gamepad.CURSOR_VARF)
	_cer(img.get_pixelv(v).a > 0.5, "vârful %s cade pe un pixel plin al degetului" % v)
	var gol_deasupra := true
	for x in img.get_width():
		if img.get_pixel(x, 0).a > 0.05:
			gol_deasupra = false
	_cer(gol_deasupra, "și deasupra lui nu mai e nimic (e chiar vârful)")

	print("\n[2] MENIUL PRINCIPAL")
	var meniu: Node = load("res://menu.tscn").instantiate()
	await _pune_scena(meniu)
	await _cadre(10)
	_cer(Gamepad.in_meniu(), "e meniu")
	_cer(_vizibil(), "cursorul se vede")
	Gamepad._schimba_mod("pad")
	await _cadre(2)
	_cer(not _vizibil(), "cu controllerul în mână dispare")
	Gamepad._schimba_mod("mouse")
	await _cadre(2)
	_cer(_vizibil(), "un clic de mouse îl aduce înapoi")
	await _scoate(meniu)

	print("\n[3] RUNDA")
	var lume: Node = load("res://main.tscn").instantiate()
	await _pune_scena(lume)
	# intro-ul: cinematică pusă pe pauză, fără butoane
	var intro_vazut := false
	var ascuns_in_intro := true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		if get_tree().paused:
			intro_vazut = true
			if _vizibil():
				ascuns_in_intro = false
		elif intro_vazut:
			break
	if intro_vazut:
		_cer(ascuns_in_intro, "în intro (joc pe pauză, fără butoane) cursorul NU apare")
	await _cadre(5)
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.max_hp = 100000000   # moartea ar scrie în leaderboard-ul ADEVĂRAT
		p.hp = p.max_hp
	_cer(not get_tree().paused, "runda merge")
	_cer(not Gamepad.in_meniu() and not _vizibil(), "cât joci, cursorul NU se vede")

	# Pauză FĂRĂ niciun meniu deschis (cum face o cinematică): nimic n-are voie să arate mâna. Dacă
	# un strat ține în repaus un panou vizibil cu butoane, fiecare cinematică ar scoate cursorul.
	get_tree().paused = true
	await _cadre(3)
	for c in lume.get_children():
		if c is CanvasLayer and c.visible and Gamepad._are_butoane(c):
			print("  !! stratul %s ține butoane vizibile în repaus" % c.name)
	_cer(not Gamepad.in_meniu() and not _vizibil(), "joc pe pauză fără meniu (ca o cinematică) → ascuns")
	get_tree().paused = false
	await _cadre(3)

	await _ecran(lume, "Pause", "PAUZA (ESC)", func(n): n.cere_pauza(), func(n): n._on_resume())
	await _ecran(lume, "AlbaMenu", "ALBA-NEAGRA", func(n): n.open(), func(n): n._inchide())
	await _ecran(lume, "Casino", "EGT", func(n): n.open(), func(n): n._inchide())
	await _ecran(lume, "DubiosMenu", "OMUL IN PALTON", func(n): n.open(), func(n): n._inchide())
	await _ecran(lume, "LevelUp", "LEVEL UP", func(n): n.open(), Callable())

	# ESC adevărat, prin InputMap, nu prin funcție: așa se vede că merge și pe tastatură
	print("\n[4] ESC DE PE TASTATURĂ")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _cadre(5)
	esc = esc.duplicate()
	esc.pressed = false
	Input.parse_input_event(esc)
	await _cadre(5)
	_cer(get_tree().paused and _vizibil(), "ESC → pauză → cursorul apare")
	Gamepad._schimba_mod("pad")
	await _cadre(2)
	_cer(not _vizibil(), "în pauză, cu controllerul, tot ascuns")
	Gamepad._schimba_mod("mouse")
	await _cadre(2)
	lume.get_node("Pause")._on_resume()
	await _cadre(5)
	_cer(not get_tree().paused and not _vizibil(), "înapoi în joc → dispare")

	print("\n[5] COSTUL")
	var t1 := Time.get_ticks_usec()
	for i in 1000:
		Gamepad.in_meniu()
	print("  in_meniu() în rundă: %.2f µs pe apel" % (float(Time.get_ticks_usec() - t1) / 1000.0))

	await _scoate(lume)
	print("\n=========================================")
	print("=== %s ===" % ("TOTUL E BINE" if _erori == 0 else "%d PROBLEME" % _erori))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()

func _ecran(lume: Node, nume: String, titlu: String, deschide: Callable, inchide: Callable) -> void:
	print("\n[ecran] " + titlu)
	var n := lume.get_node_or_null(nume)
	_cer(n != null, "există nodul %s" % nume)
	if n == null:
		return
	deschide.call(n)
	await _cadre(20)
	_cer(get_tree().paused, "jocul e pe pauză")
	_cer(Gamepad.in_meniu() and _vizibil(), "cursorul se vede")
	if inchide.is_valid():
		inchide.call(n)
		await _cadre(20)
		_cer(not get_tree().paused and not _vizibil(), "închis → cursorul dispare")
