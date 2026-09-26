extends Node2D

# UNEALTĂ: CRUCEA, arma care se învârte în jurul tău (2026-09-23). Nu face parte din joc.
#
#   "<godot.exe>" --path <proiect> res://tool_cruce.tscn
#
# Se rulează ca SCENĂ (are nevoie de autoload-uri). ⚠️ NU headless: ultima secțiune face poze, iar
# headless-ul le scoate negre.
#
# ⚠️ ATINGE SALVAREA ADEVĂRATĂ, pe două căi, deci FĂ-ȚI O COPIE a lui
# `%APPDATA%\Godot\app_userdata\JOC-BZN-Mobile\scores.save` ÎNAINTE:
#   • secțiunea [8] duce un player până la nivelul 50 pe drumul ADEVĂRAT, deci chiar deblochează
#     crucea, iar `Unlocks.deblocheaza` scrie pe disc;
#   • unealta pune și ea `GameSettings.unlocked["cross"]` cât ține măsurătoarea (vezi mai jos).
# La sfârșit pune totul înapoi cum era ȘI salvează, deci fișierul trebuie să iasă identic — dar
# verifică tu cu `cmp`, nu mă crede pe cuvânt.
#
# 🔑 DE CE deblochează unealta crucea în RAM: `player.gd::_ready` schimbă o armă neîncuiată pe
# pistol (`if not Unlocks.e_deblocat(weapon_type)`). Într-o salvare obișnuită crucea E încuiată,
# deci TOATE măsurătorile de mai jos s-ar fi luat pe pistol și ar fi ieșit verzi fără să fi probat
# nimic. Se pune direct în `GameSettings.unlocked`, NU prin `op_start`: cheat-ul ăla dă și 100
# damage, și 2,5 atacuri/s, și 10 proiectile — adică ar fi stricat exact cifrele de măsurat.
#
# Ce se probează, pe secțiuni:
#   [1] registrul armei: 30 damage, 1 tur/s, și ce scrie în panoul de level up
#   [2] inelul: două cruci, față în față, pe raza cerută (și cu player-ul la scale 2, ca în joc)
#   [3] rotația E chiar attack speed-ul: măsurată pe cadre adevărate, înainte și după un upgrade
#   [4] mărimea: fix jumătate din coasă, și crește exact cât crește ea
#   [5] damage-ul PE UN INAMIC ADEVĂRAT: 30 pe lovitură și 3 lovituri pe secundă, nu 60
#   [6] bonusul de nivel: +1 cruce la fiecare 10 niveluri (nu mai e mărime), numai cu crucea ALEASĂ
#   [7] Helping Hand: crucea primită cadou se învârte și ea, dar nu aduce bonusul de nivel
#   [8] deblocarea la nivelul 50, pe drumul adevărat, cu pancarta prinsă într-un HUD de carton
#   [9] runda ADEVĂRATĂ: crucea pornită din meniu, în lumea cu inamici, plimbată câteva secunde
#  [10] poze: inelul lângă player, pagina CHOOSE WEAPON încuiată și deblocată

const POZE := "user://cruce_%s.png"

var _erori := 0
var _caracter_initial := ""
var _arma_initiala := ""
var _unlocked_initial := {}
var _upgrades_initial := {}
var _op_initial := false

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

func _aprox(a: float, b: float, eps: float) -> bool:
	return absf(a - b) <= eps

