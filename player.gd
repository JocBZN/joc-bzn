extends CharacterBody2D

var bullet_scene: PackedScene = preload("res://bullet.tscn")  # glonțul curent (se schimbă la unele upgrade-uri)
const FIRE_TRAIL := preload("res://firetrail.gd")  # băltoaca de foc lăsată de Firewalker

# Numele animațiilor, pe optimi de cerc (vezi _update_anim).
# Ordinea urmează unghiul crescător (y în jos): E, SE, S, SV, V, NV, N, NE.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 300.0
@export var fire_interval: float = 0.5
@export var bullet_damage: int = 10        # cât rău fac gloanțele (crește la level up)
@export var bullet_speed: float = 700.0    # cât de repede zboară glonțul (crește la level up)
@export var bullet_count: int = 1          # câte gloanțe paralele tragi odată (+1 la fiecare bonus)
@export var bullet_spacing: float = 26.0   # distanța dintre gloanțele paralele

# --- upgrade-uri de armă ---
@export var crit_chance: float = 0.0       # șansa (0..1) ca o lovitură să fie critică
@export var crit_mult: float = 2.0         # de câte ori mai mult damage la critic
@export var pierce: int = 0                # prin câți inamici trece glonțul
@export var bullet_scale: float = 1.0      # mărimea glonțului (1 = normal)
@export var knockback: float = 0.0         # cât împinge inamicul înapoi
@export var explosion_radius: float = 0.0  # raza exploziei AOE la impact (0 = fără) — Jean's Bomb
@export var explosion_damage: int = 0      # cât damage face explozia AOE
@export var fire_trail_time: float = 0.0   # cât rămâne dâra de foc pe jos (0 = fără) — Firewalker
@export var fire_trail_damage: int = 0     # damage pe tick al dârei de foc
@export var fire_trail_size: float = 0.0   # lățimea focului în px (crește cu fiecare upgrade)

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

# --- Screen shake (tremurat de cameră, ex. la lovitură critică) ---
@export var shake_decay: float = 4.0   # cât de repede se liniștește tremuratul
@export var shake_max: float = 16.0    # amplitudinea maximă (pixeli)
var _trauma: float = 0.0               # 0 = liniște, 1 = tremurat maxim
var _shaking: bool = false             # controlăm camera DOAR cât tremurăm (ca să nu ne batem cu statuia)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _cam: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	# arma de start aleasă din meniu (Choose Weapon)
	var chosen_weapon := load(GameSettings.weapon_path) as PackedScene
	if chosen_weapon != null:
		bullet_scene = chosen_weapon
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
	# timer pentru dâra de foc (Firewalker): lasă o băltoacă cât timp mergi
	var trail_timer := Timer.new()
	trail_timer.wait_time = 0.18
	trail_timer.timeout.connect(_drop_fire)
	add_child(trail_timer)
	trail_timer.start()

# Adaugă „traumă" (tremurat). Se cheamă de ex. la lovitură critică.
func add_shake(amount: float) -> void:
	_trauma = min(1.0, _trauma + amount)

func _process(delta: float) -> void:
	if _cam == null:
		return
	if _trauma > 0.0:
		_shaking = true
		_trauma = max(0.0, _trauma - shake_decay * delta)
		var amt := _trauma * _trauma  # pătrat = tremurat mai natural (mai brusc, se stinge lin)
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_max * amt
	elif _shaking:
		_shaking = false
		_cam.offset = Vector2.ZERO  # gata tremuratul: readucem camera o dată, apoi n-o mai atingem

func _physics_process(delta: float) -> void:
	var directie := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = directie * speed
	move_and_slide()
	if directie != Vector2.ZERO:
		_update_anim(directie)
	else:
		var idle_nume := "idle_" + ultima_directie  # stă pe loc: poza statică pe ultima direcție
		if anim.animation != idle_nume:
			anim.play(idle_nume)

func _update_anim(directie: Vector2) -> void:
	var cadran := wrapi(int(round(directie.angle() / (PI / 4.0))), 0, 8)
	ultima_directie = DIRECTII[cadran]
	# Schimbăm animația DOAR când chiar diferă. Altfel, lângă granița dintre două
	# direcții (mai ales cu stick analog), play() ar reseta cadrul la 0 în fiecare
	# frame și animația de alergat ar părea înghețată.
	if anim.animation != ultima_directie:
		# păstrăm cadrul + progresul, ca pasul de alergare să curgă, nu să sară la 0
		# (toate animațiile de alergat au același număr de cadre)
		var cadru := anim.frame
		var progres := anim.frame_progress
		anim.play(ultima_directie)
		anim.set_frame_and_progress(cadru, progres)

func _fire() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var dir := (target.global_position - global_position).normalized()
	Audio.play("shoot", -6.0)  # sunet de tragere (puțin mai încet ca să nu obosească)
	Fx.muzzle(global_position + dir * 34.0)  # fulger la gura armei, spre inamic
	var perp := Vector2(-dir.y, dir.x)  # perpendicular pe direcție → gloanțele stau unul lângă altul (paralele)
	var any_crit := false
	for i in bullet_count:
		var offset := (i - (bullet_count - 1) / 2.0) * bullet_spacing  # centrate față de player
		var bullet := bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = global_position + perp * offset
		# critic: aruncăm zarul o dată per glonț; dacă iese, damage × crit_mult
		var is_crit := randf() < crit_chance
		if is_crit:
			any_crit = true
		bullet.damage = int(bullet_damage * crit_mult) if is_crit else bullet_damage
		bullet.is_crit = is_crit
		bullet.speed = bullet_speed    # zboară cu viteza curentă a player-ului
		bullet.pierce = pierce         # prin câți inamici trece
		bullet.knockback = knockback   # cât împinge inamicul
		bullet.explosion_radius = explosion_radius  # explozie AOE la impact (Jean's Bomb)
		bullet.explosion_damage = explosion_damage
		bullet.scale *= bullet_scale   # mărimea glonțului (sprite + hitbox)
		bullet.set_direction(dir)      # setează direcția ȘI rotește glonțul cu fața spre inamic
	if any_crit:
		add_shake(0.35)  # tremurat scurt la lovitură critică

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

# Firewalker: lasă o băltoacă de foc pe jos cât timp player-ul se mișcă.
func _drop_fire() -> void:
	if fire_trail_time <= 0.0 or velocity.length() < 5.0:
		return
	var patch := FIRE_TRAIL.new()
	patch.duration = fire_trail_time     # cât rămâne (crește cu fiecare upgrade)
	patch.damage = fire_trail_damage
	patch.size = fire_trail_size         # mărimea (crește cu fiecare upgrade)
	patch.direction = velocity.normalized()  # focul se orientează în direcția de mers
	get_parent().add_child(patch)        # în World (y-sort). Nodul e putin DEASUPRA player-ului →
	patch.global_position = global_position - Vector2(0, 4)  # e desenat în SPATE, iar vizualul e coborât la picioare în firetrail.gd

func take_damage(amount: int) -> void:
	hp -= amount
	Audio.play("hurt", -3.0)  # player lovit
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
	Audio.play("levelup")  # jingle de nivel nou
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
