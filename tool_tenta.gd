extends Node2D

# UNEALTA care verifica CULOAREA PROIECTILELOR (`player.gd`, sectiunea „CULOAREA PROIECTILELOR").
#
#   godot --path <proj> res://tool_tenta.tscn        (FEREASTRA, nu --headless: face si poza)
#
# Cerinta lui Razvan (2026-09-04): 1 proiectil = normal; de la 5 proiectile un sfert ALBASTRE,
# de la 10 inca un sfert MOV, de la 20 inca un sfert VERZI, la toate armele si itemele.
#
# Verifica patru lucruri, fiindca fiecare se poate strica IN TACERE (nu crapa nimic, doar nu se
# mai vede culoarea):
#
#   1. TIPARUL, cerut chiar functiei din player: la fiecare prag ies EXACT sferturile cerute, iar
#      culorile nedeblocate nu apar deloc.
#   2. GLOANTELE ADEVARATE: se trage cu `_fire()` de-adevaratelea si se citeste materialul de pe
#      sprite-ul fiecarui glont nascut. Firul player -> glont -> sprite e singurul loc unde
#      treaba asta poate sa se rupa mut (materialul NU se mosteneste de la parinte in Godot).
#   3. SABIA SI COASA: la ele „proiectilele" extra sunt atacuri in plus, deci si taieturile /
#      tururile de lama trebuie sa se coloreze.
#   4. POZA: se randeaza arta adevarata cu fiecare culoare, ca sa se vada ca tenta chiar se vede
#      pe alama glontului (un `modulate` albastru ar fi facut-o aproape neagra — de aia e shader).
#
# ⚠️ NU se atinge `GameSettings` si nu moare nimeni, deci `user://scores.save` ramane neatinsa.

const CULORI := ["albastru", "mov", "verde"]
const PRAGURI := [5, 10, 20]
const ESANTION := 1000   # cate proiectile se numara pentru proportii

var _erori := 0
var _p: Node = null

func _cer(ok: bool, text: String) -> void:
	print(("  ✔ " if ok else "  ✘ ") + text)
	if not ok:
		_erori += 1

func _nume_slot(s: int) -> String:
	return "de baza" if s < 0 else CULORI[s]

func _ready() -> void:
	print("=== UNEALTA: culoarea proiectilelor ===")
	_p = load("res://player.tscn").instantiate()
	add_child(_p)
	await get_tree().process_frame
	# ⚠️ Player-ul TRAGE SINGUR: `fire_timer` cheama `_fire()` de la sine, iar `_process` misca
	# taieturile inapoi langa el. Cat au mers, poza iesea cu o taietura straina mazgalita peste
	# randuri (un burst de sabie pornit din senin in cele 0.7s de expunere). Le oprim pe amandoua:
	# de aici incolo trage doar unealta, cand vrea ea.
	_p.fire_timer.stop()
	_p.set_process(false)
	_p.bullet_count = 1
	_p.broken_watch_stacks = 0
	_p.aimbot_stacks = 0

	print("\n--- [1] shaderul si materialele ---")
	_cer(ResourceLoader.exists(_p.TENTA_SHADER), "shaderul `%s` exista" % _p.TENTA_SHADER)
	_cer(_p._tenta_mats.size() == CULORI.size(),
		"player-ul si-a facut cate un material pentru fiecare culoare (%d)" % _p._tenta_mats.size())
	for i in _p._tenta_mats.size():
		var c: Color = _p._tenta_mats[i].get_shader_parameter("tenta")
		print("      %-9s → %s" % [CULORI[i], str(c)])

	print("\n--- [2] tiparul, cerut functiei din player ---")
	await _verifica_tipar()

	print("\n--- [3] gloante trase de-adevaratelea ---")
	await _verifica_gloante()

	print("\n--- [4] sabia si coasa ---")
	await _verifica_melee()

	print("\n--- [5] poza ---")
	await _poza()

	print("\n=== %s ===" % ("TOTUL E BINE" if _erori == 0 else "%d PROBE PICATE" % _erori))
	get_tree().quit()

