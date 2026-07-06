extends Node

const ENEMY := preload("res://enemy.tscn")

@export var spawn_interval: float = 1.0
@export var spawn_distance: float = 700.0

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_enemy)
	add_child(timer)
	timer.start()

func _spawn_enemy() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var enemy := ENEMY.instantiate()
	var unghi := randf() * TAU
	var offset := Vector2(cos(unghi), sin(unghi)) * spawn_distance
	# îl punem în același nod ca player-ul (World, care e Y-sortat) → inamicii
	# sunt și ei acoperiți/descoperiți corect de copaci
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset
