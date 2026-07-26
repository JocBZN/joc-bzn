extends CharacterBody2D

# SARATALIN — boss-ul Nether-ului. Îl chemi de la structura „Summoning Portal"
# (`summoning_portal.gd`), care se scufundă în pământ cu cutremur, exact ca statuia
# care îl cheamă pe Garda. Diferența: Saratalin NU iese din pământ, ci COBOARĂ DIN TAVAN
# — pornește deasupra marginii de sus a ecranului, deci player-ul nu-l vede apărând,
# doar coborând.
#
# ARTA: o singură foaie, `harta/nether/Nether Boss/Saratalin.png`, 3360×240 = 15 cadre
# de 224×240 lipite pe orizontală. NU e tăiată în 15 fișiere: o feliem la rulare cu
# `AtlasTexture` (fiecare cadru = o fereastră peste aceeași imagine), ca la frunzele din
# `leaffall.gd`. Dacă înlocuiești foaia cu una cu alt număr de cadre, schimbi doar
# `FRAMES` / `FRAME_W` de mai jos.
#
# Cele 15 cadre sunt o singură animație de plutire, în buclă — creatura nu merge pe
# picioare, deci nu are nevoie de animații pe 8 direcții ca Garda.

const SHEET := "res://harta/nether/Nether Boss/Saratalin.png"
const FRAME_W := 224   # lățimea unui cadru din foaie
const FRAME_H := 240
const FRAMES := 15     # câte cadre are foaia

const LIGHTNING := preload("res://lightning.tscn")

@export var speed: float = 62.0        # plutește greoi, ca un boss
@export var max_hp: int = 700          # mai rezistent decât Garda (300)
@export var anim_fps: float = 10.0     # 15 cadre la 10 fps = o plutire completă la 1.5s
@export var xp_value: int = 100        # cât XP lasă când moare (se înmulțește cu bonusul din Nether)

# --- Cum coboară din tavan ---
@export var descend_duration: float = 1.9   # cât durează coborârea (secunde)
@export var ceiling_margin: float = 260.0   # cu cât pornește DEASUPRA marginii de sus a ecranului
@export var land_shake: float = 26.0        # cât zguduie camera când atinge pământul
@export var land_shake_time: float = 0.5

# --- Atacul obișnuit: aruncă un proiectil spre tine ---
@export var attack_range: float = 520.0
@export var attack_interval: float = 1.8
@export var bolt_damage: int = 18
@export var bolt_speed: float = 320.0
# Culoarea proiectilelor lui — roz-magenta, ca foaia lui, ca să nu le confunzi cu ale Gărzii.
@export var bolt_tint: Color = Color(1.6, 0.5, 1.5)

# --- Atacul special: un CERC de proiectile în toate direcțiile ---
# Garda trage o rafală spre tine; Saratalin umple ecranul în jurul lui, deci nu poți sta
# lipit de el. Ca să te ferești trebuie să te miști printre raze, nu doar să fugi în lateral.
@export var ring_interval: float = 8.0   # o dată la câte secunde
@export var ring_count: int = 14         # câte proiectile are cercul

var hp: int
var _dying := false
var _coboara := false     # cât timp coboară din tavan nu atacă și nu se mișcă singur
var _atk_cooldown := 0.0
var _ring_cooldown := 0.0
var _flash_tween: Tween

var _xp1: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# se întărește cu dificultatea, exact ca Garda și ca inamicii normali. În Nether,
	# `Difficulty.mult_time_override` e scris de `nether.gd`, deci un Saratalin chemat
	# după Nether Swarm e mult mai tare decât unul chemat în primul minut.
	max_hp = int(max_hp * Difficulty.enemy_hp_mult())
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")   # ca gloanțele să-l lovească și să facă damage la contact
	add_to_group("saratalin")
	_ring_cooldown = ring_interval * 0.5   # nu deschide cu cercul fix în clipa aterizării
	_build_frames()
	anim.play("float")
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")

# Feliem foaia în cadre. `AtlasTexture` = o fereastră peste imaginea mare; nu copiem
# pixeli și nu avem nevoie de 15 fișiere pe disc.
func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("float")
	frames.set_animation_speed("float", anim_fps)
	frames.set_animation_loop("float", true)
	var sheet := load(SHEET) as Texture2D
	if sheet == null:
		push_warning("Saratalin: lipsește %s (rulează --headless --import)" % SHEET)
		anim.sprite_frames = frames
		return
	for i in FRAMES:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame("float", at)
	anim.sprite_frames = frames

