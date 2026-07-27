extends Area2D

# CHEIA de cufăr, căzută de la un inamic mort (0.5% — vezi `enemy.gd::_drop_xp`).
# Se ridică mergând peste ea, exact ca gemele de XP, și intră în `GameSettings.run_keys`.
# O cheie = un cufăr (`chest.gd`).
#
# E o variantă mult mai simplă decât `xp.gd`: acolo există contopirea în bule, fiindcă în
# Final Swarm cad mii de geme. Aici cade una la ~200 de morți, deci nu se strâng niciodată
# grămadă și n-au de ce să se contopească.

@export var magnet_range: float = 150.0   # de la ce distanță zboară spre player (puțin peste XP,
                                          # ca o cheie rară să nu-ți scape pe lângă picior)
@export var magnet_speed: float = 420.0

var _time := 0.0
var _base_scale: Vector2
var _luata := false
var _player: Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("key")
	body_entered.connect(_on_body_entered)
	_base_scale = sprite.scale
	_time = randf() * TAU   # ca două chei căzute odată să nu pulseze identic

func _physics_process(delta: float) -> void:
	if _luata:
		return
	# aceeași animație „vie" ca la XP: pulsează ușor și plutește sus-jos
	_time += delta
	sprite.scale = _base_scale * (1.0 + 0.12 * sin(_time * 5.0))
	sprite.position.y = -5.0 * absf(sin(_time * 3.0))
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and global_position.distance_to(_player.global_position) < magnet_range:
		global_position += (_player.global_position - global_position).normalized() * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
	if _luata or not body.is_in_group("player"):
		return
	_luata = true
	remove_from_group("key")
	GameSettings.add_key()
	Audio.play("xp", -3.0)   # același blip ca la XP, dar mai tare: e un obiect rar
	var t := create_tween()
	t.tween_property(sprite, "scale", _base_scale * 1.7, 0.08)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)
