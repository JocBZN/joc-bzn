extends Node

# UNEALTĂ DE PROFILARE (se rulează ca SCENĂ, în fereastră normală):
#
#   godot --path <proiect> res://tool_profil.tscn
#
# ÎNTREBAREA: „după 9 minute în lumea normală începe să lagheze rău". Unde se duc
# milisecundele? Ochiul zice „lagheze"; profilul zice CINE.
#
# Ce face: pornește `main.tscn`, sare cronometrul rundei la `MINUT` (dificultatea e o
# funcție de `Difficulty.time`, deci minutul 9 se poate FABRICA — nu trebuie jucat),
# îi dă player-ului un build de minutul 9 (`UPGRADES` iteme trase la sorți, ca la level
# up), îl plimbă în cerc (ca să curgă chunk-urile) și tipărește la fiecare secundă:
#
#   fps | cadru mediu | CEL MAI PROST cadru | process | fizică | noduri | inamici | geme | gloanțe
#
# ⚠️ Media pe secundă, nu o citire instantanee: o singură citire de `TIME_PROCESS` sare de la
# 14 la 46 ms între două cadre vecine și nu spune nimic. Iar laggul se SIMTE pe cel mai prost
# cadru din secundă, nu pe medie — de-aia sunt tipărite amândouă.
#
# ⚠️ Player NEMURITOR (`max_hp` uriaș, doar în RAM): moartea trece prin `gameover.gd` și
# SCRIE în leaderboard-ul REAL `user://scores.save`. Vezi avertismentul din CLAUDE.md.
#
# ⚠️ NU folosim `Engine.time_scale` ca să ajungem mai repede la minutul 9: ar falsifica exact
# lucrul măsurat (ms pe cadru). Dificultatea o punem direct, ceasul curge normal.

const MINUT := 9.0 * 60.0      # unde sărim cronometrul rundei
const UPGRADES := 30           # câte iteme are un build de minutul 9
const SECUNDE := 60            # cât măsurăm

var _player: Node2D = null
var _t := 0.0
var _next_log := 1.0

# Statistici strânse pe secunda curentă (vezi avertismentul de mai sus).
var _cadre := 0
var _suma_dt := 0.0
var _dt_max := 0.0
var _suma_proc := 0.0
var _suma_fizica := 0.0

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout

	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		print("NU AM GĂSIT PLAYER-UL"); get_tree().quit(); return
	_player.max_hp = 99999999
	_player.hp = _player.max_hp

	# build de minutul 9: iteme trase cu aceleași șanse ca la level up, aplicate pe loc
	var lv := get_tree().get_first_node_in_group("levelup_menu")
	if lv != null and lv.has_method("da_random_acum"):
		for i in UPGRADES:
			lv.da_random_acum()
	print("BUILD: %d iteme aplicate" % UPGRADES)

	Difficulty.time = MINUT
	print("Difficulty.time = %.0f  (spawn_mult=%.2f  hp_mult=%.2f)" \
		% [Difficulty.time, Difficulty.spawn_mult(), Difficulty.enemy_hp_mult()])
	print("  t |   fps | cadru | prost | proc | fiz | noduri | inam | geme | glont | draw | perechi")

func _process(delta: float) -> void:
	if _player == null:
		return
	_t += delta
	_cadre += 1
	_suma_dt += delta
	_dt_max = maxf(_dt_max, delta)
	_suma_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	_suma_fizica += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	Difficulty.time = MINUT + _t   # ceasul curge normal de la minutul 9 încolo

	# plimbare în cerc, prin INPUT (ca să treacă prin exact același cod ca la joc)
	var unghi := _t * 0.7
	var dorit := Vector2(cos(unghi), sin(unghi))
	_apasa("move_right", dorit.x > 0.35)
	_apasa("move_left",  dorit.x < -0.35)
	_apasa("move_down",  dorit.y > 0.35)
	_apasa("move_up",    dorit.y < -0.35)

	if _t < _next_log:
		return
	_next_log += 1.0
	var n := maxi(1, _cadre)
	print("%3.0f | %5.1f | %5.1f | %5.1f | %4.1f | %3.1f | %6d | %4d | %4d | %5d | %4d | %6d" % [
		_t,
		float(n) / maxf(0.001, _suma_dt),
		_suma_dt / float(n) * 1000.0,
		_dt_max * 1000.0,
		_suma_proc / float(n) * 1000.0,
		_suma_fizica / float(n) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		get_tree().get_nodes_in_group("enemy").size(),
		get_tree().get_nodes_in_group("xp").size(),
		_gloante(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
	])
	_cadre = 0
	_suma_dt = 0.0
	_dt_max = 0.0
	_suma_proc = 0.0
	_suma_fizica = 0.0
	if _t >= SECUNDE:
		_raport_final()
		get_tree().quit()

func _apasa(actiune: String, da: bool) -> void:
	if da:
		Input.action_press(actiune)
	else:
		Input.action_release(actiune)

# Gloanțele nu-s într-un grup — le numărăm după script, printre copiii lumii.
func _gloante() -> int:
	var n := 0
	if _player == null or _player.get_parent() == null:
		return 0
	for c in _player.get_parent().get_children():
		var sc: Script = c.get_script() as Script
		if sc != null and String(sc.resource_path).ends_with("bullet.gd"):
			n += 1
	return n

# CINE sunt nodurile care există? Numărate pe clasă și pe script, ca să iasă la iveală
# ce se adună fără să fie evident (efecte, umbre, etichete).
func _raport_final() -> void:
	var pe_clasa := {}
	var pe_script := {}
	_numara(get_tree().root, pe_clasa, pe_script)
	print("\n--- NODURI PE CLASĂ (top 20) ---")
	_tipareste(pe_clasa, 20)
	print("\n--- NODURI PE SCRIPT (top 20) ---")
	_tipareste(pe_script, 20)

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
