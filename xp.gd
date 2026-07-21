extends Area2D

# Glob de XP care stă pe jos. Are viață: pulsează + plutește, e atras spre player
# când se apropie (magnet), și face un mic "pop" când e adunat.

@export var value: int = 1
@export var magnet_range: float = 130.0   # de la ce distanță începe să fie atras spre player
@export var magnet_speed: float = 420.0   # cât de repede zboară spre player
# Ce fel de gemă e asta: 1 = xp1 (comună), 2 = xp2 (rară), 3 = xp3 (bula, vezi mai jos).
# Se contopesc doar geme de ACELAȘI fel.
@export var tier: int = 1

# --- CONTOPIREA ÎN BULE ---
# În Final Swarm mor ~30 de inamici pe secundă și n-ai cum să aduni tot: gemele rămase
# în urmă se strângeau la nesfârșit (măsurat: 5390 de geme = 4 FPS — ăsta era laghitul).
#
# Nicio gemă nu se pierde: când se adună CLUSTER_NR geme de același fel în același loc,
# ele ZBOARĂ toate spre centru și se contopesc într-o BULĂ (xp3), care valorează exact
# cât toate la un loc. Bulele se contopesc și ele între ele, tot câte CLUSTER_NR, deci
# oricât ar dura runda, numărul de geme rămâne mic de la sine.
const CLUSTER_NR := 20        # câte geme intră într-o bulă
const CLUSTER_RAZA := 260.0   # cât de aproape trebuie să fie ca să conteze „în același loc" (px)
const SUCT_DURATA := 0.22     # cât durează zborul spre centru
const BULA := "res://xp3.tscn"

# Încărcată o singură dată, la prima contopire. NU `preload`: xp3.tscn folosește chiar
# scriptul ăsta, iar un preload circular script→scenă→script supără încărcătorul.
static var _scena_bula: PackedScene

# --- CULOAREA BULEI ---
# Bula folosește arta gemei xp2, vopsită ROȘU la rulare: fiecare pixel primește nuanța
# NUANTA_BULA, dar își păstrează saturația și luminozitatea → același desen, aceleași umbre,
# altă culoare. Se face o singură dată pe rundă (`static`), la prima bulă.
#
# De ce vopsit în cod și nu un `xp3.png` separat: dacă schimbi arta lui `xp/xp2.png`, bula se
# ia automat după ea. Un fișier separat ar rămâne în urmă în tăcere (și ar cere reimport).
# Am încercat întâi un overlay roșu additiv peste artă — abia se vedea, orbul rămânea albastru.
const NUANTA_BULA := 0.0      # 0.0 = roșu; 0.97 ≈ vișiniu, dacă vrei alt ton
static var _tex_rosie: Texture2D

var _time := 0.0
var _base_scale: Vector2
var _collected := false
var _player: Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("xp")
	body_entered.connect(_on_body_entered)
	if tier == 3:
		sprite.texture = _textura_rosie(sprite.texture)
	_base_scale = sprite.scale
	_time = randf() * TAU   # faze diferite, ca să nu pulseze toate la fel
	# AMÂNAT, nu chemat aici: cine ne creează ne pune poziția DUPĂ `add_child`, deci în `_ready`
	# gema e încă la (0,0) și n-ar găsi niciun vecin. `call_deferred` o cheamă la sfârșitul
	# cadrului, când poziția e deja pusă.
	_incearca_contopirea.call_deferred()

# Sunt destule geme de fel cu mine, aproape de mine, ca să facem o bulă?
# Verificarea o face gema NOU apărută — un singur test la fiecare gemă căzută, exact
# în momentul în care numărul din zonă poate să fi crescut.
func _incearca_contopirea() -> void:
	if _collected or not is_inside_tree():
		return   # între timp am fost culeasă sau înghițită de altă bulă
	if tier == 2:
		return   # gema rară nu se contopește: sunt oricum puține și vrei s-o vezi ca atare
	var vecine: Array[Node2D] = []
	for g in get_tree().get_nodes_in_group("xp"):
		var gema: Node2D = g as Node2D
		if gema == null or gema == self or gema.tier != tier or gema._collected:
			continue
		if global_position.distance_to(gema.global_position) <= CLUSTER_RAZA:
			vecine.append(gema)
	if vecine.size() + 1 < CLUSTER_NR:
		return
	# dacă sunt mai multe decât ne trebuie, le luăm pe cele mai apropiate de noi
	vecine.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) \
			< global_position.distance_squared_to(b.global_position))
	vecine.resize(CLUSTER_NR - 1)
	vecine.append(self)
	_contopeste(vecine)

