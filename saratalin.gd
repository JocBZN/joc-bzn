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

const SHEET := "res://harta/nether/Nether Boss/Saratalin_contur.png"
const FRAME_W := 224   # lățimea unui cadru din foaie
const FRAME_H := 240
const FRAMES := 15     # câte cadre are foaia

const LIGHTNING := preload("res://lightning.tscn")

@export var speed: float = 62.0        # plutește greoi, ca un boss
# Viață FIXĂ, nu scalată cu dificultatea ca la ceilalți inamici: e o luptă de boss cu bară pe
# ecran și cu o fază care începe exact la jumătate, deci trebuie să fie același prag de fiecare
# dată. Damage-ul și viteza lui cresc în continuare cu runda — doar viața stă pe loc.
@export var max_hp: int = 10000
@export var nume: String = "SARATALIN"   # ce scrie deasupra barei
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
# Proiectilul lui e ȘTREANGUL (`Saratalin Attack.png`), nu bastona Gărzii. Cadrele rotite
# cu contur mov sunt generate de `tool_contur.gd` — aceeași unealtă care a făcut bastona,
# deci arată la fel de „vrăjit". Colorizarea e ușoară: doar ridică movul și luminozitatea,
# ca să prindă glow-ul din `atmosphere.gd`, fără să înece culoarea funiei.
const BOLT_FRAMES := "res://harta/nether/Nether Boss/attack_frames/"
@export var bolt_tint: Color = Color(1.2, 1.0, 1.25)

# --- Atacul special: un CERC de proiectile în toate direcțiile ---
# Garda trage o rafală spre tine; Saratalin umple ecranul în jurul lui, deci nu poți sta
# lipit de el. Ca să te ferești trebuie să te miști printre raze, nu doar să fugi în lateral.
@export var ring_interval: float = 8.0   # o dată la câte secunde
@export var ring_count: int = 14         # câte proiectile are cercul

# --- FAZA 2: la jumătatea vieții ---
# Când ajunge la 50% viață, jocul îngheață, camera intră pe el, pulsează mov de două ori,
# urmează un cutremur mov — și de acolo încolo atacă de FURIE_ATAC ori mai des.
@export var furie_atac: float = 3.0      # de câte ori mai repede atacă în faza 2
# Atacul NOU, doar în faza 2: o salvă de proiectile ȚINTITE, unul după altul, foarte rapid.
# Ca rafala Gărzii, dar de 5 în loc de 3. Ținta se recitește la fiecare proiectil, deci
# salva te urmărește dacă fugi — nu pleacă toate spre locul unde erai la prima.
@export var salva_shots: int = 5
@export var salva_gap: float = 0.10      # pauza ÎNTRE proiectilele salvei (mic = salvă strânsă)
@export var salva_interval: float = 6.0  # o dată la câte secunde
@export var cin_zoom: float = 1.7        # cât de aproape intră camera (1 = neschimbat)
@export var cin_intrare: float = 0.55    # cât durează apropierea camerei
@export var cin_puls: float = 0.42       # cât ține UN puls mov
@export var cin_cutremur: float = 1.0    # cât ține cutremurul mov
@export var cin_iesire: float = 0.45     # cât durează întoarcerea camerei
const CULOARE_PULS := Color(3.2, 0.8, 4.0)   # peste 1 = strălucește (prinde glow-ul din atmosphere.gd)

var hp: int
var _dying := false
var _coboara := false     # cât timp coboară din tavan nu atacă și nu se mișcă singur
var _faza2 := false       # a trecut de jumătatea vieții (cinematica s-a jucat o dată)
var _cinematic := false   # rulează cinematica ACUM (nu se mișcă, nu atacă)
var _atk_cooldown := 0.0
var _ring_cooldown := 0.0
# salva de faza 2, derulată cu un contor din `_physics_process` (NU cu `await`): dacă moare
# la mijlocul salvei, contorul dispare odată cu nodul — o corutină și-ar relua firul pe un
# nod deja eliberat. Același tipar ca rafala Gărzii.
var _salva_left := 0
var _salva_timer := 0.0
var _salva_cooldown := 0.0
var _flash_tween: Tween

