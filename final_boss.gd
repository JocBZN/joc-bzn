extends CharacterBody2D

# SIR JOHN — boss-ul CASTELULUI (a patra dimensiune, `prison.gd`). A luat locul lui THE WARDEN pe
# 2026-08-22, când Răzvan a redenumit `harta/prison` în `harta/castle`, a golit folderul boss-ului
# și a pus înăuntru un cavaler în platoșă însângerată.
#
# ⚠️ NU MAI IESE DINTR-O STATUIE. Statuia (`prison_statue.gd`) a fost ștearsă: acum te așteaptă
# acolo din clipa în care intri, ca Celesto în Ender, și intră cu cinematică
# (`prison.gd::_cutscene_sir_john`). Cât trăiește, poarta nu te lasă să pleci.
#
# ARTA: 8 direcții × 8 cadre de MERS, tăiate din GIF-urile lui Răzvan cu `tool_taie_gifuri.ps1`,
# în `harta/castle/boss/frames/` (`walk_<directie>_<n>.png`, pânză 88×88, silueta ~61 px).
#
# ⚠️ N-ARE CADRE DE STAT PE LOC și n-are animație de atac — exact ca Celesto, și se rezolvă la
# fel: când atacă se OPREȘTE o clipă (`pauza_atac`), atât. `Idle_rotations_8dir.gif` din folder
# NU se folosește, deși pare tentant: e desenat pe pânză de 64, adică la ALTĂ SCARĂ decât mersul,
# iar cavalerul și-ar schimba mărimea când s-ar opri. (Aceeași capcană ca la pompier, 2026-08-22.)
#
# ⚠️ ARE 8 DIRECȚII, nu 4 ca Warden-ul dinaintea lui — arta nouă le are pe toate desenate, deci
# `_uita_spre` rotunjește la optime de cerc, ca la `enemy.gd` și `celesto.gd`.
#
# CUM E LUPTA — tot trei faze, ca la Warden (Răzvan a cerut structura asta pe 2026-08-17: „primul
# doar cu un atac, al 2lea cu 2 atacuri si al 3lea cu toate cele 3 si sa devina mai rapid"), dar
# cu atacurile refăcute pe efectele din `Attacks.gif`:
#   • FAZA 1 (100% → 70%) — UNDA (`prison_inel.gd`): înfige sabia în lespezi și pleacă un inel din
#     el. Singurul atac care nu te caută: „dă-te de pe mine".
#   • FAZA 2 (sub 70%)    — + LOVITURA (`prison_bolovan.gd`): cade din cer peste locul unde ești,
#     cu telegraf lung. De aici nu mai poți sta pe loc.
#   • FAZA 3 (sub 40%)    — + TĂIETURA (`castle_taietura.gd`) ȘI devine mai iute. Semiluna zboară
#     spre tine; în faza 3 sunt TREI, în evantai, deci nu mai e destul să te dai un pas la stânga.
#
# Pragurile sunt PROCENTE din viață, ca la Celesto și Saratalin: așa înseamnă același lucru la
# orice rundă, indiferent de build.

const ART := "res://harta/castle/boss/frames/"
# Aceeași ordine ca la `enemy.gd`: octantul 0 e estul, apoi în sensul acelor de ceas.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const CADRE_PE_DIRECTIE := 8
const FPS_MERS := 9.0

const INEL := preload("res://prison_inel.gd")
const LOVITURA := preload("res://prison_bolovan.gd")
const TAIETURA := preload("res://castle_taietura.gd")

# ⚠️ 140, nu 62 (urcat pe 2026-08-17, păstrat). Player-ul merge cu 215+, iar cavalerul, spre
# deosebire de Saratalin (care cade peste tine) și Celesto (care se teleportează în spatele tău),
# **n-are cum să se apropie**. La 62 îl lăsai în urmă la pas și lupta devenea o plimbare. La 140 te
# ajunge din urmă dacă stai, iar în faza 3 (×1.45 = 203) te presează serios fără să te întreacă.
@export var speed: float = 140.0
# Viață FIXĂ, nescalată cu dificultatea — ca la Saratalin (10 000) și Celesto (100 000), și din
# același motiv: pragurile de fază trebuie să cadă în același loc la fiecare rundă.
@export var max_hp: int = 260000
@export var nume: String = "SIR JOHN"
@export var xp_value: int = 240

# Cât stă pe loc după ce atacă. N-are animație de atac, deci ăsta e SINGURUL semn că a făcut ceva
# — exact soluția de la Celesto (`pauza_atac`). Fără el, atacurile par că apar din senin.
@export var pauza_atac: float = 0.30

# --- atacul 1: unda (din faza 1) ---
@export var inel_interval: float = 4.2
@export var inel_damage: int = 30
# ⚠️ 380, nu 520 ca la Warden: efectul nou are 96 px de artă (foaia `Attacks.gif`), față de 400 cât
# avea inelul de piatră. La 520 ar fi trebuit mărit de 11 ori și ieșea o pată. 380 e cât se poate
# duce fără să se vadă că e o poză mică întinsă — iar el te presează oricum, e melee.
@export var inel_raza: float = 380.0

