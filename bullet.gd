extends Area2D

@export var speed: float = 700.0
@export var damage: int = 10
@export var lifetime: float = 2.0

# --- setate de player la tragere (upgrade-uri de armă) ---
var pierce: int = 0        # prin câți inamici trece înainte să dispară (0 = se oprește la primul)
var knockback: float = 0.0 # cât de tare împinge inamicul înapoi
var is_crit: bool = false  # dacă lovitura e critică (pentru numărul galben)

var direction: Vector2 = Vector2.RIGHT
var time_left: float
var _hits: int = 0         # câți inamici a lovit deja

func _ready() -> void:
	time_left = lifetime
	body_entered.connect(_on_body_entered)

# Sprite-ul glonțului e desenat cu vârful spre NORD (sus). Îl rotim ca vârful să
# arate spre direcția de zbor (spre inamic). +PI/2 fiindcă „sus" înseamnă -90° față de axa X.
func set_direction(new_dir: Vector2) -> void:
	direction = new_dir
	rotation = new_dir.angle() + PI / 2.0

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	time_left -= delta
	if time_left <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(damage)
		# efecte la lovitură: scântei + număr de damage (crit = galben mare)
		var col := Color(1.0, 0.85, 0.2) if is_crit else Color(0.6, 1.0, 1.0)
		Fx.impact(global_position, col)
		Fx.damage_number(global_position, damage, is_crit)
		# împinge inamicul înapoi, dacă avem knockback
		if knockback > 0.0 and body.has_method("apply_knockback"):
			body.apply_knockback(direction * knockback)
		# străpungere: dispare doar după ce a lovit (pierce + 1) inamici
		_hits += 1
		if _hits > pierce:
			queue_free()
