extends Node

const ENEMY := preload("res://enemy.tscn")

@export var spawn_interval: float = 1.0   # pauza de bază între apariții (la dificultate 0)
@export var min_interval: float = 0.2     # cât de repede pot apărea la maximum
@export var spawn_distance: float = 700.0

var timer: Timer

func _ready() -> void:
	Difficulty.time = 0.0  # joc nou → resetăm dificultatea la zero
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_enemy)
	add_child(timer)
	timer.start()

func _spawn_enemy() -> void:
	# Cu cât dificultatea e mai mare, cu atât apar mai des (dar nu sub min_interval)
	timer.wait_time = max(min_interval, spawn_interval / Difficulty.spawn_mult())
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var enemy := ENEMY.instantiate()
	var unghi := randf() * TAU
	var offset := Vector2(cos(unghi), sin(unghi)) * spawn_distance
	# îl punem în World (Y-sortat), la fel ca player-ul, ca să fie acoperit corect de copaci
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset
