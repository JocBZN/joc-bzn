extends CharacterBody2D

var bullet_scene: PackedScene = preload("res://bullet.tscn")  # glonțul curent (se schimbă la unele upgrade-uri)
const FIRE_TRAIL := preload("res://firetrail.gd")  # băltoaca de foc lăsată de Firewalker
const ICE_TRAIL := preload("res://icetrail.gd")    # dâra de gheață lăsată de Frostwalker
const GOD_TRAIL := preload("res://godtrail.gd")    # dâra combinată (Firewalker + Frostwalker = Godwalker)

# Numele animațiilor, pe optimi de cerc (vezi _update_anim).
# Ordinea urmează unghiul crescător (y în jos): E, SE, S, SV, V, NV, N, NE.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 300.0
@export var fire_interval: float = 0.5
@export var bullet_damage: int = 10        # cât rău fac gloanțele (crește la level up)
@export var bullet_speed: float = 700.0    # cât de repede zboară glonțul (crește la level up)
@export var bullet_count: int = 1          # câte gloanțe paralele tragi odată (+1 la fiecare bonus)
@export var bullet_spacing: float = 26.0   # distanța dintre gloanțele paralele

# --- tipul de armă (ales din meniu: pistol / mage / extinguisher) ---
var weapon_type: String = "pistol"
# Stingător = AURĂ: pulsează în jurul tău, mai mare cu nivelul, mai des cu cadența
@export var aura_base_radius: float = 90.0
@export var aura_growth: float = 12.0      # cât crește raza pe nivel
@export var aura_damage: int = 6           # damage pe puls de aură
var _aura_tex: Texture2D
var _foam_frames: SpriteFrames  # animația de spumă (rândul 6 din stingator_effects.png)
var _muzzle_frames: SpriteFrames     # fulger la țeavă (pistol/mage)
var _mage_boom_frames: SpriteFrames  # explozie violet la impact (mage staff)
var _mage_orb_frames: SpriteFrames   # sfera magică (proiectilul mage)
@export var muzzle_scale: float = 1.2

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
@export var frost_trail_time: float = 0.0  # cât rămâne dâra de gheață pe jos (0 = fără) — Frostwalker
@export var frost_trail_damage: int = 0    # damage pe tick al gheții (≈ jumătate din foc)
@export var frost_trail_size: float = 0.0  # lățimea gheții în px (crește cu fiecare upgrade)
@export var frost_slow_time: float = 0.0   # cât timp stă înghețat inamicul (hold), +0.5s pe upgrade — Frostwalker

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
var xp_gain_mult := 1.0  # multiplicator XP primit (din meta-progresie)
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
	# arma aleasă din meniu (pistol / mage / extinguisher)
	weapon_type = GameSettings.weapon_type
	_apply_meta()  # upgrade-uri permanente cumpărate din meniu (meta-progresie)
	_aura_tex = _make_radial_texture()   # fallback vizual pentru aura stingătorului
	_foam_frames = _build_foam_frames()  # animația de spumă (rândul 6 din stingator_effects.png)
	_muzzle_frames = _load_fx_frames("res://fx/muzzle", 26.0, false)
	_mage_boom_frames = _load_fx_frames("res://fx/mage_boom", 24.0, false)
	_mage_orb_frames = _load_fx_frames("res://fx/mage_orb", 18.0, true)  # loop = proiectil continuu
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
	# timer pentru dâra de gheață (Frostwalker): lasă gheață cât timp mergi
	var ice_timer := Timer.new()
	ice_timer.wait_time = 0.18
	ice_timer.timeout.connect(_drop_ice)
	add_child(ice_timer)
	ice_timer.start()

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

# dispecer de tragere: fiecare tick face altceva după arma aleasă
func _fire() -> void:
	if weapon_type == "extinguisher":
		_aura_pulse()      # stingătorul nu trage gloanțe, ci pulsează o aură
	else:
		_fire_bullets()    # pistol / mage

