extends CharacterBody2D

# CELESTO — boss-ul dimensiunii ENDER. Te așteaptă acolo din clipa în care intri (`ender.gd` îl
# pune într-un inel în jurul fântânii de întoarcere) și, cât timp trăiește, fântâna nu se
# deschide. A luat locul lui „Undead Executioner Puppet" pe 2026-08-04, când Răzvan i-a adus
# arta nouă; foile vechi nu mai sunt pe disc.
#
# ARTA: 8 direcții × 8 cadre de MERS, fișiere separate, în `harta/Portal Ender/Celesto/frames/`
# (`walk_<directie>_<n>.png`, 128×128). Direcțiile `west` și `north_west` sunt oglindite din
# perechile lor de est de `tool_celesto.gd` (recentrate, ca să nu sară lateral la schimbarea
# direcției).
#
# CONTURUL ALBASTRU (podeaua Ender-ului e o nebuloasă aproape neagră, iar silueta lui e neagră —
# fără contur ar fi o gaură în ecran) NU mai e copt în poze: îl desenează `contur_1px.gdshader`,
# pus pe sprite din scenă. Copt ar fi ieșit gros cât 1px ÎNMULȚIT cu scale-ul de 3.2; din shader
# rămâne 1 pixel de ecran. De aia se citește `frames/`, nu `frames_contur/`.
#
# ⚠️ ARE DOAR MERS. Fără animație de atac, de invocare sau de moarte — deci, spre deosebire de
# Saratalin și de boss-ul dinainte, aici NU se așteaptă un „cadru al loviturii": coasa pleacă
# din secunda în care se decide atacul, iar el doar se oprește o clipă (`_pauza_atac`) ca să se
# vadă că a aruncat. Moartea e un fade, nu o foaie de cadre.
#
# CUM E LUPTA (praguri în procente din viață, ca să însemne același lucru la orice rundă):
#   • FAZA 1 (100% → 75%) — merge spre tine și aruncă: coasă țintită, bumerang, cerc de coase;
#   • FAZA 2 (sub 75%) — începe să se TELEPORTEZE în spatele tău la fiecare 8s, cheamă creaturi
#     și atacă mai des;
#   • FAZA 3 (sub 50%) — se teleportează la 4s și, la fiecare 10s, aruncă o COASĂ URIAȘĂ (×3 ca
#     desen și ca hitbox) spre tine, cu cutremur.

const ART := "res://harta/Portal Ender/Celesto/frames/"
# Aceeași ordine ca la `enemy.gd`: octantul 0 e estul, apoi în sensul acelor de ceas.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const CADRE_PE_DIRECTIE := 8
const FPS_MERS := 10.0

# --- cinematica de intrare (`ender.gd::_cutscene_celesto`) ---
# Acolo NU merge pe loc: stă pe un singur cadru („freeze frame"), din profil. Când sare în
# dreapta cadrului se uită spre stânga și invers — deci mereu spre mijloc, niciodată spre tine.
const CUT_DIR_DREAPTA := "west"   # e în DREAPTA ecranului → se uită spre vest
const CUT_DIR_STANGA := "east"    # e în STÂNGA ecranului → se uită spre est
const CUT_CADRU := 0              # pe ce cadru din mers îngheață

const SCYTHE := preload("res://scythe.tscn")
# Ce cheamă din faza 2: inamicii Ender-ului, aceiași care curg oricum din `spawner.gd` cât ești
# dincolo. (Până pe 2026-08-04 chema creaturile Nether-ului, fiindcă Ender-ul n-avea ale lui.)
const SLUGA := preload("res://enemy_ender.tscn")

@export var speed: float = 74.0          # plutește, ca Saratalin, dar puțin mai iute
# Viață FIXĂ, nescalată cu dificultatea — la fel ca la Saratalin, și din același motiv: e o
# luptă cu bară pe ecran și cu faze care încep la praguri fixe, deci pragurile trebuie să
# însemne același lucru la fiecare rundă. Mult mai mult decât Saratalin (10 000): ca să ajungi
# aici trebuie să-l fi bătut deja pe el.
@export var max_hp: int = 100000
@export var nume: String = "CELESTO THE ETERNAL"     # ce scrie deasupra barei (tradus în `i18n.gd`)
@export var xp_value: int = 150          # se înmulțește cu bonusul de XP al Ender-ului

