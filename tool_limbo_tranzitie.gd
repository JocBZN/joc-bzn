extends Node

# UNEALTA TRANZIȚIEI LIMBO — măsoară și verifică drumul lumea normală ↔ Limbo (`limbo.gd`).
#
# Trei lucruri, într-o singură rulare peste jocul ADEVĂRAT (`main.tscn`):
#   1. cât costă, în milisecunde de cadru, intrarea și ieșirea (cadrele lungi se tipăresc);
#   2. cum ARATĂ: patru capturi din fiecare drum (cerc închizându-se · negru · deschidere · după);
#   3. dacă drumul prin NETHER se întoarce cum trebuie: mori în Nether → Limbo → înapoi în Nether,
#      cu podeaua lui, fără decorul lumii normale.
#
# ⚠️ Întâi `PreloadAll`, ca la orice măsurătoare de timpi: altfel plătim citirea de pe disc și dăm
# vina pe tranziție (vezi nota din CLAUDE.md, invocarea monumentului).
# ⚠️ Rulează cu FEREASTRĂ (fără `--headless`): capturile au nevoie de GPU.

const ASTEPTARE := 4.0        # cât lăsăm lumea să se genereze înainte de măsurătoare
const PRAG_MS := 25.0         # de la cât în sus tipărim un cadru
const POZE := false            # false = doar măsurăm (o captură costă ~140 ms și strică măsurătoarea)

var _limbo: Node = null
var _nether: Node = null
var _player: Node2D = null
var _t: Array[float] = []
var _et: Array[String] = []
var _eticheta := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # măsurăm și cadrele de sub pauza tranziției
	PreloadAll.porneste()
	while not PreloadAll.pas():
		await get_tree().process_frame
	add_child(load("res://main.tscn").instantiate())
	await get_tree().create_timer(ASTEPTARE).timeout
	_limbo = get_tree().get_first_node_in_group("limbo")
	_nether = get_tree().get_first_node_in_group("nether")
	_player = get_tree().get_first_node_in_group("player")
	if _limbo == null or _player == null:
		push_error("lipsesc limbo/player")
		get_tree().quit()
		return

	print("--- 1. INTRARE ---")
	_eticheta = "ENTER"
	_limbo.call("enter", _player)
	# ca să apucăm să măsurăm IEȘIREA: altfel moare în Limbo și intră `_abort`, alt drum
	_player.max_hp = 999999
	_player.hp = 999999
	await _poze("in", [0.18, 0.50, 0.75, 1.60])
	await get_tree().create_timer(2.0).timeout

	print("--- 2. IEȘIRE ---")
	_eticheta = "EXIT"
	_limbo.call("_exit_limbo")
	await _poze("out", [0.18, 0.50, 0.75, 1.60])
	await get_tree().create_timer(2.0).timeout
	_raport()

	if _nether != null:
		await _drumul_prin_nether()
	get_tree().quit()

# ---------- 3. Nether → Limbo → Nether ----------
func _drumul_prin_nether() -> void:
	print("--- 3. NETHER → LIMBO → NETHER ---")
	_nether.call("enter", _player, _player.global_position)
	await get_tree().create_timer(2.5).timeout
	var poz := _player.global_position
	_limbo.call("enter", _player)
	await get_tree().create_timer(3.0).timeout
	print("  în Limbo:  limbo.active=%s nether.active=%s (suspendat, deci rămâne `active`)" % [_limbo.get("active"), _nether.get("active")])
	_limbo.call("_exit_limbo")
	await get_tree().create_timer(3.0).timeout
	var mutat := _player.global_position.distance_to(poz)
	print("  înapoi:    limbo.active=%s nether.active=%s | player la %.0f px de unde a murit" % [_limbo.get("active"), _nether.get("active"), mutat])
	print("  decor:     %s" % _decor())
	if POZE:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://limbo_nether.png"))

# Câte obiecte are fiecare generator de decor. În Nether trebuie să fie ZERO peste tot.
func _decor() -> String:
	var parent := _player.get_parent()
	var out := []
	for n in ["Props", "Rocks", "Bushes", "Chests", "Portals"]:
		var nd := parent.get_node_or_null(n)
		out.append("%s=%d" % [n, nd.get_child_count() if nd != null else -1])
	return ", ".join(out)

# ---------- măsurătoarea ----------
func _poze(prefix: String, momente: Array) -> void:
	if not POZE:
		await get_tree().create_timer(float(momente[momente.size() - 1])).timeout
		return
	var trecut := 0.0
	for m in momente:
		await get_tree().create_timer(m - trecut).timeout
		trecut = m
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("user://limbo_%s_%02d.png" % [prefix, int(m * 100)]))

func _process(delta: float) -> void:
	_t.append(delta * 1000.0)
	_et.append(_eticheta)
	_eticheta = ""

func _raport() -> void:
	print("--- cadre peste %.0f ms ---" % PRAG_MS)
	var max_in := 0.0
	var max_out := 0.0
	var faza := ""
	var t_faza := 0.0
	var t := 0.0
	for i in _t.size():
		t += _t[i] / 1000.0
		if _et[i] != "":
			faza = _et[i]
			t_faza = t
		if faza == "ENTER":
			max_in = maxf(max_in, _t[i])
		elif faza == "EXIT":
			max_out = maxf(max_out, _t[i])
		if _t[i] > PRAG_MS and faza != "":
			print("  [%4d] %7.2f ms   (+%.2f s de la %s)" % [i, _t[i], t - t_faza, faza])
	print("--- cel mai lung cadru: intrare %.2f ms · ieșire %.2f ms ---" % [max_in, max_out])