var _xp1: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# se întărește cu dificultatea, exact ca Garda și ca inamicii normali. În Nether,
	# `Difficulty.mult_time_override` e scris de `nether.gd`, deci un Saratalin chemat
	# după Nether Swarm e mult mai tare decât unul chemat în primul minut.
	# viața rămâne fixă (vezi `max_hp`); doar viteza urmează dificultatea rundei
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")   # ca gloanțele să-l lovească și să facă damage la contact
	add_to_group("boss")    # IMUN la instakill (Hacksaw) — vezi `bullet.gd` / `player.gd`
	add_to_group("saratalin")
	var bara := _bara()
	if bara != null:
		bara.arata(nume, max_hp)
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

# ---------- cinematica de la jumătatea vieții ----------
# ÎNGHEAȚĂ jocul, camera intră pe el, pulsează mov de două ori, urmează un cutremur mov,
# apoi totul revine la normal — dar de acum atacă de `furie_atac` ori mai des.
#
# Ca să meargă cu jocul pe pauză ne punem NOI pe `PROCESS_MODE_ALWAYS`: un tween e legat de
# nodul care l-a creat și se oprește dacă acel nod e pe pauză. `_cinematic` ține
# `_physics_process` mut cât ține treaba, ca să nu ne mișcăm și să nu tragem între timp.
func _cinematica_faza2() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_infurie()
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	_cinematic = true
	var mod_vechi := process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# ÎNGHEȚ TOTAL. Pauza oprește deja player-ul, inamicii și gloanțele, dar mai rămâneau
	# două lucruri care se mișcau peste filmuleț:
	#   • `Fx` (numerele de damage, scânteile) e autoload cu PROCESS_MODE_ALWAYS — îl trecem
	#     pe „pauzabil" cât ține treaba și îl punem la loc după;
	#   • cronometrul de tras al player-ului putea scoate un ultim glonț chiar în cadrul în
	#     care s-a declanșat pauza (cinematica pornește dintr-o lovitură, adică din fizică).
	var fx_vechi := Fx.process_mode
	Fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	if player.fire_timer != null:
		player.fire_timer.stop()
	# Lovitura care a declanșat cinematica tocmai a pornit sclipirea albă (`_flash`), care
	# animează ACEEAȘI proprietate ca pulsurile mov. Lăsată în viață, ea trage `modulate`
	# înapoi spre alb și movul nu se mai vede deloc. O oprim și pornim de la culoare curată.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	anim.modulate = Color(1, 1, 1)

	# 1) camera intră pe el: mutăm privirea de la player spre boss și strângem zoom-ul
	var zoom_vechi := Vector2.ONE
	var offset_vechi := Vector2.ZERO
	var neted_vechi := false
	var tinta := Vector2.ZERO
	if cam != null:
		zoom_vechi = cam.zoom
		offset_vechi = cam.offset
		neted_vechi = cam.position_smoothing_enabled
		# netezirea camerei se face în procesarea ei internă, care NU rulează pe pauză;
		# lăsată pornită, camera ar rămâne blocată pe loc tot filmulețul
		cam.position_smoothing_enabled = false
		tinta = global_position - player.global_position
		var t := create_tween().set_parallel()
		t.tween_property(cam, "offset", tinta, cin_intrare)
		t.tween_property(cam, "zoom", zoom_vechi * cin_zoom, cin_intrare)
		await t.finished

	# 2) două pulsuri mov pe el — FIECARE puls își pornește propriul sunet, la momentul lui.
	# Nu un sunet lung peste tot filmulețul: câte o instanță per aprindere (`Audio.play` ia o
	# boxă liberă de fiecare dată, deci se pot suprapune fără să se taie una pe alta).
	# `pitch_rand = 0` — pulsurile trebuie să sune identic, nu ușor diferit ca gloanțele.
	for i in 2:
		var p := create_tween()
		Audio.play("saratalin_flash", -4.0, 0.0)
		p.tween_property(anim, "modulate", CULOARE_PULS, cin_puls * 0.4)
		p.tween_property(anim, "modulate", Color(1, 1, 1), cin_puls * 0.6)
		await p.finished

	# 3) cutremur — MOVUL rămâne pe EL, nu pe ecran: se aprinde și ține aprins cât se zguduie.
	# E tot o aprindere, deci primește și el sunetul, plus bubuitura de cutremur peste.
	var g := create_tween()
	g.tween_property(anim, "modulate", CULOARE_PULS, 0.15)
	Audio.play("saratalin_flash", -4.0, 0.0)
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)   # bubuitura de cutremur peste aprindere
	await _cutremur(cam, tinta).finished
	await create_tween().tween_property(anim, "modulate", Color(1, 1, 1), 0.3).finished

	# 4) camera înapoi la player (readuce și offset-ul la zero după zguduire)
	if cam != null:
		var t2 := create_tween().set_parallel()
		t2.tween_property(cam, "offset", offset_vechi, cin_iesire)
		t2.tween_property(cam, "zoom", zoom_vechi, cin_iesire)
		await t2.finished
		cam.position_smoothing_enabled = neted_vechi

	Fx.process_mode = fx_vechi
	if player.fire_timer != null:
		player.fire_timer.start()
	get_tree().paused = false
	process_mode = mod_vechi
	_cinematic = false
	_infurie()