# --- atacul 2: lovitura care cade (din faza 2) ---
@export var lovitura_interval: float = 5.5
@export var lovitura_damage: int = 42
@export var lovitura_cate: int = 1        # câte deodată (crește în faza 3)

# --- atacul 3: tăietura (din faza 3) ---
@export var taietura_interval: float = 6.5
@export var taietura_damage: int = 55
@export var taietura_viteza: float = 430.0
@export var taietura_cate: int = 3        # evantaiul din faza 3
@export var taietura_unghi: float = 0.30  # cât de larg e evantaiul, în radiani, între semiluni

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
# ADORMIT = născut pentru cinematica de intrare (`prison.gd::_cutscene_sir_john`). Se pune din
# AFARĂ, ÎNAINTE de `add_child`, ca `_ready()` să-l vadă: cât e true nu se mișcă, nu atacă și nu-și
# cere bara. `trezeste()` îl pornește.
var _adormit := false
var _faza := 1
var _pauza := 0.0
var _inel_cd := 0.0
var _lovitura_cd := 0.0
var _taietura_cd := 0.0
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
	# La INTRAREA în castel, `prison.gd` îl naște adormit și rulează cinematica: bara o cheamă
	# ATUNCI ea, nu noi.
	if not _adormit:
		var bara := _bara()
		if bara != null:
			bara.arata(nume, max_hp)
	# nu deschide lupta cu toate atacurile deodată
	_inel_cd = 1.6
	_lovitura_cd = lovitura_interval * 0.7
	_taietura_cd = taietura_interval * 0.8
	if anim != null and anim.sprite_frames != null:
		anim.play(DIRECTII[2])   # south, până se hotărăște încotro merge
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")

# O animație pe direcție, din fișiere separate (ca la Celesto). Construite la RULARE, nu într-un
# `.tres` scris de mână: 64 de UID-uri tastate manual sunt 64 de șanse de „resource not found".
func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var lipsa := 0
	for d in DIRECTII:
		frames.add_animation(d)
		frames.set_animation_speed(d, FPS_MERS)
		frames.set_animation_loop(d, true)
		for i in CADRE_PE_DIRECTIE:
			var tex := load("%swalk_%s_%d.png" % [ART, d, i]) as Texture2D
			if tex == null:
				lipsa += 1
				continue
			frames.add_frame(d, tex)
	if lipsa > 0:
		push_warning("Sir John: lipsesc %d cadre din %s (rulează --headless --import)" % [lipsa, ART])
	anim.sprite_frames = frames

# ---------- cinematica de intrare ----------
# Chemate de `prison.gd`. `adoarme()` ÎNAINTE de `add_child` (altfel `_ready` apucă să ceară bara).
func adoarme() -> void:
	_adormit = true

func trezeste() -> void:
	_adormit = false
	# ⚠️ Repornim animația EXPLICIT: după cinematică rămâne pe cadrul înghețat, iar `_uita_spre`
	# cheamă `play()` doar când se SCHIMBĂ direcția — dacă prima direcție de mers e chiar cea în
	# care a înghețat, ar rămâne o statuie care alunecă pe hartă. (Capcană prinsă la Celesto.)
	if anim != null and anim.sprite_frames != null:
		anim.play(anim.animation)

func e_adormit() -> bool:
	return _adormit

# FREEZE FRAME: se uită într-o direcție și stă pe un cadru anume. Cinematica îl folosește ca să-l
# facă să PĂȘEASCĂ: îi dă cadrul următor la fiecare pas, în loc să lase animația să curgă singură.
# Un mers care curge lin peste o lume înghețată arată ca o înregistrare pusă pe pauză greșit; un
# cadru schimbat exact pe bocanc arată ca un pas.
func ingheata_spre(dir_nume: String, cadru: int = 0) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation(dir_nume):
		return
	anim.animation = dir_nume
	anim.frame = wrapi(cadru, 0, anim.sprite_frames.get_frame_count(dir_nume))
	anim.pause()

# Direcția (ca nume de animație) dinspre el spre un punct — cinematica o cere ca să-l întoarcă
# spre player fără să știe cum sunt numerotate octantele.
func directie_spre(punct: Vector2) -> String:
	var d := punct - global_position
	if d.length() < 0.001:
		return DIRECTII[2]
	return DIRECTII[wrapi(int(round(d.angle() / (PI / 4.0))), 0, 8)]

