extends Node2D

# SCÂNTEIA DE CLIC (2026-09-26). O pornește `Gamepad._clic_jos()` la fiecare clic stânga, cât
# se vede cursorul-mână (adică în meniuri). Un inel de aramă care se deschide din vârful
# degetului + șase fire scurte care zboară în afară, totul în ~0,3 s.
#
# Stă PE LOC, unde ai dat clic, nu se ține după mână: așa se citește ca „aici am apăsat".
# Culoarea e aceeași aramă ca inelul de focus de pe controller (`Gamepad.FOCUS_MUCHIE`), deci
# clicul de mouse și selecția de pad vorbesc aceeași limbă.
#
# Liniile sunt fără antialias: restul jocului e pixel art, iar o linie netedă ar ieși în evidență.

const DURATA := 0.30
const RAZA_INEL := Vector2(3.0, 13.0)    # de la cât la cât se deschide inelul
const FIRE := 6
const FIR_DE_LA := Vector2(5.0, 15.0)    # unde începe firul, la început → la sfârșit
const FIR_LUNGIME := 6.0

var _scantei: Array = []   # [pozitie, cand_a_pornit]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # meniurile rulează cu jocul pe pauză
	z_index = 100

func scanteie(unde: Vector2) -> void:
	_scantei.append([unde, _acum()])
	queue_redraw()

func _acum() -> float:
	return Time.get_ticks_msec() / 1000.0

func _process(_delta: float) -> void:
	if _scantei.is_empty():
		return
	var t := _acum()
	_scantei = _scantei.filter(func(s): return t - s[1] < DURATA)
	queue_redraw()

func _draw() -> void:
	var t0 := _acum()
	var arama: Color = Gamepad.FOCUS_MUCHIE
	for s in _scantei:
		var p: Vector2 = s[0]
		var t := clampf((t0 - s[1]) / DURATA, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)   # pornește iute, se oprește moale
		var a := 1.0 - t * t   # ține culoarea plină mai mult, apoi se stinge repede
		# sclipirea din mijloc — doar în prima treime, cât „lovește" degetul
		if t < 0.35:
			draw_circle(p, 3.0 * (1.0 - t / 0.35), Color(1, 1, 1, 0.9), true, -1.0, false)
		# inelul
		var r := lerpf(RAZA_INEL.x, RAZA_INEL.y, e)
		draw_arc(p, r, 0.0, TAU, 20, Color(arama, a), lerpf(3.0, 1.0, t), false)
		# firele, între razele inelului, rotite o jumătate de pas ca să nu stea în cruce
		var r1 := lerpf(FIR_DE_LA.x, FIR_DE_LA.y, e)
		var r2 := r1 + FIR_LUNGIME * (1.0 - t)
		for i in FIRE:
			var d := Vector2.from_angle(TAU * (i + 0.5) / FIRE)
			draw_line(p + d * r1, p + d * r2, Color(arama.lightened(0.3), a), 2.0, false)