# Un player gata de măsurat: fără moarte de contact, fără critic, fără instakill. Cele trei nu
# sunt cosmetică — un critic picat la întâmplare ar fi mutat cifra de damage și proba ar fi ieșit
# roșie o dată la câteva rulări, adică exact genul de probă în care nimeni nu mai are încredere.
func _player(arma: String = "cross") -> Node:
	GameSettings.weapon_type = arma
	var p: Node = load("res://player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	p.max_hp = 100000000
	p.hp = p.max_hp
	p.crit_chance = 0.0
	p.instakill_chance = 0.0
	p.knockback = 0.0        # altfel prima lovitură îl scoate pe inamic din inel
	return p

func _sterge(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
	await get_tree().process_frame

func _ready() -> void:
	await get_tree().process_frame
	_caracter_initial = GameSettings.character
	_arma_initiala = GameSettings.weapon_type
	_unlocked_initial = GameSettings.unlocked.duplicate()
	# ⚠️ Și magazinul, tot în RAM: `_apply_meta` adaugă damage și scade pauza dintre atacuri după
	# ce ai cumpărat. Cu el pornit, „30 damage" și „1.00/s" n-ar mai fi fost cifrele ARMEI, ci
	# cifrele armei plus cumpărăturile lui Răzvan — adică proba ar fi ieșit roșie pe un joc corect.
	_upgrades_initial = GameSettings.upgrades.duplicate()
	GameSettings.upgrades = {}
	# ⚠️ Și cheat-ul OP din meniu (`op_start`), tot numai în RAM: pornit în salvare, îi dă
	# player-ului de test 100 damage, 2.50/s și încă 9 proiectile — adică 11 cruci. Prins pe 2026-09-24.
	_op_initial = GameSettings.op_start
	GameSettings.op_start = false
	# Caracterul contează: Liu Xiang ar fi adus +1% damage pe nivel peste măsurătorile de la [5].
	GameSettings.character = "grasu"
	GameSettings.unlocked["cross"] = true   # ⚠️ NUMAI în RAM; vezi capul fișierului

	print("\n================ CRUCEA ================")
	await _sectiunea_1()
	await _sectiunea_2()
	await _sectiunea_3()
	await _sectiunea_4()
	await _sectiunea_5()
	await _sectiunea_6()
	await _sectiunea_7()
	await _sectiunea_8()
	await _sectiunea_9()
	await _sectiunea_10()
	_gata()

# ---------------------------------------------------------------------------
# [1] Registrul armei: cifrele cerute și ce scrie panoul
# ---------------------------------------------------------------------------
func _sectiunea_1() -> void:
	print("\n[1] REGISTRUL ARMEI")
	var arme: Dictionary = load("res://player.gd").get_script_constant_map().get("ARME", {})
	_cer(arme.has("cross"), "crucea e în tabelul ARME")
	var c: Dictionary = arme.get("cross", {})
	_cer(int(c.get("damage", 0)) == 30, "damage de pornire = 30 (scrie %s)" % c.get("damage", 0))
	var ture := 1.0 / float(c.get("interval", 1.0))
	_cer(_aprox(ture, 1.0, 0.001), "1 tur pe secundă (din interval iese %.4f)" % ture)
	var p: Node = await _player()
	_cer(p.weapon_type == "cross", "arma rămâne crucea, nu cade înapoi pe pistol")
	# Ce SCRIE în panoul de level up trebuie să fie aceeași cifră, nu una ținută pe lângă.
	var scris := {}
	for rand in p.stat_lines():
		scris[String(rand.get("label", ""))] = String(rand.get("value", ""))
	_cer(String(scris.get("Attack Speed", "")) == "1.00/s",
		"panoul scrie Attack Speed [%s]" % scris.get("Attack Speed", ""))
	_cer(String(scris.get("Damage", "")) == "30",
		"panoul scrie Damage [%s]" % scris.get("Damage", ""))
	await _sterge(p)

# ---------------------------------------------------------------------------
# [2] Inelul: câte cruci și unde stau
# ---------------------------------------------------------------------------
func _sectiunea_2() -> void:
	print("\n[2] INELUL")
	var p: Node = await _player()
	p.scale = Vector2(2, 2)   # ca în main.tscn — pozițiile copiilor se împart la scara asta
	await get_tree().process_frame
	await get_tree().process_frame
	_cer(p._cruci.size() == 2, "două cruci la început (sunt %d)" % p._cruci.size())
	if p._cruci.size() == 2:
		var a: Node2D = p._cruci[0]["nod"]
		var b: Node2D = p._cruci[1]["nod"]
		var da := a.global_position.distance_to(p.global_position)
		var db := b.global_position.distance_to(p.global_position)
		# 110 fix: de pe 2026-09-26 crucea nu mai are bonus de MĂRIME pe nivel (are proiectile), deci
		# la nivelul 1 orbita e exact cea din `cross_raza` (până atunci era × 1,01).
		var astept: float = p.cross_raza
		_cer(_aprox(da, astept, 0.5) and _aprox(db, astept, 0.5),
			"amândouă la %.1f px de player, deși el e la scale 2 (măsurat %.1f și %.1f)"
			% [astept, da, db])
		var unghi := absf(rad_to_deg((a.global_position - p.global_position)
			.angle_to(b.global_position - p.global_position)))
		_cer(_aprox(unghi, 180.0, 0.5), "față în față, la 180° (măsurat %.1f°)" % unghi)
	# un proiectil în plus (Gunslinger) = o cruce în plus, și se împart din nou egal pe cerc
	p.stacked_armory_stacks += 1
	await get_tree().process_frame
	_cer(p._cruci.size() == 3, "+1 proiectil → trei cruci (sunt %d)" % p._cruci.size())
	if p._cruci.size() == 3:
		var u: Array[float] = []
		for t in p._cruci:
			u.append(rad_to_deg((t["nod"].global_position - p.global_position).angle()))
		var d1 := fposmod(u[1] - u[0], 360.0)
		var d2 := fposmod(u[2] - u[1], 360.0)
		_cer(_aprox(d1, 120.0, 0.5) and _aprox(d2, 120.0, 0.5),
			"la 120° una de alta (măsurat %.1f° și %.1f°)" % [d1, d2])
	await _sterge(p)

# ---------------------------------------------------------------------------
# [3] Rotația E chiar attack speed-ul
# ---------------------------------------------------------------------------
# Măsurat pe cadre ADEVĂRATE, nu citind o variabilă: adunăm unghiul parcurs între două cadre
# (desfășurat, ca trecerea prin 360° să nu pună socoteala pe zero) și îl împărțim la timpul
# scurs, luat din ceasul de sistem. O funcție corectă pe care n-o cheamă nimeni ar fi trecut
# proba dacă ne uitam doar la `_cross_period()`.
func _ture_pe_secunda(p: Node, secunde: float) -> float:
	var t0 := Time.get_ticks_usec()
	var a0: float = p._cross_unghi
	var total := 0.0
	var scurs := 0.0
	while scurs < secunde:
		await get_tree().process_frame
		var a1: float = p._cross_unghi
		total += fposmod(a1 - a0, TAU)
		a0 = a1
		scurs = float(Time.get_ticks_usec() - t0) / 1000000.0
	return (total / TAU) / scurs

func _sectiunea_3() -> void:
	print("\n[3] ROTAȚIA")
	var p: Node = await _player()
	await get_tree().process_frame
	var v0: float = await _ture_pe_secunda(p, 1.5)
	_cer(_aprox(v0, 1.0, 0.05), "se învârte de %.3f ori pe secundă (cerut 1)" % v0)
	# un upgrade de cadență (jumătate de pauză = de două ori mai multe atacuri pe secundă)
	p.fire_interval *= 0.5
	p._seteaza_cadenta()
	await get_tree().process_frame
	var v1: float = await _ture_pe_secunda(p, 1.5)
	_cer(_aprox(v1, 2.0, 0.1), "cu attack speed dublu se învârte de %.3f ori pe secundă" % v1)
	await _sterge(p)

# ---------------------------------------------------------------------------
# [4] Mărimea: jumătate din coasă, și crește exact cât ea
# ---------------------------------------------------------------------------
func _sectiunea_4() -> void:
	print("\n[4] MĂRIMEA")
	var p: Node = await _player()
	await get_tree().process_frame
	_cer(_aprox(p.cross_art_size * 2.0, p.scythe_art_size, 0.01),
		"e fix de două ori mai mică decât coasa (%.0f px față de %.0f)"
		% [p.cross_art_size, p.scythe_art_size])
	var latime0: float = p._cruci[0]["nod"].scale.x * p._cross_px.x
	# 75 fix (până pe 2026-09-26: 75 × 1,01, cât ținea bonusul de mărime de la nivelul 1). Cifra
	# așteptată e scrisă aici, nu
	# luată din `weapon_size_scale()` — altfel proba s-ar fi comparat cu ea însăși.
	_cer(_aprox(latime0, p.cross_art_size, 0.5),
		"pe ecran iese lată de %.1f px (75, fără bonus de mărime)" % latime0)
	var raza0: float = p._cross_raza_acum()
	var m0: float = p.weapon_size_mult
	# Pufferfish / Rat's Burger / Double Dose cresc `weapon_size_mult`
	p.weapon_size_mult = m0 * 2.0
	await get_tree().process_frame
	var latime1: float = p._cruci[0]["nod"].scale.x * p._cross_px.x
	_cer(_aprox(latime1, latime0 * 2.0, 0.5),
		"la Weapon Size dublu se face de două ori mai lată (%.1f → %.1f px)" % [latime0, latime1])
	_cer(_aprox(p._cross_raza_acum(), raza0 * 2.0, 0.5),
		"și orbita se lărgește odată cu ea (%.0f → %.0f px)" % [raza0, p._cross_raza_acum()])
	# ...iar HITBOX-UL crește cu desenul: o țintă la 50 px pe verticală de centrul crucii e
	# dincolo de brațul lung al celei mici (~34 px + 5 marjă) și sub el la cea mare (~69 px).
	var tinta := Vector2(0, 50)
	p.weapon_size_mult = m0
	await get_tree().process_frame
	var mic: bool = p._crucea_atinge(Vector2.ZERO, tinta, 0.0)
	p.weapon_size_mult = m0 * 2.0
	await get_tree().process_frame
	var mare: bool = p._crucea_atinge(Vector2.ZERO, tinta, 0.0)
	_cer(not mic and mare,
		"hitbox-ul crește cu desenul: ținta de la 50 px e ratată de crucea mică (%s) și prinsă de cea mare (%s)"
		% [mic, mare])
	await _sterge(p)

# ---------------------------------------------------------------------------
# [5] Damage-ul pe un inamic ADEVĂRAT
# ---------------------------------------------------------------------------
# Proba care contează cel mai mult: nu „funcția întoarce 30", ci „inamicului i-au ieșit 30 din
# viață, de exact atâtea ori pe secundă". Aici s-ar vedea și greșeala cea mai ușor de făcut la o
# armă care stă permanent peste inamici — damage la fiecare CADRU, adică de 60 de ori pe secundă
# în loc de 3.
func _sectiunea_5() -> void:
	print("\n[5] DAMAGE PE UN INAMIC ADEVARAT")
	var p: Node = await _player()
	p.bullet_damage = 30
	await get_tree().process_frame
	_cer(_aprox(p.damage_mult(), 1.0, 0.0001),
		"niciun procent de damage pe deasupra (x%.3f)" % p.damage_mult())
	var e := load("res://enemy.tscn").instantiate() as Node2D
	add_child(e)
	await get_tree().process_frame
	e.speed = 0.0               # stă pe loc, fix pe raza inelului
	e.max_hp = 1000000
	e.hp = e.max_hp
	e.global_position = p.global_position + Vector2(p.cross_raza, 0)
	var hp0: int = e.hp
	var t0 := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t0) / 1000000.0 < 2.0:
		await get_tree().process_frame
		e.global_position = p.global_position + Vector2(p.cross_raza, 0)   # nu-l lăsăm împins
	var secunde := float(Time.get_ticks_usec() - t0) / 1000000.0
	var pierdut: int = hp0 - int(e.hp)
	_cer(pierdut > 0, "l-a lovit (a pierdut %d viață în %.2f s)" % [pierdut, secunde])
	_cer(pierdut % 30 == 0, "fiecare lovitură a scos EXACT 30 (a pierdut %d)" % pierdut)
	var lovituri := float(pierdut) / 30.0
	var pe_secunda := lovituri / secunde
	_cer(_aprox(pe_secunda, 2.0, 0.4),
		"%d lovituri = %.2f pe secundă (2 cruci x 1 tur = 2)" % [int(lovituri), pe_secunda])
	_cer(pe_secunda < 10.0, "deci NU lovește în fiecare cadru (aia ar fi fost ~60/s)")
	# ...și Duridama merge prin cruce, ca prin orice altă armă (vezi ⚠️ din tool_duridama.gd)
	p.duridama_stacks = 100
	e.hp = e.max_hp
	var t1 := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t1) / 1000000.0 < 1.0 and not e.golden:
		await get_tree().process_frame
		e.global_position = p.global_position + Vector2(p.cross_raza, 0)
	_cer(e.golden, "Duridama aurește inamicul lovit de cruce")
	await _sterge(e)
	await _sterge(p)

