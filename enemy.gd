extends CharacterBody2D

# Numele animațiilor pe octanți (după unghi), în ordinea 0=est, apoi din 45° în 45°.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 120.0
@export var max_hp: int = 30
@export var knockback_decay: float = 900.0  # cât de repede se stinge împinsul (px/s pe secundă)

# Înmulțitor de PUTERE pus din AFARĂ, de `spawner.gd`, înainte ca inamicul să intre în arbore
# (deci înainte de `_ready`, unde se aplică). Serveșe unui singur lucru deocamdată: după ce
# player-ul se întoarce viu din Nether, POLIȚIȘTII lumii normale devin de două ori mai grași
# (vezi `spawner.gd::escaped_power_mult`). Creaturile din Nether nu-l primesc — ele sunt deja
# tari, și așa au rămas, cum a cerut Răzvan pe 2026-07-30.
#
# ⚠️ Doar VIAȚA se înmulțește, nu și viteza. Damage-ul de contact nici n-ar avea ce: el nu vine
# de la inamic, ci din statul `contact_damage` al player-ului × `Difficulty.enemy_damage_mult()`
# (vezi `player._take_contact_damage`), deci e la fel pentru orice inamic de pe ecran.
@export var power_mult: float = 1.0

# Cât de tare lovește ĂSTA la contact, față de un inamic obișnuit. Până pe 2026-08-04 damage-ul
# de contact era IDENTIC pentru orice inamic de pe ecran (venea doar din statul `contact_damage`
# al player-ului × dificultate), deci nu exista niciun fel de „ăsta doare mai tare". A apărut
# odată cu creatura din ENDER, cerută „de 2x mai rapidă și cu damage dublu față de cele din
# Nether" — vezi `player._take_contact_damage`, care înmulțește per inamic.
@export var damage_mult: float = 1.0

# Cât XP lasă ĂSTA la moarte, față de un inamic obișnuit. 1.0 la toți cei născuți de
# `spawner.gd`; hoarda monumentului vine cu 2.0 (vezi `monument.gd`). Se aplică în `_drop_xp`,
# peste `Difficulty.xp_mult()` — deci e o înmulțire pe TOT ce lasă, și gema normală, și cea rară.
#
# ⚠️ Nu-l confunda cu `_xp_bonus`: ăla e bonusul de MOMENT (2× la moartea aurită de Duridama)
# și se dă la `_die()`; ăsta e o însușire a inamicului, pusă înainte să intre în arbore.
@export var xp_drop_mult: float = 1.0

# Cadrele de mers, construite LA RULARE din fișiere separate: `<frames_dir>/run_<directie>_<n>.png`,
# 8 direcții × `frames_count` cadre. Gol = animațiile vin din scenă (`sprite_frames`), ca la
# polițiști și la creatura Nether, care au `.tres`-uri.
#
# De ce și așa: creatura din Ender are 64 de poze separate, iar un `.tres` scris de mână ar fi
# însemnat 64 de UID-uri tastate, adică 64 de șanse de „resource not found" în joc. Aceeași
# soluție ca la `celesto.gd`.
@export var frames_dir: String = ""
@export var frames_count: int = 8
@export var frames_fps: float = 10.0

# --- Unde se opresc, ca să nu intre peste player (2026-07-28) ---
# `stop_dist` = distanța CENTRU-LA-CENTRU sub care inamicul nu mai înaintează spre tine: acolo
# se ating desenele. 41 = jumătatea lățimii player-ului (15) + jumătatea lățimii polițistului
# (26), măsurate pe pixelii chiar desenați, fără marginea transparentă. Creatura din Nether e
# mai lată, așa că `enemy_nether.tscn` își pune 53 al ei.
#
# 🔑 NU e coliziune fizică — layerele au rămas exact cum erau (inamicii se ciocnesc doar de
# obstacole, `mask = 1`). De-asta nu se întoarce bug-ul vechi: inamicii nu se opresc unul în
# altul (deci nu se lipesc în ciorchine) și nu împing player-ul, fiindcă fizica nici nu știe
# unii de alții. Oprirea e o simplă socoteală de distanță, aici în cod.
#
# ⚠️ Nu urca `stop_dist` peste `contact_range`-ul player-ului (60): damage-ul de contact se dă
# tot pe distanță, deci un inamic oprit mai departe de-atât n-ar mai apuca să te lovească
# NICIODATĂ. `_oprire()` plafonează singur și te avertizează în consolă dacă se întâmplă.
@export var stop_dist: float = 41.0
const STOP_SLACK := 4.0     # zonă moartă înainte de oprire: fără ea ar tremura între „mai fac un pas" și „stau"
const STOP_MARGINE := 6.0   # cât rămâne garantat sub `contact_range` după plafonare
var _stop := -1.0           # `stop_dist` plafonat, calculat o singură dată (vezi `_oprire()`)
var hp: int
var _dying := false
var _knockback := Vector2.ZERO  # împins temporar de gloanțe

