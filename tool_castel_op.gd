extends Node

# UNEALTĂ (se rulează ca SCENĂ; merge headless — se uită la cifre, nu la imagine):
#
#   godot --headless --path <proiect> res://tool_castel_op.tscn
#
# ÎNTREBAREA (Răzvan, 2026-09-01): „La Sir John inamicii de acolo vreau să fie cei mai OP din joc."
# Ca să nu fie o părere, unealta măsoară două lucruri:
#
#   A. CLASAMENTUL — pentru fiecare fel de inamic din joc, la același moment de rundă (`MINUT`):
#      viața efectivă, damage-ul de contact pe secundă și viteza, cu TOȚI multiplicatorii puși
#      (dificultatea, îngroșarea de castel, îngroșarea polițiștilor scăpați din Nether). Așa se
#      vede negru pe alb dacă un cavaler de castel e sau nu peste tot ce mai există.
#
#   B. CASTELUL RULAT PE BUNE — intri chiar prin `prison.enter()`, cu un build de minutul 8, și
#      se măsoară 30 de secunde: cât damage pe secundă încasezi, câți cavaleri sunt pe hartă,
#      câți te ating, cât trăiește unul.
#
# ⚠️ Player NEMURITOR (`max_hp` uriaș, doar în RAM) — moartea trece prin `gameover.gd` și SCRIE
# în leaderboard-ul REAL `user://scores.save`. Viața pierdută se măsoară și se dă înapoi.
# ⚠️ `xp_to_next` uriaș: un level up pune jocul pe PAUZĂ, iar măsurătoarea ar sta cu el.
# ⚠️ Boss-ul e PARCAT (`prison._park_boss(true)`, funcția jocului) imediat după cinematică:
# altfel damage-ul lui SIR JOHN ar intra în cifra cavalerilor.

const MINUT := 8.0 * 60.0     # când ajungi în castel, în practică
const UPGRADES := 25          # build de minutul 8, tras la sorți cu sămânță fixă
const SECUNDE := 20.0   # per fază (pe loc / fugind)
const SAMANTA := 20260901

# fel, scenă, unde apare
const FELURI := [
	["politist", "res://enemy.tscn", "lume"],
	["politist scapat din Nether", "res://enemy.tscn", "lume+2x"],
	["skinny", "res://enemy_police_skinny.tscn", "lume"],
	["SWAT", "res://enemy_swat.tscn", "lume"],
	["pompier", "res://enemy_firefighter.tscn", "lume"],
	["creatura Nether", "res://enemy_nether.tscn", "Nether"],
	["creatura Ender", "res://enemy_ender.tscn", "Ender"],
	["CAVALER (castel)", "res://enemy_cavaler.tscn", "castel"],
]

var _player: Node2D = null
var _prison: Node = null
var _masor := false
var _faza := 0
var _t := 0.0
var _hp_pierdut := 0
var _suma_vii := 0.0
var _suma_lipiti := 0.0
var _cadre := 0
var _morti := 0
var _vazuti := {}

func _ready() -> void:
	seed(SAMANTA)
	Difficulty.time = MINUT
	_clasament()
	await _ruleaza_castelul()

# ---------- A. CLASAMENTUL ----------

