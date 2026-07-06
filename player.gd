extends CharacterBody2D

var bullet_scene: PackedScene = preload("res://bullet.tscn")  # glonțul curent (se schimbă la unele upgrade-uri)

# Numele animațiilor, pe sferturi de cerc (vezi _update_anim).
const DIRECTII := ["east", "south", "west", "north"]  # 0=dreapta 1=jos 2=stânga 3=sus

@export var speed: float = 300.0
@export var fire_interval: float = 0.5
@export var bullet_damage: int = 10        # cât rău fac gloanțele (crește la level up)
@export var bullet_speed: float = 700.0    # cât de repede zboară glonțul (crește la level up)

@export var max_hp: int = 100
@export var contact_range: float = 60.0
@export var contact_damage: int = 5
@export var damage_interval: float = 0.5
@export var hp_regen: int = 0              # HP regenerat pe secundă (crește la level up)
var hp: int

# --- XP / nivel ---
@export var xp_to_next: int = 20  # cât XP îți trebuie pentru nivelul următor
var xp: int = 0
var level: int = 1
var dead := false  # ca să nu declanșăm Game Over de mai multe ori

var ultima_directie := "south"  # ultima direcție în care s-a uitat (pentru poza de stat pe loc)
var fire_timer: Timer           # îl ținem ca variabilă ca să-i putem schimba viteza la level up

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	anim.play("idle_south")  # pornim stând pe loc, uitându-ne în jos
	fire_timer = Timer.new()
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_fire)
	add_child(fire_timer)
	fire_timer.start()
	var damage_timer := Timer.new()
	damage_timer.wait_time = damage_interval
	damage_timer.timeout.connect(_take_contact_damage)
	add_child(damage_timer)
	damage_timer.start()
	# timer de regenerare: la fiecare secundă adaugă hp_regen (0 până iei upgrade-ul)
	var regen_timer := Timer.new()
	regen_timer.wait_time = 1.0
	regen_timer.timeout.connect(_regen)
	add_child(regen_timer)
	regen_timer.start()

func _physics_process(delta: float) -> void:
	var directie := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = directie * speed
	move_and_slide()
	if directie != Vector2.ZERO:
		_update_anim(directie)
	else:
		anim.play("idle_" + ultima_directie)  # stă pe loc: poza statică pe ultima direcție

func _update_anim(directie: Vector2) -> void:
	var cadran := wrapi(int(round(directie.angle() / (PI / 2.0))), 0, 4)
	ultima_directie = DIRECTII[cadran]
	anim.play(ultima_directie)

func _fire() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var bullet := bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.damage = bullet_damage  # glonțul face cât damage are player-ul acum
	bullet.speed = bullet_speed    # și zboară cu viteza curentă a player-ului
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

func _regen() -> void:
	if hp_regen > 0 and hp > 0:
		hp = min(max_hp, hp + hp_regen)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp = 0
		die()

func die() -> void:
	if dead:
		return
	dead = true
	var screen := get_tree().get_first_node_in_group("gameover_screen")
	if screen != null:
		screen.show_gameover(Difficulty.time, level)
	else:
		get_tree().reload_current_scene()  # fallback dacă n-ai adăugat încă ecranul de Game Over

func gain_xp(amount: int) -> void:
	xp += amount
	# while (nu if) ca să prindem și cazul în care un salt mare de XP trece peste mai multe niveluri
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()

func _level_up() -> void:
	level += 1
	xp_to_next = int(xp_to_next * 1.2)  # pragul crește cu 20% la fiecare nivel
	var menu := get_tree().get_first_node_in_group("levelup_menu")
	if menu != null:
		menu.open()

# --- îmbunătățiri aplicate de ecranul de level up ---
func upgrade_max_hp(amount: int) -> void:
	max_hp += amount
	hp += amount  # te și vindecă cu cât ai crescut viața maximă

func upgrade_fire_rate(factor: float) -> void:
	fire_interval *= factor              # factor < 1 → pauză mai mică între trageri = tragi mai des
	fire_timer.wait_time = fire_interval
