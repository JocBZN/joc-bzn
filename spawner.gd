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
# În LUMEA NORMALĂ, după primul minut, printre polițiștii obișnuiți începe să se strecoare
# „Police Skinny": același `enemy.gd`, dar mai iute (160 față de 120), mai gras (45 față de 30)
# și lovește puțin mai tare (`damage_mult = 1.3`). Arta e a lui Răzvan, pusă pe 2026-08-05 în
# `homeless directii/Police Skinny/`. Vezi `skinny_after` / `skinny_share` mai jos.
const ENEMY_SKINNY := preload("res://enemy_police_skinny.tscn")
# ...și de la jumătatea rundei apare SWAT-ul: tot `enemy.gd`, tot atât de iute ca Skinny (160),
# dar cu 150 HP de bază — adică exact JUMĂTATE din cei 300 ai Gărzii. Nu e o cifră aleasă din
# ochi: `garda.gd` și `enemy.gd` își înmulțesc amândoi viața cu ACELAȘI `Difficulty.enemy_hp_mult()`
# în clipa nașterii, deci raportul de 1/2 se ține în orice secundă a rundei, nu doar la 6:00.
# Arta e a lui Răzvan, pusă pe 2026-08-07 în `homeless directii/Swat/`. Vezi `swat_after` mai jos.
const ENEMY_SWAT := preload("res://enemy_swat.tscn")

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

# --- Police Skinny în lumea normală (cerut pe 2026-08-05) ---
# `skinny_after` = de la ce secundă a rundei începe să apară. 60 = după primul minut.
# `skinny_share` = ce parte din POLIȚIȘTI sunt Skinny de atunci încolo (0.35 ≈ unul din trei).
#
# Ca la `nether_share`, NU se schimbă câți inamici apar, doar CINE sunt — deci primul minut
# rămâne exact cum era, iar de la 1:00 lumea devine mai colțuroasă fără să devină mai
# aglomerată. Se împarte doar felia de polițiști: dacă te-ai întors din Nether, creaturile
# violete rămân tot `nether_share` din total, iar Skinny mușcă din restul.
#
# Se numără pe cronometrul rundei (`Difficulty.time`), care stă pe loc în Limbo și în Nether —
# adică „un minut petrecut în LUMEA NORMALĂ", cum s-a cerut, nu un minut de ceas.
@export var skinny_after: float = 60.0
@export_range(0.0, 1.0) var skinny_share: float = 0.35

# --- SWAT în lumea normală (cerut pe 2026-08-07) ---
# Cerința: „apare când mai are player-ul 6:00 în lumea normală". Cronometrul de pe ecran SCADE de
# la 10:00, deci „mai are 6:00" înseamnă `time_left() == 360`, adică `Difficulty.time >= 240` —
# 4:00 SCURSE. De aia scrie 240 aici și nu 360. Se numără pe același `Difficulty.time` ca Skinny,
# care stă pe loc în Limbo/Nether/Ender, deci e chiar „în lumea normală".
#
# `swat_share` = ce parte din POLIȚIȘTI sunt SWAT de atunci încolo. Se întreabă ÎNAINTEA lui
# Skinny, deci la 0.20 iese: 20% SWAT, 28% Skinny (35% din restul) și 52% polițist obișnuit.
#
# ⚠️ Ține-l mic. Un SWAT are de 5 ori viața unui Skinny; la 0.35 (cât are Skinny) jumătate din
# runda de după minutul 4 s-ar transforma în tocat buști. 0.20 ≈ unul din cinci polițiști.
@export var swat_after: float = 240.0
@export_range(0.0, 1.0) var swat_share: float = 0.20

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

func _process(_delta: float) -> void:
	# un singur anunț, exact când cele 10 minute s-au terminat
	if not _final_swarm_announced and Difficulty.is_final_swarm():
		_final_swarm_announced = true
		_announce("FINAL SWARM", "They just keep coming. Survive as long as you can.")
		Audio.play("levelup", -2.0)

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
	# Cursed Tome (itemul dubiosului): +25% inamici pe secundă, cumulat. Aici, în formula comună,
	# nu în `_spawn_tick` — altfel Limbo, care își naște singur inamicii din ea, l-ar fi ignorat.
	var p = get_tree().get_first_node_in_group("player")
	if p != null and "spawn_rate_mult" in p:
		rate *= float(p.spawn_rate_mult)
	return rate

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
	if (scena == ENEMY or scena == ENEMY_SKINNY) and _scapat_din_nether():
		enemy.power_mult = escaped_power_mult
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

# Ce fel de polițist iese acum în lumea normală: cel obișnuit, Skinny (mai iute și mai tare) sau
# SWAT (la fel de iute ca Skinny, dar de cinci ori mai gras). Fiecare apare abia după secunda lui,
# ca începutul rundei să rămână blând. SWAT-ul se întreabă PRIMUL, deci Skinny ia felia lui din ce
# a rămas — același tipar ca Nether/Ender mai sus, ca cele două să nu se calce.
func _politist() -> PackedScene:
	if Difficulty.time >= swat_after and randf() < swat_share:
		return ENEMY_SWAT
	if Difficulty.time >= skinny_after and randf() < skinny_share:
		return ENEMY_SKINNY
	return ENEMY

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