# --- Sclipirea de la lovitură ---
# Nu e un Tween, ci un simplu cronometru care se scurge în `_physics_process`. Un tween per
# lovitură părea curat, dar la 300 de inamici loviți de mai multe ori pe secundă (aură, Thunder
# God) însemna mii de obiecte Tween create și aruncate în fiecare secundă — pur cost.
var _flash_time := 0.0        # cât mai ține sclipirea
var _flash_dur := 0.0         # cât a ținut în total (pt. stingerea liniară)
var _flash_color := Color(1, 1, 1)

# --- Slow de la Frostwalker (gheața lăsată de player) ---
const SLOW_MIN_MULT := 0.5    # viteza la slow MAXIM (0.5 = 50% din normal)
const SLOW_HOLD := 0.5        # secunde de slow MAXIM la început, după ce atinge gheața
const SLOW_RECOVER := 0.5     # cât durează revenirea lină la viteza normală după hold
const SLOW_TINT := Color(0.55, 0.75, 1.35)  # filtru albastru „înghețat" (modulate)
const ELECTRIC_TINT := Color(0.5, 0.85, 2.6)  # sclipire albastră electrică (Thunder God)
var _slow_time: float = 0.0   # timp rămas de slow (hold + recover); reîmprospătat cât stă în gheață
var _player: Node2D = null    # ținut minte, nu căutat prin arbore la fiecare cadru

# --- Ocolirea obstacolelor (2026-07-30) ---
# Inamicii merg DREPT spre țintă. Când în drum le iese un copac, o piatră sau o statuie,
# `move_and_slide()` îi lipește de ea: dacă îi lovesc din plin, alunecarea n-are încotro să-i
# ducă și rămân împingând în hitbox la nesfârșit, pe loc. Cerut de Răzvan: când se blochează,
# să o ia la STÂNGA sau la DREAPTA și apoi să revină pe traiectorie.
#
# NU e pathfinding și nici nu vrem să fie — n-avem hartă de navigație (lumea e generată în
# chunk-uri, infinită), iar la 300 de inamici un A* pe cadru ar omorî framerate-ul. E doar
# reflexul de „dă-te lateral": îl ținem OCOL_DURATA secunde, apoi îi dăm iar drumul spre țintă.
# Dacă obstacolul mai e în față, se declanșează din nou — dar de data asta din alt unghi, deci
# ocolirea înaintează pas cu pas în jurul lui în loc să-l ia de la capăt.
const OCOL_PROGRES := 0.4              # sub 40% din pasul cerut într-un cadru = nu înaintează
const OCOL_RABDARE := 0.15             # atâtea secunde de ne-înaintare până se hotărăște să ocolească
const OCOL_DURATA := 0.6               # cât ține cotitura, dacă între timp nu se eliberează drumul
const OCOL_UNGHI := deg_to_rad(80.0)   # cât cotește (90° = perfect lateral; 80 lasă și un pic de înaintare)
const OCOL_UITARE := 1.0               # după atâtea secunde de mers curat, uită partea aleasă
const OCOL_INSISTENTA := 2.0           # cât insistă pe o parte până s-o încerce pe cealaltă
const OCOL_CASTIG := 40.0              # cu atâția px trebuie să se apropie de țintă ca să conteze că merge
const OCOL_INSISTENTA_MAX := 16.0      # plafonul răbdării, ca dublarea să nu urce la infinit
var _blocat := 0.0            # de câte secunde împinge degeaba
var _ocol := 0.0              # cât mai are de mers pe lângă obstacol
var _ocol_semn := 0.0         # +1 = într-o parte, -1 = în cealaltă (semnul rotației); 0 = neales
var _ocol_total := 0.0        # de cât timp ocolește fără să se apropie de țintă
var _ocol_dist := 0.0         # cât de departe era de țintă la ultima apropiere care a contat
var _ocol_limita := 0.0       # câtă răbdare are pe partea asta (se dublează la fiecare întoarcere)
var _liber := 0.0             # de câte secunde merge nestingherit (vezi OCOL_UITARE)