# [2] Proportiile, cerute chiar lui `_tenta_urmatoare()` (nu recalculate aici: o formula copiata
# ar fi trecut proba si cu jocul stricat). Se numara ESANTION proiectile la rand, ca in joc —
# numaratoarea curge dintr-o salva in alta, deci asta e chiar ce vede jucatorul pe termen lung.
func _verifica_tipar() -> void:
	print("  proiectile   de baza   albastru   mov      verde")
	for n in [1, 2, 4, 5, 9, 10, 19, 20, 25]:
		_p.stacked_armory_stacks = n - 1
		_p._proj_idx = 0
		var c := {-1: 0, 0: 0, 1: 0, 2: 0}
		for i in ESANTION:
			var s: int = _p._tenta_mats.find(_p._tenta_urmatoare())
			c[s] = int(c[s]) + 1
		var rand := "  %-12d" % n
		for s in [-1, 0, 1, 2]:
			rand += "%-9s" % ("%.0f%%" % (100.0 * float(c[s]) / float(ESANTION)))
		print(rand)
		# ce ASTEPTAM: fiecare culoare al carei prag l-ai atins ia exact un sfert, restul zero
		var ok := true
		for i in CULORI.size():
			var vrut := 0.25 if n >= PRAGURI[i] else 0.0
			if not is_equal_approx(float(c[i]) / float(ESANTION), vrut):
				ok = false
		_cer(ok, "%d proiectile: %s" % [n, _asteptat_text(n)])

func _asteptat_text(n: int) -> String:
	var parti := []
	for i in CULORI.size():
		if n >= PRAGURI[i]:
			parti.append("25%% " + CULORI[i])
	if parti.is_empty():
		return "toate in culoarea de baza"
	return "un sfert pentru fiecare din " + ", ".join(parti)

# [3] Se trage cu `_fire()`, exact ca in joc, si se citeste materialul de pe SPRITE-ul fiecarui
# glont nascut — nu de pe nodul-glont, care nu deseneaza nimic. Cu 20 de proiectile trebuie sa
# iasa toate cele trei culori, in sferturi.
func _verifica_gloante() -> void:
	var tinte := _pune_inamici(8)
	for arma in ["pistol", "mage", "knife"]:
		_p.weapon_type = arma
		_p.stacked_armory_stacks = 19    # 1 + 19 = 20 de proiectile
		_p._proj_idx = 0
		_curata_gloante()
		for salva in 5:
			_p._fire()
		var c := {-1: 0, 0: 0, 1: 0, 2: 0}
		var fara_sprite := 0
		for b in _gloante():
			var spr := b.get_node_or_null("Sprite2D") as CanvasItem
			if spr == null:
				fara_sprite += 1
				continue
			# la mage, glontul de alama e ascuns si desenul e izbucnirea adaugata peste el
			var desen: CanvasItem = spr
			if arma == "mage":
				for k in b.get_children():
					if k is AnimatedSprite2D:
						desen = k
			var s: int = _p._tenta_mats.find(desen.material)
			c[s] = int(c[s]) + 1
		var total: int = _gloante().size()
		_cer(total == 100, "%s: 5 salve x 20 de proiectile = %d gloante" % [arma, total])
		_cer(fara_sprite == 0, "%s: fiecare glont are un desen de colorat" % arma)
		var ok := total > 0
		for i in CULORI.size():
			if not is_equal_approx(float(c[i]) / float(max(total, 1)), 0.25):
				ok = false
		_cer(ok, "%s: sferturile ajung pe gloantele adevarate (baza %d, albastru %d, mov %d, verde %d)"
			% [arma, c[-1], c[0], c[1], c[2]])
	_curata_gloante()
	for t in tinte:
		t.queue_free()
	await get_tree().process_frame

func _pune_inamici(n: int) -> Array:
	var iesire := []
	for i in n:
		var e := Node2D.new()
		e.add_to_group("enemy")
		add_child(e)
		e.global_position = _p.global_position + Vector2(220, 0).rotated(TAU * float(i) / float(n))
		iesire.append(e)
	return iesire