# --- atacul obișnuit: aruncă o coasă spre tine ---
@export var attack_range: float = 560.0
@export var attack_interval: float = 2.0
@export var scythe_damage: int = 22
@export var scythe_speed: float = 340.0
@export var pauza_atac: float = 0.35     # cât stă pe loc după ce aruncă (n-are animație de atac)

# --- bumerangul: coasa aruncată ÎN DIRECȚIA OPUSĂ ție, care se întoarce după tine ---
@export var bumerang_interval: float = 6.0
@export var bumerang_raza: float = 420.0     # câți pixeli se duce în spate până se oprește
@export var bumerang_damage: int = 26        # lovește la întoarcere, din spate: doare mai tare
# ⚠️ Pleacă mult mai repede decât o coasă obișnuită, și nu de dragul spectacolului: frânând pe o
# distanță fixă, timpul până se oprește e `2·rază/viteză`. La viteza normală (340) ar fi însemnat
# 2,5 secunde numai dusul — o armă pe care o uiți până se întoarce. La 700 ajunge în ~1,2s.
@export var bumerang_speed: float = 700.0

# --- cercul de coase, atacul lui de zonă ---
@export var ring_interval: float = 9.0
@export var ring_count: int = 12

# --- faza 2: teleportare + creaturi + mai des ---
@export var faza2_prag: float = 0.75         # sub 75% din viață (i-ai luat un sfert)
@export var teleport_interval: float = 8.0
@export var teleport_distanta: float = 50.0  # la câți pixeli în spatele tău apare
@export var furie_atac: float = 1.6          # de câte ori mai des atacă din faza 2
@export var summon_interval: float = 11.0
@export var summon_count: int = 4            # câte creaturi cheamă odată
@export var summon_radius: float = 260.0     # la ce distanță de el apar

# --- faza 3: teleportare de două ori mai deasă + coasa uriașă ---
@export var faza3_prag: float = 0.50         # sub jumătate de viață
@export var teleport_interval_f3: float = 4.0
@export var coasa_mare_interval: float = 10.0
@export var coasa_mare_marime: float = 3.0   # de câte ori e mai mare (desen ȘI hitbox)
@export var coasa_mare_damage: int = 45
@export var coasa_mare_speed: float = 260.0  # mai lentă decât cele mici: se vede venind

var hp: int
# ADORMIT = născut pentru cinematica de intrare (`ender.gd::_cutscene_celesto`). Se pune din afară,
# ÎNAINTE de `add_child`, ca `_ready()` să-l vadă: cât e true, nu se mișcă, nu atacă și nu-și cere
# bara. `trezeste()` îl pornește.
var _adormit := false
var _dying := false
var _faza := 1
var _pauza := 0.0             # cât mai stă pe loc după o aruncare
var _atk_cooldown := 0.0
var _ring_cooldown := 0.0
var _bumerang_cooldown := 0.0
var _summon_cooldown := 0.0
var _teleport_cooldown := 0.0
var _coasa_mare_cooldown := 0.0
var _flash_tween: Tween
var _xp1: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# ca la ceilalți: viteza urmează dificultatea rundei, viața nu
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")         # ca gloanțele să-l lovească
	add_to_group("boss")          # IMUN la instakill (Hacksaw) — vezi `bullet.gd`
	add_to_group("celesto")
	# La INTRAREA în Ender, `ender.gd` îl naște adormit și rulează cinematica: apare din nimic,
	# îi urcă bara pe ecran, apoi dispare la locul lui și abia atunci începe lupta. Bara o cheamă
	# ATUNCI cinematica, nu noi — de aia sărim peste `arata()` aici.
	if not _adormit:
		var bara := _bara()
		if bara != null:
			bara.arata(nume, max_hp)
	# nu deschide lupta cu toate atacurile deodată
	_ring_cooldown = ring_interval * 0.5
	_bumerang_cooldown = bumerang_interval * 0.6
	_summon_cooldown = summon_interval * 0.5
	_build_frames()
	if _adormit:
		# Cinematica de intrare îl vrea ÎNGHEȚAT și din PROFIL (cerut de Răzvan pe 2026-08-06:
		# „freeze frame … si sa nu se uite in sud"). `ender.gd` îi dă direcția la fiecare salt;
		# asta e doar poza de start, aceeași cu primul salt, ca să nu se întoarcă degeaba.
		ingheata_spre(CUT_DIR_DREAPTA)
	else:
		anim.play(DIRECTII[2])    # south, până se hotărăște încotro merge
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")

