extends CharacterBody2D

const BULLET := preload("res://bullet.tscn")

# Numele animațiilor, pe sferturi de cerc (vezi _update_anim).
const DIRECTII := ["east", "south", "west", "north"]  # 0=dreapta 1=jos 2=stânga 3=sus

@export var speed: float = 300.0
@export var fire_interval: float = 0.5

@export var max_hp: int = 100
@export var contact_range: float = 60.0
@export var contact_damage: int = 5
@export var damage_interval: float = 0.5
var hp: int

var ultima_directie := "south"  # ultima direcție în care s-a uitat (pentru poza de stat pe loc)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	anim.play("idle_south")  # pornim stând pe loc, uitându-ne în jos
	var fire_timer := Timer.new()
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_fire)
	add_child(fire_timer)
	fire_timer.start()
	var damage_timer := Timer.new()
	damage_timer.wait_time = damage_interval
	damage_timer.timeout.connect(_take_contact_damage)
	add_child(damage_timer)
	damage_timer.start()

func _physics_process(delta: float) -> void:
	var directie := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = directie * speed
	move_and_slide()
	if directie != Vector2.ZERO:
		_update_anim(directie)
	else:
		anim.play("idle_" + ultima_directie)  # stă pe loc: poza statică pe ultima direcție

func _update_anim(directie: Vector2) -> void:
	# angle() dă unghiul în radiani (0 = dreapta, crește în sensul acelor de ceas).
	# Împărțim la 90° (PI/2) și rotunjim ca să aflam în care din cele 4 sferturi suntem.
	var cadran := wrapi(int(round(directie.angle() / (PI / 2.0))), 0, 4)
	ultima_directie = DIRECTII[cadran]
	anim.play(ultima_directie)  # dacă e deja aceeași animație, doar continuă/reia

func _fire() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var bullet := BULLET.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = (target.global_position - global_position).normalized()

func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var min_dist := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < min_dist:
			min_dist = d
			nearest = enemy
	return nearest

func _take_contact_damage() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) < contact_range:
			take_damage(contact_damage)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp = 0
		die()

func die() -> void:
	get_tree().reload_current_scene()
