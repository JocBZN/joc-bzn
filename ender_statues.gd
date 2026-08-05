extends Node2D

# Statuile de schimb din Ender (`ender_statue.gd`) — puse toate deodată, într-un INEL în jurul
# fântânii prin care ai intrat: între `dist_min` (600) și `dist_max` (2000) de pixeli de ea.
#
# ⚠️ NU e un generator pe chunk-uri ca frații lui (`statues.gd`, `monuments.gd`). A fost, până pe
# 2026-08-05, și era greșit pentru treaba asta: împrăștia statui pe la infinit, deci una putea
# ieși la 30.000px de fântână, adică într-un loc în care n-ajungi niciodată în cele 6 minute.
# Răzvan a cerut explicit „maxim 2000 de pixeli de portal, minim 600", iar asta nu e o regulă de
# chunk, e o regulă de DISTANȚĂ FAȚĂ DE UN PUNCT — un inel se scrie direct, nu se filtrează.
# Bonus: știi sigur câte sunt (`numar`), pe când filtrarea unui generator ți-ar fi dat câteodată
# zero, și ai fi intrat în Ender fără nicio statuie.
#
# Nodul merge PE DOS față de toate celelalte generatoare: pornește stins și se aprinde exact cât
# `ender.active` — vezi `ender.gd::ENDER_ONLY_NODES`. La ieșire, `_toggle_generator` îi eliberează
# copiii, deci la o eventuală intrare următoare inelul se naște din nou.

const ENDER_STATUE := preload("res://ender_statue.tscn")

@export var numar: int = 3              # câte statui primești pe intrare
@export var dist_min: float = 600.0     # nici una mai aproape de fântână (cerut)
@export var dist_max: float = 2000.0    # nici una mai departe (cerut)
@export var dist_intre: float = 520.0   # cât de departe stau una de alta, ca să nu se îngrămădească
@export var incercari: int = 40         # câte poziții încearcă până acceptă una prea apropiată

func _process(_delta: float) -> void:
	# Le punem O SINGURĂ dată: cât avem copii, treaba e făcută. („Am copii" e chiar semnul pe care
	# îl șterge `_toggle_generator` la ieșirea din Ender, deci se re-armează singur.)
	if get_child_count() > 0:
		return
	var e := get_tree().get_first_node_in_group("ender")
	if e == null or not e.active or not e.has_method("portal_pos"):
		return
	var centru: Vector2 = e.portal_pos()
	if centru == Vector2.INF:
		return          # fântâna încă nu se știe (suntem în cadrul intrării) — încercăm la următorul
	_aseaza(centru)

func _aseaza(centru: Vector2) -> void:
	var puse: Array[Vector2] = []
	for i in numar:
		var poz := _un_loc(centru, puse)
		puse.append(poz)
		var s := ENDER_STATUE.instantiate()
		add_child(s)
		s.global_position = poz

# Un punct în inel, cât mai departe de cele deja puse. Dacă după `incercari` tot n-a găsit unul
# la `dist_intre` de restul (se întâmplă dacă ceri multe statui într-un inel mic), îl ia pe cel
# mai bun dintre cele încercate — mai bine două mai apropiate decât o statuie lipsă.
func _un_loc(centru: Vector2, puse: Array[Vector2]) -> Vector2:
	var cel_mai_bun := Vector2.ZERO
	var cea_mai_buna := -1.0
	for i in incercari:
		var unghi := randf() * TAU
		var raza := randf_range(dist_min, dist_max)
		var poz := centru + Vector2(cos(unghi), sin(unghi)) * raza
		var minim := INF
		for p in puse:
			minim = minf(minim, poz.distance_to(p))
		if minim >= dist_intre:
			return poz
		if minim > cea_mai_buna:
			cea_mai_buna = minim
			cel_mai_bun = poz
	return cel_mai_bun