# ---------------------------------------------------------------------------
# [6] Bonusul de nivel: +1 PROIECTIL (o cruce în plus) la fiecare 10 niveluri, numai cu crucea
# ALEASĂ. Până pe 2026-09-26 era +1% mărime; proba verifică și că mărimea NU mai crește.
# ---------------------------------------------------------------------------
func _sectiunea_6() -> void:
	print("\n[6] BONUSUL DE NIVEL")
	var p: Node = await _player()
	await get_tree().process_frame
	# câte cruci se învârt la fiecare nivel, citite din inelul ADEVĂRAT (nu din formulă)
	var cruci := {}
	cruci[1] = p._cruci.size()
	for L in range(2, 31):
		p._level_up(false)
		await get_tree().process_frame
		cruci[L] = p._cruci.size()
	_cer(cruci[1] == 2 and cruci[9] == 2, "nivelurile 1-9: tot 2 cruci (%d, %d)" % [cruci[1], cruci[9]])
	_cer(cruci[10] == 3 and cruci[19] == 3, "nivelul 10: a treia cruce, până la 19 (%d, %d)" % [cruci[10], cruci[19]])
	_cer(cruci[20] == 4 and cruci[30] == 5, "nivelul 20: 4 cruci, nivelul 30: 5 (%d, %d)" % [cruci[20], cruci[30]])
	_cer(_aprox(p.weapon_size_scale(), 1.0, 0.0001),
		"mărimea NU mai crește cu nivelul (x%.4f la nivelul 30)" % p.weapon_size_scale())
	# crucile se împart egal pe cerc și după ce au venit din nivel
	if p._cruci.size() == 5:
		var a: Vector2 = p._cruci[0]["nod"].global_position - p.global_position
		var b: Vector2 = p._cruci[1]["nod"].global_position - p.global_position
		_cer(_aprox(absf(rad_to_deg(a.angle_to(b))), 72.0, 0.5),
			"cele 5 cruci stau la 72° una de alta (%.1f°)" % absf(rad_to_deg(a.angle_to(b))))
	var scris := ""
	for rand in p.stat_lines():
		if String(rand.get("label", "")) == "Projectiles":
			scris = String(rand.get("value", ""))
	_cer(scris == "4", "panoul scrie Projectiles [%s] (1 de bază + 3 din nivel)" % scris)
	await _sterge(p)
	var q: Node = await _player("pistol")
	for i in range(1, 30):
		q._level_up(false)
	await get_tree().process_frame
	_cer(q.proiectile_din_nivel() == 0 and q.projectiles_total() == 1,
		"cu pistolul în mână nu vine niciun proiectil din nivel (%d)" % q.projectiles_total())
	_cer(q._cruci.is_empty(), "și nu se învârte nicio cruce")
	await _sterge(q)

