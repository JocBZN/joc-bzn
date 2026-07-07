extends Node2D

# Băltoacă de foc lăsată de player când merge (upgrade Firewalker).
# Joacă animația de foc (4 cadre din spritesheet), face damage inamicilor care o ating,
# apoi se stinge după `duration` secunde. `duration` crește cu fiecare upgrade luat.

const FIRE_DIR := "res://Upgrades/firewalker anim/"
const FIRE_FRAME_COUNT := 4
const VISUAL_OFFSET := Vector2(0, 62)  # vizualul (și zona de damage) coborâte la picioarele player-ului

# setate de player ÎNAINTE de add_child (ca _ready să le folosească)
var duration: float = 1.0     # cât rămâne pe jos (secunde)
var damage: int = 5           # damage pe tick
var size: float = 80.0        # lățimea focului în px (crește cu fiecare upgrade)
var tick_interval: float = 0.4  # cât de des face damage
var radius: float = 32.0      # raza de damage (derivată din `size` în _ready)
var direction: Vector2 = Vector2.LEFT  # direcția de mers a player-ului (vestul = fără rotire)

static var _frames: SpriteFrames  # cadrele, construite o singură dată și refolosite

func _ready() -> void:
	z_index = -1  # mereu SUB actori (player/inamici), dar peste teren (care e la -10)
	radius = size * 0.4  # zona de damage ≈ din lățimea focului
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = _get_frames()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.scale = Vector2.ONE * (size / 32.0)  # scalăm cadrul (32px lățime) la `size` px
	anim.position = VISUAL_OFFSET  # coborâm vizualul la picioare (nodul e putin deasupra, pt. y-sort → foc în spate)
	# cadrele au fața spre VEST (unghi PI); le rotim să arate în direcția de mers
	anim.rotation = direction.angle() - PI
	anim.play("default")
	add_child(anim)

	# damage periodic cât timp focul e activ
	var t := Timer.new()
	t.wait_time = tick_interval
	t.timeout.connect(_burn)
	add_child(t)
	t.start()

	# ține `duration` secunde, apoi se stinge lin și dispare
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(anim, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

func _get_frames() -> SpriteFrames:
	if _frames != null and _frames.get_frame_count("default") > 0:
		return _frames
	_frames = SpriteFrames.new()
	_frames.set_animation_speed("default", 10.0)
	_frames.set_animation_loop("default", true)
	for i in FIRE_FRAME_COUNT:
		var tex := load("%sfirewalker_%d.png" % [FIRE_DIR, i]) as Texture2D
		if tex != null:
			_frames.add_frame("default", tex)
	return _frames

func _burn() -> void:
	var center := global_position + VISUAL_OFFSET  # zona de damage e pe flacără, nu pe nod
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if center.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(damage)
