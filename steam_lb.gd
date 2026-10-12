extends Node
# Leaderboard-ul de pe STEAM (autoload "SteamLB"). Adăugat 2026-10-12.
#
# Leaderboard-ul l-a făcut Răzvan în Steamworks: nume „Highscore”, Sort Method = Descending,
# Display Type = Numeric. SCORUL trimis = SECUNDELE supraviețuite (întregi) — exact criteriul după
# care e sortat și clasamentul local din `GameSettings.scores`, deci cele două spun același lucru.
# Nivelul și kill-urile merg ca „details” ([nivel, kills]), ca pagina din joc să le poată arăta.
# 💡 În Steamworks, Display Type „Time (seconds)” ar face și pagina de pe site să scrie 12:11 în
# loc de 731 — jocul nu se schimbă cu nimic dacă îl muți acolo (el formatează singur).
#
# ⚠️ Totul trece prin `_steam` (`Engine.get_singleton("Steam")`), NU prin clasa `Steam` scrisă
# direct. Clasa există doar când pluginul GodotSteam (`addons/godotsteam/`) s-a încărcat; dacă
# lipsește (alt calculator, alt export), un `Steam.ceva` scris în cod ar fi eroare de COMPILARE și
# ar pica tot autoload-ul. Așa, fără plugin sau fără clientul Steam pornit, `activ` rămâne false și
# jocul merge exact ca înainte, doar cu clasamentul local.

const APP_ID := 5107310
const NUME_LB := "Highscore"
const CATE := 10   # câte rânduri aducem în pagina din meniu (top 10, ca și cel local)

signal intrari_gata(intrari: Array)   # [{rank, nume, timp, nivel, kills, eu}], deja sortate

var activ := false        # Steam pornit și leaderboard-ul găsit — doar atunci trimitem/cerem
var motiv := ""           # de ce NU e activ (pentru log și pentru textul din meniu)
var _steam: Object = null
var _handle := 0
var _de_trimis: Array = []    # scoruri venite înainte să se găsească leaderboard-ul
var _cerere_globala := false  # cineva a cerut top-ul înainte să se găsească leaderboard-ul
var _ultimele: Array = []     # ultimele intrări brute, ca să refacem numele când sosesc

func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		motiv = "plugin GodotSteam lipsă"
		return
	_steam = Engine.get_singleton("Steam")
	# embed_callbacks = true: pluginul își rulează singur `run_callbacks()` în fiecare cadru.
	var r: Dictionary = _steam.steamInitEx(APP_ID, true)
	if int(r.get("status", 1)) != 0:
		motiv = "Steam nepornit (%s)" % str(r.get("verbal", "?"))
		push_warning("SteamLB: " + motiv)
		_steam = null
		return
	_steam.leaderboard_find_result.connect(_la_gasit)
	_steam.leaderboard_score_uploaded.connect(_la_trimis)
	_steam.leaderboard_scores_downloaded.connect(_la_descarcat)
	_steam.persona_state_change.connect(_la_persona)
	_steam.findLeaderboard(NUME_LB)

func _la_gasit(handle: int, gasit: int) -> void:
	if gasit == 0 or handle == 0:
		motiv = "leaderboard-ul „%s” nu există în Steamworks" % NUME_LB
		push_warning("SteamLB: " + motiv)
		return
	_handle = handle
	activ = true
	motiv = ""
	for s in _de_trimis:
		_trimite(s[0], s[1], s[2])
	_de_trimis.clear()
	if _cerere_globala:
		_cerere_globala = false
		cere_top()

# Chemat din `GameSettings.add_score()` — deci DOAR pentru rundele care intră și în clasamentul
# local (rundele cu challenge ies deja acolo, înainte să ajungă aici).
func trimite_scor(secunde: float, nivel: int, kills: int) -> void:
	if _steam == null:
		return
	if not activ:
		_de_trimis.append([secunde, nivel, kills])   # leaderboard-ul încă se caută
		return
	_trimite(secunde, nivel, kills)

func _trimite(secunde: float, nivel: int, kills: int) -> void:
	# keep_best = true: Steam păstrează singur cel mai bun scor al jucătorului; o rundă mai slabă
	# nu-l coboară în clasament.
	_steam.uploadLeaderboardScore(int(secunde), true, PackedInt32Array([nivel, kills]), _handle)

func _la_trimis(ok: int, _h: int, rez: Dictionary) -> void:
	if ok == 0:
		push_warning("SteamLB: trimiterea scorului a eșuat")
		return
	print("SteamLB: scor %d trimis, schimbat=%d, loc %d (înainte %d)" % [int(rez.get("score", 0)),
		int(rez.get("score_changed", 0)), int(rez.get("global_rank_new", 0)), int(rez.get("global_rank_prev", 0))])

# Cere top-ul global; răspunsul vine prin semnalul `intrari_gata`.
func cere_top() -> void:
	if _steam == null:
		return
	if not activ:
		_cerere_globala = true
		return
	_steam.downloadLeaderboardEntries(1, CATE, 0, _handle)   # 0 = LEADERBOARD_DATA_REQUEST_GLOBAL

func _la_descarcat(_mesaj: String, _h: int, intrari: Array) -> void:
	_ultimele = intrari
	for e in intrari:
		var id: int = int(e.get("steam_id", 0))
		# Numele unui străin nu e mereu în cache-ul clientului; îl cerem și vine prin
		# `persona_state_change`. `true` = ne trebuie doar numele, nu și avatarul.
		if _nume(id) == "":
			_steam.requestUserInformation(id, true)
	intrari_gata.emit(_formateaza())

func _formateaza() -> Array:
	var eu: int = int(_steam.getSteamID())
	var out := []
	for e in _ultimele:
		var id: int = int(e.get("steam_id", 0))
		var d: PackedInt32Array = e.get("details", PackedInt32Array())
		out.append({
			"rank": int(e.get("global_rank", 0)),
			"nume": _nume(id),
			"timp": int(e.get("score", 0)),
			"nivel": d[0] if d.size() > 0 else 0,
			"kills": d[1] if d.size() > 1 else 0,
			"eu": id == eu,
		})
	return out

func _nume(id: int) -> String:
	var n: String = _steam.getFriendPersonaName(id)
	return "" if n == "" or n == "[unknown]" else n

func _la_persona(id: int, _flags: int) -> void:
	for e in _ultimele:
		if int(e.get("steam_id", 0)) == id:
			intrari_gata.emit(_formateaza())
			return