# ---------------------------------------------------------------------------
# [7] Helping Hand: crucea primită cadou
# ---------------------------------------------------------------------------
func _sectiunea_7() -> void:
	print("\n[7] HELPING HAND")
	var p: Node = await _player("pistol")
	await get_tree().process_frame
	_cer(p._cruci.is_empty(), "cu pistolul ales, niciun inel")
	# Prin ITEM, nu scriind direct în `arme_secundare`: `adauga_arma_secundara` face și timer-ul,
	# iar fără el `_seteaza_cadenta` crapă la primul level up. Trage la sorți dintre armele pe care
	# nu le ai, deci o chemăm până iese crucea — cel mult de cinci ori.
	var primite: Array[String] = []
	for i in 8:
		if p.arme_secundare.has("cross"):
			break
		primite.append(p.adauga_arma_secundara())
	_cer(p.arme_secundare.has("cross"), "Helping Hand a dat crucea (a dat pe rând %s)" % str(primite))
	await get_tree().process_frame
	_cer(p._cruci.size() == 2, "crucea primită cadou se învârte și ea (%d cruci)" % p._cruci.size())
	for i in range(1, 20):
		p._level_up(false)
	await get_tree().process_frame
	_cer(p.proiectile_din_nivel() == 0 and p._cruci.size() == 2,
		"dar NU aduce bonusul ei de nivel: tot 2 cruci la nivelul 20 (%d)" % p._cruci.size())
	_cer(_aprox(p.weapon_size_scale(), 1.0, 0.0001),
		"deci Weapon Size rămâne x%.4f" % p.weapon_size_scale())
	await _sterge(p)