# Pistol (simplu) și Mage Staff (AOE) trag gloanțe spre cel mai apropiat inamic.
func _fire_bullets() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var dir := (target.global_position - global_position).normalized()
	Audio.play("shoot", -6.0)
	_muzzle(global_position + dir * 34.0, dir)
	# Mage Staff: fiecare glonț explodează AOE la impact (peste eventualul Jean's Bomb)
	var ex_radius := explosion_radius
	var ex_damage := explosion_damage
	if weapon_type == "mage":
		ex_radius = max(ex_radius, 110.0)
		ex_damage = max(ex_damage, int(bullet_damage * 0.6))
	var perp := Vector2(-dir.y, dir.x)
	var any_crit := false
	for i in bullet_count:
		var offset := (i - (bullet_count - 1) / 2.0) * bullet_spacing
		var bullet := bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = global_position + perp * offset
		var is_crit := randf() < crit_chance
		if is_crit:
			any_crit = true
		bullet.damage = int(bullet_damage * crit_mult) if is_crit else bullet_damage
		bullet.is_crit = is_crit
		bullet.speed = bullet_speed
		bullet.pierce = pierce
		bullet.knockback = knockback
		bullet.explosion_radius = ex_radius
		bullet.explosion_damage = ex_damage
		if weapon_type == "mage":
			bullet.explosion_frames = _mage_boom_frames  # explozie violet la impact
			_make_mage_orb(bullet)                       # proiectil = sferă magică animată
		bullet.scale *= bullet_scale
		bullet.set_direction(dir)
	if any_crit:
		add_shake(0.35)

# Stingător: aură care pulsează în jurul tău. Rază = bază + nivel × creștere;
# frecvența pulsului = fire_interval (scade cu upgrade-urile de cadență) → tot mai des.
func _aura_pulse() -> void:
	var radius := aura_base_radius + level * aura_growth
	var dmg := aura_damage + int(bullet_damage * 0.5)  # aura scalează și cu upgrade-urile de damage
	var hit := false
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(dmg)
			Fx.damage_number(enemy.global_position, dmg)
			if knockback > 0.0 and enemy.has_method("apply_knockback"):
				enemy.apply_knockback((enemy.global_position - global_position).normalized() * knockback)
			hit = true
	if hit:
		Audio.play("shoot", -12.0)  # foșnet slab (placeholder până ai sunet de spumă)
	_spawn_aura_ring(radius)

# Vizual placeholder al aurei: un nor bleu-alb care se extinde din player și se stinge.
func _spawn_aura_ring(radius: float) -> void:
	# preferăm animația de spumă (rândul 6); dacă nu e importată încă, cădem pe inelul gradient
	if _foam_frames != null and _foam_frames.get_frame_count("foam") > 0:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = _foam_frames
		a.animation = "foam"
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar
		a.modulate = Color(0.8, 0.95, 1.0, 0.9)  # ușor bleu, ca spuma
		a.z_index = -1  # sub player/inamici
		get_parent().add_child(a)
		a.global_position = global_position
		a.scale = Vector2.ONE * (radius * 2.0) / 64.0  # frame 64px → diametru = 2×rază
		a.play("foam")
		a.animation_finished.connect(a.queue_free)
		return
	# fallback: inel gradient (dacă frame-urile nu-s încă importate de Godot)
	if _aura_tex == null:
		return
	var s := Sprite2D.new()
	s.texture = _aura_tex
	s.modulate = Color(0.6, 0.9, 1.0, 0.5)
	s.z_index = -1
	get_parent().add_child(s)
	s.global_position = global_position
	var full := (radius * 2.0) / 256.0
	s.scale = Vector2.ONE * full * 0.25
	var t := create_tween()
	t.tween_property(s, "scale", Vector2.ONE * full, 0.28)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.32)
	t.tween_callback(s.queue_free)

# Construiește animația de spumă din cele 8 frame-uri tăiate (rândul 6 din stingator_effects.png).
func _build_foam_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if not sf.has_animation("foam"):
		sf.add_animation("foam")
	sf.set_animation_loop("foam", false)
	sf.set_animation_speed("foam", 20.0)  # 8 frame-uri la 20fps ≈ 0.4s
	for i in 8:
		var path := "res://stingator/foam_%d.png" % i
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				sf.add_frame("foam", tex)
	return sf

# --- efecte animate din gigapack (muzzle / explozie mage / sferă mage) ---
# Încarcă frame_0.png, frame_1.png ... dintr-un folder, într-o animație numită "fx".
func _load_fx_frames(dir: String, fps: float, loop: bool) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("fx")
	sf.set_animation_loop("fx", loop)
	sf.set_animation_speed("fx", fps)
	var i := 0
	while ResourceLoader.exists("%s/frame_%d.png" % [dir, i]):
		var tex := load("%s/frame_%d.png" % [dir, i]) as Texture2D
		if tex != null:
			sf.add_frame("fx", tex)
		i += 1
	return sf

# Joacă o animație one-shot în lume și o distruge la final.
func _play_effect(frames: SpriteFrames, pos: Vector2, sc: float, z: int, rot: float = 0.0) -> void:
	if frames == null or frames.get_frame_count("fx") == 0:
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.animation = "fx"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.z_index = z
	a.rotation = rot
	a.scale = Vector2.ONE * sc
	get_parent().add_child(a)
	a.global_position = pos
	a.play("fx")
	a.animation_finished.connect(a.queue_free)