func _gloante() -> Array:
	var iesire := []
	for c in get_children():
		if c is Area2D:
			iesire.append(c)
	return iesire

func _curata_gloante() -> void:
	for b in _gloante():
		remove_child(b)
		b.free()

# [4] Sabia si coasa: aici „proiectilele" extra sunt atacuri in plus (vezi `_start_burst`), deci
# taieturile si tururile de lama trebuie sa se coloreze dupa acelasi tipar. Se cheama direct
# atacul, de 8 ori, ca sa se vada doua cicluri intregi fara sa astepti burst-ul in timp real.
func _verifica_melee() -> void:
	for arma in ["sword", "scythe"]:
		_p.weapon_type = arma
		_p.stacked_armory_stacks = 19
		_p._proj_idx = 0
		_p._slashes.clear()
		_p._sweeps.clear()
		var sloturi := []
		for i in 8:
			if arma == "sword":
				_p._sword_swing()
			else:
				_p._scythe_swing()
			var lista: Array = _p._slashes if arma == "sword" else _p._sweeps
			if lista.is_empty():
				continue
			var nod: CanvasItem = lista[lista.size() - 1]["nod"] as CanvasItem
			sloturi.append(-2 if nod == null else _p._tenta_mats.find(nod.material))
		_cer(sloturi.size() == 8, "%s: opt atacuri, opt desene (%d)" % [arma, sloturi.size()])
		_cer(sloturi == [-1, 0, 1, 2, -1, 0, 1, 2],
			"%s: tiparul se repeta din patru in patru → %s"
			% [arma, str(sloturi.map(func(s): return _nume_slot(s)))])
		for t in _p._slashes + _p._sweeps:
			var nod: Node = t["nod"]
			if nod != null and is_instance_valid(nod):
				nod.get_parent().remove_child(nod)
				nod.free()   # nu queue_free: ar fi ramas in poza de la [5]
		_p._slashes.clear()
		_p._sweeps.clear()
	await get_tree().process_frame

# [5] POZA. Arta ADEVARATA, colorata prin drumul adevarat (`_spawn_one_bullet` / `_sword_swing`),
# doar oprita din zbor si asezata pe randuri ca sa incapa in cadru. Umflata de 3 ori: la marimea
# din joc un glont are 27px si nu s-ar vedea daca albastrul e albastru sau doar inchis.
const POZA_ZOOM := 3.0
const COL_X := [-300.0, -100.0, 100.0, 300.0]
const RAND_Y := {"pistol": -170.0, "mage": -40.0, "knife": 90.0, "sword": 215.0, "marime reala": 330.0}

var _probe := []   # {arma, slot, nod} — de aici se citesc pixelii la [6]