# ---------------------------------------------------------------------------
# [8] Deblocarea la nivelul 50, pe drumul ADEVĂRAT
# ---------------------------------------------------------------------------
# HUD de carton: prinde pancarta fără să pornim tot jocul. `Unlocks` caută un nod din grupul
# „hud" cu metoda `announce` — atât îi trebuie.
const HUD_FALS := """
extends Node
var primite: Array[String] = []
func announce(text: String, sub: String = \"\", culoare: Color = Color.WHITE) -> void:
	primite.append(sub)
"""

func _sectiunea_8() -> void:
	print("\n[8] DEBLOCAREA LA NIVELUL 50")
	GameSettings.unlocked.erase("cross")   # o luăm de la capăt, încuiată
	_cer(not Unlocks.e_castigat("cross"), "la început e încuiată")
	_cer(Unlocks.cerinta("cross") == "Reach level 50 in one run",
		"cerința scrisă: [%s]" % Unlocks.cerinta("cross"))
	var sc := GDScript.new()
	sc.source_code = HUD_FALS
	sc.reload()
	var hud := Node.new()
	hud.set_script(sc)
	hud.add_to_group("hud")
	add_child(hud)
	await get_tree().process_frame
	var p: Node = await _player("pistol")
	# Prin `_level_up`, nu prin `Unlocks.deblocheaza`: altfel proba ar fi trecut și cu cârligul
	# din `player.gd` șters cu totul.
	for i in range(1, 49):
		p._level_up(false)
	await get_tree().process_frame
	_cer(p.level == 49, "player-ul a ajuns la nivelul %d" % p.level)
	_cer(not Unlocks.e_castigat("cross"), "la nivelul 49 tot încuiată")
	p._level_up(false)
	await get_tree().process_frame
	_cer(Unlocks.e_castigat("cross"), "la nivelul 50 se deblochează")
	await get_tree().create_timer(0.3).timeout
	_cer(hud.primite.has("CROSS"),
		"pancarta strigă numele luat din meniu (a primit %s)" % str(hud.primite))
	await _sterge(p)
	await _sterge(hud)

