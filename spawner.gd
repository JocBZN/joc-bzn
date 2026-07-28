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

# La fiecare tick calculăm din nou cât de deasă e ploaia de inamici.
func _spawn_tick() -> void:
	# câți inamici pe secundă ar trebui să apară acum
	var rate := (1.0 / spawn_interval) * Difficulty.spawn_mult()
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
	var enemy := _scena_inamic().instantiate()
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
	enemy.global_position = player.global_position + offset

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

# Ce inamic naște lumea ACUM. În Nether numai creaturile violete, în rest polițiștii.
# Întrebăm nodul din grupul „nether" (e `nether.gd`, un CanvasLayer din `main.tscn`) — el
# știe dacă ești dincolo. Dacă lipsește (o scenă de test fără el), rămân inamicii normali.
func _scena_inamic() -> PackedScene:
	var n := get_tree().get_first_node_in_group("nether")
	if n != null and n.get("active") == true:
		return ENEMY_NETHER
	return ENEMY

# Cere HUD-ului să afișeze un text mare pe ecran (cu subtitlu).
func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