# --- Duridama: inamic „aurit" (upgrade_45) ---
# La 1% (× stack) când e lovit, inamicul devine AURIU: îngheață exact în cadrul în care a fost
# lovit (animație + mișcare oprite) și primește un filtru auriu. Lovitura care-l aurește NU-i
# scade viața — doar îl îngheață. URMĂTOAREA lovitură îl ucide instant și lasă 2× XP.
const GOLD_TINT := Color(2.2, 1.6, 0.25)   # filtru auriu (modulate multiplică, deci valori supraunitare)
var golden := false
var _xp_bonus := 1.0          # cât XP lasă la moarte (2.0 la moartea aurită)

# --- Horse Mask: inamic „fermecat" (upgrade_52) ---
# La 5% (× stack) când îl lovești TU, inamicul se întoarce împotriva alor lui: își ia drept țintă
# alt inamic, se ține după el și-l lovește până moare. Cât e fermecat NU-ți mai face damage la
# contact (vezi player._take_contact_damage), dar tu îl poți omorî normal — e tot inamic.
# Când victima moare, vraja se rupe și se întoarce la tine.
const CHARM_TINT := Color(2.0, 0.6, 1.6)   # filtru roz-violet: se vede imediat cine e fermecat
const CHARM_RANGE := 700.0                 # de la ce distanță își caută victima (px)
const CHARM_HIT_RANGE := 70.0              # cât de aproape trebuie ca s-o lovească (px)
const CHARM_INTERVAL := 0.5                # o lovitură la fiecare jumătate de secundă
const CHARM_DAMAGE := 10                   # cât ia victima la o lovitură (× dificultate)
var charmed := false          # citit de player.gd ca să nu-ți mai facă damage cât e fermecat
var _charm_target: Node2D = null
var _charm_next := 0.0        # momentul (sec) când poate lovi din nou

# Scenele de XP (le încărcăm doar dacă există deja, ca să nu dea eroare)
var _xp1: PackedScene
var _xp2: PackedScene
var _key: PackedScene
var _magnet: PackedScene

# Șansa ca un inamic mort să lase o CHEIE de cufăr (cerut de Răzvan: 0.5%, adică 1 la 200
# de morți). NU se scalează cu nimic — nici cu dificultatea, nici cu norocul: e o rată fixă,
# ca să poți socoti câte cufere deschizi într-o rundă după câți inamici omori.
const KEY_CHANCE := 0.005
# MAGNETUL de XP (`magnet.gd`): 0.2%, adică 1 la 500 de morți. Tot fix, din același motiv.
# ⚠️ COBORÂT pe 2026-08-18 (era 0.005, ca la cheie) — cerut de Răzvan. E acum cel mai rar drop
# din joc, de 2,5 ori mai rar decât cheia.
const MAGNET_CHANCE := 0.002

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Devine mai puternic cu cât dificultatea a crescut (setat la nașterea fiecărui inamic)
	max_hp = maxi(1, int(max_hp * Difficulty.enemy_hp_mult() * power_mult))
	speed = speed * Difficulty.enemy_speed_mult()
	hp = max_hp
	add_to_group("enemy")
	if frames_dir != "":
		_build_frames()
	if ResourceLoader.exists("res://xp1.tscn"):
		_xp1 = load("res://xp1.tscn")
	if ResourceLoader.exists("res://xp2.tscn"):
		_xp2 = load("res://xp2.tscn")
	if ResourceLoader.exists("res://key.tscn"):
		_key = load("res://key.tscn")
	if ResourceLoader.exists("res://magnet.tscn"):
		_magnet = load("res://magnet.tscn")

