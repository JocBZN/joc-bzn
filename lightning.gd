extends Area2D

# Bilă de lightning aruncată de boss-ul „Garda" spre player. Zboară drept pe direcția
# dată la lansare și face damage când atinge player-ul. Hitbox = cerc (în lightning.tscn).

const FRAME_DIR := "res://boss/lightning_burst_003_large_violet/"
const FRAME_COUNT := 10  # frame0000.png … frame0009.png

@export var speed: float = 340.0
@export var damage: int = 15
@export var lifetime: float = 3.0     # după atâtea secunde dispare (dacă nu lovește nimic)
@export var anim_fps: float = 8.0     # mai mic = cadrele se mișcă mai greu (animația se vede mai bine)
# Colorizare: valori PESTE 1 fac bila mai luminoasă → iese în evidență (și „strălucește" cu glow-ul din atmosphere.gd)
@export var tint: Color = Color(1.9, 1.5, 2.4)

var direction: Vector2 = Vector2.RIGHT
var _time_left: float

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_time_left = lifetime
	_build_frames()
	anim.modulate = tint  # colorizare/luminozitate ca să se vadă mai bine
	anim.play("default")
	body_entered.connect(_on_body_entered)

func set_direction(new_dir: Vector2) -> void:
	direction = new_dir.normalized()

func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", anim_fps)
	frames.set_animation_loop("default", true)
	for i in FRAME_COUNT:
		var tex := load("%sframe%04d.png" % [FRAME_DIR, i]) as Texture2D
		if tex != null:
			frames.add_frame("default", tex)
	if frames.get_frame_count("default") == 0:
		push_warning("Lightning: cadrele nu-s importate încă — deschide o dată proiectul în Godot.")
	anim.sprite_frames = frames

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# lovește DOAR player-ul (trece prin garda care a aruncat-o, prin copaci etc.)
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
