extends Node

# Spawner-ul de inamici. NU mai există valuri — inamicii curg continuu, iar
# presiunea crește cu timpul (vezi `difficulty.gd` pentru modelul de scaling).
#
#   0:00 → 10:00   cronometrul SCADE, inamicii se îngroașă liniar
#   după 10:00     FINAL SWARM: cronometrul urcă, totul devine exponențial
#
# BOSS-ul („Garda") NU mai apare automat — îl chemi tu de la statuie, când te
# simți pregătit (`statue.gd`). Cu cât îl chemi mai târziu, cu atât e mai tare,
# fiindcă `garda.gd` citește aceiași multiplicatori de dificultate.

const ENEMY := preload("res://enemy.tscn")
# În Nether curg ALȚI inamici: creaturile violete din `enemy_nether.tscn` (același `enemy.gd`,
# alte cadre, viteză mult mai mare). Spawner-ul continuă să lucreze cât ești acolo — Nether-ul
# nu-l oprește, cum face Limbo — deci el trebuie să știe de unde ia scena.
const ENEMY_NETHER := preload("res://enemy_nether.tscn")
# ...iar în ENDER curg ai lui: aceeași `enemy.gd`, dar de două ori mai iuți decât cei din Nether
# (380 față de 190) și cu `damage_mult = 2.0`, adică te mușcă dublu la contact. Arta e a lui
# Răzvan, pusă pe 2026-08-04 în `harta/Portal Ender/enemy ender/`.
const ENEMY_ENDER := preload("res://enemy_ender.tscn")
# În LUMEA NORMALĂ, printre polițiștii obișnuiți se strecoară „Police Skinny": același `enemy.gd`,
# dar mai iute (160 față de 120), mai gras (45 față de 30) și lovește puțin mai tare
# (`damage_mult = 1.3`). Arta e a lui Răzvan, pusă pe 2026-08-05 în `homeless directii/Police Skinny/`.
const ENEMY_SKINNY := preload("res://enemy_police_skinny.tscn")
# ...și SWAT-ul: tot `enemy.gd`, tot atât de iute ca Skinny (160), dar cu 150 HP de bază — adică
# exact JUMĂTATE din cei 300 ai Gărzii. Nu e o cifră aleasă din ochi: `garda.gd` și `enemy.gd` își
# înmulțesc amândoi viața cu ACELAȘI `Difficulty.enemy_hp_mult()` în clipa nașterii, deci raportul
# de 1/2 se ține în orice secundă a rundei, nu doar la 6:00.
# Arta e a lui Răzvan, pusă pe 2026-08-07 în `homeless directii/Swat/`.
const ENEMY_SWAT := preload("res://enemy_swat.tscn")
# Amândoi apar de la SECUNDA 0, la fel ca polițistul obișnuit — vezi „VALURILE" mai jos.
# ...și POMPIERUL: cel mai tare inamic al lumii normale, singurul care NU e pe masă de la început
# (intră la 3:00 — vezi `minut_politisti`). Arta e a lui Răzvan, pusă pe 2026-08-15 în
# `homeless directii/Firefighter/`.
const ENEMY_FIREFIGHTER := preload("res://enemy_firefighter.tscn")

# Ce curge în PUȘCĂRIE: toate felurile din joc, amestecate în părți egale. Nu sunt inamici noi —
# sunt exact ăștia, doar îngroșați (vezi `prison.gd::ENEMY_POWER` și `_spawn_enemy` mai jos).
# Dacă adaugi vreodată un inamic nou și vrei să apară și acolo, îl treci aici.
const PRISON_FELURI := [ENEMY, ENEMY_SKINNY, ENEMY_SWAT, ENEMY_FIREFIGHTER, ENEMY_NETHER, ENEMY_ENDER]

@export var spawn_interval: float = 1.0   # pauza de bază între apariții (la secunda 0)
@export var min_interval: float = 0.2     # cât de des poate porni un lot de spawn
@export var spawn_distance: float = 700.0
# Cât de larg e conul din jurul privirii din care apar inamicii (grade, în fiecare parte).
# 180 = CERC COMPLET, te înconjoară din toate direcțiile (cerut pe 2026-07-28).
# 45 ar însemna „doar din față", cum era între 2026-07-22 și acum.
@export var spawn_cone_deg: float = 180.0
# Marja peste marginea ecranului la care apar. Contează abia de când spawnul e în cerc: în față
# aveai oricum destul loc, dar în SPATE și în lateral ecranul se vede mai departe decât
# `spawn_distance`, deci inamicii ar fi „pocnit" în plin ecran, din senin. Vezi `_distanta_spawn`.
@export var spawn_margin: float = 90.0
@export var max_enemies: int = 300        # plafon de siguranță, ca să nu moară framerate-ul
@export var max_batch: int = 12           # câți inamici pot apărea deodată într-un lot