# O animație pe direcție, din fișiere separate (nu foi de cadre ca la Saratalin). Construite la
# rulare, nu într-un `.tres` scris de mână: 64 de UID-uri tastate manual sunt 64 de șanse de
# „resource not found" în joc.
func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var lipsa := 0
	for dir_nume in DIRECTII:
		frames.add_animation(dir_nume)
		frames.set_animation_speed(dir_nume, FPS_MERS)
		frames.set_animation_loop(dir_nume, true)
		for i in CADRE_PE_DIRECTIE:
			var cale := "%swalk_%s_%d.png" % [ART, dir_nume, i]
			var tex := load(cale) as Texture2D
			if tex == null:
				lipsa += 1
				continue
			frames.add_frame(dir_nume, tex)
	if lipsa > 0:
		push_warning("Celesto: lipsesc %d cadre din %s (rulează --headless --import)" % [lipsa, ART])
	anim.sprite_frames = frames

# ---------- luptă ----------
func _physics_process(delta: float) -> void:
	if _dying or _adormit:
		return   # cât ține cinematica de intrare stă pe loc: nici pas, nici atac
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()

	_atk_cooldown -= delta
	_ring_cooldown -= delta
	_bumerang_cooldown -= delta
	_summon_cooldown -= delta
	_teleport_cooldown -= delta
	_coasa_mare_cooldown -= delta

	# Pauza de după o aruncare: stă pe loc, dar animația merge mai departe — n-are cadre de
	# atac, deci singurul semn că a aruncat ceva e că se oprește o clipă.
	if _pauza > 0.0:
		_pauza -= delta
		velocity = Vector2.ZERO
	else:
		velocity = dir * speed
		move_and_slide()
	_uita_spre(dir)

	# Teleportarea nu e un atac, e o repoziționare: se poate întâmpla oricând, chiar și în pauză.
	if _faza >= 2 and _teleport_cooldown <= 0.0:
		_teleport_cooldown = teleport_interval_f3 if _faza >= 3 else teleport_interval
		_teleporteaza(player)

	if _pauza > 0.0:
		return   # cât își trage sufletul după o aruncare nu începe alta

	# Ordinea contează: cele rare și mari trec înaintea celor dese și mici, altfel atacul
	# obișnuit, care e mereu gata, n-ar lăsa niciodată loc celorlalte.
	if _faza >= 3 and _coasa_mare_cooldown <= 0.0:
		_coasa_mare_cooldown = coasa_mare_interval
		_arunca_coasa_mare(dir)
		return
	if _ring_cooldown <= 0.0:
		_ring_cooldown = ring_interval
		_cerc_de_coase()
		return
	if _bumerang_cooldown <= 0.0:
		_bumerang_cooldown = bumerang_interval
		_arunca_bumerang(dir)
		return
	if _faza >= 2 and _summon_cooldown <= 0.0:
		_summon_cooldown = summon_interval
		_cheama_slugi()
		return
	if _atk_cooldown <= 0.0 and global_position.distance_to(player.global_position) <= attack_range:
		_atk_cooldown = attack_interval
		_arunca_coasa(dir)

