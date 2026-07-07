extends Area2D

# Glob de XP care stă pe jos. Are viață: pulsează + plutește, e atras spre player
# când se apropie (magnet), și face un mic "pop" când e adunat.

@export var value: int = 1
@export var magnet_range: float = 130.0   # de la ce distanță începe să fie atras spre player
@export var magnet_speed: float = 420.0   # cât de repede zboară spre player

var _time := 0.0
var _base_scale: Vector2
var _collected := false
var _player: Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_scale = sprite.scale
	_time = randf() * TAU   # faze diferite, ca să nu pulseze toate la fel

func _physics_process(delta: float) -> void:
	if _collected:
		return
	# animație idle: pulsează ușor + plutește sus-jos
	_time += delta
	sprite.scale = _base_scale * (1.0 + 0.12 * sin(_time * 5.0))
	sprite.position.y = -5.0 * absf(sin(_time * 3.0))
	# magnet: dacă player-ul e aproape, zboară spre el
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		if global_position.distance_to(_player.global_position) < magnet_range:
			var dir := (_player.global_position - global_position).normalized()
			global_position += dir * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collected = true
		Audio.play("xp", -6.0)  # blip la adunat XP
		body.gain_xp(value)
		_pop()

func _pop() -> void:
	# efect la colectare: crește rapid și se stinge, apoi dispare
	var t := create_tween()
	t.tween_property(sprite, "scale", _base_scale * 1.7, 0.08)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)