# O animație pe direcție, din poze separate. Numele animațiilor sunt exact cele din `DIRECTII`,
# deci restul codului (care face `anim.play(DIRECTII[idx])`) nu știe și nu-i pasă de unde vin.
#
# ⚠️ Cadrele se încarcă o dată per POZĂ, dar `SpriteFrames` se construiește pentru FIECARE inamic
# născut. Godot ține texturile în cache, deci pozele nu se recitesc de pe disc — se recreează doar
# obiectul, care e ieftin. Dacă vreodată se simte la sute de inamici, se ține un singur
# `SpriteFrames` static per folder și se dă la toți (sunt read-only).
func _build_frames() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var lipsa := 0
	for d in DIRECTII:
		sf.add_animation(d)
		sf.set_animation_speed(d, frames_fps)
		sf.set_animation_loop(d, true)
		for i in frames_count:
			var cale := "%s/run_%s_%d.png" % [frames_dir, d, i]
			var tex := load(cale) as Texture2D
			if tex == null:
				lipsa += 1
				continue
			sf.add_frame(d, tex)
	if lipsa > 0:
		push_warning("Inamic: lipsesc %d cadre din %s (rulează --headless --import)" % [lipsa, frames_dir])
	anim.sprite_frames = sf
	anim.play(DIRECTII[2])   # south, până se hotărăște încotro merge

func _physics_process(delta: float) -> void:
	if _dying or golden:
		return   # aurit = înghețat: nici mișcare, nici schimbare de animație/culoare
	# Pe cine urmărește acum: victima, dacă e fermecat (Horse Mask), altfel player-ul.
	var tinta: Node2D = _charm_tinta() if charmed else null
	if tinta == null:
		# Player-ul se ține minte, nu se caută prin arbore în fiecare cadru: la 300 de inamici
		# asta însemna 300 de căutări pe cadru, degeaba (e mereu același nod).
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node2D
		tinta = _player
	if tinta == null:
		return
	if charmed:
		_charm_attack(tinta)
	var spre := tinta.global_position - global_position
	var directie := spre.normalized()
	# mers (oprit la marginea player-ului, încetinit de gheață) + împins de gloanțe
	var dist := spre.length()
	var mers := _ocoleste(_viteza_mers(directie, dist, not charmed), dist, delta)
	velocity = mers + _knockback
	var inainte := global_position
	move_and_slide()
	# a înaintat cât a cerut, sau împinge degeaba într-un obstacol? (vezi OCOL_*)
	_verifica_blocaj(mers, global_position - inainte, dist, delta)
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)  # împinsul scade rapid la 0
	# scade slow-ul și pune filtrul albastru cât timp e înghețat (dar nu în timpul unei sclipiri de lovitură)
	if _slow_time > 0.0:
		_slow_time = max(0.0, _slow_time - delta)
	if _flash_time > 0.0:
		# sclipirea se stinge lin spre tenta curentă (albă/albastră, după slow)
		_flash_time = maxf(0.0, _flash_time - delta)
		anim.modulate = _tenta().lerp(_flash_color, _flash_time / _flash_dur)
	else:
		anim.modulate = _tenta()
	# angle() = unghiul spre player (0 = est, crește în sensul acelor de ceas) → octant 0..7.
	# Cât ocolește un obstacol se uită ÎNCOTRO MERGE, nu spre țintă: altfel s-ar vedea mergând
	# lateral cu fața la tine, ca un crab, și n-ar mai fi limpede că se dă pe lângă copac.
	var privire := directie
	if _ocol > 0.0 and mers.length() > 0.001:
		privire = mers.normalized()
	var idx := wrapi(int(round(privire.angle() / (PI / 4.0))), 0, 8)
	# doar când chiar se schimbă direcția (ca la player): play() în fiecare cadru costă degeaba
	if anim.animation != DIRECTII[idx]:
		anim.play(DIRECTII[idx])

