extends Node

# UNEALTĂ: REFLECT vs BLOCK (2026-09-24). Nu face parte din joc.
#
# Regula lui Răzvan: reflectul cu PROCENT (Vodka, Old Reliable, Sunglasses → `reflect_pct`) doar
# ÎNTOARCE damage-ul, lovitura te atinge oricum. SINGURUL item care blochează e Mike's Hedgehog:
# lovitura prinsă de el nu-ți ia viață și se întoarce întreagă în inamic, o dată la 6 s.
#
# Se cheamă chiar `player._take_contact_damage()`, cu un inamic adevărat (`enemy.tscn`) lipit de
# player — adică funcția pe care o rulează jocul. Se rulează ca SCENĂ (autoload-uri), merge
# headless. Nu atinge salvarea: `op_start` și magazinul se golesc numai în RAM, iar player-ul nu
# moare (viață uriașă).

var _erori := 0
var _op := false
var _upg := {}

func _cer(ok: bool, m: String) -> void:
	if ok:
		print("  [OK]  " + m)
	else:
		_erori += 1
		print("  [NU]  " + m)

func _pereche() -> Array:
	var p: Node2D = load("res://player.tscn").instantiate()
	add_child(p)
	var e: Node2D = load("res://enemy.tscn").instantiate()
	add_child(e)
	await get_tree().process_frame
	p.global_position = Vector2.ZERO
	p.max_hp = 1000000
	p.hp = p.max_hp
	e.speed = 0.0
	e.max_hp = 1000000
	e.hp = e.max_hp
	e.global_position = Vector2(10, 0)   # în `contact_range`
	return [p, e]

func _lovitura(p: Node2D, e: Node2D) -> Array:
	var hp_p: int = p.hp
	var hp_e: int = e.hp
	e.global_position = p.global_position + Vector2(10, 0)
	p._take_contact_damage()
	return [hp_p - int(p.hp), hp_e - int(e.hp)]

func _sterge(a: Array) -> void:
	for n in a:
		n.queue_free()
	await get_tree().process_frame

func _ready() -> void:
	_op = GameSettings.op_start
	_upg = GameSettings.upgrades.duplicate()
	GameSettings.op_start = false
	GameSettings.upgrades = {}
	await get_tree().process_frame
	var dmg := maxi(1, int(round(5 * Difficulty.enemy_damage_mult())))
	print("\n================ REFLECT vs BLOCK ================")
	print("(o lovitură de contact acum = %d)" % dmg)

	print("\n[1] FĂRĂ NIMIC")
	var a := await _pereche()
	var r := _lovitura(a[0], a[1])
	_cer(r[0] == dmg and r[1] == 0, "încasezi %d, inamicul nimic (%d / %d)" % [dmg, r[0], r[1]])
	await _sterge(a)

	print("\n[2] REFLECT CU PROCENT (Sunglasses + Old Reliable = 40%) — NU blochează")
	a = await _pereche()
	a[0].reflect_pct = 0.40
	for i in 3:
		r = _lovitura(a[0], a[1])
		_cer(r[0] == dmg and r[1] == maxi(1, int(round(dmg * 0.40))),
			"lovitura %d: tu pierzi %d (tot), inamicul %d" % [i + 1, r[0], r[1]])
	await _sterge(a)

	print("\n[3] MIKE'S HEDGEHOG — BLOCHEAZĂ, o dată la 6 s")
	a = await _pereche()
	a[0].hedgehog = true
	r = _lovitura(a[0], a[1])
	_cer(r[0] == 0 and r[1] == dmg, "prima lovitură: tu pierzi 0, inamicul primește %d înapoi (%d / %d)" % [dmg, r[0], r[1]])
	r = _lovitura(a[0], a[1])
	_cer(r[0] == dmg and r[1] == 0, "a doua, în cooldown: încasezi %d, nimic înapoi (%d / %d)" % [dmg, r[0], r[1]])
	var cd: float = a[0]._hedgehog_next - Time.get_ticks_msec() / 1000.0
	_cer(cd > 5.5 and cd <= 6.0, "cooldown-ul e de 6 s (mai sunt %.2f s)" % cd)
	a[0]._hedgehog_next = 0.0   # „au trecut 6 secunde"
	r = _lovitura(a[0], a[1])
	_cer(r[0] == 0 and r[1] == dmg, "după cooldown blochează iar (%d / %d)" % [r[0], r[1]])
	await _sterge(a)

	print("\n[4] AMÂNDOUĂ — se adună, dar blocul e doar al ariciului")
	a = await _pereche()
	a[0].hedgehog = true
	a[0].reflect_pct = 0.25
	var pct := maxi(1, int(round(dmg * 0.25)))
	r = _lovitura(a[0], a[1])
	_cer(r[0] == 0 and r[1] == dmg + pct, "prinsă de arici: tu 0, inamicul %d + %d (%d / %d)" % [dmg, pct, r[0], r[1]])
	r = _lovitura(a[0], a[1])
	_cer(r[0] == dmg and r[1] == pct, "în cooldown: tu %d, inamicul doar procentul %d (%d / %d)" % [dmg, pct, r[0], r[1]])
	await _sterge(a)

	GameSettings.op_start = _op
	GameSettings.upgrades = _upg
	print("\n=================================================")
	print("=== %s ===" % ("TOTUL E BINE" if _erori == 0 else "%d PROBLEME" % _erori))
	get_tree().quit()
