extends CharacterBody2D

# THE WARDEN — boss-ul PUȘCĂRIEI, ultima dimensiune. Nu apare singur: îl scoate STATUIA
# (`prison_statue.gd`), pe care o găsești într-un inel în jurul porții de intrare. Cât trăiește,
# poarta nu te lasă să pleci.
#
# ARTA (tăiată din foile lui Răzvan de `scratchpad/extrage3.ps1`, vezi session log-ul):
#   `harta/prison/boss/frames/` — `idle_<dir>.png` și `walk_<dir>_<n>.png`.
#
# ⚠️ ARE DOAR 4 DIRECȚII (sud, nord, est, vest), nu 8 ca ceilalți. Nu e o scurtătură: atâtea sunt
# desenate. De aia `_uita_spre` rotunjește la cel mai apropiat sfert de cerc, nu la optime — pe
# diagonale se folosește direcția orizontală, care se citește mai bine (silueta din profil e
# limpede, cea din față/spate nu spune încotro merge).
#
# ⚠️ Mersul lateral are 3 cadre, cel din față/spate are 4. `_build_frames` nu presupune un număr
# fix: încarcă până nu mai găsește fișier. Dacă mai adaugi cadre, merg singure.
#
# CUM E LUPTA — trei faze, cerute așa de Răzvan („primul doar cu un atac, al 2lea cu 2 atacuri
# si al 3lea cu toate cele 3 si sa devina mai rapid"):
#   • FAZA 1 (100% → 70%) — doar INELUL de piatră (`prison_inel.gd`): unda care pleacă din el.
#     Atacul „dă-te de pe mine", singurul care nu te caută.
#   • FAZA 2 (sub 70%)   — + BOLOVANUL (`prison_bolovan.gd`): cade peste locul în care ești.
#     De aici nu mai poți sta pe loc.
#   • FAZA 3 (sub 40%)   — + RAZA (`prison_laser.gd`) ȘI devine mai iute: merge mai repede și
#     atacă mai des (`furie`). Raza lovește instantaneu pe toată lungimea, dar se încarcă vizibil.
#
# Pragurile sunt PROCENTE din viață, ca la Celesto și Saratalin: așa înseamnă același lucru la
# orice rundă, indiferent de build.

const ART := "res://harta/prison/boss/frames/"
const DIRECTII := ["east", "south", "west", "north"]   # 0 = est, apoi în sensul acelor de ceas
const MAX_CADRE := 8          # cât căutăm până ne oprim (foile au 3-4)
const FPS_MERS := 7.0

const INEL := preload("res://prison_inel.gd")
const BOLOVAN := preload("res://prison_bolovan.gd")
const LASER := preload("res://prison_laser.gd")

@export var speed: float = 62.0          # greoi: e un munte de piatră, nu un alergător
# Viață FIXĂ, nescalată cu dificultatea — ca la Saratalin (10 000) și Celesto (100 000), și din
# același motiv: pragurile de fază trebuie să cadă în același loc la fiecare rundă. Mai mult
# decât Celesto, fiindcă ca să ajungi aici trebuie să-l fi bătut deja pe el.
@export var max_hp: int = 260000
@export var nume: String = "THE WARDEN"
@export var xp_value: int = 240

# --- atacul 1: inelul (din faza 1) ---
@export var inel_interval: float = 4.2
@export var inel_damage: int = 30
@export var inel_raza: float = 520.0

# --- atacul 2: bolovanul (din faza 2) ---
@export var bolovan_interval: float = 5.5
@export var bolovan_damage: int = 42
@export var bolovan_cate: int = 1        # câți deodată (crește în faza 3)

# --- atacul 3: raza (din faza 3) ---
@export var laser_interval: float = 6.5
@export var laser_damage: int = 55
@export var laser_lungime: float = 900.0

# --- fazele ---
@export var faza2_prag: float = 0.70
@export var faza3_prag: float = 0.40
@export var furie_viteza: float = 1.45   # de câte ori e mai iute în faza 3
@export var furie_atac: float = 1.5      # de câte ori atacă mai des în faza 3

@export var death_time: float = 1.6
# Premiul: 5 NIVELURI. Saratalin dă 3, Celesto 4 — ăsta e ultimul, deci dă cel mai mult.
const NIVELURI_PREMIU := 5
@export var premiu_intarziere: float = 1.6