# ---------- coborârea din tavan ----------
# Chemată de `summoning_portal.gd` imediat după ce l-a pus la locul lui: mutăm nodul
# deasupra ecranului și îl lăsăm să plutească în jos, înapoi în punctul ăla.
#
# Mutăm TOT nodul, nu doar sprite-ul (cum face statuia cu Garda): dacă am muta doar arta,
# corpul ar fi deja jos și te-ar lovi un boss invizibil cât „coboară".
func coboara_din_tavan() -> void:
	var tinta := global_position
	global_position = tinta - Vector2(0, _jumatate_ecran() + ceiling_margin)
	_coboara = true
	var t := create_tween()
	t.set_ease(Tween.EASE_IN_OUT)
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "global_position", tinta, descend_duration)
	t.tween_callback(_a_aterizat)

func _a_aterizat() -> void:
	_coboara = false
	_zguduie_camera()   # bufnitura: se simte că a atins pământul

# Jumătatea de sus a ecranului, în pixeli de LUME (nu de ecran): de atât are nevoie ca
# să pornească din afara câmpului vizual. Camera player-ului are zoom, deci împărțim la el.
func _jumatate_ecran() -> float:
	var inaltime := get_viewport_rect().size.y
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam != null and cam.zoom.y > 0.0:
			return inaltime / cam.zoom.y * 0.5
	return inaltime * 0.5

func _zguduie_camera() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	tw.tween_method(_shake.bind(cam), 1.0, 0.0, land_shake_time)
	tw.tween_callback(_shake_stop.bind(cam))

func _shake(amount: float, cam: Camera2D) -> void:
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * land_shake * amount

func _shake_stop(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

# ---------- luptă ----------
func _physics_process(delta: float) -> void:
	if _dying or _coboara:
		return   # cât coboară nu se mișcă singur (de mutat îl mută tween-ul) și nu atacă
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	# se uită spre tine: foaia îl desenează cu fața în jos, deci doar oglindim stânga/dreapta
	if absf(dir.x) > 0.05:
		anim.flip_h = dir.x < 0.0

	_atk_cooldown -= delta
	_ring_cooldown -= delta
	var in_range := global_position.distance_to(player.global_position) <= attack_range

	# cercul de proiectile pleacă indiferent cât de departe ești — e atacul lui de zonă
	if _ring_cooldown <= 0.0:
		_ring_cooldown = ring_interval
		_atk_cooldown = maxf(_atk_cooldown, attack_interval * 0.5)  # să nu se lipească de cerc
		_trage_cerc()
		return

	if _atk_cooldown <= 0.0 and in_range:
		_atk_cooldown = attack_interval
		_trage(dir)

func _trage_cerc() -> void:
	Audio.play("garda_attack", -2.0)
	for i in ring_count:
		var unghi := TAU * float(i) / float(ring_count)
		_trage(Vector2(cos(unghi), sin(unghi)), false)

func _trage(dir: Vector2, cu_sunet: bool = true) -> void:
	var parent := get_parent()
	if parent == null:
		return
	if cu_sunet:
		Audio.play("garda_attack")
	var proj := LIGHTNING.instantiate()
	# ⚠️ `tint` se pune ÎNAINTE de `add_child`: `lightning.gd` îl citește o singură dată, în
	# `_ready()`, iar `_ready()` se declanșează chiar în clipa în care nodul intră în arbore.
	# Pus după, proiectilele rămâneau violet ca ale Gărzii. (`damage`/`speed` se citesc în
	# fiecare cadru, deci pe alea nu le deranjează ordinea.)
	proj.tint = bolt_tint
	proj.damage = maxi(1, int(round(bolt_damage * Difficulty.enemy_damage_mult())))
	proj.speed = bolt_speed
	parent.add_child(proj)
	proj.global_position = global_position + dir * 90.0   # pornește puțin în fața lui
	proj.set_direction(dir)

func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		_flash()   # sclipire albă scurtă la fiecare lovitură

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(5, 5, 5)
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.12)

func _die() -> void:
	_dying = true
	GameSettings.add_kill()
	remove_from_group("enemy")
	remove_from_group("saratalin")
	# ieșirea din Nether e închisă până cade el — anunțăm dimensiunea că a căzut
	var nether := get_tree().get_first_node_in_group("nether")
	if nether != null:
		nether.boss_invins()
	_drop_xp.call_deferred()   # vezi enemy.gd: un Area2D nou nu se poate adăuga în timpul fizicii
	_zguduie_camera()
	var t := create_tween()
	t.tween_property(anim, "scale", anim.scale * 1.4, 0.12)
	t.parallel().tween_property(anim, "modulate:a", 0.0, 0.16)
	t.tween_callback(queue_free)

func _drop_xp() -> void:
	var parent := get_parent()
	if parent == null or _xp1 == null:
		return
	var gem := _xp1.instantiate()
	gem.value = int(round(xp_value * Difficulty.xp_mult()))
	parent.add_child(gem)
	gem.global_position = global_position