# Cât de repede și încotro merge pe cadrul ăsta. Când ținta e PLAYER-UL sunt trei cazuri:
#   dist mai mare decât oprirea     → merge normal spre el;
#   între oprire-SLACK și oprire    → STĂ pe loc — aici se ating desenele, ăsta e tot scopul;
#   sub oprire-SLACK                → iese înapoi din el.
# Al treilea caz nu e teoretic: player-ul nu e oprit de nimeni (așa a fost cerut, ca să nu-l mai
# împingă gloata), deci poate să intre EL peste un inamic oprit. Fără ieșire, inamicul ar rămâne
# lipit în mijlocul lui — exact ce arăta bug-ul vechi.
# Ieșirea folosește viteza ÎNTREAGĂ, nu cea încetinită de gheață: altfel un inamic înghețat prin
# care ai trecut ar ieși în ralanti și ar sta secunde bune peste tine.
#
# Când e fermecat (Horse Mask) și aleargă după alt inamic, nu se aplică nimic din toate astea:
# distanța de acolo e treaba lui `CHARM_HIT_RANGE`, iar cifra 41 e croită pe lățimea player-ului.
func _viteza_mers(directie: Vector2, dist: float, spre_player: bool) -> Vector2:
	var v := speed * _current_slow_mult()
	if not spre_player:
		return directie * v
	var stop := _oprire()
	if dist > stop:
		return directie * v
	if dist > stop - STOP_SLACK:
		return Vector2.ZERO
	if dist < 0.001:
		# Suprapunere PERFECTĂ (player-ul a nimerit exact centrul lui). `normalized()` pe un vector
		# nul dă tot zero, deci „iese înapoi" ar însemna să nu se miște niciodată și ar rămâne
		# înțepenit în player — chiar bug-ul de care fugim. Îl scoatem într-o direcție oarecare,
		# dar aceeași de fiecare dată pentru același inamic (nu una nouă la fiecare cadru, care
		# l-ar face să vibreze pe loc), și diferită de la unul la altul, ca doi suprapuși să nu
		# plece amândoi în același sens. Prins de testul din 2026-07-28.
		return Vector2.RIGHT.rotated(float(get_instance_id() % 360) * (PI / 180.0)) * speed
	return -directie * speed

# Dacă e în plină ocolire, cotește mersul cerut cu OCOL_UNGHI în partea aleasă. Altfel îl lasă
# neatins. Când inamicul stă pe loc (a ajuns la tine), ocolirea se anulează: n-are ce ocoli.
#
# Tot aici stă plasa de siguranță pentru FUNDĂTURI. Partea aleasă poate să dea într-un colț
# (două pietre aproape lipite, un obstacol în „L") și atunci inamicul ar împinge acolo la
# nesfârșit. Măsura e simplă și cinstită: dacă în OCOL_INSISTENTA secunde de ocolit NU s-a
# apropiat de țintă cu măcar OCOL_CASTIG px, partea aia nu duce nicăieri → o încearcă pe
# cealaltă. Cifra 2s nu e la întâmplare: e cât îi trebuie să facă vreo 240px pe lângă obstacol,
# adică să treacă de un copac întreg. Prima variantă schimba partea la FIECARE reblocaj, adică
# la ~0,7s, și atunci nu apuca să iasă niciodată — se legăna pe fața obstacolului la infinit.
func _ocoleste(mers: Vector2, dist: float, delta: float) -> Vector2:
	if _ocol <= 0.0:
		return mers
	_ocol = maxf(0.0, _ocol - delta)
	if mers.length() < 0.001:
		_ocol = 0.0
		return mers
	_ocol_total += delta
	if dist < _ocol_dist - OCOL_CASTIG:
		_ocol_dist = dist        # chiar câștigă teren → îi mai dăm răbdare pe partea asta
		_ocol_total = 0.0
		_ocol_limita = OCOL_INSISTENTA
	elif _ocol_total >= _ocol_limita:
		_ocol_semn = -_ocol_semn  # fundătură: pe partea cealaltă
		_ocol_total = 0.0
		_ocol_dist = dist
		# și cu DUBLU de răbdare. Fără dublare, un obstacol lung (un zid, nu un copac) l-ar
		# prinde între cele două capete ale lui: 2s într-o parte nu-i ajung să-l ocolească,
		# se întoarce, 2s nici în cealaltă, și tot așa la nesfârșit. Dublând, a treia-a patra
		# legănare îl scoate de la orice capăt. Măsurat pe un zid de 320px: 4/7 ajungeau cu
		# răbdare fixă, 7/7 cu dublare.
		_ocol_limita = minf(_ocol_limita * 2.0, OCOL_INSISTENTA_MAX)
	return mers.rotated(_ocol_semn * OCOL_UNGHI)

