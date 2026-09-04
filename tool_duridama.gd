extends Node2D

# UNEALTĂ: merge Duridama cu FIECARE din cele cinci arme? (nu face parte din joc)
#
#   "<godot.exe>" --path <proiect> res://tool_duridama.tscn
#
# Se rulează ca SCENĂ (are nevoie de autoload-uri) și poate merge headless: nu face poze.
#
# Cum măsoară, per armă:
#   1. un inamic pus în fața player-ului, șansa de aurire pusă la 100% (`duridama_stacks = 100`);
#   2. o lovitură → inamicul trebuie să iasă AURIT și cu viața NEATINSĂ (aurirea nu face damage);
#   3. încă o lovitură → trebuie să moară pe loc, cu `_xp_bonus == 2.0`.
# Dacă o armă nu trece prin `enemy.take_damage()`, pasul 2 nu se întâmplă și se vede aici.
#
# Apoi aceeași probă cu șansa REALĂ a unei singure luări (1%), pe multe lovituri, ca să se vadă
# că nu e ceva ce merge doar la 100%.

const ARME := ["pistol", "mage", "knife", "sword", "scythe"]
const ENEMY := "res://enemy.tscn"
const DIST := 40.0            # cât de aproape stă inamicul de player (în raza oricărei arme)
const CADRE_IMPACT := 45      # câte cadre așteptăm ca glonțul să zboare / tăietura să treacă

var _err := 0
var _p: Node = null

func _ok(m: String) -> void:
	print("  [OK]  ", m)

func _fail(m: String) -> void:
	_err += 1
	print("  [NU]  ", m)

func _cer(cond: bool, m: String) -> void:
	if cond:
		_ok(m)
	else:
		_fail(m)

func _ready() -> void:
	await get_tree().process_frame
	print("\n========== DURIDAMA PE FIECARE ARMĂ ==========")
	_p = load("res://player.tscn").instantiate()
	add_child(_p)
	_p.global_position = Vector2.ZERO
	if _p.get("fire_timer") != null:
		_p.fire_timer.stop()      # tragem noi, când vrem
	# ⚠️ Player-ul stă lipit de inamici toată proba, deci ar muri de damage de contact — iar la
	# moarte pornește ecranul de gameover, care REÎNCARCĂ scena (unealta o lua de la capăt la
	# nesfârșit) și scrie în leaderboard-ul ADEVĂRAT. Îi dăm viață cât să nu se pună problema.
	_p.max_hp = 100000000
	_p.hp = _p.max_hp
	await get_tree().process_frame

	await _sectiunea_1()
	await _sectiunea_2()
	await _sectiunea_3()
	await _sectiunea_4()

	print("\n==============================================")
	if _err == 0:
		print("=== TOTUL E BINE ===")
	else:
		print("=== %d PROBLEME ===" % _err)
	get_tree().quit(1 if _err > 0 else 0)

func _curata_inamicii() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.free()

# Un inamic pus exact sub player (`facing_dir()` e DOWN la pornire, deci e și în bătaia săbiei).
func _pune_inamic() -> Node2D:
	var e := load(ENEMY).instantiate() as Node2D
	add_child(e)
	e.global_position = _p.global_position + Vector2(0, DIST)
	return e

# ⚠️ Curăță TOT ce a mai rămas viu din tragerea dinainte: gloanțe pe drum (sunt copii ai
# scenei, vezi `get_parent().add_child(bullet)` din player.gd), tăieturi de sabie care mai dau
# treceri de damage cât ține animația, și tururi de coasă neterminate.
#
# Fără asta, proba MINTE: prima variantă a uneltei raporta că mage și coasa „aurește și ucide
# din aceeași tragere", când de fapt o tăietură de sabie rămasă din proba dinainte îl aurea,
# iar arma de acum doar îl termina. Adică exact concluzia greșită, cu toate probele verzi.
func _curata_atacurile() -> void:
	for t in _p._slashes:
		if is_instance_valid(t["nod"]):
			t["nod"].queue_free()
	_p._slashes.clear()
	for t in _p._sweeps:
		if is_instance_valid(t["nod"]):
			t["nod"].queue_free()
	_p._sweeps.clear()
	_p._burst_left = 0
	for c in get_children():
		if c == _p or c.is_in_group("enemy"):
			continue
		c.queue_free()

