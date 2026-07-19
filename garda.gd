extends CharacterBody2D

# „Garda" — inamic-boss invocat DOAR de statuie (butonul Summon). Vezi statue.gd.
# Cât iese din pământ (înghețat de statue.gd) arată cadrul static „summon" (garda_0.png).
# După ce pornește, joacă animația de MERS pe 8 direcții, aleasă după unghiul spre player.

const FRAME_DIR := "res://boss/"
const SUMMON_TEX := "res://boss/garda_0.png"  # poza statică, doar pentru momentul invocării
# Numele animațiilor pe octanți (după unghi), în ordinea 0=est, apoi din 45° în 45° — ca la enemy.gd.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 70.0        # mai lent decât inamicul normal (boss greoi)
@export var max_hp: int = 300          # mult mai rezistent
@export var anim_fps: float = 10.0     # viteza animației de mers
@export var xp_value: int = 50         # cât XP lasă când moare (boss → mult)

# --- Atac de la distanță: aruncă o bilă de lightning ---
@export var attack_range: float = 420.0    # de la ce distanță aruncă („nu foarte mare")
@export var attack_interval: float = 2.0   # pauza între aruncări (secunde)
@export var lightning_damage: int = 15     # cât rău face bila
@export var lightning_speed: float = 340.0 # cât de repede zboară bila

# --- Atac special: o dată la 10s aruncă atacul normal de 3 ori la rând, foarte rapid ---
@export var special_interval: float = 10.0  # o dată la câte secunde
@export var special_shots: int = 3          # câte bile aruncă în rafală
@export var special_gap: float = 0.12       # pauza ÎNTRE bilele rafalei (mic = rafală strânsă)

const LIGHTNING := preload("res://lightning.tscn")
var _atk_cooldown := 0.0
var _special_cooldown := 0.0
# Rafala e derulată din `_physics_process` cu un contor, NU cu `await`: dacă garda moare în mijlocul
# rafalei, o corutină și-ar relua firul pe un nod deja eliberat. Contorul dispare odată cu nodul.
var _burst_left := 0
var _burst_timer := 0.0

var hp: int
var _dying := false
var _flash_tween: Tween

var _xp1: PackedScene
var _xp2: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# se întărește cu dificultatea, exact ca inamicul normal
	max_hp = int(max_hp * Difficulty.enemy_hp_mult())
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")  # ca gloanțele să-l lovească și să facă damage la contact
	_build_frames()
	anim.play("summon")  # cadrul static cât iese din pământ (statue.gd îl ține pe loc)
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")
	if ResourceLoader.exists("res://xp2.tscn"):
		_xp2 = load("res://xp2.tscn")

# Construim animațiile din PNG-uri (încărcate la RULARE, ca restul artei noi):
#  - „summon" = un singur cadru (garda_0),
#  - câte o animație de mers pentru fiecare din cele 8 direcții (walk_<dir>_<i>.png).
func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	frames.add_animation("summon")
	frames.set_animation_loop("summon", false)
	var st := load(SUMMON_TEX) as Texture2D
	if st != null:
		frames.add_frame("summon", st)

	for d in DIRECTII:
		frames.add_animation(d)
		frames.set_animation_speed(d, anim_fps)
		frames.set_animation_loop(d, true)
		var i := 0
		while true:
			var path := "%swalk_%s_%d.png" % [FRAME_DIR, d, i]
			if not ResourceLoader.exists(path):
				break
			var tex := load(path) as Texture2D
			if tex == null:
				break
			frames.add_frame(d, tex)
			i += 1

	anim.sprite_frames = frames

func _physics_process(delta: float) -> void:
	if _dying:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	# unghiul spre player → octant 0..7 → animația de mers pe direcția aia
	var idx := wrapi(int(round(dir.angle() / (PI / 4.0))), 0, 8)
	anim.play(DIRECTII[idx])
	var in_range := global_position.distance_to(player.global_position) <= attack_range
	_atk_cooldown -= delta
	_special_cooldown -= delta

	# Rafala în curs: scoate bilele una după alta. Ținta se recitește la fiecare bilă (`player` e
	# proaspăt în fiecare cadru), deci rafala te urmărește dacă fugi — nu pleacă toate în același loc.
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire_lightning(player)
			_burst_left -= 1
			_burst_timer = special_gap
		return  # cât ține rafala, atacul normal tace

	# Atacul special: o dată la `special_interval`, dacă e în rază.
	if _special_cooldown <= 0.0 and in_range:
		_burst_left = special_shots
		_burst_timer = 0.0                 # prima bilă pleacă imediat
		_special_cooldown = special_interval
		# ca atacul normal să nu se lipească de coada rafalei
		_atk_cooldown = maxf(_atk_cooldown, special_shots * special_gap + attack_interval * 0.5)
		return

	# Atacul normal: o bilă când cooldown-ul e gata.
	if _atk_cooldown <= 0.0 and in_range:
		_fire_lightning(player)
		_atk_cooldown = attack_interval

func _fire_lightning(player: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dir := (player.global_position - global_position).normalized()
	var proj := LIGHTNING.instantiate()
	parent.add_child(proj)
	proj.global_position = global_position + dir * 80.0  # pornește puțin în fața gărzii
	proj.damage = lightning_damage
	proj.speed = lightning_speed
	proj.set_direction(dir)

func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		_flash()  # sclipire albă scurtă la fiecare lovitură

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(5, 5, 5)  # alb foarte strălucitor
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.12)

func _die() -> void:
	_dying = true
	GameSettings.add_kill()  # bossul se numără și el la kill count
	remove_from_group("enemy")
	_drop_xp.call_deferred()  # vezi enemy.gd: Area2D nou nu se poate adăuga în timpul fizicii
	var t := create_tween()
	t.tween_property(anim, "scale", anim.scale * 1.4, 0.1)
	t.parallel().tween_property(anim, "modulate:a", 0.0, 0.14)
	t.tween_callback(queue_free)

func _drop_xp() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if _xp1 != null:
		var gem := _xp1.instantiate()
		gem.value = int(round(xp_value * Difficulty.xp_mult()))
		parent.add_child(gem)
		gem.global_position = global_position
