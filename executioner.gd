extends CharacterBody2D

# UNDEAD EXECUTIONER PUPPET — boss-ul dimensiunii ENDER. Te așteaptă acolo din clipa în care
# intri (`ender.gd` îl pune într-un inel în jurul fântânii de întoarcere) și, cât timp trăiește,
# portalul nu se deschide. Fratele mai adânc al lui Saratalin: aceleași unelte, alt ritm.
#
# ARTA: cinci foi de cadre în `harta/Portal Ender/Undead executioner puppet/png/`, toate cu
# cadre de 100×100, dar așezate în GRILE (mai multe rânduri), nu pe un singur rând ca Saratalin.
# Le feliem la rulare cu `AtlasTexture` — o fereastră peste foaie, fără fișiere separate pe disc.
# Cadrele se citesc pe rânduri, de la stânga la dreapta; celulele goale de la coadă (o grilă rar
# iese fix plină) se sar prin `cadre`, numărul REAL de desene din fiecare foaie.
#
# ⚠️ Folosim copiile `*_contur.png`, generate de `tool_contur_foaie.gd`: desenul e o siluetă
# NEAGRĂ, iar podeaua Ender-ului e o nebuloasă aproape neagră — fără conturul albastru boss-ul
# ar fi o gaură în ecran. Foile lui Răzvan rămân neatinse; unealta se poate re-rula oricând.

const ART := "res://harta/Portal Ender/Undead executioner puppet/png/"
const CADRU := 100   # latura unui cadru, în pixeli (toate foile sunt pe grilă de 100×100)

# foaie → câte desene are, cât de repede se joacă, dacă se reia în buclă
const FOI := {
	"float":  {"fisier": "idle2_contur.png",     "cadre": 8,  "fps": 8.0,  "bucla": true},
	"attack": {"fisier": "attacking_contur.png", "cadre": 13, "fps": 16.0, "bucla": false},
	"skill":  {"fisier": "skill1_contur.png",    "cadre": 12, "fps": 14.0, "bucla": false},
	"summon": {"fisier": "summon_contur.png",    "cadre": 5,  "fps": 7.0,  "bucla": false},
	"death":  {"fisier": "death_contur.png",     "cadre": 18, "fps": 12.0, "bucla": false},
}

# În ce cadru al animației pleacă efectiv lovitura. Nu la început: coasa trebuie să fi ajuns
# în aer, altfel proiectilul iese din el înainte să se vadă că a lovit.
const CADRU_LOVITURA := {"attack": 4, "skill": 6, "summon": 3}

const LIGHTNING := preload("res://lightning.tscn")
# Ce cheamă în faza 2: creaturile violete ale Nether-ului. Ender-ul nu are inamici proprii
# (nu există artă), deci se folosesc ele — aceleași care curg oricum din `spawner.gd`.
const SLUGA := preload("res://enemy_nether.tscn")

@export var speed: float = 74.0          # plutește, ca Saratalin, dar puțin mai iute
# Viață FIXĂ, nescalată cu dificultatea — la fel ca la Saratalin, și din același motiv: e o
# luptă cu bară pe ecran și cu o fază care începe fix la jumătate, deci pragul trebuie să
# însemne același lucru la fiecare rundă. Mult mai mult decât Saratalin (10 000): ca să ajungi
# aici trebuie să-l fi bătut deja pe el.
@export var max_hp: int = 100000
@export var nume: String = "UNDEAD EXECUTIONER PUPPET"   # ce scrie deasupra barei
@export var xp_value: int = 150          # se înmulțește cu bonusul de XP al Ender-ului

# --- atacul obișnuit: taie cu coasa și aruncă tăietura spre tine ---
@export var attack_range: float = 560.0
@export var attack_interval: float = 2.0
@export var bolt_damage: int = 22
@export var bolt_speed: float = 340.0
# Proiectil PLACEHOLDER: ștreangul lui Saratalin, colorat albastru. Tăietura de coasă n-are
# artă proprie încă. (Și Saratalin a împrumutat bastona Gărzii până și-a primit ștreangul.)
const BOLT_FRAMES := "res://harta/nether/Nether Boss/attack_frames/"
@export var bolt_tint: Color = Color(0.55, 0.95, 1.7)

# --- skill: un CERC de tăieturi în toate direcțiile ---
@export var ring_interval: float = 9.0
@export var ring_count: int = 16