# ---------------------------------------------------------------------------
# [9] ÎN JOCUL ADEVĂRAT (nu într-o scenă goală)
# ---------------------------------------------------------------------------
# Tot ce e mai sus s-a măsurat pe un player pus singur într-o scenă goală. Aici pornim lumea
# întreagă — pământ, inamici care vin peste tine, tot — fiindcă probele de laborator nu spun dacă
# arma chiar trăiește în joc: dacă inelul rămâne în urmă când mergi, dacă se desenează sub pământ
# sau dacă spawner-ul aduce inamici pe care crucea nu-i atinge, aici se vede și nicăieri altundeva.
#
# ⚠️ Player-ul primește viață cât o lume: MOARTEA lui pornește ecranul de Game Over, care scrie în
# LEADERBOARD-UL ADEVĂRAT. Runda ține câteva secunde, dar paza asta nu costă nimic.
func _sectiunea_9() -> void:
	print("\n[9] IN JOCUL ADEVARAT")
	GameSettings.unlocked["cross"] = true
	GameSettings.weapon_type = "cross"
	var lume: Node = load("res://main.tscn").instantiate()
	add_child(lume)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var p := get_tree().get_first_node_in_group("player")
	_cer(p != null, "player-ul e în lume")
	if p == null:
		return
	p.max_hp = 100000000
	p.hp = p.max_hp
	_cer(p.weapon_type == "cross", "a intrat în rundă cu crucea (are [%s])" % p.weapon_type)
	_cer(p._cruci.size() == 2, "inelul s-a făcut în lume (%d cruci)" % p._cruci.size())
	var morti0: int = GameSettings.run_kills
	# Îl plimbăm spre dreapta: dacă inelul n-ar fi copil al player-ului, ar rămâne în urmă.
	Input.action_press("move_right")
	var t0 := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t0) / 1000000.0 < 20.0:   # 20 s, nu 12: de pe 2026-09-24 inelul face 1 tur/s, nu 1.5
		await get_tree().process_frame
		if GameSettings.run_kills > morti0:
			break
	Input.action_release("move_right")
	await get_tree().process_frame
	var morti: int = GameSettings.run_kills - morti0
	_cer(morti > 0, "a omorât %d inamici doar cu inelul, în lumea adevărată" % morti)
	var dist: float = p._cruci[0]["nod"].global_position.distance_to(p.global_position)
	_cer(_aprox(dist, p.cross_raza * p.weapon_size_scale(), 1.0),
		"inelul l-a urmat în mers (cruce la %.1f px de el)" % dist)
	await _poza("in_joc")
	await _sterge(lume)
	GameSettings.unlocked = _unlocked_initial.duplicate()
	GameSettings.weapon_type = _arma_initiala

