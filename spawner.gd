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
@export var max_enemies: int = 300        # plafon de siguranță, ca să nu moară framerate-ul
@export var max_batch: int = 12           # câți inamici pot apărea deodată într-un lot

var timer: Timer
var _final_swarm_announced := false

func _ready() -> void:
	Difficulty.time = 0.0     # joc nou → resetăm cronometrul
	GameSettings.reset_run()  # resetăm monedele și kill-urile strânse în rundă
	Audio.play_music()        # pornim muzica de fundal
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_tick)
	add_child(timer)
	timer.start()
	_announce("SURVIVE 10:00", "Summon the boss at the statue when you're ready")

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
	var unghi := randf() * TAU
	var offset := Vector2(cos(unghi), sin(unghi)) * spawn_distance
	# în World (Y-sortat), la fel ca player-ul, ca să fie acoperit corect de copaci
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset

# Cere HUD-ului să afișeze un text mare pe ecran (cu subtitlu).
func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