# UNDA lui, dar DOAR ca desen: cinematica o folosește la lovitura de sabie din final, când jocul e
# pe pauză și player-ul nu poate fi lovit. Vezi `fara_damage` în `prison_inel.gd`.
func unda_de_spectacol(raza: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var n = INEL.new()
	n.damage = 0
	n.fara_damage = true
	n.raza_max = raza
	# ⚠️ ALWAYS: cinematica ține jocul pe pauză, iar un inel pauzabil ar rămâne agățat pe ecran,
	# la mărimea de start, până se termină filmulețul.
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(n)
	n.global_position = global_position

# ---------- luptă ----------
func _physics_process(delta: float) -> void:
	if _dying or _adormit:
		return   # cât ține cinematica de intrare stă pe loc: nici pas, nici atac
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()

	_inel_cd -= delta
	_lovitura_cd -= delta
	_taietura_cd -= delta

	# Pauza de după un atac: stă pe loc, dar animația merge mai departe — n-are cadre de atac,
	# deci singurul semn că a lovit e că se oprește o clipă.
	if _pauza > 0.0:
		_pauza -= delta
		velocity = Vector2.ZERO
	else:
		velocity = dir * speed
		move_and_slide()
	_uita_spre(dir)

	if _pauza > 0.0:
		return   # cât își trage sufletul nu începe alt atac

	# Ordinea: cele rare și mari înaintea celor dese, altfel unda (mereu gata) n-ar lăsa
	# niciodată loc celorlalte — aceeași regulă ca la Celesto.
	if _faza >= 3 and _taietura_cd <= 0.0:
		_taietura_cd = taietura_interval
		_taie(dir)
		return
	if _faza >= 2 and _lovitura_cd <= 0.0:
		_lovitura_cd = lovitura_interval
		_arunca_lovitura(player)
		return
	if _inel_cd <= 0.0:
		_inel_cd = inel_interval
		_scoate_inel()

# Cel mai apropiat OPTIME de cerc. `angle()` dă 0 la est și crește în sensul acelor de ceas →
# indice 0..7 în `DIRECTII`. `play()` doar când chiar se schimbă direcția (ca la `enemy.gd`),
# altfel animația s-ar lua de la capăt în fiecare cadru și ar părea înghețată.
func _uita_spre(dir: Vector2) -> void:
	if dir.length() < 0.001:
		return
	var idx := wrapi(int(round(dir.angle() / (PI / 4.0))), 0, 8)
	if anim.animation != DIRECTII[idx]:
		anim.play(DIRECTII[idx])

# ---------- atacuri ----------
# ⚠️ Variabilele de mai jos sunt NETIPIZATE dinadins. `INEL.new()` întoarce un Node2D cu scriptul
# atașat, dar dacă îl declari `var n := Node2D.new()` (sau `: Node2D`), verificarea statică din
# GDScript nu găsește `damage`/`raza_max` pe Node2D și **jocul nici nu pornește** — e eroare de
# parsare, nu de rulare. Aceeași capcană ca la `celesto.gd::_teleporteaza`.
func _scoate_inel() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_pauza = pauza_atac
	var n = INEL.new()
	n.damage = inel_damage
	n.raza_max = inel_raza
	parent.add_child(n)
	n.global_position = global_position
	Audio.play("sirjohn_slam", -2.0)

func _arunca_lovitura(player: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	_pauza = pauza_atac
	for i in maxi(1, lovitura_cate):
		var n = LOVITURA.new()
		n.damage = lovitura_damage
		parent.add_child(n)
		# prima cade fix pe tine, restul împrăștiate în jur (faza 3)
		var imprastiere := Vector2.ZERO if i == 0 else Vector2(randf_range(-220.0, 220.0), randf_range(-220.0, 220.0))
		n.global_position = player.global_position + imprastiere
	Audio.play("sirjohn_smite", -3.0)

# Tăietura: semiluna care zboară spre tine. În faza 3 sunt TREI, în evantai — una singură se
# evită dintr-un pas lateral, trei acoperă un unghi și te obligă să te miști ÎNAINTE să plece.
func _taie(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	_pauza = pauza_atac
	var cate := maxi(1, taietura_cate)
	# evantaiul se așază SIMETRIC în jurul direcției spre tine: la 3 bucăți iese -u, 0, +u
	var start := -taietura_unghi * (float(cate) - 1.0) * 0.5
	for i in cate:
		var n = TAIETURA.new()
		n.damage = taietura_damage
		n.viteza = taietura_viteza
		parent.add_child(n)
		n.global_position = global_position
		n.porneste(dir.rotated(start + taietura_unghi * float(i)))
	Audio.play("sirjohn_slash", -3.0)

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
	_lovitura_cd = 1.2      # se vede imediat ce s-a schimbat
	_anunta("SIR JOHN RAGES", "The sky starts falling")
	Audio.play("levelup", -6.0)

func _intra_in_faza3() -> void:
	var din_1 := _faza < 2
	_faza = 3
	if din_1:
		_lovitura_cd = 1.2
	# „sa devina mai rapid": și la mers, și la atacat
	speed *= furie_viteza
	inel_interval = maxf(inel_interval / furie_atac, 1.2)
	lovitura_interval = maxf(lovitura_interval / furie_atac, 1.8)
	lovitura_cate = 3
	_taietura_cd = 1.5
	_anunta("SIR JOHN DRAWS BLOOD", "Three blades, not one")
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
