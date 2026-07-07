extends Node

# Managerul de VALURI (waves). Structura unui val:
#   1) SPAWNING — apar inamici normali `wave_duration` secunde (tot mai des/greu cu valul);
#   2) BOSS     — apare un BOSS („Garda"); cât trăiește, nu mai apar inamici normali;
#   3) BREAK    — o scurtă pauză, apoi începe valul următor (mai greu).
# Textul de pe ecran ("VALUL 3", "BOSS!", "VAL TERMINAT") e afișat de HUD (hud.announce).

const ENEMY := preload("res://enemy.tscn")
const BOSS := preload("res://garda.tscn")

@export var spawn_interval: float = 1.0   # pauza de bază între apariții (la valul 1)
@export var min_interval: float = 0.2     # cât de repede pot apărea la maximum
@export var spawn_distance: float = 700.0
@export var wave_duration: float = 25.0   # cât ține partea de spawn a unui val (secunde)
@export var break_duration: float = 4.0   # pauza dintre valuri (secunde)

enum State { SPAWNING, BOSS, BREAK }
var _state: int = State.BREAK
var _wave_time: float = 0.0
var _break_time: float = 0.0
var _boss: Node = null   # referință la boss cât e viu

var timer: Timer

func _ready() -> void:
	Difficulty.time = 0.0   # joc nou → resetăm cronometrul
	Difficulty.wave = 1
	Audio.play_music()      # pornim muzica de fundal
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_enemy)
	add_child(timer)
	timer.start()
	# primul val începe după o scurtă pauză (ca să apuci să citești textul)
	_start_break(2.0)

func _exit_tree() -> void:
	Audio.stop_music()  # ieșim din joc (meniu/restart) → oprim muzica

func _process(delta: float) -> void:
	match _state:
		State.SPAWNING:
			_wave_time -= delta
			if _wave_time <= 0.0:
				_start_boss()
		State.BOSS:
			# valul se termină când bossul a murit (referința nu mai e validă)
			if _boss == null or not is_instance_valid(_boss):
				_wave_cleared()
		State.BREAK:
			_break_time -= delta
			if _break_time <= 0.0:
				_start_wave()

# --- Fazele valului ---

func _start_break(secs: float) -> void:
	_state = State.BREAK
	_break_time = secs

func _start_wave() -> void:
	_state = State.SPAWNING
	_wave_time = wave_duration
	Difficulty.wave = _wave_number()
	_announce("WAVE %d" % _wave_number(), "Get ready!")
	Audio.play("levelup")  # mic fanfaron la începutul valului

func _start_boss() -> void:
	_state = State.BOSS
	_announce("BOSS!", "Defeat it to move on")
	_boss = _spawn_boss()

func _wave_cleared() -> void:
	_announce("WAVE %d CLEARED" % _wave_number(), "Next wave starting...")
	_boss = null
	_wave = _wave_number() + 1  # trecem la valul următor
	_start_break(break_duration)

# ținem numărul de val într-o variabilă simplă (1, 2, 3, ...)
var _wave: int = 1
func _wave_number() -> int:
	return _wave

# --- Spawn inamici / boss ---

func _spawn_enemy() -> void:
	# apar inamici normali DOAR în timpul părții de spawn a valului
	if _state != State.SPAWNING:
		return
	# cu cât valul e mai mare, cu atât apar mai des (dar nu sub min_interval)
	timer.wait_time = max(min_interval, spawn_interval / Difficulty.spawn_mult())
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var enemy := ENEMY.instantiate()
	var unghi := randf() * TAU
	var offset := Vector2(cos(unghi), sin(unghi)) * spawn_distance
	# în World (Y-sortat), la fel ca player-ul, ca să fie acoperit corect de copaci
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset

func _spawn_boss() -> Node:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var boss := BOSS.instantiate()
	var unghi := randf() * TAU
	var offset := Vector2(cos(unghi), sin(unghi)) * spawn_distance
	player.get_parent().add_child(boss)
	boss.global_position = player.global_position + offset
	return boss

# Cere HUD-ului să afișeze un text mare pe ecran (cu subtitlu).
func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