# Cutremurul din cinematică: zgâlțâie offset-ul camerei în jurul poziției pe care o privim.
# Tween-ul e creat pe NOI (suntem ALWAYS), fiindcă unul creat pe cameră ar sta pe pauză.
func _cutremur(cam: Camera2D, baza: Vector2) -> Tween:
	var t := create_tween()
	if cam == null:
		t.tween_interval(cin_cutremur)
		return t
	t.tween_method(func(amount: float):
		cam.offset = baza + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * land_shake * 1.6 * amount,
		1.0, 0.0, cin_cutremur)
	return t

# De aici încolo atacă de `furie_atac` ori mai des.
func _infurie() -> void:
	attack_interval = maxf(attack_interval / furie_atac, 0.05)
	ring_interval = maxf(ring_interval / furie_atac, 0.5)
	_atk_cooldown = 0.0
	_ring_cooldown = ring_interval
	_salva_cooldown = salva_interval * 0.5   # nu deschide cu salva fix când se termină filmulețul

# Adevărat cât rulează filmulețul — `pause.gd` întreabă, ca ESC să nu-l întrerupă.
func in_cinematic() -> bool:
	return _cinematic

func _bara() -> Node:
	return get_tree().get_first_node_in_group("boss_bar")

# Bara dispare odată cu el: și când moare, și când e șters (ex. ieși din Nether).
func _exit_tree() -> void:
	var bara := _bara()
	if bara != null and bara.has_method("ascunde"):
		bara.ascunde()

# ---------- luptă ----------
func _physics_process(delta: float) -> void:
	if _dying or _coboara or _cinematic:
		return   # cât coboară / cât ține cinematica nu se mișcă singur și nu atacă
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
	_salva_cooldown -= delta
	var in_range := global_position.distance_to(player.global_position) <= attack_range

	# salvă în curs: scoate proiectilele unul după altul, spre unde ești ACUM
	if _salva_left > 0:
		_salva_timer -= delta
		if _salva_timer <= 0.0:
			_trage(dir)
			_salva_left -= 1
			_salva_timer = salva_gap
		return   # cât ține salva, restul atacurilor tac

	# cercul de proiectile pleacă indiferent cât de departe ești — e atacul lui de zonă
	if _ring_cooldown <= 0.0:
		_ring_cooldown = ring_interval
		_atk_cooldown = maxf(_atk_cooldown, attack_interval * 0.5)  # să nu se lipească de cerc
		_trage_cerc()
		return

	# salva de 5 — o are DOAR după cinematică
	if _faza2 and _salva_cooldown <= 0.0 and in_range:
		_salva_cooldown = salva_interval
		_salva_left = salva_shots
		_salva_timer = 0.0   # primul proiectil pleacă imediat
		# ca atacul obișnuit să nu se lipească de coada salvei
		_atk_cooldown = maxf(_atk_cooldown, salva_shots * salva_gap + attack_interval * 0.5)
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
	proj.frame_dir = BOLT_FRAMES
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
	var bara := _bara()
	if bara != null:
		bara.set_hp(hp)
	if hp <= 0:
		_die()
		return
	_flash()   # sclipire albă scurtă la fiecare lovitură
	# a scăzut sub jumătate → o singură dată, cinematica de fază 2
	if not _faza2 and hp <= max_hp / 2:
		_faza2 = true
		_cinematica_faza2()

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