func _poza() -> void:
	_curata_gloante()
	_curata_lame()
	var anim := _p.get_node_or_null("AnimatedSprite2D")
	if anim != null:
		anim.visible = false          # camera ramane pe el, doar personajul nu mai sta in poza
	_p.stacked_armory_stacks = 19     # 20 de proiectile = toate cele trei culori deblocate
	_fundal()
	for arma in ["pistol", "mage", "knife"]:
		_p.weapon_type = arma
		_p._proj_idx = 0
		for i in 4:
			_p._spawn_one_bullet(Vector2.ZERO, Vector2.RIGHT, 10, 0.0, 0)
			var b := get_children()[get_child_count() - 1] as Node2D
			b.speed = 0.0
			b.homing_turn = 0.0
			b.scale *= POZA_ZOOM
			b.global_position = _p.global_position + Vector2(COL_X[i], RAND_Y[arma])
			_probe.append({"arma": arma, "slot": i - 1, "nod": b})
	# Un rand LA MARIMEA DIN JOC (fara POZA_ZOOM): randurile de sus sunt umflate de 3 ori ca sa se
	# vada desenul, dar intrebarea adevarata e daca albastrul se citeste ca albastru pe un glont de
	# 27 de pixeli, in fuga. Aici se vede.
	_p.weapon_type = "pistol"
	_p._proj_idx = 0
	for i in 4:
		_p._spawn_one_bullet(Vector2.ZERO, Vector2.RIGHT, 10, 0.0, 0)
		var b2 := get_children()[get_child_count() - 1] as Node2D
		b2.speed = 0.0
		b2.homing_turn = 0.0
		b2.global_position = _p.global_position + Vector2(COL_X[i], RAND_Y["marime reala"])
		_probe.append({"arma": "marime reala", "slot": i - 1, "nod": b2})
	_p.weapon_type = "sword"
	_p._proj_idx = 0
	# ⚠️ Intai se fac toate patru, apoi se GOLESTE `_slashes` si abia dupa aia se aseaza pe randuri:
	# cat timp o taietura e in lista, `_update_slashes` o pune inapoi langa player la fiecare cadru
	# — prima varianta a pozei le avea pe toate patru una peste alta si proba citea acelasi gri.
	var taieturi := []
	for i in 4:
		_p._sword_swing()
		if _p._slashes.is_empty():
			break
		taieturi.append(_p._slashes[_p._slashes.size() - 1]["nod"])
	_p._slashes.clear()
	for i in taieturi.size():
		var nod := taieturi[i] as AnimatedSprite2D
		if nod == null:
			continue
		nod.speed_scale = 0.0    # inghetat pe un cadru plin; e o poza, nu o animatie
		nod.frame = int(nod.sprite_frames.get_frame_count("fx") / 2)
		nod.rotation = 0.0
		var ps: float = max(_p.scale.x, 0.001)
		nod.position = Vector2(COL_X[i], RAND_Y["sword"]) / ps
		_probe.append({"arma": "sword", "slot": i - 1, "nod": nod})
	await get_tree().process_frame
	_etichete()
	await get_tree().create_timer(0.7).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://tenta.png"))
	print("  poza: user://tenta.png (%dx%d)" % [img.get_width(), img.get_height()])
	print("\n--- [6] culorile citite chiar din pixelii randati ---")
	_verifica_poza(img)

# UNDE se vede pe ecran un nod din lume. Nu se socoteste de mana (576 + x): camera player-ului are
# zoom 0.7, deci lumea si ecranul NU sunt la scara 1:1 — prima varianta a probei citea alaturi de
# proiectil si raporta „fundal" acolo unde pe ecran era un glont colorat.
func _pe_ecran(nod: Node2D) -> Vector2:
	return get_viewport().get_canvas_transform() * nod.global_position

func _fundal() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var r := ColorRect.new()
	r.color = FUNDAL
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(r)

func _etichete() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var capete := ["de baza", "albastru 5+", "mov 10+", "verde 20+"]
	for p in _probe:
		var e := _pe_ecran(p["nod"])
		if p["arma"] == "pistol":
			_eticheta(cl, capete[int(p["slot"]) + 1], Vector2(e.x - 40.0, 26.0), 120.0)
		if int(p["slot"]) == -1:
			_eticheta(cl, String(p["arma"]).to_upper(), Vector2(24.0, e.y - 12.0), 160.0)

func _eticheta(cl: CanvasLayer, text: String, poz: Vector2, latime: float) -> void:
	var l := Label.new()
	l.text = text
	l.position = poz
	l.size = Vector2(latime, 26.0)
	l.add_theme_font_size_override("font_size", 15)
	cl.add_child(l)

# [6] CULORILE CITITE DIN POZA. Probele de mai sus se uita la MATERIALUL pus pe sprite — trec si
# cu shaderul rupt (m-a prins pe 2026-09-04: un `:=` in loc de `=` in GLSL, shaderul nu compila,
# toate cele 12 probe de mai sus ieseau verzi si pe ecran nu se schimba absolut nimic). Asta se
# uita la PIXELII randati: coloana albastra trebuie sa fie chiar albastra pe ecran.
const FUNDAL := Color(0.06, 0.06, 0.09)
const RAZA_PROBA := 45          # jumatatea patratului citit, in pixeli de captura

