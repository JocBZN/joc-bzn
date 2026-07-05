extends CharacterBody2D

# Numele animațiilor pe octanți (după unghi), în ordinea 0=est, apoi din 45° în 45°.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 120.0
@export var max_hp: int = 30
var hp: int

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var directie := (player.global_position - global_position).normalized()
	velocity = directie * speed
	move_and_slide()
	# angle() = unghiul spre player (0 = est, crește în sensul acelor de ceas).
	# Împărțim la 45° (PI/4) și rotunjim → octantul (0..7), potrivit cu DIRECTII.
	var idx := wrapi(int(round(directie.angle() / (PI / 4.0))), 0, 8)
	anim.play(DIRECTII[idx])  # dacă e deja aceeași animație, doar continuă

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