# Compară cât s-a mișcat cu cât a cerut. Dacă a înaintat, uită blocajul. Dacă împinge degeaba
# de mai mult de OCOL_RABDARE secunde, pornește ocolirea. Pragul e pe DEPLASAREA REALĂ, nu pe
# „am atins ceva": inamicii ating obstacole tot timpul și alunecă frumos pe lângă ele — problema
# e doar când alunecarea nu-i mai duce nicăieri.
func _verifica_blocaj(mers: Vector2, deplasare: Vector2, dist: float, delta: float) -> void:
	var cerut := mers.length() * delta
	if cerut < 0.001:
		_blocat = 0.0   # nu voia să meargă nicăieri (stă lângă player) → nu e blocaj
		return
	if deplasare.length() >= cerut * OCOL_PROGRES:
		_blocat = 0.0
		# A trecut de obstacol și merge curat de-o vreme? Atunci uită partea aleasă, ca
		# la următorul copac s-o poată alege din nou pe cea scurtă.
		if _ocol <= 0.0:
			_liber += delta
			if _liber >= OCOL_UITARE:
				_ocol_semn = 0.0
				_ocol_total = 0.0
		return
	_liber = 0.0
	_blocat += delta
	if _blocat < OCOL_RABDARE:
		return
	_blocat = 0.0
	# ⚠️ Partea se alege O SINGURĂ DATĂ per obstacol și se PĂSTREAZĂ până scapă de el. Prima
	# variantă alegea din nou la fiecare blocaj, iar dacă se lovea iar (normal: după cotitură
	# ținta e tot dincolo de copac) alegea partea opusă „ca s-o încerce și pe aia" — rezultatul
	# a fost un inamic care se plimba la nesfârșit în sus și-n jos pe fața obstacolului, fără
	# să-i dea ocol niciodată. Prins de testul cu 7 inamici: 6 ajungeau, unul se legăna la
	# infinit. Acum se ține de partea aleasă până chiar înaintează.
	if _ocol_semn == 0.0:
		_ocol_semn = _alege_partea(mers.normalized())
		_ocol_total = 0.0
		_ocol_dist = dist
		_ocol_limita = OCOL_INSISTENTA
	_ocol = OCOL_DURATA

# Stânga sau dreapta? Adunăm normalele obstacolelor atinse la ultima alunecare: tangenta la ele
# (normala rotită cu 90°) e „pe lângă ce", iar dintre cele două sensuri ale ei îl luăm pe cel
# care duce mai spre țintă. Așa, dacă inamicul a nimerit copacul puțin pe stânga, îl ocolește
# pe stânga — pe drumul scurt, nu pe cel lung.
#
# Când e LOVIT DIN PLIN tangenta nu ne spune nimic (normala e fix înapoi, ambele sensuri duc la
# fel de departe). Atunci hotărăște id-ul instanței — arbitrar, dar CONSTANT pentru același inamic
# (nu se răzgândește la fiecare cadru, deci nu tremură pe loc) și diferit de la unul la altul,
# ca doi blocați de același copac să nu plece amândoi în aceeași parte.
func _alege_partea(dir: Vector2) -> float:
	var n := Vector2.ZERO
	for i in get_slide_collision_count():
		n += get_slide_collision(i).get_normal()
	if n.length() > 0.001:
		var t := n.normalized().orthogonal()
		if t.dot(dir) < 0.0:
			t = -t
		if t.dot(dir) > 0.12:
			var semn := signf(dir.cross(t))
			if semn != 0.0:
				return semn
	return 1.0 if int(get_instance_id()) % 2 == 0 else -1.0