func _asteapta(cadre: int) -> void:
	for i in cadre:
		await get_tree().process_frame

func _trage(arma: String) -> void:
	_p._fire_secundar(arma)

# ---------------------------------------------------------------------------
# [1] Cu șansa la 100%: ce face FIECARE armă, urmărit cadru cu cadru
# ---------------------------------------------------------------------------
# ⚠️ Nu e destul să te uiți DUPĂ ce s-a terminat totul: la mage și la coasă inamicul apucă să fie
# aurit ȘI ucis în aceeași tragere, deci o probă care se uită la sfârșit vede doar un nod dispărut
# și nu poate spune dacă a fost aurit sau pur și simplu omorât de damage. De-aia urmărim fiecare
# cadru: ținem minte dacă a fost aurit vreodată și cu ce bonus de XP a murit.
func _urmareste(e: Node2D, cadre: int) -> Dictionary:
	var r := {"aurit": false, "mort": false, "xp": 1.0, "hp": 0, "cadru_aurit": -1, "cadru_mort": -1}
	for i in cadre:
		await get_tree().process_frame
		if not is_instance_valid(e):
			r["mort"] = true
			break
		if e.golden and not r["aurit"]:
			r["aurit"] = true
			r["cadru_aurit"] = i
		if e._dying and not r["mort"]:
			r["mort"] = true
			r["cadru_mort"] = i
			r["xp"] = e._xp_bonus
		r["hp"] = e.hp
	return r

func _sectiunea_1() -> void:
	print("\n--- [1] șansa pusă la 100%, o armă pe rând ---")
	_p.duridama_stacks = 100      # 100 × 1% = 100%
	_cer(is_equal_approx(_p.duridama_chance(), 1.0), "șansa de aurire e 100%% (%d luări)" % _p.duridama_stacks)

	for arma in ARME:
		_curata_inamicii()
		_curata_atacurile()
		await _asteapta(3)
		await get_tree().process_frame
		var e := _pune_inamic()
		await get_tree().process_frame
		var hp0: int = e.hp

		# lovitura 1
		_trage(arma)
		var r1 := await _urmareste(e, CADRE_IMPACT)
		_cer(r1["aurit"], "%s: prima lovitură l-a AURIT (cadrul %d)" % [arma, r1["cadru_aurit"]])
		if r1["mort"]:
			_fail("%s: a și MURIT din prima tragere (cadrul %d, XP ×%.1f) — nu apuci să vezi inamicul auriu" % [arma, r1["cadru_mort"], r1["xp"]])
			continue
		_cer(r1["hp"] == hp0, "%s: aurirea nu i-a scăzut viața (%d/%d)" % [arma, r1["hp"], hp0])

		# lovitura 2
		_trage(arma)
		var r2 := await _urmareste(e, CADRE_IMPACT)
		_cer(r2["mort"], "%s: a doua lovitură l-a ucis pe loc" % arma)
		_cer(is_equal_approx(r2["xp"], 2.0) or not is_instance_valid(e), "%s: a murit ca aurit (XP ×%.1f)" % [arma, r2["xp"]])
	_curata_inamicii()

# ---------------------------------------------------------------------------
# [2] Câte lovituri ROSTOGOLESC zarul, per armă
# ---------------------------------------------------------------------------
# Un inel de inamici în jurul player-ului, o singură tragere, șansa la 100%: câți se aurește
# deodată = câte lovituri distincte dă arma aia într-o tragere. Arată dacă vreo armă lovește fără
# să treacă prin `take_damage` (ăia n-ar ieși niciodată auriți).
const IN_INEL := 40
const RAZA_INEL := 46.0