# Cifrele se calculează exact ca în joc:
#   viața   `enemy.gd::_ready`      → max_hp * Difficulty.enemy_hp_mult() * power_mult
#   damage  `player._take_contact_damage` → 5 (contact_damage) * enemy_damage_mult() * damage_mult,
#           plătit la fiecare 0,5 s ȘI PER INAMIC LIPIT DE TINE → înmulțit cu 2 = pe secundă
#   viteza  `enemy.gd::_ready`      → speed * Difficulty.enemy_speed_mult() (plafonat la 2.2)
func _clasament() -> void:
	var hp_m := Difficulty.enemy_hp_mult()
	var dmg_m := Difficulty.enemy_damage_mult()
	var sp_m := Difficulty.enemy_speed_mult()
	var pr := load("res://prison.gd")
	var xp_baza := Difficulty.xp_mult()   # cu `Difficulty.xp_bonus` = 1 (lumea normală)
	print("A) CLASAMENT la minutul %d  (hp x%.1f, damage x%.2f, viteza x%.2f)"
		% [int(MINUT / 60.0), hp_m, dmg_m, sp_m])
	print("   %-28s %8s %10s %8s %8s  %s" % ["fel", "viata", "dmg/sec", "viteza", "XP/mort", "unde"])
	var randuri := []
	for f in FELURI:
		var scena: PackedScene = load(f[1])
		var e: Node = scena.instantiate()
		var hp: float = float(e.max_hp)
		var dmg: float = float(e.damage_mult)
		var sp: float = float(e.speed)
		var e_xp_drop: float = float(e.xp_drop_mult)
		var putere := 1.0
		if f[2] == "lume+2x":
			putere = 2.0                      # `spawner.gd::escaped_power_mult`
		elif f[2] == "castel":
			putere = float(pr.ENEMY_POWER)    # îngroșarea dimensiunii
			sp *= float(pr.ENEMY_SPEED)
			dmg *= float(pr.ENEMY_DAMAGE)
		e.free()
		var viata := hp * hp_m * putere
		var pe_sec := 2.0 * maxf(1.0, round(5.0 * dmg_m * dmg))
		var xp_dim: float = {"lume": 1.0, "lume+2x": 1.0, "Nether": 2.0, "Ender": 3.0, "castel": 4.0}[f[2]]
		var xp_pe_mort: float = round(1.0 * xp_baza * xp_dim) * float(e_xp_drop)
		randuri.append([f[0], viata, pe_sec, sp * sp_m, f[2], xp_pe_mort])
	randuri.sort_custom(func(a, b): return a[1] > b[1])
	for r in randuri:
		print("   %-28s %8d %10d %8d %8d  %s" % [r[0], int(r[1]), int(r[2]), int(r[3]), int(r[5]), r[4]])
	var cav = null
	for r in randuri:
		if r[0].begins_with("CAVALER"):
			cav = r
	# Verdictul, pe fiecare axă: cine e al doilea și cu cât rămâne în urmă. Așa se vede dacă
	# „cel mai OP" e adevărat, nu doar simțit.
	for axa in [[1, "viata"], [2, "damage/sec"], [3, "viteza"]]:
		var i: int = axa[0]
		var altul = null
		for r in randuri:
			if r == cav:
				continue
			if altul == null or r[i] > altul[i]:
				altul = r
		if cav[i] > altul[i]:
			print("   → %s: CAVALERUL e primul (%d), al doilea %s (%d) — cu %.0f%% mai putin"
				% [axa[1], int(cav[i]), altul[0], int(altul[i]), 100.0 * (1.0 - altul[i] / cav[i])])
		else:
			print("   → %s: primul e %s (%d), cavalerul are %d"
				% [axa[1], altul[0], int(altul[i]), int(cav[i])])

# ---------- B. CASTELUL, RULAT ----------