# `stop_dist`, plafonat o singură dată sub raza de damage a player-ului. Vezi comentariul de la
# `stop_dist`: dacă un inamic s-ar opri mai departe decât `contact_range`, n-ar mai putea să te
# lovească deloc, iar jocul ar deveni imposibil de pierdut — în tăcere. Așa că plafonăm, dar o
# și spunem în consolă: înseamnă că sprite-ul inamicului e mai lat decât raza de contact și
# atunci se mărește `contact_range`, nu se micșorează pe furiș oprirea.
func _oprire() -> float:
	if _stop >= 0.0:
		return _stop
	_stop = stop_dist
	if _player != null and is_instance_valid(_player) and "contact_range" in _player:
		var plafon: float = float(_player.contact_range) - STOP_MARGINE
		if _stop > plafon:
			push_warning("Enemy: stop_dist %.0f > contact_range-%.0f → plafonat la %.0f, altfel inamicul nu te-ar mai atinge" % [_stop, STOP_MARGINE, plafon])
			_stop = plafon
	return _stop

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

# Culoarea de modulate în starea de acum: roz dacă e fermecat (are prioritate, ca să se vadă mereu
# cine luptă de partea ta), altfel alb când nu e înghețat, spre albastru cât e mai încetinit.
# Sclipirile de lovitură se sting spre culoarea asta (vezi _physics_process).
func _tenta() -> Color:
	if charmed:
		return CHARM_TINT
	var s := (1.0 - _current_slow_mult()) / (1.0 - SLOW_MIN_MULT)  # 0 = deloc, 1 = slow maxim
	return Color(1, 1, 1).lerp(SLOW_TINT, s)

# Chemată de glonț când are knockback: împinge inamicul pe direcția glonțului.
func apply_knockback(v: Vector2) -> void:
	_knockback = v

func take_damage(amount: int, from_charm: bool = false) -> void:
	if _dying:
		return
	# Duridama: dacă e deja aurit, ORICE lovitură îl ucide instant și lasă 2× XP.
	if golden:
		_die(2.0)
		return
	# altfel, șansa de a-l auri (îngheață în cadrul ăsta, fără să-i scadă viața)
	if _try_golden():
		return
	# Horse Mask: doar loviturile TALE farmecă. Dacă ar farmeca și loviturile inamicilor deja
	# fermecați, un singur proc s-ar propaga în lanț prin toată gloata până n-ar mai lupta nimeni
	# cu tine. (`from_charm` vine din `charm_hit`.)
	if not from_charm:
		_try_charm()
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
	_flash_time = 0.0               # oprim orice sclipire în curs, ca aurul să rămână curat
	anim.pause()                    # îngheață EXACT cadrul curent (altfel frame-urile curg singure)
	anim.modulate = GOLD_TINT
	Audio.play("hit", 0.0)          # un „cling" mai tare, ca semnal că s-a aurit

# Rulează rostogolirea Horse Mask (șansa vine de la player). Dacă iese, îl întoarce împotriva alor lui.
func _try_charm() -> void:
	if charmed:
		return   # deja fermecat: nu-și schimbă victima în timpul vrăjii
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("horse_mask_chance"):
		return
	var sansa: float = player.horse_mask_chance()
	if sansa <= 0.0 or randf() >= sansa:
		return
	var victima := _victima_apropiata()
	if victima == null:
		return   # n-are pe cine ataca (e singur pe ecran) → nu irosim procul, se poate declanșa iar
	charmed = true
	_charm_target = victima
	_charm_next = 0.0
	anim.modulate = _tenta()

# Victima de acum. Dacă a murit (iese din grupul „enemy" chiar când începe să se stingă) sau a
# dispărut, vraja se rupe și inamicul se întoarce după player.
func _charm_tinta() -> Node2D:
	if _charm_target != null and is_instance_valid(_charm_target) and _charm_target.is_in_group("enemy"):
		return _charm_target
	charmed = false
	_charm_target = null
	if not _dying:
		anim.modulate = _tenta()
	return null

