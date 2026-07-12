extends Area2D

const EXPLOSION_KNOCKBACK := 500.0  # cât de tare suflă explozia inamicii în afară (Jean's Bomb)

@export var speed: float = 700.0
@export var damage: int = 10
@export var lifetime: float = 2.0

# --- setate de player la tragere (upgrade-uri de armă) ---
var pierce: int = 0        # prin câți inamici trece înainte să dispară (0 = se oprește la primul)
var knockback: float = 0.0 # cât de tare împinge inamicul înapoi
var is_crit: bool = false  # dacă lovitura e critică (pentru numărul galben)
var explosion_radius: float = 0.0  # raza exploziei AOE la impact (0 = fără explozie) — Jean's Bomb
var explosion_damage: int = 0      # cât damage face explozia asupra inamicilor din rază
var explosion_frames: SpriteFrames = null  # animație de explozie (mage = violet); null → Fx.explosion

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
		# Jean's Bomb: explozie AOE la impact
		if explosion_radius > 0.0:
			_explode()
		# străpungere: dispare doar după ce a lovit (pierce + 1) inamici
		_hits += 1
		if _hits > pierce:
			queue_free()

# Explozie AOE (Jean's Bomb): animația de explozie + damage tuturor inamicilor din rază.
func _explode() -> void:
	if explosion_frames != null and explosion_frames.get_frame_count("fx") > 0:
		_play_boom()  # explozie animată (mage = violet)
	else:
		Fx.explosion(global_position, explosion_radius)
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.take_damage(explosion_damage)
			Fx.damage_number(enemy.global_position, explosion_damage)
			# suflă inamicul în afara exploziei → curăță spațiul din jurul player-ului
			if enemy.has_method("apply_knockback"):
				var push := (enemy.global_position - global_position).normalized()
				if push == Vector2.ZERO:
					push = Vector2.RIGHT  # inamic fix în centru: alegem o direcție oarecare
				enemy.apply_knockback(push * EXPLOSION_KNOCKBACK)

# Explozie animată (ex. violet pentru mage). Adăugată în lume, scalată la rază; se auto-distruge.
func _play_boom() -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = explosion_frames
	a.animation = "fx"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.z_index = 60
	var fw := explosion_frames.get_frame_texture("fx", 0).get_width()
	a.scale = Vector2.ONE * (explosion_radius * 2.0) / float(max(fw, 1))
	get_parent().add_child(a)
	a.global_position = global_position
	a.play("fx")
	a.animation_finished.connect(a.queue_free)