# Fulger la țeavă: animația scifi dacă e importată, altfel fulgerul din cod (Fx).
func _muzzle(pos: Vector2, dir: Vector2) -> void:
	if _muzzle_frames != null and _muzzle_frames.get_frame_count("fx") > 0:
		_play_effect(_muzzle_frames, pos, muzzle_scale, 60, dir.angle())
	else:
		Fx.muzzle(pos)

# Înlocuiește vizualul glonțului mage cu sfera magică animată (loop).
func _make_mage_orb(bullet: Node) -> void:
	if _mage_orb_frames == null or _mage_orb_frames.get_frame_count("fx") == 0:
		bullet.modulate = Color(0.7, 0.5, 1.0)  # fallback mov dacă sfera nu e importată
		return
	var spr = bullet.get_node_or_null("Sprite2D")
	if spr != null:
		spr.visible = false  # ascundem glonțul normal
	var orb := AnimatedSprite2D.new()
	orb.sprite_frames = _mage_orb_frames
	orb.animation = "fx"
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	orb.scale = Vector2.ONE * 0.7
	bullet.add_child(orb)
	orb.play("fx")

# Textură rotundă moale (gradient radial) — placeholder pentru spumă/aură.
func _make_radial_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex

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
# Dacă are ȘI Frostwalker, nu lăsăm foc separat — combinația devine Godwalker (vezi _drop_ice).
func _drop_fire() -> void:
	if fire_trail_time <= 0.0 or frost_trail_time > 0.0 or velocity.length() < 5.0:
		return
	var patch := FIRE_TRAIL.new()
	patch.duration = fire_trail_time     # cât rămâne (crește cu fiecare upgrade)
	patch.damage = fire_trail_damage
	patch.size = fire_trail_size         # mărimea (crește cu fiecare upgrade)
	patch.direction = velocity.normalized()  # focul se orientează în direcția de mers
	get_parent().add_child(patch)        # în World (y-sort). Nodul e putin DEASUPRA player-ului →
	patch.global_position = global_position - Vector2(0, 4)  # e desenat în SPATE, iar vizualul e coborât la picioare în firetrail.gd

# Frostwalker: lasă o dâră de gheață pe jos cât timp player-ul se mișcă.
func _drop_ice() -> void:
	if frost_trail_time <= 0.0 or velocity.length() < 5.0:
		return
	# are ȘI Firewalker → lasă Godwalker (foc + gheață) în locul gheții simple
	if fire_trail_time > 0.0:
		_drop_god()
		return
	var patch := ICE_TRAIL.new()
	patch.duration = frost_trail_time    # cât rămâne (crește cu fiecare upgrade)
	patch.damage = frost_trail_damage
	patch.size = frost_trail_size        # mărimea (crește cu fiecare upgrade)
	patch.slow_hold = frost_slow_time    # cât timp înghețăm inamicul (crește cu fiecare upgrade)
	patch.direction = velocity.normalized()
	get_parent().add_child(patch)
	patch.global_position = global_position - Vector2(0, 4)

# Godwalker: dâra combinată când player-ul are ȘI Firewalker ȘI Frostwalker.
# Face damage-ul combinat (foc + gheață) ȘI încetinește inamicii; o singură animație.
func _drop_god() -> void:
	var patch := GOD_TRAIL.new()
	patch.duration = max(fire_trail_time, frost_trail_time)  # rămâne cât cea mai lungă
	patch.damage = fire_trail_damage + frost_trail_damage    # damage foc + gheață
	patch.size = max(fire_trail_size, frost_trail_size)      # cât cea mai mare
	patch.slow_hold = frost_slow_time                        # slow-ul de la Frostwalker
	patch.direction = velocity.normalized()
	get_parent().add_child(patch)
	patch.global_position = global_position - Vector2(0, 4)

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
	xp += int(amount * xp_gain_mult)
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

# Aplică upgrade-urile permanente (meta-progresie) la începutul rundei.
func _apply_meta() -> void:
	max_hp += GameSettings.level_of("hp") * 15
	bullet_damage += GameSettings.level_of("damage") * 3
	speed += GameSettings.level_of("speed") * 15.0
	fire_interval *= pow(0.96, GameSettings.level_of("firerate"))
	xp_gain_mult = 1.0 + GameSettings.level_of("xp") * 0.08
	hp_regen += GameSettings.level_of("regen") * 1
