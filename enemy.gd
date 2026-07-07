extends CharacterBody2D

# Numele animațiilor pe octanți (după unghi), în ordinea 0=est, apoi din 45° în 45°.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 120.0
@export var max_hp: int = 30
@export var knockback_decay: float = 900.0  # cât de repede se stinge împinsul (px/s pe secundă)
var hp: int
var _dying := false
var _knockback := Vector2.ZERO  # împins temporar de gloanțe
var _flash_tween: Tween

# Scenele de XP (le încărcăm doar dacă există deja, ca să nu dea eroare)
var _xp1: PackedScene
var _xp2: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Devine mai puternic cu cât dificultatea a crescut (setat la nașterea fiecărui inamic)
	max_hp = int(max_hp * Difficulty.enemy_hp_mult())
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")
	if ResourceLoader.exists("res://xp2.tscn"):
		_xp2 = load("res://xp2.tscn")

func _physics_process(delta: float) -> void:
	if _dying:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var directie := (player.global_position - global_position).normalized()
	velocity = directie * speed + _knockback  # mers spre player + eventualul împins de la gloanțe
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)  # împinsul scade rapid la 0
	# angle() = unghiul spre player (0 = est, crește în sensul acelor de ceas) → octant 0..7
	var idx := wrapi(int(round(directie.angle() / (PI / 4.0))), 0, 8)
	anim.play(DIRECTII[idx])

# Chemată de glonț când are knockback: împinge inamicul pe direcția glonțului.
func apply_knockback(v: Vector2) -> void:
	_knockback = v

func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		Audio.play("hit", -8.0)  # lovitură (scurt, mai încet — se aude des)
		_flash()  # sclipire albă scurtă la fiecare lovitură

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(5, 5, 5)  # alb foarte strălucitor
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.12)

func _die() -> void:
	_dying = true
	Audio.play("enemy_die", -5.0)  # inamic mort
	remove_from_group("enemy")  # nu mai e țintă și nu mai face damage cât se stinge
	_drop_xp()
	# animație de moarte: se umflă și se stinge, apoi dispare
	var t := create_tween()
	t.tween_property(anim, "scale", anim.scale * 1.4, 0.1)
	t.parallel().tween_property(anim, "modulate:a", 0.0, 0.14)
	t.tween_callback(queue_free)

func _drop_xp() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# XP normal (valoare de bază 1), înmulțit cu dificultatea → intake mai mare cu timpul
	if _xp1 != null:
		var gem := _xp1.instantiate()
		gem.value = int(round(gem.value * Difficulty.xp_mult()))
		parent.add_child(gem)
		gem.global_position = global_position
	# XP rar (valoare de bază 10 = de 10× cât XP1), tot scalat cu dificultatea; 5% doar la dificultate mare
	if _xp2 != null and Difficulty.xp2_unlocked() and randf() < 0.05:
		var rare := _xp2.instantiate()
		rare.value = int(round(rare.value * Difficulty.xp_mult()))
		parent.add_child(rare)
		rare.global_position = global_position + Vector2(20, 0)