# Ce parte din inamicii lumii normale sunt creaturi din Nether DUPĂ ce te-ai întors viu de acolo
# (vezi `nether.gd::escaped`). 0.30 = aproximativ unul din trei. Nu se schimbă numărul total de
# inamici, doar cine sunt: creaturile din Nether sunt mai rapide (190 față de viteza normală) și
# mai grase (50 HP), deci lumea devine mai colțuroasă fără să devină mai aglomerată.
# 0 = ca înainte (nu scapă niciunul), 1 = lumea normală rămâne doar cu creaturi violete.
@export_range(0.0, 1.0) var nether_share: float = 0.30

# ---------------------------------------------------------------------------
# VALURILE: amestecul de polițiști și ritmul lor, TRASE LA SORȚI (cerut pe 2026-08-12)
# ---------------------------------------------------------------------------
# Până acum fiecare fel de polițist avea ora lui fixă și felia lui fixă: Skinny de la 1:00 cu 35%,
# SWAT de la 4:00 cu 20%. Adică fiecare rundă arăta la fel în aceleași minute, iar primul minut era
# mereu numai polițiști obișnuiți. Cerința lui Răzvan: „nu mai vreau să aibă un timp anume la care
# se spawnează și câți — vreau din prima să fie spawn rate-ul și sprite-urile random".
#
# Acum lumea normală merge pe VALURI. La fiecare `val_min`..`val_max` secunde se trag din nou la
# sorți DOUĂ lucruri, odată:
#
#   1. AMESTECUL — fiecare fel de polițist primește o pondere nouă (`_ponderi`), adică ponderea lui
#      de bază înmulțită cu un număr aleator între 1/`haos_amestec` și `haos_amestec`. Un val poate
#      ieși plin de SWAT, următorul aproape numai polițiști slăbănogi.
#   2. RITMUL — un multiplicator peste rata calculată din dificultate (`_ritm`). Sub 1 = respiri,
#      peste 1 = te calcă.
#
# 🔑 De ce ponderi de BAZĂ diferite și nu pur și simplu 1/3 fiecare: un SWAT are de 5 ori viața unui
# polițist obișnuit. La șanse egale, jumătate din runda de la 0:10 ar fi fost tocat buști, adică
# „imposibil", nu „greu". Ponderile de bază spun cine e regula și cine e excepția; sorțul de la
# fiecare val spune cât de mult se abate valul ăsta de la regulă. Amândouă sunt `@export`, deci se
# reglează din inspector fără cod.
#
# ⚠️ DOUĂ excepții de la „fără ore fixe", amândouă cerute pe 2026-08-15, amândouă la capetele
# rundei:
#   · POMPIERUL nu intră deloc în roată până la 3:00 (vezi `minut_politisti`) — are sens tocmai
#     fiindcă e cel mai tare inamic al lumii normale;
#   · PRIMUL MINUT e al polițistului obișnuit: `cota_politist_intai` din spawnuri sunt garantat el
#     (vezi `_cota_primului_minut`). Adică începutul rundei e blând și lizibil, iar de la 1:00
#     încolo lumea e exact cea de dinainte — sorți curați, fără ore fixe.
# În rest, cum i-a vrut Răzvan: din prima, la sorți.
#
# ⚠️ `ritm_min`/`ritm_max` sunt așezate ca MEDIA lor să fie 1.0. Ritmul aleator e TEXTURĂ, nu o
# îngroșare pe furiș: dificultatea trebuie să rămână cea din `difficulty.gd`, altfel curbele de
# acolo n-ar mai însemna nimic și n-ai mai ști pe ce reglezi.
const POLITISTI := [ENEMY, ENEMY_SKINNY, ENEMY_SWAT, ENEMY_FIREFIGHTER]
@export var pond_politisti: Array[float] = [1.0, 0.7, 0.35, 0.18]
# De la a câta secundă SCURSĂ de rundă intră fiecare fel în tragerea la sorți (`Difficulty.time`).
# 0 = de la început, cum sunt primii trei.
#
# ⚠️ Singurul cu ceas e POMPIERUL, la 180 = 3:00, cerut de Răzvan pe 2026-08-15: „nu se spawnează
# de la început, doar după ce trec 3 minute din joc". E cronometrul CRESCĂTOR (cât ai jucat), nu
# cel care scade pe ecran — „3 minute trecute" e `time >= 180`, nu `time_left() <= 180`. Genul de
# cifră care ar fi trecut neobservată: la SWAT, „mai are 6:00" însemna `time >= 240`, nu 360.
#
# ⚠️ Ceasul se citește în `_politist()`, la fiecare inamic născut — NU în `_val_nou()`. Ponderile se
# trag la sorți o dată la 10–22 s, deci un val pornit la 2:59 ar fi ținut pompierul afară până la
# 3:21. Așa intră fix la secunda 180.
@export var minut_politisti: Array[float] = [0.0, 0.0, 0.0, 180.0]