# Ce animație joacă: octantul spre care merge. `angle()` dă 0 la est și crește în sensul acelor
# de ceas → indice 0..7 în `DIRECTII`. `play()` doar când chiar se schimbă direcția (ca la
# `enemy.gd`), altfel animația s-ar lua de la capăt în fiecare cadru și ar părea înghețată.
# ---------- cinematica de intrare ----------
# Chemate de `ender.gd`. `adoarme()` ÎNAINTE de `add_child` (altfel `_ready` apucă să ceară bara).
func adoarme() -> void:
	_adormit = true

func trezeste() -> void:
	_adormit = false
	# ⚠️ Repornim animația EXPLICIT. După cinematică rămâne pe cadrul înghețat, iar `_uita_spre`
	# cheamă `play()` doar când se SCHIMBĂ direcția — dacă prima direcție de mers e chiar cea în
	# care a înghețat, ar rămâne o statuie care alunecă pe hartă.
	if anim != null and anim.sprite_frames != null:
		anim.play(anim.animation)

func e_adormit() -> bool:
	return _adormit

# Sclipirea albastră de teleportare, cerută din AFARĂ. În cinematica de intrare teleportările le
# dă `ender.gd` (boss-ul e adormit, deci nu se mută singur), dar semnul vizual e tot al lui.
func puf() -> void:
	_puf()

# ---------- umbra rămasă în urmă la teleportare ----------
# Silueta lui, plată și albastră, lăsată în locul din care tocmai a plecat: se umflă puțin și se
# stinge în 0,3s. E singurul lucru care face o teleportare CITIBILĂ — fără ea, ochiul vede doar
# „era acolo / e dincolo" și mișcarea se pierde între două cadre. Se cheamă cu poziția VECHE,
# ÎNAINTE de mutare.
const UMBRA_SHADER := preload("res://celesto_umbra.gdshader")
const UMBRA_TIMP := 0.30
const UMBRA_CRESTE := 1.16   # cât se umflă cât se stinge (o urmă care „se destramă")
const UMBRA_ALFA := 0.80

func umbra(la: Vector2) -> void:
	var parent := get_parent()
	if parent == null or anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation(anim.animation):
		return
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = anim.scale
	s.z_index = anim.z_index - 1          # sub el: urma nu trebuie să-i acopere silueta
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # ca sprite-ul lui: pixeli, nu ceață
	var mat := ShaderMaterial.new()
	mat.shader = UMBRA_SHADER
	s.material = mat
	s.modulate.a = UMBRA_ALFA
	# ⚠️ Merge ȘI pe pauză, cu tween cu tot: în cinematica de intrare (`ender.gd`) jocul e înghețat,
	# iar o umbră pauzabilă ar rămâne agățată pe ecran până se termină filmulețul.
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(s)
	s.global_position = la
	var t := s.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_parallel(true)
	t.tween_property(s, "modulate:a", 0.0, UMBRA_TIMP)
	t.tween_property(s, "scale", anim.scale * UMBRA_CRESTE, UMBRA_TIMP)
	t.chain().tween_callback(s.queue_free)

# FREEZE FRAME pentru cinematică: se uită într-o direcție și STĂ, pe un singur cadru — nu merge
# pe loc. Chemată de `ender.gd` la fiecare salt: sare în dreapta → se uită spre WEST, sare în
# stânga → spre EAST, deci mereu spre mijlocul cadrului și niciodată spre tine (sud).
# `pause()` (nu `stop()`) ca să rămână pe cadrul cerut; repornirea o face `trezeste()`.
func ingheata_lateral(la_dreapta: bool) -> void:
	ingheata_spre(CUT_DIR_DREAPTA if la_dreapta else CUT_DIR_STANGA)

func ingheata_spre(dir_nume: String, cadru: int = CUT_CADRU) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation(dir_nume):
		return
	anim.animation = dir_nume
	anim.frame = mini(cadru, anim.sprite_frames.get_frame_count(dir_nume) - 1)
	anim.pause()

func _uita_spre(dir: Vector2) -> void:
	if dir.length() < 0.001:
		return
	var idx := wrapi(int(round(dir.angle() / (PI / 4.0))), 0, 8)
	if anim.animation != DIRECTII[idx]:
		anim.play(DIRECTII[idx])

