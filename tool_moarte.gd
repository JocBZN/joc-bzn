extends Node

# Unealta care verifica CINEMATICA DE MOARTE (`gameover.gd` + `moarte_iris.gdshader`).
# Porneste jocul adevarat (main.tscn), omoara player-ul si masoara, cadru cu cadru, ce fac
# cercul si sunetul: raza pe fiecare faza, centrul pe player, filtrul muzicii, straturile de
# sunet si textul de la final. Face si poze la momentele importante.
#
# ⚠️ Ruleaza FERESTRUIT — headless nu deseneaza (pozele ies negre) si are driver audio fals:
#   godot --path <proj> res://tool_moarte.tscn
#
# ⚠️ Ceasul testului e ceasul MOTORULUI (`_ceas`, adunat din delta), nu `Time.get_ticks_msec`.
# `save_png` blocheaza firul principal cateva sute de ms: pe ceas de perete testul ar cere
# momentele mai devreme decat le poate arata animatia si ar "pica" degeaba (capcana asta e deja
# in CLAUDE.md, de la cinematica lui Saratalin). Tween-urile merg pe delta, deci si noi.
#
# Momentele cerute se citesc din constantele lui `gameover.gd`, nu sunt scrise de mana aici:
# daca schimbi coregrafia acolo, testul se muta singur dupa ea.

const POZE := "C:/Users/GHEORG~1/AppData/Local/Temp/claude/C--WINDOWS-system32/551d4bf5-3856-4389-8b46-37e7316ca081/scratchpad/moarte_%s.png"

var _erori := 0
var _go: CanvasLayer
var _mat: ShaderMaterial

var _rec := false
var _ceas := 0.0             # secunde de la moarte, pe ceasul motorului
var _curba: Array = []       # [ceas, raza] la fiecare cadru — de aici iese netezimea
var _dt_max := 0.0
var _sar := 0                # cadre de sarit la masuratoarea de netezime (dupa o poza)
var _cadre := 0
# Pozele blocheaza firul principal cateva sute de ms fiecare (save_png), adica exact ce
# strica masuratoarea de netezime. De-aia sunt PE COMANDA, nu mereu:
#   ...console.exe --path <proj> res://tool_moarte.tscn -- poze
var _fa_poze := "poze" in OS.get_cmdline_user_args()
var _dt_prime: Array = []    # primele cadre de dupa moarte (vezi `_netezime`)
var _varf := -200.0        # cel mai mare varf pe Master in toata cinematica (dB)
var _varf_faza: Dictionary = {}   # faza -> cel mai mare varf din ea