# --- Primul minut e al polițistului obișnuit (cerut de Răzvan pe 2026-08-15) ---
# „Vreau să vină în primul minut 70% din spawn să fie Faceless Police Officer, și după primul minut
# cum e spawnul acum." Faceless Police Officer = `ENEMY`, cel din `enemy.tscn`, primul din
# `POLITISTI` (arta lui sunt GIF-urile `A_faceless_police_officer_in_walk_*` din `homeless directii/`).
#
# `cota_politist_intai` e o cotă GARANTATĂ, nu o pondere: cât ține `primul_minut`, fix atâta parte
# din polițiști e el, oricât de sălbatic ar fi ieșit valul la sorți. De-aia nu s-a rezolvat pur și
# simplu urcând `pond_politisti[0]`: haosul de val (`haos_amestec`) plimbă ponderile de 2,2 ori în
# sus sau în jos, deci „70%" ar fi însemnat oriunde între ~45% și ~85%, altfel la fiecare rundă.
# Vezi `_cota_primului_minut` pentru cum se rescrie ponderea.
#
# ⚠️ Tot `Difficulty.time`, deci tot ceasul CRESCĂTOR: „primul minut" e `time < 60`. Și tot el
# îngheață în Limbo/Nether/Ender, ceea ce aici e exact ce trebuie — un minut de joc în lumea
# normală rămâne un minut de joc în lumea normală, chiar dacă între timp ai fost dincolo.
@export var primul_minut: float = 60.0
@export_range(0.0, 1.0) var cota_politist_intai: float = 0.70

@export var haos_amestec: float = 2.2     # de câte ori poate urca/coborî o pondere într-un val
@export var ritm_min: float = 0.55
@export var ritm_max: float = 1.45
@export var val_min: float = 10.0
@export var val_max: float = 22.0
# În câte secunde alunecă ritmul spre valoarea nouă. NU sare: un salt s-ar vedea ca un lag, pe când
# o alunecare de ~1s se simte ca o maree — abia observi când se strânge lațul.
@export var val_lin: float = 1.2

var _ponderi: Array[float] = []
var _ritm := 1.0
var _ritm_tinta := 1.0
var _val_ramas := 0.0

# --- Creaturile Ender-ului în lumea normală, după ce cade Celesto (cerut pe 2026-08-05) ---
# Exact tiparul lui `nether_share`, o treaptă mai sus: îl bați pe boss-ul din a treia dimensiune
# și de atunci încolo slugile lui te urmează acasă. Steagul e `ender.gd::celesto_invins`, care —
# spre deosebire de `_boss_invins` — NU se stinge la ieșirea din Ender.
#
# ⚠️ Ține-l mic. Creaturile Ender-ului sunt cei mai duri inamici obișnuiți din joc: 380 viteză
# (peste 3× polițistul) și damage dublu la contact. La 0.15 sunt un pericol pe care îl vezi
# venind; la 0.4 lumea normală nu mai e lume normală.
@export_range(0.0, 1.0) var ender_share: float = 0.15