# ---------- atacuri ----------
# Coasa obișnuită: pleacă spre tine.
func _arunca_coasa(dir: Vector2) -> void:
	_pauza = pauza_atac
	Audio.play("garda_attack")
	var c := _coasa(scythe_damage, scythe_speed)
	if c != null:
		_lanseaza(c, dir)

# Bumerangul: pleacă în direcția OPUSĂ ție (deci prin spatele lui), se oprește după
# `bumerang_raza` pixeli și se întoarce țintindu-te. Zborul e tot în `scythe.gd`.
func _arunca_bumerang(dir: Vector2) -> void:
	_pauza = pauza_atac
	Audio.play("garda_attack", -1.0)
	var c := _coasa(bumerang_damage, bumerang_speed)
	if c == null:
		return
	c.bumerang = true
	c.raza_intoarcere = bumerang_raza
	c.lifetime = 8.0     # dus-întors durează mai mult decât o aruncare dreaptă
	_lanseaza(c, -dir)

# Cercul: coase în toate direcțiile, indiferent cât de departe ești.
func _cerc_de_coase() -> void:
	_pauza = pauza_atac
	Audio.play("garda_attack", -2.0)
	for i in ring_count:
		var unghi := TAU * float(i) / float(ring_count)
		var c := _coasa(scythe_damage, scythe_speed)
		if c != null:
			_lanseaza(c, Vector2(cos(unghi), sin(unghi)))

# Faza 3: coasa uriașă, ×3 ca desen ȘI ca hitbox, cu cutremur — nu e doar sunet, zguduie și
# camera, ca la statuie și la portalul care se scufundă.
func _arunca_coasa_mare(dir: Vector2) -> void:
	_pauza = pauza_atac * 2.0    # se vede că e altceva: stă de două ori mai mult
	Audio.play("earthquake", Audio.QUAKE_DB - 6.0, 0.0)
	_zguduie_camera(0.5)
	var c := _coasa(coasa_mare_damage, coasa_mare_speed)
	if c == null:
		return
	c.marime = coasa_mare_marime
	c.spin = 5.0             # cât e de mare, la viteza mică arată ca o elice
	_lanseaza(c, dir)

# Nașterea unei coase e ruptă în DOUĂ pe intenție: `_coasa()` o face și îi pune ce au toate,
# apoi cel care a chemat-o îi mai scrie ce vrea, și abia la urmă `_lanseaza()` o bagă în lume.
# ⚠️ Ordinea nu e stil: `scythe.gd` își citește proprietățile o SINGURĂ dată, în `_ready()`,
# adică fix la `add_child`. Ce scrii după aia (mărime, bumerang) nu mai are niciun efect.
func _coasa(dmg: int, viteza: float) -> Node2D:
	if get_parent() == null:
		return null
	var c := SCYTHE.instantiate()
	c.damage = maxi(1, int(round(dmg * Difficulty.enemy_damage_mult())))
	c.speed = viteza
	return c

func _lanseaza(c: Node2D, dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		c.queue_free()
		return
	parent.add_child(c)
	c.global_position = global_position + dir * 80.0
	c.set_direction(dir)

# ---------- faza 2: teleportarea ----------
# Apare la `teleport_distanta` pixeli ÎN SPATELE player-ului — în spate față de unde se uită EL
# (`facing_dir()`), nu față de unde stă Celesto. Deci dacă fugi, ți-l găsești pe urme.
func _teleporteaza(player: Node2D) -> void:
	# tipuri scrise pe față: `facing_dir()` vine de pe un `Node2D` netipizat, deci `:=` n-ar avea
	# ce să deducă (eroare de parsare, nu de rulare — jocul nici n-ar porni)
	var spate: Vector2 = -player.facing_dir() if player.has_method("facing_dir") else Vector2.UP
	var tinta: Vector2 = player.global_position + spate * teleport_distanta
	Audio.play("celesto_teleport", -2.0, 0.0)
	umbra(global_position)   # urma rămâne unde ERA, deci se vede de unde a plecat
	global_position = tinta
	_puf()
	_uita_spre((player.global_position - global_position).normalized())

# Semnul vizibil al teleportării: o sclipire albastră scurtă când aterizează. Fără ea ar clipi
# pur și simplu dintr-un colț în altul și n-ai înțelege ce s-a întâmplat.
func _puf() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(1.6, 2.2, 4.0)   # albastrul lui, dus la lumină
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.25)