# Le suge pe toate spre centrul lor și lasă în loc o bulă care valorează cât ele la un loc.
func _contopeste(geme: Array[Node2D]) -> void:
	if _scena_bula == null:
		if not ResourceLoader.exists(BULA):
			return   # bula nu există (încă) → lăsăm gemele în pace, jocul merge mai departe
		_scena_bula = load(BULA)
	var centru := Vector2.ZERO
	var total := 0
	for g in geme:
		centru += g.global_position
		total += g.value
	centru /= geme.size()

	var bula := _scena_bula.instantiate()
	bula.value = total
	get_parent().add_child(bula)   # `_ready`-ul ei verifică, la rândul lui, dacă se face o bulă de bule
	bula.global_position = centru
	# Apare din nimic, cât timp gemele zboară spre ea. Excepție: dacă `_ready`-ul ei tocmai a
	# făcut o bulă de bule, bula asta e deja absorbită și are propriul zbor — n-o mai atingem.
	if not bula._collected:
		bula.sprite.scale = Vector2.ZERO
		bula.create_tween().tween_property(bula.sprite, "scale", bula._base_scale, SUCT_DURATA) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for g in geme:
		g.absoarbe_spre(centru)

# Gema asta a fost înghițită de o bulă: iese din evidență, zboară spre centru și dispare.
# Publică (fără `_`) fiindcă o cheamă gema care a pornit contopirea, nu gema însăși.
func absoarbe_spre(centru: Vector2) -> void:
	_collected = true          # oprește animația idle, magnetul și culesul
	remove_from_group("xp")    # nu mai intră în socoteala altei contopiri
	var t := create_tween()
	t.tween_property(self, "global_position", centru, SUCT_DURATA).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(sprite, "scale", _base_scale * 0.3, SUCT_DURATA)
	t.tween_callback(queue_free)

# Varianta roșie a texturii primite (vezi NUANTA_BULA). Prelucrată o singură dată și refolosită.
func _textura_rosie(sursa: Texture2D) -> Texture2D:
	if _tex_rosie != null:
		return _tex_rosie
	if sursa == null:
		return sursa
	var img := sursa.get_image()
	if img == null:
		return sursa   # nu putem citi pixelii → rămâne albastră, nu stricăm nimic
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue   # pixelii transparenți n-au culoare de schimbat
			img.set_pixel(x, y, Color.from_hsv(NUANTA_BULA, c.s, c.v, c.a))
	_tex_rosie = ImageTexture.create_from_image(img)
	return _tex_rosie

func _physics_process(delta: float) -> void:
	if _collected:
		return
	# animație idle: pulsează ușor + plutește sus-jos
	_time += delta
	sprite.scale = _base_scale * (1.0 + 0.12 * sin(_time * 5.0))
	sprite.position.y = -5.0 * absf(sin(_time * 3.0))
	# magnet: dacă player-ul e aproape, zboară spre el
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		if global_position.distance_to(_player.global_position) < magnet_range:
			var dir := (_player.global_position - global_position).normalized()
			global_position += dir * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collected = true
		remove_from_group("xp")   # nu mai intră la socoteala plafonului cât se stinge
		Audio.play("xp", -6.0)  # blip la adunat XP
		body.gain_xp(value)
		_pop()

func _pop() -> void:
	# efect la colectare: crește rapid și se stinge, apoi dispare
	var t := create_tween()
	t.tween_property(sprite, "scale", _base_scale * 1.7, 0.08)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)