# --- Cât de rea devine lumea după ce te-ai întors viu din Nether (cerut pe 2026-07-30) ---
# Regula, în cuvintele lui Răzvan: „dublează spawn-rate-ul și puterea inamicilor NORMALI".
# Creaturile din Nether NU intră în dublare — ele rămân exact cum sunt dincolo (50 HP de bază
# față de 30, viteză 190 față de 120) și tot `nether_share` din inamici, cum s-a cerut.
#
#   · `escaped_police_mult` = 2 → de două ori mai mulți POLIȚIȘTI pe secundă;
#   · `escaped_power_mult`  = 2 → cu de două ori mai multă VIAȚĂ (`enemy.gd::power_mult`).
#
# ⚠️ Rata TOTALĂ nu se înmulțește cu 2, ci cu 2 / (1 − `nether_share`) = 2,86. Motivul e o
# aritmetică ușor de greșit (am greșit-o o dată): ÎNAINTE de Nether polițiștii erau 100% din
# flux, iar DUPĂ sunt doar 70% din el. Ca să fie de două ori mai mulți polițiști pe secundă ȘI
# creaturile să rămână 30% din total, fluxul întreg trebuie să crească mai mult decât dublu.
# Verificat pe rulare: 1,3 → 3,7 inamici/s, din care 2,6 polițiști (exact dublul celor 1,3).
#
# Amândoi sunt `@export`, deci se pot potoli din inspector fără să umbli în cod. 1.0 = nimic.
@export var escaped_police_mult: float = 2.0
@export var escaped_power_mult: float = 2.0

# --- Punctul de START, ales la întâmplare la fiecare rundă ---
# Lumea e infinită și generată procedural din coordonate: fiecare loc arată altfel, dar
# ACELAȘI loc arată mereu la fel. Până acum porneai mereu din (0,0), deci vedeai mereu
# exact aceeași bucată de hartă. Acum te aruncăm într-un punct aleator → hartă nouă la
# fiecare rundă, fără să stricăm determinismul chunk-urilor (esențial: ele se descarcă
# și se reîncarcă în timp ce mergi).
@export var spawn_range: float = 100000.0   # cât de departe poți fi aruncat (px, pe fiecare axă)
@export var spawn_tries: int = 40           # câte locuri încercăm până acceptăm și deșert
const CHUNK_PX := 512.0                     # ca în props.gd/rocks.gd — pentru întrebarea despre biom

var timer: Timer
var _final_swarm_announced := false

func _ready() -> void:
	add_to_group("spawner")   # ca Limbo să ne poată opri cât ești acolo
	Difficulty.reset_run()    # joc nou → cronometru de la 0, fără înghețări/override-uri rămase
	GameSettings.reset_run()  # resetăm monedele și kill-urile strânse în rundă
	_muta_player_aleator()
	# Primul val se trage ACUM, nu la prima expirare: „din prima să fie random", deci și amestecul,
	# și ritmul secundei 0 sunt deja trase la sorți. `_muta_player_aleator()` a chemat `randomize()`
	# înaintea noastră, altfel fiecare rundă ar fi pornit cu exact același val.
	_val_nou()
	_ritm = _ritm_tinta   # fără alunecare la start — n-avem de unde aluneca
	Audio.play("game_start", 6.0)  # jingle de început de rundă (fișier încet; 6 = jumătate față de 12)
	Audio.play_music()           # pornim muzica de fundal
	Audio.play_forest_ambient()  # ambientul de pădure (se estompează singur în deșert)
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_tick)
	add_child(timer)
	timer.start()
	_announce("SURVIVE 10:00", "Summon the boss at the statue when you're ready")

# Aruncă player-ul într-un colț aleator al lumii infinite → altă hartă la fiecare rundă.
# Evităm să te trezești în mijlocul deșertului (fără copaci, fără pietre, arată gol):
# încercăm câteva puncte și îl luăm pe primul care e pe iarbă curată.
func _muta_player_aleator() -> void:
	randomize()   # altfel am porni de la aceeași secvență la fiecare rulare
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var pos := Vector2.ZERO
	for i in spawn_tries:
		pos = Vector2(randf_range(-spawn_range, spawn_range), randf_range(-spawn_range, spawn_range))
		# desertness 0 = iarbă curată (nici măcar tranziția spre deșert)
		if BiomeMap.desertness_at_chunk(pos / CHUNK_PX) <= 0.0:
			break
	player.global_position = pos
	GameSettings.run_spawn = pos
	# ⚠️ OBLIGATORIU după teleportare. Camera player-ului are `position_smoothing_enabled`,
	# adică urmărește ținta lin, cu întârziere. Ea pornește din (0,0) — unde stătea player-ul
	# în scenă înainte să-l mutăm — iar noi tocmai l-am aruncat la zeci de mii de pixeli.
	# Fără resetare, primele ~2 secunde de rundă arată lumea zburând pe lângă tine până
	# prinde camera din urmă (măsurat: 89.500px decalaj în primul cadru, încă 36px la
	# cadrul 120). `reset_smoothing()` lipește camera instant pe țintă.
	# `force_update_scroll()` întâi, ca ținta să fie deja cea nouă când o „lipim".
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.force_update_scroll()
		cam.reset_smoothing()