# --- faza 2, de la jumătatea vieții: cheamă slugi și atacă mai des ---
# Saratalin are aici un filmuleț cu pulsuri mov. Ăsta nu: are o animație de INVOCARE în foaia
# lui, deci faza 2 se vede prin ce face, nu prin cameră — de la jumătate încolo cheamă creaturi.
@export var furie_atac: float = 1.6      # de câte ori mai des atacă în faza 2
@export var summon_interval: float = 11.0
@export var summon_count: int = 4        # câte creaturi cheamă odată
@export var summon_radius: float = 260.0 # la ce distanță de el apar

var hp: int
var _dying := false
var _faza2 := false
var _ocupat := false          # joacă o animație de atac → nu se mișcă și nu începe alta
var _atk_cooldown := 0.0
var _ring_cooldown := 0.0
var _summon_cooldown := 0.0
var _dir_lovitura := Vector2.RIGHT   # încotro pleacă lovitura când ajunge la cadrul ei
var _flash_tween: Tween
var _xp1: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# ca la ceilalți: viteza urmează dificultatea rundei, viața nu
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")         # ca gloanțele să-l lovească
	add_to_group("boss")          # IMUN la instakill (Hacksaw) — vezi `bullet.gd`
	add_to_group("executioner")
	var bara := _bara()
	if bara != null:
		bara.arata(nume, max_hp)
	_ring_cooldown = ring_interval * 0.5     # nu deschide lupta fix cu cercul
	_summon_cooldown = summon_interval * 0.5
	_build_frames()
	anim.animation_finished.connect(_anim_gata)
	anim.frame_changed.connect(_cadru_nou)
	anim.play("float")
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")

# Feliem foile în cadre. Grila se deduce din mărimea foii (toate cadrele sunt 100×100), iar
# cadrele se iau pe rânduri până la numărul REAL de desene — restul celulelor sunt goale.
func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for nume_anim in FOI:
		var f: Dictionary = FOI[nume_anim]
		frames.add_animation(nume_anim)
		frames.set_animation_speed(nume_anim, f["fps"])
		frames.set_animation_loop(nume_anim, f["bucla"])
		var cale: String = ART + f["fisier"]
		var foaie := load(cale) as Texture2D
		if foaie == null:
			push_warning("Executioner: lipsește %s (rulează --headless --import)" % cale)
			continue
		var coloane := int(foaie.get_width() / CADRU)
		for i in int(f["cadre"]):
			var at := AtlasTexture.new()
			at.atlas = foaie
			at.region = Rect2((i % coloane) * CADRU, (i / coloane) * CADRU, CADRU, CADRU)
			frames.add_frame(nume_anim, at)
	anim.sprite_frames = frames

# ---------- luptă ----------
func _physics_process(delta: float) -> void:
	if _dying:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()

	if _ocupat:
		return   # cât taie cu coasa stă pe loc; animațiile sunt desenate din picioare
	velocity = dir * speed
	move_and_slide()
	# foaia îl desenează cu fața spre dreapta, deci doar oglindim stânga/dreapta
	if absf(dir.x) > 0.05:
		anim.flip_h = dir.x < 0.0

	_atk_cooldown -= delta
	_ring_cooldown -= delta
	_summon_cooldown -= delta
	_dir_lovitura = dir

	# cercul pleacă oricât de departe ai fi — e atacul lui de zonă
	if _ring_cooldown <= 0.0:
		_ring_cooldown = ring_interval
		_atk_cooldown = maxf(_atk_cooldown, attack_interval * 0.5)
		_joaca("skill")
		return
	# slugile, doar în faza 2
	if _faza2 and _summon_cooldown <= 0.0:
		_summon_cooldown = summon_interval
		_joaca("summon")
		return
	if _atk_cooldown <= 0.0 and global_position.distance_to(player.global_position) <= attack_range:
		_atk_cooldown = attack_interval
		_joaca("attack")

func _joaca(nume_anim: String) -> void:
	_ocupat = true
	velocity = Vector2.ZERO
	anim.play(nume_anim)

# Animația de atac a ajuns la cadrul în care lovitura chiar pleacă.
func _cadru_nou() -> void:
	# `anim.animation` e StringName, cheile dicționarului sunt String — convertim, ca să nu
	# depindem de cum le compară Godot între ele.
	var a := String(anim.animation)
	if not CADRU_LOVITURA.has(a) or anim.frame != CADRU_LOVITURA[a]:
		return
	match a:
		"attack":
			_trage(_dir_lovitura)
		"skill":
			_trage_cerc()
		"summon":
			_cheama_slugi()

