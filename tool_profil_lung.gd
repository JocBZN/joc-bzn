extends Node

# UNEALTĂ DE PROFILARE — RUNDA ÎNTREAGĂ, ÎN TIMP REAL (se rulează ca SCENĂ):
#
#   godot --path <proiect> res://tool_profil_lung.tscn
#
# Fratele lung al lui `tool_profil.gd`. Ăla FABRICĂ minutul 9 (sare `Difficulty.time`) și e bun
# ca să vezi repede cât costă densitatea de inamici de la minutul 9. Dar reclamația lui Răzvan e
# „DUPĂ ce trec 9 minute începe să lagheze", iar asta e o afirmație despre TIMP, nu despre
# densitate: dacă ceva se adună pe parcurs (noduri care nu mor, semnale legate de mai multe ori,
# memorie), un minut 9 fabricat în 60 de secunde nu-l vede.
#
# Deci: se joacă runda ÎNTREAGĂ, la viteză normală, cu player nemuritor care se plimbă în cerc și
# alege singur upgrade-urile. La fiecare `PAS` secunde tipărește aceleași cifre. Dacă
# `cadru_ms` de la 9:00 e mult peste `cadru_ms` de la 3:00 LA ACELAȘI NUMĂR DE INAMICI,
# e o scurgere. Dacă urcă odată cu inamicii, e pur și simplu prețul hoardei.
#
# ⚠️ NU `Engine.time_scale`: ar falsifica exact lucrul măsurat (ms pe cadru). Rulează 11 minute
# reale, atât e.
#
# ⚠️ Player NEMURITOR (`max_hp` uriaș, doar în RAM) — moartea scrie în `user://scores.save`.
#
# ⚠️ `process_mode = ALWAYS`: ecranul de level up oprește arborele (`get_tree().paused`), iar
# unealta trebuie să rămână trează ca să apese ea butonul.

const DURATA := 11.0 * 60.0    # cât ține rularea (secunde de rundă)
const PAS := 15.0              # la câte secunde tipărim un rând

var _player: Node2D = null
var _lv: Node = null
var _t := 0.0
var _next_log := PAS

var _cadre := 0
var _suma_dt := 0.0
var _dt_max := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout

	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		print("NU AM GĂSIT PLAYER-UL"); get_tree().quit(); return
	_player.max_hp = 99999999
	_player.hp = _player.max_hp
	_lv = get_tree().get_first_node_in_group("levelup_menu")

	print("min:sec | fps | cadru | prost | noduri | orfani | inam | geme | glont | draw | RAM_MB | nivel")

func _process(delta: float) -> void:
	if _player == null:
		return
	# ecranul de level up oprește jocul — alegem singuri primul item și mergem mai departe
	if _lv != null and _lv.visible:
		_lv._on_choice(0)
		return

	_t += delta
	_cadre += 1
	_suma_dt += delta
	_dt_max = maxf(_dt_max, delta)

	var unghi := _t * 0.5
	var dorit := Vector2(cos(unghi), sin(unghi))
	_apasa("move_right", dorit.x > 0.35)
	_apasa("move_left",  dorit.x < -0.35)
	_apasa("move_down",  dorit.y > 0.35)
	_apasa("move_up",    dorit.y < -0.35)

	if _t < _next_log:
		return
	_next_log += PAS
	var n := maxi(1, _cadre)
	print("  %02d:%02d | %5.1f | %5.1f | %5.1f | %6d | %5d | %4d | %4d | %5d | %4d | %6.1f | %3d" % [
		int(_t) / 60, int(_t) % 60,
		float(n) / maxf(0.001, _suma_dt),
		_suma_dt / float(n) * 1000.0,
		_dt_max * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		get_tree().get_nodes_in_group("enemy").size(),
		get_tree().get_nodes_in_group("xp").size(),
		_gloante(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(_player.get("level")) if "level" in _player else 0,
	])
	_cadre = 0
	_suma_dt = 0.0
	_dt_max = 0.0
	if _t >= DURATA:
		_raport_final()
		get_tree().quit()

func _apasa(actiune: String, da: bool) -> void:
	if da:
		Input.action_press(actiune)
	else:
		Input.action_release(actiune)

func _gloante() -> int:
	var n := 0
	if _player == null or _player.get_parent() == null:
		return 0
	for c in _player.get_parent().get_children():
		var sc: Script = c.get_script() as Script
		if sc != null and String(sc.resource_path).ends_with("bullet.gd"):
			n += 1
	return n

func _raport_final() -> void:
	var pe_clasa := {}
	var pe_script := {}
	_numara(get_tree().root, pe_clasa, pe_script)
	print("\n--- NODURI PE CLASĂ (top 25) ---")
	_tipareste(pe_clasa, 25)
	print("\n--- NODURI PE SCRIPT (top 25) ---")
	_tipareste(pe_script, 25)
	print("\nItemele rundei: %s" % [_player.get("run_items")])

func _numara(n: Node, pe_clasa: Dictionary, pe_script: Dictionary) -> void:
	var c := n.get_class()
	pe_clasa[c] = int(pe_clasa.get(c, 0)) + 1
	var s: Script = n.get_script() as Script
	if s != null:
		var nume := String(s.resource_path).get_file()
		pe_script[nume] = int(pe_script.get(nume, 0)) + 1
	for ch in n.get_children():
		_numara(ch, pe_clasa, pe_script)

func _tipareste(d: Dictionary, cate: int) -> void:
	var chei: Array = d.keys()
	chei.sort_custom(func(a, b) -> bool: return d[a] > d[b])
	for i in mini(cate, chei.size()):
		print("  %6d  %s" % [d[chei[i]], chei[i]])
