extends CharacterBody2D

# Numele animațiilor pe octanți (după unghi), în ordinea 0=est, apoi din 45° în 45°.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 120.0
@export var max_hp: int = 30
@export var knockback_decay: float = 900.0  # cât de repede se stinge împinsul (px/s pe secundă)
var hp: int
var _dying := false
var _knockback := Vector2.ZERO  # împins temporar de gloanțe
var _flash_tween: Tween

# --- Slow de la Frostwalker (gheața lăsată de player) ---
const SLOW_MIN_MULT := 0.5    # viteza la slow MAXIM (0.5 = 50% din normal)
const SLOW_HOLD := 0.5        # secunde de slow MAXIM la început, după ce atinge gheața
const SLOW_RECOVER := 0.5     # cât durează revenirea lină la viteza normală după hold
const SLOW_TINT := Color(0.55, 0.75, 1.35)  # filtru albastru „înghețat" (modulate)
const ELECTRIC_TINT := Color(0.5, 0.85, 2.6)  # sclipire albastră electrică (Thunder God)
var _slow_time: float = 0.0   # timp rămas de slow (hold + recover); reîmprospătat cât stă în gheață

# --- Duridama: inamic „aurit" (upgrade_45) ---
# La 1% (× stack) când e lovit, inamicul devine AURIU: îngheață exact în cadrul în care a fost
# lovit (animație + mișcare oprite) și primește un filtru auriu. Lovitura care-l aurește NU-i
# scade viața — doar îl îngheață. URMĂTOAREA lovitură îl ucide instant și lasă 2× XP.
const GOLD_TINT := Color(2.2, 1.6, 0.25)   # filtru auriu (modulate multiplică, deci valori supraunitare)
var golden := false
var _xp_bonus := 1.0          # cât XP lasă la moarte (2.0 la moartea aurită)

# Scenele de XP (le încărcăm doar dacă există deja, ca să nu dea eroare)
var _xp1: PackedScene
var _xp2: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Devine mai puternic cu cât dificultatea a crescut (setat la nașterea fiecărui inamic)
	max_hp = int(max_hp * Difficulty.enemy_hp_mult())
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")
	if ResourceLoader.exists("res://xp2.tscn"):
		_xp2 = load("res://xp2.tscn")

func _physics_process(delta: float) -> void:
	if _dying or golden:
		return   # aurit = înghețat: nici mișcare, nici schimbare de animație/culoare
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var directie := (player.global_position - global_position).normalized()
	velocity = directie * (speed * _current_slow_mult()) + _knockback  # mers (încetinit de gheață) + împins de gloanțe
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)  # împinsul scade rapid la 0
	# scade slow-ul și pune filtrul albastru cât timp e înghețat (dar nu în timpul unei sclipiri de lovitură)
	if _slow_time > 0.0:
		_slow_time = max(0.0, _slow_time - delta)
	if _flash_tween == null or not _flash_tween.is_valid():
		anim.modulate = _slow_color()
	# angle() = unghiul spre player (0 = est, crește în sensul acelor de ceas) → octant 0..7
	var idx := wrapi(int(round(directie.angle() / (PI / 4.0))), 0, 8)
	anim.play(DIRECTII[idx])

# Chemată de gheața Frostwalker: reîmprospătează slow-ul la maxim.
# `hold` = câte secunde stă la slow MAXIM (crește cu fiecare upgrade); apoi revine în SLOW_RECOVER sec.
func apply_slow(hold: float = SLOW_HOLD) -> void:
	_slow_time = hold + SLOW_RECOVER

# Multiplicatorul de viteză acum: 1.0 = normal, SLOW_MIN_MULT = încetinit la maxim.
func _current_slow_mult() -> float:
	if _slow_time <= 0.0:
		return 1.0
	if _slow_time >= SLOW_RECOVER:
		return SLOW_MIN_MULT  # încă în faza de slow MAXIM (primele SLOW_HOLD secunde)
	return lerpf(1.0, SLOW_MIN_MULT, _slow_time / SLOW_RECOVER)  # apoi revine lin la normal

# Culoarea de modulate: alb când nu e înghețat, spre albastru cât e mai încetinit.
func _slow_color() -> Color:
	var s := (1.0 - _current_slow_mult()) / (1.0 - SLOW_MIN_MULT)  # 0 = deloc, 1 = slow maxim
	return Color(1, 1, 1).lerp(SLOW_TINT, s)

