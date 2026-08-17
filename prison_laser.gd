extends Node2D

# ATACUL 3 al boss-ului din PUȘCĂRIE: RAZA. Arta: `harta/prison/boss/atac_laser/` — 6 cadre,
# din care 0..3 = încărcarea (bila roșie care se strânge) și 4..5 = raza propriu-zisă.
#
# Îl are DOAR din faza 3, și e cel mai periculos: lovește pe toată lungimea, instantaneu, deci
# nu se evită fugind în lateral după ce a plecat. Ce-l face cinstit e ÎNCĂRCAREA: cât se aprinde
# bila, direcția e deja fixată, deci ai `timp_incarcare` secunde să ieși de pe linie.
#
# 🔑 DIRECȚIA SE ÎNGHEAȚĂ LA ÎNCEPUTUL ÎNCĂRCĂRII. O rază care te urmărește cât se încarcă ar fi
# imposibil de evitat — telegraful n-ar mai însemna nimic.
#
# ⚠️ Cadrele sunt desenate cu raza pornind din STÂNGA pânzei și mergând spre dreapta, deci:
#   • `offset.x = jumătate din pânză` mută textura la dreapta, ca originea nodului să cadă fix pe
#     capătul din care pleacă raza — altfel s-ar roti în jurul mijlocului ei și ar mătura aiurea;
#   • `rotation` = unghiul spre player (0 rad = est, exact cum e desenată).

const ART := "res://harta/prison/boss/atac_laser/"
const CADRE_INCARCARE := 4    # frame_0 .. frame_3
const CADRE_RAZA := 2         # frame_4, frame_5
const PANZA := 640.0          # latura pânzei cadrelor (vezi extractorul)
# Cât de lungă e raza DESENATĂ în ultimul cadru, în pixeli de artă, măsurată din capătul stâng.
const LUNGIME_ARTA := 620.0

@export var damage: int = 55
@export var lungime: float = 900.0      # cât ajunge în lume
@export var grosime: float = 46.0       # cât de lat e fasciculul care lovește
@export var timp_incarcare: float = 0.9
@export var timp_raza: float = 0.45

var _anim: AnimatedSprite2D
var _t := 0.0
var _tras := false
var _dir := Vector2.RIGHT

func porneste(directie: Vector2) -> void:
	if directie.length() > 0.001:
		_dir = directie.normalized()

func _ready() -> void:
	z_index = 40
	rotation = _dir.angle()
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("incarca")
	frames.set_animation_speed("incarca", float(CADRE_INCARCARE) / maxf(0.05, timp_incarcare))
	frames.set_animation_loop("incarca", false)
	frames.add_animation("trage")
	frames.set_animation_speed("trage", float(CADRE_RAZA) / maxf(0.05, timp_raza))
	frames.set_animation_loop("trage", false)
	var lipsa := 0
	for i in CADRE_INCARCARE:
		var tex := load("%sframe_%d.png" % [ART, i]) as Texture2D
		if tex == null: lipsa += 1
		else: frames.add_frame("incarca", tex)
	for i in CADRE_RAZA:
		var tex2 := load("%sframe_%d.png" % [ART, CADRE_INCARCARE + i]) as Texture2D
		if tex2 == null: lipsa += 1
		else: frames.add_frame("trage", tex2)
	if lipsa > 0:
		push_warning("Laser: lipsesc %d cadre din %s (rulează --headless --import)" % [lipsa, ART])
	if frames.get_frame_count("incarca") == 0 and frames.get_frame_count("trage") == 0:
		queue_free()
		return
	_anim.sprite_frames = frames
	# originea nodului = capătul din care pleacă raza (vezi comentariul de sus)
	_anim.offset = Vector2(PANZA * 0.5, 0.0)
	_anim.scale = Vector2.ONE * (lungime / LUNGIME_ARTA)
	add_child(_anim)
	_anim.play("incarca")

func _process(delta: float) -> void:
	_t += delta
	if not _tras:
		if _t >= timp_incarcare:
			_trage()
		return
	if _t >= timp_incarcare + timp_raza:
		queue_free()

func _trage() -> void:
	_tras = true
	_anim.play("trage")
	Audio.play("garda_attack", -1.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	# Lovește dacă player-ul e în dreptunghiul razei: proiecția pe direcție între 0 și `lungime`,
	# iar abaterea laterală sub jumătate din grosime.
	var v := player.global_position - global_position
	var de_a_lungul := v.dot(_dir)
	var lateral := absf(v.dot(Vector2(-_dir.y, _dir.x)))
	if de_a_lungul >= -20.0 and de_a_lungul <= lungime and lateral <= grosime * 0.5:
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))
