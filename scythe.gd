extends Area2D

# COASA lui CELESTO (`celesto.gd`) — proiectilul lui, în trei feluri, toate din același nod.
# Arta e o singură poză, `celesto throw.png`, care se ROTEȘTE în zbor (`spin`), deci nu-i
# trebuie cadre. Sora ștreangului lui Saratalin (`lightning.gd`), doar că aia zboară drept și
# atât; asta știe și să se întoarcă.
#
# Conturul albastru de 1px vine din `contur_1px.gdshader` (pus pe sprite din scenă), același ca
# la Celesto. Din shader, nu copt în poză, tocmai pentru coasa uriașă: un contur copt s-ar fi
# mărit și el de trei ori odată cu `marime`, iar cele două feluri de coasă n-ar mai fi arătat a
# aceeași armă.
#
# Cele trei feluri (se aleg din `celesto.gd`, punând proprietățile ÎNAINTE de `add_child`):
#   • DREAPTĂ (implicit) — pleacă pe `direction` și merge până lovește sau expiră;
#   • BUMERANG (`bumerang = true`) — e aruncată în direcția OPUSĂ player-ului, încetinește,
#     se oprește după `raza_intoarcere` pixeli, apoi se întoarce ȚINTIND player-ul. Deci nu te
#     lovește la dus, ci la întors, din spatele tău dacă n-ai plecat de acolo;
#   • URIAȘĂ (`marime = 3.0`) — aceeași coasă, de trei ori mai mare ȘI ca desen, ȘI ca hitbox.
#     Mărimea se aplică într-un singur loc (`_aplica_marime`), ca cele două să nu poată să
#     se desincronizeze.
#
# ⚠️ Ca la `lightning.gd`: proprietățile se scriu ÎNAINTE de `add_child`, fiindcă `_ready()`
# le citește o singură dată, când nodul intră în arbore.

@export var speed: float = 340.0
@export var damage: int = 22
@export var lifetime: float = 4.0      # după atâtea secunde dispare, dacă n-a lovit nimic
@export var spin: float = 9.0          # radiani pe secundă (≈1.4 rotații/s)
@export var marime: float = 1.0        # 3.0 = coasa uriașă din faza 3 (desen + hitbox)
# Cât de mare e coasa „normală" față de poză (128×128 e mai lat decât player-ul). Se înmulțește
# cu `marime`, deci schimbând-o aici se mișcă și desenul, și hitbox-ul, la toate felurile.
@export var art_scale: float = 0.7
@export var tint: Color = Color(1.15, 1.05, 1.35)   # peste 1 = mai luminoasă, se vede pe nebuloasă

# --- doar la bumerang ---
@export var bumerang: bool = false
@export var raza_intoarcere: float = 420.0   # câți pixeli se duce înainte să se oprească
@export var viteza_retur: float = 1.35       # de câte ori se întoarce mai repede decât a plecat

var direction: Vector2 = Vector2.RIGHT

var _time_left: float
var _viteza: float          # viteza de acum pe `direction` (la bumerang scade, apoi crește la retur)
var _incetinire: float      # cât frânează pe secundă, calculat din `raza_intoarcere`
var _se_intoarce := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var forma: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_time_left = lifetime
	_viteza = speed
	# Frânarea nu e o cifră aleasă din ochi: ca să se oprească EXACT după `raza_intoarcere`
	# pixeli plecând cu viteza `speed`, îți trebuie a = v² / (2·d). Așa knob-ul rămâne
	# „cât de departe se duce", care e ce vezi pe ecran, nu o accelerație abstractă.
	_incetinire = (speed * speed) / (2.0 * maxf(raza_intoarcere, 1.0))
	sprite.modulate = tint
	_aplica_marime()
	body_entered.connect(_on_body_entered)

func set_direction(new_dir: Vector2) -> void:
	direction = new_dir.normalized()

# Desenul ȘI hitbox-ul într-un singur loc. `scale` pe formă, nu o rază nouă: forma e un
# `SubResource` din scenă, deci scrisă o dată aici nu se poate uita nesincronizată cu arta.
func _aplica_marime() -> void:
	sprite.scale = Vector2.ONE * marime * art_scale
	forma.scale = Vector2.ONE * marime * art_scale

func _physics_process(delta: float) -> void:
	sprite.rotation += spin * delta
	if bumerang:
		_zbor_bumerang(delta)
	else:
		global_position += direction * _viteza * delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

# Dus: frânează pe direcția de plecare până stă. Întors: țintește player-ul ACUM (nu unde era
# când a plecat), deci te urmărește — altfel ar cădea în gol de fiecare dată când te miști.
func _zbor_bumerang(delta: float) -> void:
	if not _se_intoarce:
		_viteza -= _incetinire * delta
		if _viteza <= 0.0:
			_se_intoarce = true
			_viteza = 0.0
		else:
			global_position += direction * _viteza * delta
			return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		direction = (player.global_position - global_position).normalized()
	_viteza = minf(_viteza + _incetinire * delta, speed * viteza_retur)
	global_position += direction * _viteza * delta

func _on_body_entered(body: Node) -> void:
	# lovește DOAR player-ul (trece prin Celesto care a aruncat-o, prin creaturi, prin decor)
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