# Lovește victima, o dată la CHARM_INTERVAL, dacă e destul de aproape. Damage-ul crește cu
# dificultatea, ca și cel pe care ți-l dau ție inamicii.
func _charm_attack(victima: Node2D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _charm_next:
		return
	if global_position.distance_to(victima.global_position) > CHARM_HIT_RANGE:
		return
	_charm_next = now + CHARM_INTERVAL
	var dmg := maxi(1, int(round(CHARM_DAMAGE * Difficulty.enemy_damage_mult())))
	# garda.gd e și el în grupul „enemy", dar are `take_damage(amount)` cu UN singur argument →
	# pe inamicii normali mergem prin `charm_hit`, ca să nu se rostogolească farmec din farmec.
	if victima.has_method("charm_hit"):
		victima.charm_hit(dmg)
	elif victima.has_method("take_damage"):
		victima.take_damage(dmg)
	Fx.damage_number(victima.global_position, dmg, false)

# Lovitura dată de un inamic FERMECAT: damage normal, dar fără rostogolirea de farmec (vezi take_damage).
func charm_hit(amount: int) -> void:
	take_damage(amount, true)

# Cel mai apropiat ALT inamic, în raza de farmec. Sar peste cei deja fermecați, ca să nu ajungă doi
# fermecați să se învârtă unul după celălalt în loc să dea în gloată.
func _victima_apropiata() -> Node2D:
	var best: Node2D = null
	var best_d := CHARM_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		var alt := e as Node2D
		if alt == null or alt == self:
			continue
		if "charmed" in alt and alt.charmed:
			continue
		var d := global_position.distance_to(alt.global_position)
		if d < best_d:
			best_d = d
			best = alt
	return best

func _flash() -> void:
	_porneste_flash(Color(5, 5, 5), 0.12)  # alb foarte strălucitor, revine la tenta curentă în 0.12s

# Chemată de Thunder God când inamicul e lovit de curent: o sclipire albastră electrică, ceva mai
# lungă decât cea albă de lovitură, ca să se vadă că e „electrocutat". Revine la tenta curentă.
func flash_electric() -> void:
	if _dying or golden:   # aurit → nu-i stricăm filtrul auriu
		return
	_porneste_flash(ELECTRIC_TINT, 0.28)

# Pornește o sclipire: culoarea de start și cât durează stingerea spre tenta curentă.
func _porneste_flash(culoare: Color, durata: float) -> void:
	_flash_color = culoare
	_flash_dur = durata
	_flash_time = durata
	anim.modulate = culoare

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
	# Bonusurile (2× la Duridama, 2× la hoarda monumentului) se aplică DUPĂ rotunjire, ca să iasă
	# exact dublul dropului normal — altfel, la un xp_mult ne-întreg, `round(2.6)=3` vs
	# `round(5.2)=5` ar da un raport de 1.7, nu 2. Se înmulțesc între ele: un inamic al
	# monumentului ucis aurit lasă de 4 ori cât unul obișnuit.
	if _xp1 != null:
		var gem := _xp1.instantiate()
		gem.value = int(round(int(round(gem.value * Difficulty.xp_mult())) * _xp_bonus * xp_drop_mult))
		parent.add_child(gem)
		gem.global_position = global_position
	# XP rar (valoare de bază 10 = de 10× cât XP1), tot scalat cu dificultatea; 5% doar la dificultate mare
	if _xp2 != null and Difficulty.xp2_unlocked() and randf() < 0.05:
		var rare := _xp2.instantiate()
		rare.value = int(round(int(round(rare.value * Difficulty.xp_mult())) * _xp_bonus * xp_drop_mult))
		parent.add_child(rare)
		rare.global_position = global_position + Vector2(20, 0)
	# CHEIE de cufăr: 0.5%, independent de restul dropului (poți primi și XP rar, și cheie).
	# Cade puțin în lateral, ca să nu stea fix peste geme și să n-o vezi.
	if _key != null and randf() < KEY_CHANCE:
		var cheie := _key.instantiate()
		parent.add_child(cheie)
		cheie.global_position = global_position + Vector2(-22, -6)
	# MAGNET de XP: 0.2%, tot independent de restul dropului. Cade în cealaltă parte decât cheia,
	# ca să se vadă amândouă dacă pică odată (1 la 100.000 de morți, dar se întâmplă).
	if _magnet != null and randf() < MAGNET_CHANCE:
		var magnet := _magnet.instantiate()
		parent.add_child(magnet)
		magnet.global_position = global_position + Vector2(22, -6)