var hp: int
var _dying := false
var _adormit := false        # cât iese din pământ nu se mișcă și nu atacă
var _faza := 1
var _inel_cd := 0.0
var _bolovan_cd := 0.0
var _laser_cd := 0.0
var _flash_tween: Tween
var _xp1: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")
	add_to_group("boss")       # imun la instakill (Hacksaw) — vezi `bullet.gd`
	add_to_group("final_boss")
	_build_frames()
	if not _adormit:
		var bara := _bara()
		if bara != null:
			bara.arata(nume, max_hp)
	# nu deschide lupta cu toate atacurile deodată
	_inel_cd = 1.6
	_bolovan_cd = bolovan_interval * 0.7
	_laser_cd = laser_interval * 0.8
	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("idle_south"):
		anim.play("idle_south")
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")

# O animație de mers pe fiecare direcție + una de stat pe loc. Construite la RULARE, din fișiere
# separate (ca la Celesto): un `.tres` cu UID-uri scrise de mână e o listă de șanse să crape.
func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var lipsa := 0
	for d in DIRECTII:
		frames.add_animation(d)
		frames.set_animation_speed(d, FPS_MERS)
		frames.set_animation_loop(d, true)
		var n := 0
		for i in MAX_CADRE:
			# ⚠️ `ResourceLoader.exists`, nu direct `load`: mersul lateral are 3 cadre, cel din
			# față/spate are 4, deci ne oprim la primul care lipsește — dar `load` pe un fișier
			# inexistent scrie o EROARE roșie în consolă înainte să întoarcă null. Cu patru
			# direcții, asta însemna patru erori la fiecare invocare a boss-ului, degeaba.
			var cale := "%swalk_%s_%d.png" % [ART, d, i]
			if not ResourceLoader.exists(cale):
				break          # s-au terminat cadrele direcției ăsteia
			var tex := load(cale) as Texture2D
			if tex == null:
				break
			frames.add_frame(d, tex)
			n += 1
		if n == 0:
			lipsa += 1
		# poza de stat pe loc.
		# ⚠️ Tipul scris pe față: `DIRECTII` e Array netipizat, deci `d` e Variant, iar `:=` n-ar
		# avea ce să deducă din `"idle_" + d` — e eroare de PARSARE, adică jocul nici nu pornește.
		# Aceeași capcană ca la `celesto.gd::_teleporteaza`.
		var idle_nume: String = "idle_" + str(d)
		frames.add_animation(idle_nume)
		frames.set_animation_speed(idle_nume, 1.0)
		frames.set_animation_loop(idle_nume, true)
		var it := load("%sidle_%s.png" % [ART, d]) as Texture2D
		if it != null:
			frames.add_frame(idle_nume, it)
		elif n > 0:
			frames.add_frame(idle_nume, frames.get_frame_texture(d, 0))
	if lipsa > 0:
		push_warning("Warden: lipsesc cadrele a %d direcții din %s (rulează --headless --import)" % [lipsa, ART])
	anim.sprite_frames = frames

# ---------- invocarea: iese din pământ, ca Garda de la statuie ----------
func adoarme() -> void:
	_adormit = true

func iesi_din_pamant(adancime: float = 190.0, durata: float = 2.1) -> void:
	_adormit = true
	var start := anim.position
	anim.position = start + Vector2(0, adancime)
	anim.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(anim, "position", start, durata).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(anim, "modulate:a", 1.0, durata * 0.5)
	t.chain().tween_callback(trezeste)

func trezeste() -> void:
	_adormit = false
	var bara := _bara()
	if bara != null:
		bara.arata(nume, max_hp)
		bara.set_hp(hp)
	_anunta("THE WARDEN AWAKES", "The chains are off")
	Audio.play("levelup", -2.0)

# ---------- luptă ----------
func _physics_process(delta: float) -> void:
	if _dying or _adormit:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	_uita_spre(dir)

	_inel_cd -= delta
	_bolovan_cd -= delta
	_laser_cd -= delta

	# Ordinea: cele rare și mari înaintea celor dese, altfel inelul (mereu gata) n-ar lăsa
	# niciodată loc celorlalte — aceeași regulă ca la Celesto.
	if _faza >= 3 and _laser_cd <= 0.0:
		_laser_cd = laser_interval
		_trage_laser(dir)
		return
	if _faza >= 2 and _bolovan_cd <= 0.0:
		_bolovan_cd = bolovan_interval
		_arunca_bolovan(player)
		return
	if _inel_cd <= 0.0:
		_inel_cd = inel_interval
		_scoate_inel()