func _sectiunea_2() -> void:
	print("\n--- [2] câți inamici atinge o tragere (șansa tot 100%) ---")
	_p.duridama_stacks = 100
	for arma in ARME:
		_curata_inamicii()
		_curata_atacurile()
		await _asteapta(3)
		await get_tree().process_frame
		var lista := []
		for i in IN_INEL:
			var unghi := TAU * i / float(IN_INEL)
			var e := load(ENEMY).instantiate() as Node2D
			add_child(e)
			e.global_position = _p.global_position + Vector2(RAZA_INEL, 0).rotated(unghi)
			lista.append(e)
		await get_tree().process_frame
		_trage(arma)
		var auriti := 0
		var morti := 0
		for i in CADRE_IMPACT:
			await get_tree().process_frame
		for e in lista:
			if not is_instance_valid(e):
				morti += 1
			elif e.golden:
				auriti += 1
			elif e._dying:
				morti += 1
		_cer(auriti + morti > 0, "%s: %d auriți + %d morți din %d inamici, dintr-o tragere" % [arma, auriti, morti, IN_INEL])
	_curata_inamicii()

# ---------------------------------------------------------------------------
# [3] Aceeași capcană, dar venită dintr-un ITEM: Jean's Bomb
# ---------------------------------------------------------------------------
# Mage Staff-ul nu era un caz special — era doar singura armă cu AOE din construcție. Jean's Bomb
# pune aceeași explozie pe ORICE armă, deci trebuie să se poarte la fel: glonțul aurește, explozia
# lui NU-l termină, iar tragerea următoare da.
func _sectiunea_3() -> void:
	print("\n--- [3] Jean's Bomb pe pistol (aceeași capcană, adusă de un item) ---")
	_curata_inamicii()
	_curata_atacurile()
	await _asteapta(3)
	_p.duridama_stacks = 100
	_p.explosion_radius = 130.0
	_p.explosion_damage_pct = 0.15
	var e := _pune_inamic()
	await get_tree().process_frame
	var hp0: int = e.hp
	_trage("pistol")
	var r1 := await _urmareste(e, CADRE_IMPACT)
	_cer(r1["aurit"], "pistol + Jean's Bomb: glonțul l-a AURIT (cadrul %d)" % r1["cadru_aurit"])
	_cer(not r1["mort"], "pistol + Jean's Bomb: explozia glonțului NU l-a terminat pe loc")
	if not r1["mort"]:
		_cer(r1["hp"] == hp0, "pistol + Jean's Bomb: viața neatinsă (%d/%d)" % [r1["hp"], hp0])
		_trage("pistol")
		var r2 := await _urmareste(e, CADRE_IMPACT)
		_cer(r2["mort"], "pistol + Jean's Bomb: a doua tragere l-a ucis")
	_p.explosion_radius = 0.0
	_p.explosion_damage_pct = 0.0
	_curata_inamicii()

# ---------------------------------------------------------------------------
# [4] Poza: inamici auriți cu TOIAGUL, ceea ce înainte era imposibil de văzut
# ---------------------------------------------------------------------------
# Rulează în FEREASTRĂ (fără --headless), altfel iese neagră.
func _sectiunea_4() -> void:
	print("\n--- [4] poza ---")
	_curata_inamicii()
	_curata_atacurile()
	await _asteapta(3)
	_p.duridama_stacks = 100
	for i in 14:
		var e := load(ENEMY).instantiate() as Node2D
		add_child(e)
		e.global_position = _p.global_position + Vector2(120.0, 0).rotated(TAU * i / 14.0)
	await get_tree().process_frame
	_trage("mage")
	await _asteapta(CADRE_IMPACT)
	var auriti := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.golden:
			auriti += 1
	_cer(auriti > 0, "%d inamici auriți pe ecran, cu Mage Staff-ul" % auriti)
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.3).timeout
	var cale := "user://duridama_mage.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(cale))
	print("  poza: ", ProjectSettings.globalize_path(cale))
	_curata_inamicii()