# ---------------------------------------------------------------------------
# [10] Poze
# ---------------------------------------------------------------------------
func _poza(nume: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cale: String = POZE % nume
	img.save_png(ProjectSettings.globalize_path(cale))
	print("  poză: ", cale)

func _sectiunea_10() -> void:
	print("\n[10] POZE")
	var p: Node = await _player()
	p.scale = Vector2(2, 2)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _poza("inel")
	await _sterge(p)
	# ⚠️ Înainte de poza din meniu punem lacătele ADEVĂRATE înapoi: pagina trebuie să arate ce
	# vede Răzvan, nu ce a deschis unealta ca să poată măsura.
	GameSettings.unlocked = _unlocked_initial.duplicate()
	GameSettings.weapon_type = _arma_initiala
	var m: Node = load("res://menu.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	m._show("weapon")
	m._preview_arma("cross")
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _poza("meniu_incuiat")
	# ...și cum arată fișa DESCHISĂ, adică acolo unde se vede bonusul de nivel. Deblocarea e tot
	# în RAM și se pune la loc pe loc — `_gata()` rescrie oricum salvarea de pe disc.
	GameSettings.unlocked["cross"] = true
	m._show("main")
	await get_tree().process_frame
	m._show("weapon")
	m._preview_arma("cross")
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _poza("meniu_deblocat")
	GameSettings.unlocked = _unlocked_initial.duplicate()
	await _sterge(m)

# Totul înapoi cum era, ȘI pe disc: secțiunea [8] chiar a deblocat crucea, deci fișierul de
# salvare s-a atins. Ce scriem acum trebuie să-l aducă bit cu bit la loc (verifică cu `cmp`).
func _gata() -> void:
	GameSettings.character = _caracter_initial
	GameSettings.weapon_type = _arma_initiala
	GameSettings.unlocked = _unlocked_initial.duplicate()
	GameSettings.upgrades = _upgrades_initial.duplicate()
	GameSettings.op_start = _op_initial
	GameSettings._save()
	print("\n=======================================")
	print("pus la loc: caracter=%s arma=%s cross-deblocat=%s upgrade-uri=%d op=%s"
		% [GameSettings.character, GameSettings.weapon_type,
			GameSettings.unlocked.has("cross"), GameSettings.upgrades.size(), GameSettings.op_start])
	if _erori == 0:
		print("=== TOTUL E BINE ===")
	else:
		print("=== %d PROBLEME ===" % _erori)
	get_tree().quit(1 if _erori > 0 else 0)
