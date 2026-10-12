extends Node

# UNEALTĂ: CHALLENGE-URILE + pagina CHOOSE MODE (2026-10-12). Nu face parte din joc.
#
#   "<godot.exe>" --path <proiect> res://tool_challenges.tscn
#
# ⚠️ NU headless: secțiunea [1] face poze cu meniul.
#
# ⚠️ ATINGE SALVAREA ADEVĂRATĂ: bifa unui challenge (`Challenges.marcheaza_terminat`) cheamă
# `GameSettings._save()`, care scrie tot ce e în RAM. Unealta citește fișierul ÎNTREG la pornire
# și îl scrie la loc, octet cu octet, la sfârșit — dar numai dacă a citit ceva (un buffer gol scris
# „la loc" ar fi șters salvarea; s-a întâmplat pe 2026-09-26 cu altă unealtă). Fă-ți oricum o copie
# a lui `scores.save` înainte și verifică după cu `cmp`.
#
#   [1] meniul: START → CHOOSE MODE; NORMAL + 3 challenge-uri; bifa urmărește salvarea (poze)
#   [2] Speedrunner: +10 noroc, lumea normală 8:00, Nether 5:00, Ender 4:00, Castel 3:00
#   [3] Dual Wield: 2 arme diferite, −10 damage (min 1), −50% attack speed
#   [4] Randomizer: fără ecran, un item pe nivel, șanse egale (apar și rarități mari)
#   [5] leaderboard-ul refuză rundele cu challenge; YOU WIN dă bifa
#   [6] marginea dimensiunilor: te oprești unde ÎNCEPE negrul, nu în el

const POZE := "user://challenges_%s.png"

var _erori := 0
var _salvare_bytes := PackedByteArray()
var _stare := {}

func _ok(m: String) -> void:
	print("  [OK]  ", m)

func _fail(m: String) -> void:
	_erori += 1
	print("  [NU]  ", m)

func _cer(cond: bool, m: String) -> void:
	if cond:
		_ok(m)
	else:
		_fail(m)

func _ready() -> void:
	await get_tree().process_frame
	if FileAccess.file_exists(GameSettings.SAVE_PATH):
		_salvare_bytes = FileAccess.get_file_as_bytes(GameSettings.SAVE_PATH)
	_stare = {
		"character": GameSettings.character, "weapon_type": GameSettings.weapon_type,
		"unlocked": GameSettings.unlocked.duplicate(), "upgrades": GameSettings.upgrades.duplicate(),
		"op_start": GameSettings.op_start, "challenges_done": GameSettings.challenges_done.duplicate(),
		"scores": GameSettings.scores.duplicate(true),
	}
	# măsurătorile pe cifre curate: fără magazin, fără cheat, The G, toate armele deschise (în RAM)
	GameSettings.upgrades = {}
	GameSettings.op_start = false
	GameSettings.character = "grasu"
	for a in ["pistol", "mage", "sword", "scythe", "knife", "cross"]:
		GameSettings.unlocked[a] = true

	print("\n================ CHALLENGES ================")
	await _sectiunea_1()
	await _sectiunea_2()
	await _sectiunea_3()
	await _sectiunea_4()
	await _sectiunea_5()
	await _sectiunea_6()
	_gata()

func _poza(nume: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(POZE % nume))
	print("  poză: ", POZE % nume)