func _anim_gata() -> void:
	if anim.animation == "death":
		queue_free()
		return
	_ocupat = false
	anim.play("float")

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
	# ⚠️ `tint` și `frame_dir` se pun ÎNAINTE de `add_child`: `lightning.gd` le citește o
	# singură dată, în `_ready()`, adică fix când nodul intră în arbore.
	proj.frame_dir = BOLT_FRAMES
	proj.tint = bolt_tint
	proj.damage = maxi(1, int(round(bolt_damage * Difficulty.enemy_damage_mult())))
	proj.speed = bolt_speed
	parent.add_child(proj)
	proj.global_position = global_position + dir * 80.0
	proj.set_direction(dir)

# Faza 2: cheamă creaturi în jurul lui. Le punem pe un CERC în jurul boss-ului, nu peste
# player: altfel ar apărea lipite de tine și ai mânca damage din nimic.
func _cheama_slugi() -> void:
	var parent := get_parent()
	if parent == null:
		return
	Audio.play("earthquake", Audio.QUAKE_DB - 12.0, 0.0)
	for i in summon_count:
		var unghi := TAU * float(i) / float(summon_count) + randf() * 0.6
		var e := SLUGA.instantiate()
		parent.add_child(e)
		e.global_position = global_position + Vector2(cos(unghi), sin(unghi)) * summon_radius

func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	var bara := _bara()
	if bara != null:
		bara.set_hp(hp)
	if hp <= 0:
		_die()
		return
	_flash()
	if not _faza2 and hp <= max_hp / 2:
		_faza2 = true
		_infurie()

# De la jumătate încolo taie mai des ȘI începe să cheme slugi.
func _infurie() -> void:
	attack_interval = maxf(attack_interval / furie_atac, 0.25)
	ring_interval = maxf(ring_interval / furie_atac, 2.0)
	_summon_cooldown = 0.5      # prima invocare vine repede, ca să se vadă că s-a schimbat ceva
	_announce("THE PUPPET PULLS ITS STRINGS", "It calls the creatures to it")
	Audio.play("levelup", -6.0)

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
	remove_from_group("executioner")
	# nu mai lovește pe nimeni cât se destramă
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(1, 1, 1)
	# ieșirea din Ender e închisă până cade el
	var ender := get_tree().get_first_node_in_group("ender")
	if ender != null:
		ender.boss_invins()
	_drop_xp.call_deferred()   # un Area2D nou nu se poate adăuga în timpul fizicii (vezi enemy.gd)
	_premiu_niveluri()
	_zguduie_camera()
	# Foaia lui de moarte se destramă singură până la nimic, deci nu mai punem tween peste ea;
	# `_anim_gata()` îl șterge când se termină.
	_ocupat = true
	anim.play("death")

# Premiul: 4 NIVELURI. Saratalin dă 3, iar ca să ajungi aici trebuie să-l fi bătut întâi pe el.
const NIVELURI_PREMIU := 4
@export var premiu_intarziere: float = 1.6   # cât aștepți până sar ecranele de ales

# 🔑 Timer legat de PLAYER, nu `await` aici: nodul se șterge la capătul animației de moarte,
# iar un `await` pe un nod mort nu se mai reia niciodată. Întârzierea nu e cosmetică: fără ea,
# ecranul de level up pune jocul pe pauză peste animația de moarte și peste anunț.
func _premiu_niveluri() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	get_tree().create_timer(premiu_intarziere).timeout.connect(
		p.da_niveluri.bind(NIVELURI_PREMIU, false))

func _drop_xp() -> void:
	var parent := get_parent()
	if parent == null or _xp1 == null:
		return
	var gem := _xp1.instantiate()
	gem.value = int(round(xp_value * Difficulty.xp_mult()))
	parent.add_child(gem)
	gem.global_position = global_position

func _bara() -> Node:
	return get_tree().get_first_node_in_group("boss_bar")

# Bara dispare odată cu el: și când moare, și când e șters (ex. ieși din Ender).
func _exit_tree() -> void:
	var bara := _bara()
	if bara != null and bara.has_method("ascunde"):
		bara.ascunde()

func _zguduie_camera() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	tw.tween_method(_shake.bind(cam), 1.0, 0.0, 0.5)
	tw.tween_callback(_shake_stop.bind(cam))

func _shake(amount: float, cam: Camera2D) -> void:
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 26.0 * amount

func _shake_stop(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