func _process(delta: float) -> void:
	if not _rec:
		return
	_ceas += delta
	_cadre += 1
	if _sar > 0:
		_sar -= 1
	else:
		_dt_max = maxf(_dt_max, delta)
	_curba.append([_ceas, _raza()])
	# Varful de pe Master, cadru cu cadru: cu patru straturi normalizate la -1 dBFS peste
	# muzica, singurul mod de a sti ca mixul NU taie (peste 0 dBFS placa de sunet paraie).
	var v: float = maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0))
	_varf = maxf(_varf, v)
	var faza := _faza(_ceas)
	_varf_faza[faza] = maxf(_varf_faza.get(faza, -200.0), v)
	if _dt_prime.size() < 8:
		_dt_prime.append(delta)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # jocul se pune pe pauza la moarte; noi trebuie sa mergem
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout   # lumea se aseaza, muzica porneste

	var pl := get_tree().get_first_node_in_group("player")
	_go = get_tree().get_first_node_in_group("gameover_screen")
	_cer(pl != null, "player-ul exista")
	_cer(_go != null, "ecranul de Game Over exista")
	if pl == null or _go == null:
		get_tree().quit()
		return
	_mat = _go.get_child(0).material as ShaderMaterial
	_cer(_mat != null, "cercul are shader-ul pe el")
	_cer(not _go.visible, "cat traiesti, ecranul de moarte e ascuns")
	_cer(Audio._music != null and Audio._music.playing, "muzica rundei canta")
	_cer(not AudioServer.is_bus_effect_enabled(Audio._bus_muzica, 0), "filtrul muzicii e deschis")

	# Cat de repede merge jocul INAINTE de moarte, ca sa avem cu ce compara netezimea de dupa
	var t_ref := Time.get_ticks_msec()
	var n_ref := 0
	while Time.get_ticks_msec() - t_ref < 1000:
		await get_tree().process_frame
		n_ref += 1
	print("  (referinta: %d FPS in joc, fereastra %.0fx%.0f)" % [n_ref, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
	print("  (volume: efecte %.2f, muzica %.2f)" % [GameSettings.sfx_volume, GameSettings.music_volume])
	var vp := get_viewport().get_visible_rect().size
	var pe_ecran: Vector2 = pl.get_global_transform_with_canvas().origin / vp

	# --- MOARTEA ---
	_rec = true
	pl.die()
	await get_tree().process_frame
	_cer(_go.visible, "ecranul apare pe loc")
	_cer(get_tree().paused, "lumea ingheata")
	var centru: Vector2 = _mat.get_shader_parameter("centru")
	_cer(centru.distance_to(pe_ecran) < 0.01, "cercul e centrat pe player (%.3f,%.3f vs %.3f,%.3f)"
		% [centru.x, centru.y, pe_ecran.x, pe_ecran.y])
	_cer(_suna("death_hit"), "t=0: cade lovitura")
	_cer(not _go._center.visible, "textul NU se vede inca")

	# 1. inainte sa porneasca cercul: lumea e intreaga, doar inghetata
	await _la(_go.T_LOVITURA * 0.6)
	var r0: float = _raza()
	_cer(r0 >= _go._raza_start - 0.001, "pana la %.2fs cercul sta pe loc (raza %.3f din %.3f)"
		% [_go.T_LOVITURA, r0, _go._raza_start])
	_cer(_mat.get_shader_parameter("stins") < 0.02, "lumea inca are culoare")
	await _poza("1_inghetat")

	# 2. inghitirea
	await _la(_go.T_LOVITURA + 0.05)
	_cer(_suna("death_sweep") and _suna("death_rumble"), "matura si huruitul pornesc cu cercul")
	await _la(_go.T_LOVITURA + _go.T_INGHITIRE * 0.5)
	var r1: float = _raza()
	_cer(r1 < r0 and r1 > _go.RAZA_MICA, "la jumatatea inghitirii cercul e intre %.2f si %.2f (e %.3f)"
		% [_go.RAZA_MICA, r0, r1])
	await _poza("2_inghitire")

	# 3. strangerea
	await _la(_go.T_LOVITURA + _go.T_INGHITIRE + 0.02)
	var r2: float = _raza()
	_cer(absf(r2 - _go.RAZA_MICA) < 0.02, "dupa inghitire ramane cercul mic (%.3f, asteptat %.2f)"
		% [r2, _go.RAZA_MICA])
	await _poza("3_mic")
	await _la(_go.T_LOVITURA + _go.T_INGHITIRE + _go.T_STRANGERE - 0.03)
	var r3: float = _raza()
	_cer(r3 < r2 and r3 >= _go.RAZA_STRANSA - 0.01, "se strange incet spre %.2f (e %.3f)"
		% [_go.RAZA_STRANSA, r3])
	_cer(_mat.get_shader_parameter("rama") > 0.9, "marginea arde rosu cand e strans")
	await _poza("4_strans")

	# 4. inchiderea: raza 0, bubuitura, muzica taiata
	await _la(_go.T_CERC + 0.05)
	_cer(_raza() <= 0.0001, "cercul s-a inchis complet")
	_cer(_mat.get_shader_parameter("stins") > 0.98, "culoarea s-a scurs de tot")
	_cer(_suna("death_snap"), "bubuitura de inchidere cade odata cu cercul")
	await _poza("5_negru")

	# 5. tacerea: nimic nou nu porneste
	await _la(_go.T_CERC + _go.T_TACERE - 0.10)
	_cer(not _suna("game_over"), "in tacere NU se aude stinger-ul (inca)")
	_cer(not _go._center.visible, "in tacere nu se vede text")
	_cer(Audio._music == null or not Audio._music.playing or Audio._music.volume_db < -30.0,
		"muzica e taiata pana la tacere")
	_cer(Audio._filtru.cutoff_hz < Audio.CUTOFF_INFUNDAT * 1.05,
		"filtrul muzicii a ajuns pana la capat (%.0f Hz)" % Audio._filtru.cutoff_hz)

	# 6. textul
	await _la(_go.T_CERC + _go.T_TACERE + 0.05)
	_cer(_go._center.visible, "textul apare dupa tacere")
	_cer(_suna("game_over"), "stinger-ul cade odata cu textul")
	_cer(_go._center.modulate.a < 0.7, "textul APARE lin, nu dintr-o data (alpha %.2f)" % _go._center.modulate.a)
	await _la(_go.T_CERC + _go.T_TACERE + _go.T_TEXT + 0.15)
	_cer(is_equal_approx(_go._center.modulate.a, 1.0), "la final textul e complet vizibil")
	_cer(_go.time_label.text != "", "scrie cat ai supravietuit: %s" % _go.time_label.text)
	await _poza("6_text")
	_rec = false

	_netezime()
	print("\n=== %s ===" % ("TOATE VERIFICARILE AU TRECUT" if _erori == 0 else "%d VERIFICARI PICATE" % _erori))
	get_tree().quit()

# Cat de neteda a fost mișcarea: cate cadre, cat de mare a fost cel mai lung, si cel mai mare
# SALT de raza dintre doua cadre. Un salt mare inseamna ca ochiul vede o smucitura, chiar daca
# toate razele de mai sus au fost corecte la momentele lor.
func _netezime() -> void:
	var salt_max := 0.0
	var la := 0.0
	for i in range(1, _curba.size()):
		var d: float = absf(_curba[i][1] - _curba[i - 1][1])
		# peste inchidere (ultimii 0,09 s) saltul e voit mare — se prabuseste
		if _curba[i][0] > _go.T_CERC - _go.T_INCHIDERE:
			continue
		if d > salt_max:
			salt_max = d
			la = _curba[i][0]
	var dt_mediu: float = (_curba[-1][0] - _curba[0][0]) / maxf(_cadre - 1, 1)
	print("\n--- netezime ---")
	var dp := PackedStringArray()
	for d in _dt_prime:
		dp.append("%.0f" % (float(d) * 1000.0))
	print("  primele cadre dupa moarte (ms): ", ", ".join(dp))
	print("  %d cadre in %.2fs  (mediu %.1f FPS, cel mai lung cadru %.0f ms)"
		% [_cadre, _curba[-1][0], 1.0 / maxf(dt_mediu, 0.0001), _dt_max * 1000.0])
	print("  cel mai mare salt de raza intre doua cadre: %.4f (la t=%.2fs)" % [salt_max, la])
	# ⚠️ Cu poze, masuratoarea de netezime nu inseamna nimic: `save_png` blocheaza firul
	# principal cateva sute de ms si smuceste chiar ea animatia pe care o masuram.
	if _fa_poze:
		print("  (cu poze pornite, netezimea NU se judeca — vezi comentariul)")
	else:
		_cer(_dt_max < 0.10, "niciun cadru mai lung de 100 ms in timpul cinematicii")
		_cer(salt_max < 0.06, "cercul se misca lin, fara smucituri")
	print("
--- varfuri pe Master (dBFS) ---")
	var chei := _varf_faza.keys()
	chei.sort()
	for k in chei:
		print("  %s %6.1f" % [k, _varf_faza[k]])
	# Slider-ul de efecte al lui Razvan poate fi oriunde, deci masuratoarea se aduce la
	# SLIDER MAXIM: acolo se taie, daca se taie. (Sunetele trec toate prin `sfx_db()`.)
	var corectie: float = -linear_to_db(maxf(GameSettings.sfx_volume, 0.001))
	print("  cel mai mare varf: %.1f dBFS  (la slider maxim ar fi %.1f)" % [_varf, _varf + corectie])
	_cer(_varf + corectie < 0.0, "mixul NU taie nici cu efectele date la maxim")
	for k in chei:
		_cer(_varf_faza[k] + corectie > -35.0, "faza %s chiar se aude (%.1f dBFS la maxim)" % [k, _varf_faza[k] + corectie])

# Asteapta pana la secunda `t` de la moarte, pe ceasul motorului.
func _la(t: float) -> void:
	while _ceas < t:
		await get_tree().process_frame

func _raza() -> float:
	return _mat.get_shader_parameter("raza")

# Canta ACUM vreo boxa sunetul asta?
func _suna(nume: String) -> bool:
	var s := Audio.stream_for(nume)
	if s == null:
		return false
	for p in Audio._players:
		if p.playing and p.stream == s:
			return true
	return false

func _poza(nume: String) -> void:
	if not _fa_poze:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(POZE % nume)
	_sar = 2   # cadrul blocat de scrierea pozei nu se pune la socoteala netezimii
	print("   poza: ", nume, "  (t=%.2fs, raza %.3f, stins %.2f)"
		% [_ceas, _raza(), _mat.get_shader_parameter("stins")])

func _cer(conditie: bool, ce: String) -> void:
	if not conditie:
		_erori += 1
	print("  %s %s" % ["OK  " if conditie else "PICAT", ce])

# In ce bucata a cinematicii suntem la secunda `t` (pentru raportul de varfuri).
func _faza(t: float) -> String:
	if t < _go.T_LOVITURA:
		return "1 lovitura "
	if t < _go.T_LOVITURA + _go.T_INGHITIRE:
		return "2 inghitire"
	if t < _go.T_CERC:
		return "3 strangere"
	if t < _go.T_CERC + _go.T_TACERE:
		return "4 inchidere"
	return "5 stinger  "