func _player(arma: String = "pistol") -> Node:
	GameSettings.weapon_type = arma
	var p: Node = load("res://player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	return p

func _sterge(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------------------
func _sectiunea_1() -> void:
	print("\n[1] MENIUL: START -> CHOOSE MODE")
	Challenges.activ = ""
	GameSettings.challenges_done = {}
	var m: Node = load("res://menu.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	m._skip_intro()
	await get_tree().create_timer(0.3).timeout
	m._on_start()
	await get_tree().process_frame
	_cer(m._panels.has("mod") and m._panels["mod"].visible, "START deschide pagina CHOOSE MODE (nu pornește runda)")
	_cer(m._bife.size() == 3, "3 challenge-uri pe pagină (%d)" % m._bife.size())
	var nicio := true
	for id in m._bife:
		if m._bife[id].bifat:
			nicio = false
	_cer(nicio, "salvare fără bife -> nicio căsuță bifată")
	await get_tree().create_timer(0.4).timeout
	await _poza("pagina")
	GameSettings.challenges_done = {"dual_wield": true}
	m._show("main")
	m._show("mod")
	_cer(m._bife["dual_wield"].bifat and not m._bife["speedrunner"].bifat, "Dual Wield terminat -> doar el e bifat")
	await get_tree().create_timer(0.3).timeout
	await _poza("bifat")
	# încape pe ecran? (648 de bază)
	var r: Rect2 = m._panels["mod"].get_child(0).get_child(0).get_global_rect()
	var vp := get_viewport().get_visible_rect().size
	_cer(r.position.y >= 0.0 and r.end.y <= vp.y, "pagina încape pe înălțime (%d..%d din %d)" % [int(r.position.y), int(r.end.y), int(vp.y)])
	GameSettings.challenges_done = {}
	await _sterge(m)

# ---------------------------------------------------------------------------
func _sectiunea_2() -> void:
	print("\n[2] SPEEDRUNNER")
	Challenges.activ = ""
	var n0: float = Difficulty.run_length()
	Challenges.activ = "speedrunner"
	_cer(is_equal_approx(n0, 600.0) and is_equal_approx(Difficulty.run_length(), 480.0), "lumea normală: 10:00 -> 8:00 (%d -> %d s)" % [int(n0), int(Difficulty.run_length())])
	for t in [["res://nether.gd", 300.0, "Nether 7:00 -> 5:00"], ["res://ender.gd", 240.0, "Ender 6:00 -> 4:00"], ["res://prison.gd", 180.0, "Castel 5:00 -> 3:00"]]:
		var o: Object = load(t[0]).new()
		_cer(is_equal_approx(o._durata(), t[1]), "%s (%d s)" % [t[2], int(o._durata())])
		o.free()
	Difficulty.reset_run()
	Difficulty.time = 479.0
	_cer(not Difficulty.is_final_swarm(), "la 7:59 încă nu e Final Swarm")
	Difficulty.time = 481.0
	_cer(Difficulty.is_final_swarm(), "la 8:01 e Final Swarm")
	Difficulty.reset_run()
	var p: Node = await _player()
	_cer(is_equal_approx(p.luck, 10.0), "pornește cu 10 noroc (%.1f)" % p.luck)
	await _sterge(p)
	Challenges.activ = ""
	var p2: Node = await _player()
	_cer(is_equal_approx(p2.luck, 0.0), "Normal: 0 noroc (%.1f)" % p2.luck)
	await _sterge(p2)

# ---------------------------------------------------------------------------
func _sectiunea_3() -> void:
	print("\n[3] DUAL WIELD")
	Challenges.activ = "dual_wield"
	var vazute := {}
	var bune := true
	for i in 12:
		var p: Node = await _player("pistol")
		var a: String = p.arma_aleasa
		var b: String = p.arme_secundare[0] if p.arme_secundare.size() > 0 else ""
		vazute[a] = true
		var dmg_baza: int = int(p.ARME[a]["damage"])
		var int_baza: float = float(p.ARME[a]["interval"])
		if b == "" or b == a or p.arme_secundare.size() != 1:
			bune = false
			_fail("rularea %d: arme %s + %s" % [i, a, b])
		if p.bullet_damage != maxi(1, dmg_baza - 10):
			bune = false
			_fail("rularea %d (%s): damage %d, trebuia %d" % [i, a, p.bullet_damage, maxi(1, dmg_baza - 10)])
		if not is_equal_approx(p.fire_interval, int_baza * 2.0):
			bune = false
			_fail("rularea %d (%s): pauză %.3f, trebuia %.3f" % [i, a, p.fire_interval, int_baza * 2.0])
		await _sterge(p)
	_cer(bune, "12 runde: mereu 2 arme DIFERITE, damage −10 (min 1), attack speed −50%")
	_cer(vazute.size() >= 3, "arma principală chiar e random (%d arme diferite în 12 runde: %s)" % [vazute.size(), str(vazute.keys())])
	# Mage: 10 − 10 → 1, nu 0
	var gasit := false
	for i in 40:
		var p: Node = await _player()
		if p.arma_aleasa == "mage":
			gasit = true
			_cer(p.bullet_damage == 1, "Mage: 10 − 10 = 0 → rămâne 1 (%d)" % p.bullet_damage)
		await _sterge(p)
		if gasit:
			break
	if not gasit:
		_fail("n-a ieșit niciodată Mage în 40 de runde")
	Challenges.activ = ""

# ---------------------------------------------------------------------------
func _sectiunea_4() -> void:
	print("\n[4] RANDOMIZER")
	Challenges.activ = "randomizer"
	var p: Node = await _player()
	p.max_hp = 100000000
	p.hp = p.max_hp
	var lvl := CanvasLayer.new()
	lvl.set_script(load("res://levelup.gd"))
	add_child(lvl)
	await get_tree().process_frame
	var hud := CanvasLayer.new()
	hud.set_script(load("res://hud.gd"))
	add_child(hud)
	await get_tree().process_frame
	var n0: int = p.run_items.size()
	p._level_up(false)
	await get_tree().process_frame
	_cer(not lvl.visible and not get_tree().paused, "level up: NU apare ecranul, jocul nu se oprește")
	_cer(p.run_items.size() == n0 + 1, "...dar ai primit un item (%s)" % str(p.run_items.slice(n0)))
	await get_tree().create_timer(0.5).timeout
	await _poza("randomizer")
	await get_tree().create_timer(2.2).timeout   # razele țin ~2,4 s, apoi vine iconița
	await _poza("randomizer_iconita")
	var rar := {}
	var lucky := false
	for i in 300:
		var k: int = p.run_items.size()
		lvl._randomizer()
		if p.run_items.size() != k + 1:
			continue
		var id: String = p.run_items[k]
		if id == "lucky_die":
			lucky = true
		var u = lvl.item_dupa_id(id)
		var r := String(u.get("rar", "common")) if u != null else "?"
		rar[r] = int(rar.get(r, 0)) + 1
	print("  rarități în 300 de niveluri: ", rar)
	_cer(not lucky, "Lucky Die nu iese niciodată")
	# Normal: Legendary ~1-3%, Mythic și mai rar. Cu șanse egale ies cam cât e lista lor.
	_cer(int(rar.get("legendary", 0)) >= 15, "Legendary des, ca orice altceva (%d din 300)" % int(rar.get("legendary", 0)))
	_cer(int(rar.get("mythic", 0)) >= 1, "apar și Mythic (%d)" % int(rar.get("mythic", 0)))
	lvl.queue_free()
	hud.queue_free()
	await _sterge(p)
	# Normal: ecranul apare ca înainte
	Challenges.activ = ""
	var p2: Node = await _player()
	var lvl2 := CanvasLayer.new()
	lvl2.set_script(load("res://levelup.gd"))
	add_child(lvl2)
	await get_tree().process_frame
	p2._level_up(false)
	_cer(lvl2.visible, "Normal: ecranul de alegere apare ca înainte")
	get_tree().paused = false
	lvl2.queue_free()
	await _sterge(p2)

# ---------------------------------------------------------------------------
func _sectiunea_5() -> void:
	print("\n[5] LEADERBOARD + BIFA")
	var inainte: int = GameSettings.scores.size()
	Challenges.activ = "speedrunner"
	GameSettings.add_score(999.0, 99, 9)
	_cer(GameSettings.scores.size() == inainte, "runda cu challenge NU intră în leaderboard")
	Challenges.activ = "randomizer"
	GameSettings.challenges_done = {}
	var v := CanvasLayer.new()
	v.set_script(load("res://victory.gd"))
	add_child(v)
	await get_tree().process_frame
	var p: Node = await _player()
	v._construieste(p)
	_cer(Challenges.terminat("randomizer"), "YOU WIN cu Randomizer -> Randomizer bifat")
	_cer(not Challenges.terminat("speedrunner"), "...și numai el")
	var txt := ""
	for l in v.find_children("*", "Label", true, false):
		txt += (l as Label).text + " | "
	_cer(txt.contains("Challenge complete"), "scrie „Challenge complete” pe ecran")
	v.queue_free()
	await _sterge(p)
	Challenges.activ = ""
	GameSettings.challenges_done = {}

# ---------------------------------------------------------------------------
func _sectiunea_6() -> void:
	print("\n[6] MARGINEA DIMENSIUNILOR")
	var g := Sprite2D.new()
	g.set_script(load("res://ground.gd"))
	add_child(g)
	await get_tree().process_frame
	g.set_margine(Vector2(1000, 1000))
	var dincolo: Vector2 = g.in_margine(Vector2(1000, 1000) + Vector2(2900, 0))
	var d := dincolo.distance_to(Vector2(1000, 1000))
	_cer(is_equal_approx(d, g.MARGINE_RAZA - g.MARGINE_FADE), "te oprești la %d px, unde ÎNCEPE să se întunece (negru plin la %d)" % [int(d), int(g.MARGINE_RAZA)])
	var inauntru: Vector2 = g.in_margine(Vector2(1000, 1000) + Vector2(0, 2200))
	_cer(inauntru == Vector2(1000, 1000) + Vector2(0, 2200), "înăuntru nu te atinge nimic")
	g.opreste_margine()
	_cer(g.in_margine(Vector2(99999, 0)) == Vector2(99999, 0), "fără margine (lumea normală) n-ai limită")
	await _sterge(g)

# ---------------------------------------------------------------------------
func _gata() -> void:
	Challenges.activ = ""
	GameSettings.character = _stare["character"]
	GameSettings.weapon_type = _stare["weapon_type"]
	GameSettings.unlocked = _stare["unlocked"]
	GameSettings.upgrades = _stare["upgrades"]
	GameSettings.op_start = _stare["op_start"]
	GameSettings.challenges_done = _stare["challenges_done"]
	GameSettings.scores = _stare["scores"]
	if _salvare_bytes.size() > 0:
		var f := FileAccess.open(GameSettings.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_salvare_bytes)
		f.close()
		print("\nsalvarea pusă la loc: %d octeți" % _salvare_bytes.size())
	else:
		print("\n⚠️ n-am citit nicio salvare la pornire, deci nu scriu nimic înapoi")
	print("=== TOTUL E BINE ===" if _erori == 0 else "=== %d PROBLEME ===" % _erori)
	get_tree().quit(1 if _erori > 0 else 0)