func _ruleaza_castelul() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	# ⚠️ Jocul pornește PE PAUZĂ (cinematica de intrare în rundă) — se așteaptă până curge.
	var asteptat := 0.0
	while get_tree().paused and asteptat < 12.0:
		await get_tree().create_timer(0.2).timeout
		asteptat += 0.2
	await get_tree().create_timer(0.3).timeout

	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prison = get_tree().get_first_node_in_group("prison")
	if _player == null or _prison == null:
		print("B) NU AM GĂSIT PLAYER-UL SAU CASTELUL"); get_tree().quit(); return

	var lv := get_tree().get_first_node_in_group("levelup_menu")
	if lv != null and lv.has_method("da_random_acum"):
		seed(SAMANTA)   # ACELAȘI build la fiecare rulare, altfel două configurații nu se compară
		for i in UPGRADES:
			lv.da_random_acum()
	# viața ADEVĂRATĂ a build-ului se citește ÎNAINTE de a-l face nemuritor — ea e cifra față de
	# care se judecă damage-ul încasat mai jos ("40/sec" înseamnă altceva la 200 și la 900 viață)
	var hp_real: int = _player.max_hp
	_player.max_hp = 99999999
	_player.hp = _player.max_hp
	_player.xp_to_next = 999999999      # niciun level up: ar pune jocul pe pauză
	Difficulty.time = MINUT
	print("B) build de %d iteme: viata %d, viteza %d, damage %d, cadenta %.2fs" \
		% [UPGRADES, hp_real, int(_player.speed), _player.bullet_damage, _player.fire_interval_now()])

	var poarta: Node2D = load("res://poarta_castel.tscn").instantiate()
	_player.get_parent().add_child(poarta)
	poarta.global_position = _player.global_position + Vector2(120, 0)
	_prison.enter(_player, poarta)

	# cinematica lui SIR JOHN: se așteaptă boss-ul, apoi se PARCHEAZĂ (funcția jocului), ca
	# damage-ul lui să nu intre în cifra cavalerilor
	var c := 0.0
	while _prison._boss == null and c < 25.0:
		await get_tree().create_timer(0.25).timeout
		c += 0.25
	await get_tree().create_timer(0.5).timeout
	_prison._park_boss(true)
	print("   intrat in castel dupa %.1f s de cinematica; boss parcat" % c)

	# DOUĂ măsurători, fiindcă adevărul e între ele:
	#   • PE LOC — cazul cel mai rău: te-au încolțit și nu mai ieși. Așa se vede cât te costă
	#     UN cavaler lipit de tine, înmulțit cu câți apucă să se lipească.
	#   • FUGIND — player-ul se plimbă în cerc prin INPUT adevărat (ca `tool_profil.gd`), adică
	#     exact ce face un om care nu vrea să moară.
	_player.hp = _player.max_hp
	_faza = 1
	_masor = true
	await get_tree().create_timer(SECUNDE).timeout
	_masor = false
	_raport("PE LOC (incoltit)")
	_reset()
	_faza = 2
	_masor = true
	await get_tree().create_timer(SECUNDE).timeout
	_masor = false
	_raport("FUGIND (in cerc)")
	# a treia oară cu SIR JOHN dezlegat: asta e dimensiunea așa cum se joacă, nu în laborator
	_prison._park_boss(false)
	_reset()
	_faza = 2
	_masor = true
	await get_tree().create_timer(SECUNDE).timeout
	_masor = false
	_raport("FUGIND, CU SIR JOHN PE CAP")
	for a in ["move_right", "move_left", "move_up", "move_down"]:
		Input.action_release(a)
	get_tree().quit()

func _reset() -> void:
	_t = 0.0
	_cadre = 0
	_hp_pierdut = 0
	_suma_vii = 0.0
	_suma_lipiti = 0.0
	_morti = 0
	_vazuti = {}

func _process(delta: float) -> void:
	if not _masor or _player == null:
		return
	_t += delta
	_cadre += 1
	if _faza == 2:
		var unghi := _t * 0.7
		var dorit := Vector2(cos(unghi), sin(unghi))
		_apasa("move_right", dorit.x > 0.35)
		_apasa("move_left", dorit.x < -0.35)
		_apasa("move_down", dorit.y > 0.35)
		_apasa("move_up", dorit.y < -0.35)
	if _player.hp < _player.max_hp:
		_hp_pierdut += _player.max_hp - _player.hp
		_player.hp = _player.max_hp
	var vii := 0
	var lipiti := 0
	var acum := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en == null or en.is_in_group("final_boss"):
			continue
		vii += 1
		acum[en.get_instance_id()] = true
		if _player.global_position.distance_to(en.global_position) < _player.contact_range:
			lipiti += 1
	for id in _vazuti:
		if not acum.has(id):
			_morti += 1
	_vazuti = acum
	_suma_vii += vii
	_suma_lipiti += lipiti

func _apasa(actiune: String, da: bool) -> void:
	if da:
		Input.action_press(actiune)
	else:
		Input.action_release(actiune)

func _raport(cum: String) -> void:
	var vii: float = _suma_vii / maxf(1.0, float(_cadre))
	var lipiti: float = _suma_lipiti / maxf(1.0, float(_cadre))
	var pe_sec: float = float(_hp_pierdut) / _t
	# legea lui Little: câți sunt pe hartă / câți mor pe secundă = cât trăiește unul
	var viata_unuia: float = vii / maxf(0.001, float(_morti) / _t)
	print("   %s, %.0f s (SPAWN_MULT=%.2f):" % [cum, _t, _prison.SPAWN_MULT])
	print("      damage incasat: %.0f/sec  (cu %.1f cavaleri lipiti de tine, in medie)"
		% [pe_sec, lipiti])
	print("      cavaleri pe harta: %.1f | omorati: %d (%.1f/min) | unul traieste ~%.1f s"
		% [vii, _morti, float(_morti) * 60.0 / _t, viata_unuia])