func _exit_tree() -> void:
	Audio.stop_music()  # ieșim din joc (meniu/restart) → oprim muzica

func _process(delta: float) -> void:
	# un singur anunț, exact când cele 10 minute s-au terminat
	if not _final_swarm_announced and Difficulty.is_final_swarm():
		_final_swarm_announced = true
		_announce("FINAL SWARM", "They just keep coming. Survive as long as you can.")
		Audio.play("levelup", -2.0)
	_avans_val(delta)

# Cronometrul valurilor. Merge pe `delta`, NU pe `Difficulty.time`: ăla stă pe loc în Limbo, în
# Nether și în Ender, deci valurile ar fi înghețat acolo și te-ai fi întors în lume cu exact
# amestecul cu care ai plecat — și, mai rău, cu ritmul blocat pe cifra de atunci.
func _avans_val(delta: float) -> void:
	_val_ramas -= delta
	if _val_ramas <= 0.0:
		_val_nou()
	# `delta / val_lin` = ce fracțiune din alunecare se face în cadrul ăsta. Plafonat la 1 ca la
	# framerate mic (sau după o pauză lungă) să nu sară dincolo de țintă.
	_ritm = lerpf(_ritm, _ritm_tinta, minf(1.0, delta / maxf(0.01, val_lin)))

# Trage la sorți valul următor: cât ține, cât de des curg inamicii în el și din cine e făcut.
func _val_nou() -> void:
	_val_ramas = randf_range(val_min, val_max)
	_ritm_tinta = randf_range(ritm_min, ritm_max)
	_ponderi.clear()
	var h := maxf(1.0, haos_amestec)
	# Mereu exact câte scene sunt în `POLITISTI`, nu câte a lăsat cineva în inspector: dacă lista de
	# ponderi ar fi mai scurtă sau mai lungă, roata de la `_politist()` ar ieși din listă.
	for i in POLITISTI.size():
		var baza := float(pond_politisti[i]) if i < pond_politisti.size() else 1.0
		_ponderi.append(baza * randf_range(1.0 / h, h))

# Câți inamici pe secundă ar trebui să curgă ACUM, la dificultatea de acum.
#
# E scoasă din `_spawn_tick` ca s-o poată folosi și `limbo.gd`: acolo spawner-ul e OPRIT (Limbo
# își naște singur inamicii), dar de pe 2026-08-06 trebuie să-i scoată în EXACT același ritm ca
# lumea de acum un minut. Un singur loc unde trăiește formula — inclusiv corecția aia de
# 2/(1−nether_share), pe care am greșit-o o dată deja (vezi comentariul de la `escaped_*`).
func rata_curenta() -> float:
	var rate := (1.0 / spawn_interval) * Difficulty.spawn_mult()
	if _scapat_din_nether():
		# de două ori mai mulți polițiști, cu creaturile tot la `nether_share` din total
		rate *= escaped_police_mult / maxf(0.01, 1.0 - nether_share)
	# CÂT EȘTI ÎN NETHER: pedeapsa pentru intrarea prea devreme (cerută pe 2026-08-11). Formula ei
	# stă în `nether.gd::spawn_mult` — aici doar o cerem, la fel ca felia de creaturi scăpate.
	# Cele două nu se calcă: `_scapat_din_nether()` e adevărat exact când NU mai ești acolo.
	var n := get_tree().get_first_node_in_group("nether")
	if n != null and n.get("active") == true and n.has_method("spawn_mult"):
		rate *= n.spawn_mult()
	# Ritmul aleator al valului (vezi „VALURILE"). DOAR în lumea normală: Nether-ul și Ender-ul își
	# au fiecare formula lui, calibrată pe promisiuni exacte („aici nu e niciodată mai gol decât
	# lumea la 2:00"), iar un multiplicator care se plimbă între 0.55 și 1.45 peste ea ar face
	# promisiunile alea false o parte din timp.
	if _in_lumea_normala():
		rate *= _ritm
	return rate

# Suntem în lumea obișnuită (sau în Limbo, care e tot ea, cu un minut în urmă)?
func _in_lumea_normala() -> bool:
	for grup in ["nether", "ender", "prison"]:
		var d := get_tree().get_first_node_in_group(grup)
		if d != null and d.get("active") == true:
			return false
	return true