# Chemată de glonț când are knockback: împinge inamicul pe direcția glonțului.
func apply_knockback(v: Vector2) -> void:
	_knockback = v

func take_damage(amount: int) -> void:
	if _dying:
		return
	# Duridama: dacă e deja aurit, ORICE lovitură îl ucide instant și lasă 2× XP.
	if golden:
		_die(2.0)
		return
	# altfel, șansa de a-l auri (îngheață în cadrul ăsta, fără să-i scadă viața)
	if _try_golden():
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		Audio.play("hit", -8.0)  # lovitură (scurt, mai încet — se aude des)
		_flash()  # sclipire albă scurtă la fiecare lovitură

# Rulează rostogolirea Duridama (șansa vine de la player). Dacă iese, îl aurește și îngheață.
func _try_golden() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("duridama_chance"):
		return false
	var sansa: float = player.duridama_chance()
	if sansa <= 0.0 or randf() >= sansa:
		return false
	_make_golden()
	return true

func _make_golden() -> void:
	golden = true
	_knockback = Vector2.ZERO       # nu mai alunecă din împinsul glonțului
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()         # oprim orice sclipire în curs, ca aurul să rămână curat
	anim.pause()                    # îngheață EXACT cadrul curent (altfel frame-urile curg singure)
	anim.modulate = GOLD_TINT
	Audio.play("hit", 0.0)          # un „cling" mai tare, ca semnal că s-a aurit

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(5, 5, 5)  # alb foarte strălucitor
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", _slow_color(), 0.12)  # revine la tenta curentă (albastră dacă e înghețat)

# Chemată de Thunder God când inamicul e lovit de curent: o sclipire albastră electrică, ceva mai
# lungă decât cea albă de lovitură, ca să se vadă că e „electrocutat". Revine la tenta curentă.
func flash_electric() -> void:
	if _dying or golden:   # aurit → nu-i stricăm filtrul auriu
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = ELECTRIC_TINT
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", _slow_color(), 0.28)

func _die(xp_bonus: float = 1.0) -> void:
	_dying = true
	_xp_bonus = xp_bonus
	golden = false                 # ca _physics_process să nu mai iasă devreme cât se stinge
	anim.play()                    # reluăm animația pentru tween-ul de moarte (era pausat dacă era aurit)
	Audio.play("enemy_die", -5.0)  # inamic mort
	GameSettings.add_run_coins(1)  # monedă pentru meta-progresie
	GameSettings.add_kill()        # kill count (apare pe HUD și în leaderboard)
	remove_from_group("enemy")  # nu mai e țintă și nu mai face damage cât se stinge
	# Gema de XP e un Area2D și o adăugăm DEFERRED: dacă moartea vine dintr-un
	# `_on_body_entered` (glonț), suntem în mijlocul calculelor de fizică și Godot
	# refuză să activeze un shape nou acolo („Can't change this state while
	# flushing queries"). Deferred = o adaugă la sfârșitul cadrului, când e sigur.
	_drop_xp.call_deferred()
	# animație de moarte: se umflă și se stinge, apoi dispare
	var t := create_tween()
	t.tween_property(anim, "scale", anim.scale * 1.4, 0.1)
	t.parallel().tween_property(anim, "modulate:a", 0.0, 0.14)
	t.tween_callback(queue_free)

func _drop_xp() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# XP normal (valoare de bază 1), înmulțit cu dificultatea → intake mai mare cu timpul
	# Bonusul (2× la Duridama) se aplică DUPĂ rotunjire, ca să iasă exact dublul dropului normal —
	# altfel, la un xp_mult ne-întreg, `round(2.6)=3` vs `round(5.2)=5` ar da un raport de 1.7, nu 2.
	if _xp1 != null:
		var gem := _xp1.instantiate()
		gem.value = int(round(int(round(gem.value * Difficulty.xp_mult())) * _xp_bonus))
		parent.add_child(gem)
		gem.global_position = global_position
	# XP rar (valoare de bază 10 = de 10× cât XP1), tot scalat cu dificultatea; 5% doar la dificultate mare
	if _xp2 != null and Difficulty.xp2_unlocked() and randf() < 0.05:
		var rare := _xp2.instantiate()
		rare.value = int(round(int(round(rare.value * Difficulty.xp_mult())) * _xp_bonus))
		parent.add_child(rare)
		rare.global_position = global_position + Vector2(20, 0)