# Faza 2: cheamă creaturi în jurul LUI, nu peste tine — altfel ar apărea lipite de player și ai
# mânca damage din nimic.
func _cheama_slugi() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_pauza = pauza_atac
	Audio.play("earthquake", Audio.QUAKE_DB - 12.0, 0.0)
	for i in summon_count:
		var unghi := TAU * float(i) / float(summon_count) + randf() * 0.6
		var e := SLUGA.instantiate()
		parent.add_child(e)
		e.global_position = global_position + Vector2(cos(unghi), sin(unghi)) * summon_radius

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
	# ordinea: întâi pragul de jos, ca o lovitură uriașă care sare peste faza 2 să te ducă
	# direct în 3 (și tot să anunțe o singură dată)
	if _faza < 3 and hp <= int(max_hp * faza3_prag):
		_intra_in_faza3()
	elif _faza < 2 and hp <= int(max_hp * faza2_prag):
		_intra_in_faza2()

func _intra_in_faza2() -> void:
	_faza = 2
	attack_interval = maxf(attack_interval / furie_atac, 0.25)
	ring_interval = maxf(ring_interval / furie_atac, 2.0)
	_teleport_cooldown = 1.0    # prima teleportare vine repede, ca să se vadă ce s-a schimbat
	_summon_cooldown = 1.5
	_announce("CELESTO VANISHES", "It starts appearing behind you")
	Audio.play("levelup", -6.0)

func _intra_in_faza3() -> void:
	var din_1 := _faza < 2
	_faza = 3
	if din_1:
		# n-a trecut prin faza 2 (o lovitură l-a dus direct sub jumătate): îi luăm și de acolo
		attack_interval = maxf(attack_interval / furie_atac, 0.25)
		ring_interval = maxf(ring_interval / furie_atac, 2.0)
		_summon_cooldown = 1.5
	_teleport_cooldown = 1.0
	_coasa_mare_cooldown = 2.5
	_announce("CELESTO REAPS", "A greater scythe, twice as often")
	Audio.play("levelup", -4.0)

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(5, 5, 5)
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.12)

# N-are foaie de moarte (are doar mers), deci se stinge: se umflă puțin, se face lumină și
# dispare. Tot ce ține de „nu mai lovește pe nimeni" se face ÎNAINTE de tween.
@export var death_time: float = 1.2

func _die() -> void:
	_dying = true
	GameSettings.add_kill()
	remove_from_group("enemy")
	remove_from_group("celesto")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	# ieșirea din Ender e închisă până cade el
	var ender := get_tree().get_first_node_in_group("ender")
	if ender != null:
		ender.boss_invins()
	_drop_xp.call_deferred()   # un Area2D nou nu se poate adăuga în timpul fizicii (vezi enemy.gd)
	_premiu_niveluri()
	_zguduie_camera(0.5)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(anim, "modulate", Color(3.0, 3.6, 6.0, 0.0), death_time)
	t.tween_property(anim, "scale", anim.scale * 1.25, death_time)
	t.chain().tween_callback(queue_free)

# Premiul: 4 NIVELURI. Saratalin dă 3, iar ca să ajungi aici trebuie să-l fi bătut întâi pe el.
const NIVELURI_PREMIU := 4
@export var premiu_intarziere: float = 1.6   # cât aștepți până sar ecranele de ales

# 🔑 Timer legat de PLAYER, nu `await` aici: nodul se șterge la capătul animației de moarte,
# iar un `await` pe un nod mort nu se mai reia niciodată. Întârzierea nu e cosmetică: fără ea,
# ecranul de level up pune jocul pe pauză peste moartea lui și peste anunț.
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
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 26.0 * amount

func _shake_stop(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