# Ce fel de inamic naște lumea acum — PUBLIC, tot pentru Limbo (vezi `_scena_inamic`).
func scena_inamic() -> PackedScene:
	return _scena_inamic()

# La fiecare tick calculăm din nou cât de deasă e ploaia de inamici.
func _spawn_tick() -> void:
	var rate := rata_curenta()
	var interval := 1.0 / rate
	var batch := 1
	# dacă ritmul cerut e mai rapid decât poate bate timer-ul, compensăm scoțând
	# mai mulți inamici odată în loc să pornim timer-ul mai des
	if interval < min_interval:
		batch = int(ceil(min_interval / interval))
		interval = min_interval
	timer.wait_time = interval

	var vii := get_tree().get_nodes_in_group("enemy").size()
	batch = min(batch, max_batch, max_enemies - vii)
	for i in batch:
		_spawn_enemy()

func _spawn_enemy() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var scena := _scena_inamic()
	var enemy := scena.instantiate()
	# Polițiștii se îngrașă după ce te-ai întors din Nether; creaturile de acolo, nu — ele erau
	# deja tari. Se pune ÎNAINTE de `add_child`, fiindcă `enemy.gd::_ready()` îl citește acolo.
	# Skinny e tot polițist, deci intră și el în îngroșare.
	#
	# ⚠️ SWAT-ul NU intră, deși e tot polițist. Cerința lui e „50% din viața Gărzii în momentul
	# ăla", iar `power_mult = 2` l-ar face 100% din ea — adică un boss de-a dreptul, din întâmplare,
	# și numai pe rundele în care ai trecut prin Nether. Promisiunea trebuie să fie adevărată în
	# orice secundă, deci îngroșarea se oprește la Skinny.
	#
	# ⚠️ Nici POMPIERUL, din același motiv, dar mai apăsat: are 225 din cei 300 ai Gărzii, adică 75%.
	# Dublat ar fi ajuns la 450 — o rundă în care te-ai plimbat prin Nether ți-ar fi scos pe cap, la
	# 8% din spawnuri, un inamic cu de UNU-ȘI-JUMĂTATE viața boss-ului. „Cel mai tare din lumea
	# normală" e una, „mai tare decât boss-ul" e alta.
	if (scena == ENEMY or scena == ENEMY_SKINNY) and _scapat_din_nether():
		enemy.power_mult = escaped_power_mult
	_ingroasa_pentru_puscarie(enemy)
	# Inamicii apar într-un con de ±`spawn_cone_deg` în jurul privirii. Cu 180 (implicit de pe
	# 2026-07-28) conul e cercul întreg, deci te înconjoară — nu mai vin doar din față.
	# Când stai pe loc, privirea rămâne ultima direcție de mers.
	var privire := Vector2.DOWN
	if player.has_method("facing_dir"):
		privire = player.facing_dir()
	var con := deg_to_rad(spawn_cone_deg)
	var unghi := privire.angle() + randf_range(-con, con)
	var offset := Vector2(cos(unghi), sin(unghi)) * _distanta_spawn()
	# în World (Y-sortat), la fel ca player-ul, ca să fie acoperit corect de copaci
	player.get_parent().add_child(enemy)
	# Nether-ul și Ender-ul au un capăt (vezi `ground.gd`). Când te plimbi pe lângă buză, conul de
	# spawn cade jumătate în gol — `loc_in_margine` îl oglindește, deci inamicul vine dinspre lume,
	# nu de peste prăpastie. În lumea normală întoarce punctul neatins.
	var poz := player.global_position + offset
	var ground := get_tree().get_first_node_in_group("ground")
	if ground != null and ground.has_method("loc_in_margine"):
		poz = ground.loc_in_margine(player.global_position, poz)
	enemy.global_position = poz

# PUȘCĂRIA: aceiași inamici, dar mai OP. Cele trei cifre stau în `prison.gd` (ENEMY_POWER /
# ENEMY_SPEED / ENEMY_DAMAGE), nu aici — acolo e locul unde se reglează dimensiunea.
#
# ⚠️ Se cheamă ÎNAINTE de `add_child`, ca tot ce se coace în `enemy.gd::_ready()` (viața, viteza
# finală) să apuce valorile astea. După `add_child` n-ar mai avea niciun efect pe viață.
#
# ⚠️ Se aplică PESTE `power_mult` pus mai sus, nu în locul lui — dar în pușcărie `_scapat_din_nether()`
# e oricum fals (verifică să nu fii într-o dimensiune), deci în practică nu se suprapun.
func _ingroasa_pentru_puscarie(enemy: Node) -> void:
	var pr := get_tree().get_first_node_in_group("prison")
	if pr == null or pr.get("active") != true:
		return
	enemy.power_mult = float(enemy.power_mult) * float(pr.ENEMY_POWER)
	enemy.speed = float(enemy.speed) * float(pr.ENEMY_SPEED)
	enemy.damage_mult = float(enemy.damage_mult) * float(pr.ENEMY_DAMAGE)