func _verifica_poza(img: Image) -> void:
	var f := float(img.get_width()) / 1152.0   # captura iese la 1920, coordonatele sunt in 1152
	var pe_arma := {}
	for p in _probe:
		var r := _culoare_medie(img, _pe_ecran(p["nod"]) * f)
		if not pe_arma.has(p["arma"]):
			pe_arma[p["arma"]] = {}
		pe_arma[p["arma"]][int(p["slot"])] = r
	for arma in pe_arma:
		var c: Dictionary = pe_arma[arma]
		print("      %-7s  baza %s | albastru %s | mov %s | verde %s"
			% [arma, _hex(c[-1]), _hex(c[0]), _hex(c[1]), _hex(c[2])])
		# ⚠️ Intai „s-a desenat ceva acolo?". Fara proba asta, un punct nimerit pe fundal
		# (#0f0f17) trecea drept „albastru", fiindca si fundalul are albastrul peste rosu.
		var goale := []
		for s in [-1, 0, 1, 2]:
			if c[s]["pixeli"] == 0:
				goale.append(_nume_slot(s))
		_cer(goale.is_empty(), "%s: toate cele patru proiectile se vad in poza%s"
			% [arma, "" if goale.is_empty() else "  GOALE: " + str(goale)])
		if not goale.is_empty():
			continue
		var baza: Color = c[-1]["col"]
		var a: Color = c[0]["col"]
		var m: Color = c[1]["col"]
		var v: Color = c[2]["col"]
		_cer(a.b > a.r and a.b > a.g, "%s: albastrul chiar e albastru pe ecran" % arma)
		_cer(m.b > m.g and m.r > m.g, "%s: movul chiar e mov pe ecran" % arma)
		_cer(v.g > v.r and v.g > v.b, "%s: verdele chiar e verde pe ecran" % arma)
		# si ca proiectilul NEATINS a ramas cum era: altfel ar fi colorate toate, nu un sfert
		var deosebit := absf(baza.r - a.r) + absf(baza.g - a.g) + absf(baza.b - a.b)
		_cer(deosebit > 0.10, "%s: proiectilul de baza a ramas neatins (se deosebeste cu %.2f)"
			% [arma, deosebit])

# Media pixelilor care NU sunt fundal, in patratul din jurul punctului, plus CATI au fost. Fundalul
# se scoate ca sa nu traga media spre gri-ul inchis si sa iasa „toate culorile la fel".
func _culoare_medie(img: Image, centru: Vector2) -> Dictionary:
	var s := Vector3.ZERO
	var n := 0
	for y in range(int(centru.y) - RAZA_PROBA, int(centru.y) + RAZA_PROBA):
		for x in range(int(centru.x) - RAZA_PROBA, int(centru.x) + RAZA_PROBA):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var p := img.get_pixel(x, y)
			if absf(p.r - FUNDAL.r) < 0.02 and absf(p.g - FUNDAL.g) < 0.02 and absf(p.b - FUNDAL.b) < 0.02:
				continue
			s += Vector3(p.r, p.g, p.b)
			n += 1
	if n == 0:
		return {"col": FUNDAL, "pixeli": 0}
	s /= float(n)
	return {"col": Color(s.x, s.y, s.z), "pixeli": n}

func _hex(d: Dictionary) -> String:
	if int(d["pixeli"]) == 0:
		return "(gol)  "
	return "#" + Color(d["col"]).to_html(false)

# Orice taietura / lama ramasa de la probele de mai sus. Sunt copii ai player-ului, deci stau fix
# in mijlocul pozei si arata ca o mazgalitura peste randuri. Se face acum, nu la [4]: acolo
# `queue_free` le-ar fi lasat vii inca un cadru.
func _curata_lame() -> void:
	var propriul := _p.get_node_or_null("AnimatedSprite2D")
	for c in _p.get_children():
		if c == propriul:
			continue
		if c is Sprite2D or c is AnimatedSprite2D:
			_p.remove_child(c)
			c.free()
