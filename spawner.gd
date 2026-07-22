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

@export var spawn_interval: float = 1.0   # pauza de bază între apariții (la secunda 0)
@export var min_interval: float = 0.2     # cât de des poate porni un lot de spawn
@export var spawn_distance: float = 700.0
# Cât de larg e conul din fața player-ului din care apar inamicii (grade, în fiecare parte).
# 45 = un sfert de cerc în față. 180 ar însemna „de peste tot", ca înainte.
@export var spawn_cone_deg: float = 45.0
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
	Difficulty.time = 0.0     # joc nou → resetăm cronometrul
	GameSettings.reset_run()  # resetăm monedele și kill-urile strânse în rundă
	_muta_player_aleator()
	Audio.play_music()        # pornim muzica de fundal
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

func _exit_tree() -> void:
	Audio.stop_music()  # ieșim din joc (meniu/restart) → oprim muzica

func _process(_delta: float) -> void:
	# un singur anunț, exact când cele 10 minute s-au terminat
	if not _final_swarm_announced and Difficulty.is_final_swarm():
		_final_swarm_announced = true
		_announce("FINAL SWARM", "They just keep coming. Survive as long as you can.")
		Audio.play("levelup")

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
	var enemy := ENEMY.instantiate()
	# Inamicii apar DOAR din direcția în care se uită player-ul (cerut pe 2026-07-22): un con
	# de ±`spawn_cone_deg` în jurul privirii, nu tot cercul. Când stai pe loc, privirea rămâne
	# ultima direcție de mers, deci continuă să vină de acolo.
	var privire := Vector2.DOWN
	if player.has_method("facing_dir"):
		privire = player.facing_dir()
	var con := deg_to_rad(spawn_cone_deg)
	var unghi := privire.angle() + randf_range(-con, con)
	var offset := Vector2(cos(unghi), sin(unghi)) * spawn_distance
	# în World (Y-sortat), la fel ca player-ul, ca să fie acoperit corect de copaci
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset

# Cere HUD-ului să afișeze un text mare pe ecran (cu subtitlu).
func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