# Cel mai apropiat SFERT de cerc (4 direcții desenate, vezi comentariul de sus). Pe diagonale
# câștigă orizontala: profilul spune limpede încotro merge, fața/spatele nu.
func _uita_spre(dir: Vector2) -> void:
	if dir.length() < 0.001:
		return
	var idx := wrapi(int(round(dir.angle() / (PI / 2.0))), 0, 4)
	var nume_anim: String = DIRECTII[idx]
	if anim.animation != nume_anim:
		anim.play(nume_anim)

# ---------- atacuri ----------
# ⚠️ Variabilele de mai jos sunt NETIPIZATE dinadins. `INEL.new()` întoarce un Node2D cu scriptul
# atașat, dar dacă îl declari `var n := Node2D.new()` (sau `: Node2D`), verificarea statică din
# GDScript nu găsește `damage`/`raza_max` pe Node2D și **jocul nici nu pornește** — e eroare de
# parsare, nu de rulare. Aceeași capcană ca la `celesto.gd::_teleporteaza` (vezi comentariul de
# acolo despre `facing_dir()`).
func _scoate_inel() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var n = INEL.new()
	n.damage = inel_damage
	n.raza_max = inel_raza
	parent.add_child(n)
	n.global_position = global_position
	Audio.play("earthquake", Audio.QUAKE_DB - 10.0, 0.0)

func _arunca_bolovan(player: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in maxi(1, bolovan_cate):
		var n = BOLOVAN.new()
		n.damage = bolovan_damage
		parent.add_child(n)
		# primul cade fix pe tine, restul împrăștiat în jur (faza 3)
		var imprastiere := Vector2.ZERO if i == 0 else Vector2(randf_range(-220.0, 220.0), randf_range(-220.0, 220.0))
		n.global_position = player.global_position + imprastiere
	Audio.play("garda_attack", -3.0)

func _trage_laser(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var n = LASER.new()
	n.damage = laser_damage
	n.lungime = laser_lungime
	parent.add_child(n)
	n.global_position = global_position
	n.porneste(dir)

# ---------- viață, faze, moarte ----------
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
	# întâi pragul de jos: o lovitură uriașă care sare peste faza 2 te duce direct în 3
	if _faza < 3 and hp <= int(max_hp * faza3_prag):
		_intra_in_faza3()
	elif _faza < 2 and hp <= int(max_hp * faza2_prag):
		_intra_in_faza2()

func _intra_in_faza2() -> void:
	_faza = 2
	_bolovan_cd = 1.2      # se vede imediat ce s-a schimbat
	_anunta("THE WARDEN RAGES", "The ceiling starts falling")
	Audio.play("levelup", -6.0)

func _intra_in_faza3() -> void:
	var din_1 := _faza < 2
	_faza = 3
	if din_1:
		_bolovan_cd = 1.2
	# „sa devina mai rapid": și la mers, și la atacat
	speed *= furie_viteza
	inel_interval = maxf(inel_interval / furie_atac, 1.2)
	bolovan_interval = maxf(bolovan_interval / furie_atac, 1.8)
	bolovan_cate = 3
	_laser_cd = 1.5
	_anunta("THE WARDEN BURNS", "Get off the line")
	Audio.play("levelup", -4.0)

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
	remove_from_group("final_boss")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var prison := get_tree().get_first_node_in_group("prison")
	if prison != null and prison.has_method("boss_invins"):
		prison.boss_invins()
	_drop_xp.call_deferred()   # Area2D nou nu se poate adăuga în timpul fizicii (vezi enemy.gd)
	_premiu_niveluri()
	_zguduie_camera(0.8)
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(anim, "modulate", Color(2.4, 2.0, 1.6, 0.0), death_time)
	t.tween_property(anim, "position", anim.position + Vector2(0, 90.0), death_time)
	t.chain().tween_callback(queue_free)

# 🔑 Timer legat de PLAYER, nu `await` aici: nodul se șterge la capătul animației de moarte, iar
# un `await` pe un nod mort nu se mai reia niciodată (vezi `celesto.gd`).
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

func _exit_tree() -> void:
	var bara := _bara()
	if bara != null and bara.has_method("ascunde"):
		bara.ascunde()

func _zguduie_camera(durata: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	tw.tween_method(_shake.bind(cam), 1.0, 0.0, durata)
	tw.tween_callback(_shake_stop.bind(cam))

func _shake(amount: float, cam: Camera2D) -> void:
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 28.0 * amount

func _shake_stop(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

func _anunta(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