# Naște un inamic la o poziție anume, cu toate îngroșările la locul lor. O cere `prison.gd`
# pentru valul de la intrare — ca să nu-și facă el o copie a logicii de mai sus și să rămână
# în urmă la prima schimbare.
func naste_inamic_aici(poz: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var enemy := _scena_inamic().instantiate()
	_ingroasa_pentru_puscarie(enemy)
	player.get_parent().add_child(enemy)
	enemy.global_position = poz

# De la ce distanță apar. Niciodată mai aproape decât colțul ecranului + `spawn_margin`, ca să
# nu-i vezi materializându-se. Zona vizibilă o citim din transformarea camerei
# (`canvas_transform` inversată = ce bucată de lume se vede acum), NU din `spawn_distance`
# calculat de mână: așa rămâne corect la orice zoom, orice rezoluție de telefon și orice
# scară a player-ului — dacă am fi socotit „viewport / zoom" am fi ignorat scara părintelui.
func _distanta_spawn() -> float:
	var vp := get_viewport()
	if vp == null:
		return spawn_distance
	var vizibil := vp.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	return max(spawn_distance, vizibil.size.length() * 0.5 + spawn_margin)

# Ce inamic naște lumea ACUM.
#   • în Nether  → numai creaturile violete;
#   • în lumea normală, DUPĂ ce te-ai întors viu din Nether → amestec: `nether_share` din ei
#     sunt creaturi violete, restul polițiști (cerut de Răzvan pe 2026-07-30);
#   • altfel → doar polițiști.
# Întrebăm nodul din grupul „nether" (e `nether.gd`, un CanvasLayer din `main.tscn`) — el ține
# atât `active`, cât și `escaped`. Dacă lipsește (o scenă de test fără el), rămân cei normali.
func _scena_inamic() -> PackedScene:
	# PUȘCĂRIA (a patra) n-are inamici desenați ai ei: cerut explicit — „folosește enemy-ii care
	# există deja, doar fă-i mai OP deocamdată". Deci trage la sorți din TOATE felurile din joc,
	# cu ponderi egale, iar îngroșarea o face `_spawn_enemy` (viață, viteză, damage).
	# Se întreabă PRIMA: în pușcărie nu poți fi în altă dimensiune.
	var pr := get_tree().get_first_node_in_group("prison")
	if pr != null and pr.get("active") == true:
		return PRISON_FELURI[randi() % PRISON_FELURI.size()]
	# Ender-ul (a treia dimensiune) ÎȘI ARE inamicii lui de pe 2026-08-04 (`enemy_ender.tscn`).
	# Se întreabă primul: în Ender nu poți fi și în Nether.
	var e := get_tree().get_first_node_in_group("ender")
	if e != null and e.get("active") == true:
		return ENEMY_ENDER
	var n := get_tree().get_first_node_in_group("nether")
	if n != null and n.get("active") == true:
		return ENEMY_NETHER
	# --- de aici încolo suntem în LUMEA NORMALĂ ---
	if n != null and n.get("escaped") == true and randf() < nether_share:
		return ENEMY_NETHER
	# ...iar dacă ai ucis vreodată în runda asta pe Celesto, printre ei se strecoară și creaturile
	# lui. Se întreabă DUPĂ Nether, deci cele două felii nu se calcă: Ender-ul ia `ender_share`
	# din ce a rămas, nu din tot.
	if e != null and e.get("celesto_invins") == true and randf() < ender_share:
		return ENEMY_ENDER
	return _politist()

# Ce fel de polițist iese acum în lumea normală: cel obișnuit, Skinny (mai iute și mai tare), SWAT
# (la fel de iute ca Skinny, dar de cinci ori mai gras) sau POMPIERUL (cel mai tare din lume, dar
# abia de la 3:00). Primii trei sunt pe masă de la secunda 0; cine iese se trage la sorți din
# ponderile valului de acum (vezi „VALURILE" sus). Cât ține primul minut, o cotă fixă din ei e
# garantat cel obișnuit (`_cota_primului_minut`).
#
# Roata clasică: aduni ponderile, tragi un număr în intervalul ăsta și mergi până cade. NU e nici
# un fel de rezervor („exact 2 SWAT din 10") — asta e cerința, sorți curați: poți primi trei SWAT
# la rând, sau niciunul un minut întreg.
func _politist() -> PackedScene:
	# Ponderile de ACUM: cele trase la sorți pentru valul curent, cu porțile de ceas aplicate...
	var p: Array[float] = []
	for i in _ponderi.size():
		p.append(_pondere(i))
	# ...și cu cota garantată a primului minut peste ele, dacă mai suntem în el.
	_cota_primului_minut(p)
	var total := 0.0
	for w in p:
		total += w
	if total <= 0.0:
		return ENEMY   # ponderi toate pe 0 (reglaj greșit din inspector) → nu rămânem fără inamici
	var r := randf() * total
	for i in p.size():
		r -= p[i]
		if r <= 0.0:
			return POLITISTI[i] as PackedScene
	return ENEMY

# Rescrie ponderea polițistului obișnuit cât ține primul minut, ca din roată să iasă EXACT
# `cota_politist_intai` din el. Roata dă felii proporționale cu ponderile, deci ecuația e:
#
#     w0 / (w0 + restul) = cota   →   w0 = restul * cota / (1 − cota)
#
# La cota 0,70 și restul 1,05 (Skinny 0,7 + SWAT 0,35, pompierul e încă închis) iese w0 = 2,45,
# adică 2,45 / 3,5 = 70%. Exact, la orice val: dacă haosul umflă Skinny-ul, `restul` crește și w0
# crește odată cu el.
#
# 🔑 Ceilalți NU se ating între ei — doar primul se rescrie. Deci în cei 30% rămași, proporțiile
# valului sunt fix cele trase la sorți: un val „de SWAT" rămâne un val de SWAT, doar că se joacă
# într-o treime din spawnuri în loc de tot. Și numărul TOTAL de inamici nu se schimbă nicăieri:
# aici se alege doar CINE iese, nu CÂȚI (ăia vin din `rata_curenta()`).
func _cota_primului_minut(p: Array[float]) -> void:
	if p.is_empty() or Difficulty.time >= primul_minut:
		return
	var restul := 0.0
	for i in range(1, p.size()):
		restul += p[i]
	# cota 1,0 („numai el") sau n-a mai rămas nimeni în roată → împărțirea de mai jos ar fi pe zero.
	# `maxf(..., 1.0)` ne asigură că totalul nu iese 0 și nu ajungem pe ramura de avarie.
	if cota_politist_intai >= 1.0 or restul <= 0.0:
		for i in range(1, p.size()):
			p[i] = 0.0
		p[0] = maxf(p[0], 1.0)
		return
	p[0] = restul * cota_politist_intai / (1.0 - cota_politist_intai)

# Ponderea felului `i` ACUM: cea trasă la sorți pentru valul curent, sau 0 dacă încă nu i-a venit
# ceasul (vezi `minut_politisti`). Un fel blocat iese complet din roată — nu-i „mută" felia altcuiva
# după niciun calcul: pur și simplu ceilalți împart un total mai mic, deci ponderile lor relative
# rămân exact cele de dinainte, iar numărul TOTAL de inamici nu se schimbă.
func _pondere(i: int) -> float:
	var ceas: float = minut_politisti[i] if i < minut_politisti.size() else 0.0
	if Difficulty.time < ceas:
		return 0.0
	return _ponderi[i]

# Te-ai întors VIU din Nether? Cât ești ÎNCĂ acolo nu se aplică nimic din îngroșarea de mai sus:
# Nether-ul își are dificultatea lui (`nether.gd::_diff_time`), n-are rost să o dublăm și noi peste.
func _scapat_din_nether() -> bool:
	# Nici în Ender nu se aplică, din același motiv: acolo dificultatea o scrie `ender.gd`.
	# (Și ești acolo tocmai FIINDCĂ ai scăpat din Nether, deci fără linia asta îngroșarea
	# s-ar aplica mereu în a treia dimensiune.)
	var e := get_tree().get_first_node_in_group("ender")
	if e != null and e.get("active") == true:
		return false
	var n := get_tree().get_first_node_in_group("nether")
	if n == null or n.get("active") == true:
		return false
	return n.get("escaped") == true

# Cere HUD-ului să afișeze un text mare pe ecran (cu subtitlu).
func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
