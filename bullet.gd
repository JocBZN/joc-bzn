extends Area2D

const BOOM_VISUAL_SCALE := 1.3 / 3.0  # doar vizualul exploziei mage; raza de damage rămâne neschimbată

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
var instakill_chance: float = 0.0  # șansa (0..1) să ucidă instant inamicul (Hacksaw)
var thunder: bool = false          # Thunder God: la impact, curent electric spre inamicii din jur

var direction: Vector2 = Vector2.RIGHT
var time_left: float
var _hits: int = 0         # câți inamici a lovit deja

# --- URMARIRE (homing) ---
# Inainte, glontul pleca in linie dreapta spre unde ERA inamicul in clipa tragerii. Cu multe
# proiectile bonus (Gunslinger / Twin Comets / Broken Watch), fiecare pleaca spre alt inamic
# aflat departe, care intre timp se misca -> majoritatea treceau pe langa. Acum se corecteaza
# in zbor spre tinta, cu o viteza de rotire limitata (nu e teleghidat perfect).
@export var homing_turn: float = 8.0   # rad/s; 0 = zboara drept, ca inainte. 8 = 85% rata de lovire (masurat)
var target: Node2D = null              # pus de player la tragere
var _retarget_in: float = 0.0
const RETARGET_EVERY := 0.2            # cat de rar cauta o tinta noua, daca a ramas fara
const RETARGET_RANGE_SQ := 700.0 * 700.0

func _ready() -> void:
	time_left = lifetime
	body_entered.connect(_on_body_entered)

# Sprite-ul glonțului e desenat cu vârful spre NORD (sus). Îl rotim ca vârful să
# arate spre direcția de zbor (spre inamic). +PI/2 fiindcă „sus" înseamnă -90° față de axa X.
func set_direction(new_dir: Vector2) -> void:
	direction = new_dir
	rotation = new_dir.angle() + PI / 2.0

func _physics_process(delta: float) -> void:
	if homing_turn > 0.0:
		_update_target(delta)
		if target != null:
			var spre := target.global_position - global_position
			# Tintim UNDE VA FI inamicul cand ajungem la el, nu unde e ACUM. Fara asta glontul
			# ramane mereu in urma unei tinte care se misca, o rateaza la limita si apoi se
			# invarte in jurul ei: raza lui de viraj (speed / homing_turn) e mai mare decat
			# distanta la care trece pe langa, deci nu mai poate intoarce destul de strans.
			# (Masurat: cu urmarire „naiva" rata de lovire cadea la 0%.)
			var v: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
			var aim := spre + v * (spre.length() / maxf(speed, 1.0))
			# Daca tinta a ramas in SPATE, zburam mai departe drept. Un glont care se intoarce
			# dupa ea ar orbita la nesfarsit; asa trece pe langa si isi cauta alta tinta in fata.
			if aim.length_squared() > 1.0 and aim.dot(direction) > 0.0:
				var da := direction.angle_to(aim.normalized())
				var max_turn := homing_turn * delta
				direction = direction.rotated(clampf(da, -max_turn, max_turn)).normalized()
				rotation = direction.angle() + PI / 2.0
	global_position += direction * speed * delta
	time_left -= delta
	if time_left <= 0:
		queue_free()

# Tinta traieste? Daca nu, cauta alta - dar RAR (o data la RETARGET_EVERY) si doar in fata,
# ca sa nu se intoarca din drum si ca sa nu scanam grupul de inamici la fiecare cadru:
# in Final Swarm sunt sute de gloante vii si sute de inamici (vezi pass-ul de performanta).
func _update_target(delta: float) -> void:
	if target != null and is_instance_valid(target) and not target.is_queued_for_deletion():
		return
	target = null
	_retarget_in -= delta
	if _retarget_in > 0.0:
		return
	_retarget_in = RETARGET_EVERY
	var best: Node2D = null
	var best_d2 := RETARGET_RANGE_SQ
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en == null or en.is_queued_for_deletion():
			continue
		var spre := en.global_position - global_position
		if spre.dot(direction) <= 0.0:
			continue          # e in spate; nu ne intoarcem dupa el
		var d2 := spre.length_squared()
		if d2 < best_d2:
			best_d2 = d2
			best = en
	target = best

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		# Hacksaw: șansă să ucidă instant inamicul (îi scoatem toată viața dintr-o lovitură)
		var kill := instakill_chance > 0.0 and randf() < instakill_chance
		var dealt := damage
		if kill:
			dealt = int(body.hp) if "hp" in body else 999999
		body.take_damage(dealt)
		# efecte la lovitură: scântei + număr de damage (crit = galben mare; instakill = roșu mare)
		var col := Color(1.0, 0.2, 0.2) if kill else (Color(1.0, 0.85, 0.2) if is_crit else Color(0.6, 1.0, 1.0))
		Fx.impact(global_position, col)
		Fx.damage_number(global_position, dealt, is_crit or kill)
		# Thunder God: curent electric de la inamicul lovit spre toți ceilalți din rază.
		# Amânat (call_deferred) fiindcă suntem în callback-ul de coliziune (pas de fizică) — a omorî
		# vecinii aici strică starea („Can't change this state while flushing queries").
		if thunder:
			var pl := get_tree().get_first_node_in_group("player")
			if pl != null and pl.has_method("thunder_burst_maybe"):
				pl.call_deferred("thunder_burst_maybe", global_position, body.get_instance_id())
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
			# Explozia NU mai sufla inamicii (cerut de Razvan pe 2026-07-21): ii imprastia
			# tocmai din gramada in care abia ii adunasesi, iar gloantele trase dupa ea
			# ramaneau fara tinta. Knockback-ul de la GLONT (Knockback Stick) ramane.

# Explozie animată (ex. violet pentru mage). Adăugată în lume, scalată la rază; se auto-distruge.
func _play_boom() -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = explosion_frames
	a.animation = "fx"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.z_index = 60
	var fw := explosion_frames.get_frame_texture("fx", 0).get_width()
	a.scale = Vector2.ONE * (explosion_radius * 2.0 * BOOM_VISUAL_SCALE) / float(max(fw, 1))
	get_parent().add_child(a)
	a.global_position = global_position
	a.play("fx")
	a.animation_finished.connect(a.queue_free)
