extends CharacterBody2D

var bullet_scene: PackedScene = preload("res://bullet.tscn")  # glonțul curent (se schimbă la unele upgrade-uri)
var has_weird: bool = false   # ai luat Weird Concoction? (pt. sinergia cu Stroh → glonț combinat)
var has_stroh: bool = false   # ai luat Stroh? (pt. sinergia cu Weird Concoction → glonț combinat)
var _rusty_taken: bool = false   # Rusty Hacksaw luat cel puțin o dată (pt. baza vs. stack)
var _doctor_taken: bool = false  # Doctor's Hacksaw luat cel puțin o dată
const FIRE_TRAIL := preload("res://firetrail.gd")  # băltoaca de foc lăsată de Firewalker
const ICE_TRAIL := preload("res://icetrail.gd")    # dâra de gheață lăsată de Frostwalker
const GOD_TRAIL := preload("res://godtrail.gd")    # dâra combinată (Firewalker + Frostwalker = Godwalker)
const SHOCKWAVE := preload("res://shockwave.gd")   # unda de șoc a lui Panic Button

# Numele animațiilor, pe optimi de cerc (vezi _update_anim).
# Ordinea urmează unghiul crescător (y în jos): E, SE, S, SV, V, NV, N, NE.
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

@export var speed: float = 300.0
@export var fire_interval: float = 0.5
@export var bullet_damage: int = 10        # cât rău fac gloanțele (crește la level up)
@export var bullet_speed: float = 700.0    # cât de repede zboară glonțul (crește la level up)
# Gloanțe paralele: din 2026-07-21 NICIUN item nu mai crește `bullet_count` (Twin Comets dădea
# +2, acum dă proiectile bonus ca Gunslinger). Mecanica rămâne funcțională, gata de refolosit.
@export var bullet_count: int = 1          # câte gloanțe paralele tragi odată
@export var bullet_spacing: float = 26.0   # distanța dintre gloanțele paralele
# Broken Watch: la fiecare salvă, ȘANSĂ (fixă) să tragi proiectile bonus în ALȚI inamici la
# întâmplare (ca Gunslinger, dar pe șansă). Șansa NU crește cu luările — crește CÂTE proiectile
# bonus dai când se declanșează (+1 pe luare). Doar la gloanțe (pistol/mage).
@export var broken_watch_chance: float = 0.5  # șansa să se declanșeze bonusul
var broken_watch_stacks: int = 0              # câte proiectile bonus tragi când se declanșează
# Gunslinger (+1 pe luare) și Twin Comets (+2 pe luare): proiectile GARANTATE trase în ALȚI
# inamici la întâmplare — pleacă în direcții diferite deodată. Doar la gloanțe (pistol/mage).
var stacked_armory_stacks: int = 0            # câte proiectile bonus în alți inamici
# Thunder God: la impact (glonț SAU sabie), curent electric de la inamicul LOVIT spre toți ceilalți
# din rază (ca Jacob's Ladder din Binding of Isaac). Animația pornește din inamic, nu din player, și
# NU se lanțuie mai departe. Inamicii loviți de curent capătă o tentă albastră (enemy.flash_electric).
@export var thunder_range: float = 200.0      # raza maximă de legare între inamici (px)
const THUNDER_MAX_ARCE := 10                  # câte arcuri se DESENEAZĂ dintr-o descărcare (damage-ul îl iau toți)
const THUNDER_MAX_ARCE_VII := 60              # câte arcuri pot exista pe ecran în total, din toate descărcările
var _arce_vii: int = 0                        # câte arcuri sunt vii acum (vezi `_spawn_electric_arc`)
var thunder_stacks: int = 0                   # de câte ori ai luat itemul (0 = nu-l ai)
const THUNDER_PCT_PER_STACK := 0.25           # cât damage face arcul, pe luare (vezi thunder_damage_pct)
const ARMORY_RANGE_SQ := 600.0 * 600.0        # raza în care se caută ținte pentru proiectilele bonus
var _electric_frames: SpriteFrames            # cadrele fulgerului (fx/electricity fx, 14 × 64×63)
# Plugged In: versiune „ieftină" de Thunder God — ȘANSĂ să facă exact același lucru la impact.
# +10% pe luare (prima luare = 10%, cum a cerut Răzvan), plafonat la 100% (= Thunder God permanent).
@export var plugged_in_chance_per: float = 0.10
var plugged_in_stacks: int = 0                # de câte ori ai luat Plugged In

# Duridama: la fiecare lovitură, șansă să „aurească" inamicul (îl îngheață); următoarea lovitură
# îl ucide instant și dă 2× XP. +1% pe luare. Rostogolirea o face enemy.gd, cu șansa de aici.
const DURIDAMA_PER := 0.01
var duridama_stacks: int = 0

func duridama_chance() -> float:
	return minf(1.0, duridama_stacks * DURIDAMA_PER)

# Undying Spirit: prima moarte te trimite în Limbo în loc de Game Over (vezi limbo.gd).
# Se consumă la prima folosire — a doua oară mori normal, chiar dacă ai luat itemul de mai multe ori.
var has_undying: bool = false
var undying_used: bool = false

# --- tipul de armă (ales din meniu: pistol / mage / extinguisher) ---
var weapon_type: String = "pistol"
# Stingător = AURĂ: pulsează în jurul tău, mai mare cu nivelul, mai des cu cadența
@export var aura_base_radius: float = 90.0
@export var aura_growth: float = 12.0      # cât crește raza pe nivel
@export var aura_damage: int = 10          # damage de bază pe puls; total = asta + 50% din bullet_damage (10 + 5 = 15 la start)
@export var foam_scale: float = 1.25       # mărimea spumei: crește ȘI vizualul, ȘI hitbox-ul (rămân mereu egale)
var _aura_tex: Texture2D
var _foam_frames: SpriteFrames  # animația de spumă (rândul 6 din stingator_effects.png)
var _muzzle_frames: SpriteFrames     # fulger la țeavă (pistol/mage)
var _mage_boom_frames: SpriteFrames  # explozie violet la impact (mage staff)
var _mage_orb_frames: SpriteFrames   # sfera magică (proiectilul mage)
@export var muzzle_scale: float = 1.2
# Diametrul sferei mage pe ecran, în pixeli. Glonțul are scale 0.1 în bullet.tscn,
# așa că sfera trebuie să compenseze scara părintelui (vezi _make_mage_orb).
@export var mage_orb_size: float = 35.0

# --- Cursed Sword: taie automat în direcția în care se uită player-ul ---
#
# Gândită ca Firewalker (vezi firetrail.gd), din 3 motive:
#  1. mărimea e în PIXELI, nu multiplicator → schimbi arta, mărimea rămâne (`size / 32.0` acolo);
#  2. raza de damage se DERIVĂ din mărime (`radius = size * 0.4` acolo) → hitbox-ul urmează
#     automat arta, nu se mai pot despărți (boala de care am tot suferit cu sabia);
#  3. cadrele au fața spre VEST, rotite cu `dir.angle() - PI`.
#
# „înainte" și „lateral" sunt față de DIRECȚIA ÎN CARE TE UIȚI, nu față de ecran:
#   înainte + = mai departe de tine   |  lateral + = spre dreapta ta
# Se rotesc odată cu privirea → tăietura iese IDENTICĂ în toate cele 8 direcții, doar întoarsă.
# (Nu pune aici offset-uri „pe ecran", nerotite — am încercat și strică fix asta: la est
#  trăgeau tăietura spre tine, la nord o dădeau lateral.)
#
# HITBOX-UL E UN DREPTUNGHI FIX, croit pe ANVELOPA animației (uniunea tuturor cadrelor):
#   - pornește de la player (x = 0) → prinde și golul dintre el și tăietură;
#   - se termină în față și în lateral la cel mai depărtat pixel din TOATĂ animația;
#   - nu se schimbă pe parcursul măturatului — e mereu aceeași formă.
# Anvelopa se MĂSOARĂ la pornire, din pixelii cadrelor (`_masoara_arta_sabiei`), nu e scrisă de
# mână: schimbi arta, se recalculează singură. Și fiind exprimată în pixeli de artă, urmează
# automat `sword_size` / `sword_reach` / `sword_lateral`.
#
# (Am încercat înainte un cerc — prindea și golul dintre coarnele semilunii; și 1:1 pe pixeli —
#  exact, dar lăsa fără damage spațiul dintre player și tăietură. Dreptunghiul le rezolvă pe ambele.)
#
# `sword_debug = true` îl desenează peste joc: dreptunghi roșu = ce lovește, cruce albastră =
# unde e agățată arta, linie albă = direcția.

const SWORD_FRAME_W := 64.0                  # lățimea unui cadru (fx/cursed sword fx: 12 cadre de 64×55)

# 160 = ce aveai tu reglat în player.tscn înainte de arta nouă (sword_scale 2.5 × cadru de 64 px).
# Butonul s-a redenumit, așa că ți-am dus alegerea mai departe. Acum se scrie direct în pixeli.
@export var sword_size: float = 200        # lățimea tăieturii în PIXELI pe ecran (ca `size` la Firewalker)
@export var sword_reach: float = 42.0        # cât de departe în față e centrul tăieturii
@export var sword_lateral: float = 3.0       # cât în lateral (3 o centrează pe axa privirii; arta e aproape simetrică)
@export var sword_art_rotation: float = 0.0  # reglaj fin peste convenția „arta e spre vest", dacă nu cade perfect
@export var sword_anim_speed: float = 1.0    # cât de repede se joacă tăietura (1 = normal ≈ 22 cadre/sec)
@export var sword_debug: bool = false        # desenează conturul tăieturii peste joc, ca să-l reglezi cu ochii

@export var sword_base_damage: int = 8       # damage de bază/tăietură; total = asta + bullet_damage
@export var sword_slow_start: float = 1.9    # la început taie mai rar (fire_interval × asta la selectarea sabiei)

# --- Stolen Halo: aureola care plutește deasupra capului după ce iei itemul ---
const HALO_FRAME_W := 64.0                   # lățimea unui cadru (fx/halo fx: 10 cadre de 64×58)
@export var halo_size: float = 54.0          # lățimea aureolei în px pe ecran
# Offset pe ECRAN, nerotit — aureola stă mereu deasupra capului, indiferent încotro te uiți.
# (La sabie un offset nerotit ar fi greșit, fiindcă tăietura se rotește cu privirea. Aici nu.)
@export var halo_side: float = -4.0          # cât în lateral (− = spre stânga pe ecran)
@export var halo_height: float = 76.0        # cât de sus stă, deasupra centrului player-ului
											 # (creștetul e la ~62 px: sprite 124×124, capul la 31 px × scale 2)
var _halo: AnimatedSprite2D = null           # aureola, o dată pusă rămâne tot restul rundei
var _sword_frames: SpriteFrames             # cele 12 cadre din fx/cursed sword fx
var _sword_frame_px := Vector2(64, 55)      # mărimea unui cadru, în pixeli de artă (citită din textură)
var _sword_env := Rect2()                   # anvelopa animației (uniunea cadrelor), în pixeli de artă
var _slashes: Array = []                    # tăieturile în curs; le rotim după privire cât se joacă
var _facing: Vector2 = Vector2.DOWN         # ultima direcție reală în care s-a uitat player-ul (pt. tăietura sabiei)

# --- upgrade-uri de armă ---
# --- Unusual Clover: NOROCUL. Face două lucruri complet diferite: ---
#  1. înclină șansele de RARITATE la level up (calculul e în levelup.gd, `_sanse_cu_noroc`);
#  2. adaugă puncte procentuale la șansele itemelor pe care LE AI deja (aici, `luck_bonus`).
# Ce NU face: nu-ți dă o șansă pe care n-ai luat-o niciodată. Fără Adrenaline criticul rămâne
# 0%, nu 2% — altfel norocul ți-ar strecura pe furiș mecanici pe care nu le-ai ales.
const LUCK_CHANCE_PER := 0.004   # +0.4 puncte procentuale per punct de noroc (5 noroc = +2%)
var luck: float = 0.0            # ZECIMAL, nu întreg: The Office dă +2.5

func luck_bonus() -> float:
	return luck * LUCK_CHANCE_PER

@export var crit_chance: float = 0.0       # șansa (0..1) ca o lovitură să fie critică
@export var crit_mult: float = 2.0         # de câte ori mai mult damage la critic
@export var instakill_chance: float = 0.0  # șansa (0..1) ca o lovitură să ucidă instant inamicul (Hacksaw)
@export var pierce: int = 0                # prin câți inamici trece glonțul
@export var bullet_scale: float = 1.0      # mărimea glonțului (1 = normal)
# --- mărimea ARMEI (sprite + hitbox), comună tuturor armelor ---
# Pistol/Mage: mărește glonțul (și sfera mage, fiind copil al lui). Stingător: mărește raza aurei.
const BULLET_BASE_PX := 27.0               # cât are glonțul de bază pe ecran (193px × 1.4 sprite × 0.1 root)
@export var weapon_size_px: float = 0.0    # Pufferfish: +10 px adăugați la mărimea armei
@export var weapon_size_mult: float = 1.0  # Rat's Burger: × 1.30 peste mărimea curentă
@export var knockback: float = 0.0         # cât împinge inamicul înapoi
@export var explosion_radius: float = 0.0  # raza exploziei AOE la impact (0 = fără) — Jean's Bomb
@export var explosion_damage: int = 0      # damage FIX al exploziei (nefolosit acum, vezi mai jos)
# Jean's Bomb: explozia face un PROCENT din damage-ul salvei (15% la prima luare, +10% pe
# repetare), calculat la fiecare tragere în `_fire_bullets` — deci crește singur cu upgrade-urile
# de damage luate după. Înainte era un 25 fix, care rămânea în urmă până devenea neglijabil.
@export var explosion_damage_pct: float = 0.0
@export var fire_trail_time: float = 0.0   # cât rămâne dâra de foc pe jos (0 = fără) — Firewalker
@export var fire_trail_damage: int = 0     # damage pe tick al dârei de foc
@export var fire_trail_size: float = 0.0   # lățimea focului în px (crește cu fiecare upgrade)
@export var frost_trail_time: float = 0.0  # cât rămâne dâra de gheață pe jos (0 = fără) — Frostwalker
@export var frost_trail_damage: int = 0    # damage pe tick al gheții (≈ jumătate din foc)
@export var frost_trail_size: float = 0.0  # lățimea gheții în px (crește cu fiecare upgrade)
@export var frost_slow_time: float = 0.0   # cât timp stă înghețat inamicul (hold), +0.5s pe upgrade — Frostwalker

# --- bonusuri care depind de starea de ACUM (vezi damage_mult() și crit_chance_now()) ---
# Astea NU se pot scrie o dată în bullet_damage / crit_chance, ca la The Nightclub sau Adrenaline:
# se schimbă în timpul rundei (viața curentă, viteza curentă), deci se recalculează la fiecare lovitură.
@export var theo_hp_threshold: float = 0.20  # Theo's Wrath se aprinde sub 20% din viața maximă
var theo_bonus: float = 0.0                  # cât dă Theo's Wrath: +15% prima dată, +10% la fiecare repetare
var _theo_taken: bool = false                # Theo's Wrath luat cel puțin o dată (bază vs. stack)
var cig_bonus: float = 0.0                   # Cigarette Pack: +5% aditiv la fiecare luare
@export var diesel_per_stack: float = 0.15   # Diesel Power: +15% damage pe luare, la viteza de la START
var diesel_stacks: int = 0                   # de câte ori ai luat Diesel Power
@export var katana_per_stack: float = 0.15   # Megane's Katana: +15% șansă de critic pe luare, la viteza de la START
var katana_stacks: int = 0                   # de câte ori ai luat Megane's Katana
# Plafonul e comun lui Diesel Power și Megane's Katana (amândouă se uită la viteză, vezi speed_ratio()):
# peste 2× viteza de start nu mai cresc, altfel Alex's Protection compune viteza la infinit.
@export var speed_ratio_cap: float = 2.0
var _speed_base: float = 300.0               # viteza la începutul rundei (după META) = reperul lor

@export var max_hp: int = 100
@export var contact_range: float = 60.0
@export var contact_damage: int = 5
@export var damage_interval: float = 0.5
@export var hedgehog: bool = false         # Mike's Hedgehog: reflectă damage-ul primit înapoi în inamic
var _hedgehog_next: float = 0.0            # momentul (sec) când reflectul redevine disponibil (cooldown 3s)
@export var hp_regen: int = 0              # HP regenerat pe secundă (crește la level up)
var hp: int

# Valorile cu care PORNEȘTI runda (după META), prinse în _ready. Reperul pentru panoul de
# statusuri din meniul de level-up: un stat e gri dacă e la fel ca aici, verde dacă e mai bun,
# roșu dacă e mai slab. Vezi stat_lines().
var _stats_base := {}

# --- XP / nivel ---
@export var xp_to_next: int = 20  # cât XP îți trebuie pentru nivelul următor
var xp: int = 0
var level: int = 1
var xp_gain_mult := 1.0  # multiplicator XP primit (din meta-progresie)
var dead := false  # ca să nu declanșăm Game Over de mai multe ori

var ultima_directie := "south"  # ultima direcție în care s-a uitat (pentru poza de stat pe loc)
var fire_timer: Timer           # îl ținem ca variabilă ca să-i putem schimba viteza la level up

# --- Screen shake (tremurat de cameră, ex. la lovitură critică) ---
@export var shake_decay: float = 4.0   # cât de repede se liniștește tremuratul
@export var shake_max: float = 16.0    # amplitudinea maximă (pixeli)
var _trauma: float = 0.0               # 0 = liniște, 1 = tremurat maxim
var _shaking: bool = false             # controlăm camera DOAR cât tremurăm (ca să nu ne batem cu statuia)
# CUTREMUR: `add_shake` e o singură lovitură de trauma, care la shake_decay = 4 se stinge în ~0.15s —
# bun pentru un critic, prea scurt pentru Panic Button. Cutremurul ține trauma SUS pe o durată, apoi
# o lasă să scadă lin. Vezi `start_quake`.
var _quake_left: float = 0.0           # secunde rămase
var _quake_total: float = 0.0
var _quake_strength: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _cam: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	# arma aleasă din meniu (pistol / mage / extinguisher)
	weapon_type = GameSettings.weapon_type
	_apply_meta()  # upgrade-uri permanente cumpărate din meniu (meta-progresie)
	# Reperul lui Diesel Power = viteza cu care PORNEȘTI runda, luată DUPĂ META. Așa itemul
	# măsoară viteza câștigată în rundă (Weird Concoction, Alex's Protection), nu ce ai cumpărat
	# din magazin — altfel cine are Speed-ul maxat ar începe cu bonusul deja pe jumătate dat.
	_speed_base = speed
	_aura_tex = _make_radial_texture()   # fallback vizual pentru aura stingătorului
	_foam_frames = _build_foam_frames()  # animația de spumă (rândul 6 din stingator_effects.png)
	_muzzle_frames = _load_fx_frames("res://fx/muzzle", 26.0, false)
	_mage_boom_frames = _load_fx_frames("res://fx/mage_boom", 24.0, false)
	_mage_orb_frames = _load_fx_frames("res://fx/mage_orb", 18.0, true)  # loop = proiectil continuu
	_sword_frames = _load_fx_frames("res://fx/cursed sword fx", 22.0, false)  # animația de tăiere (12 cadre)
	_electric_frames = _load_fx_frames("res://fx/electricity fx", 30.0, false)  # arcul de Thunder God (14 cadre)
	_masoara_arta_sabiei()  # anvelopa animației → din ea se croiește dreptunghiul care lovește
	# Cursed Sword taie mai rar la început (ca să simți creșterea când iei attack speed).
	# O face slow o SINGURĂ dată aici; upgrade-urile de attack speed (Rabbit's Foot etc.) o accelerează după.
	if weapon_type == "sword":
		fire_interval *= sword_slow_start
	hp = max_hp
	# reperul panoului de statusuri: valorile de la START, DUPĂ meta + slow-ul sabiei
	_stats_base = {
		"bullet_damage": float(bullet_damage),
		"fire_interval": fire_interval,
		"crit_chance": crit_chance,
		"bullet_count": float(bullet_count),
		"pierce": float(pierce),
		"weapon_size": weapon_size_scale(),
		"knockback": knockback,
		"instakill_chance": instakill_chance,
		"speed": speed,
		"max_hp": float(max_hp),
		"hp_regen": float(hp_regen),
		"contact_damage": float(contact_damage),
	}
	anim.play("idle_south")  # pornim stând pe loc, uitându-ne în jos
	fire_timer = Timer.new()
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_fire)
	add_child(fire_timer)
	fire_timer.start()
	var damage_timer := Timer.new()
	damage_timer.wait_time = damage_interval
	damage_timer.timeout.connect(_take_contact_damage)
	add_child(damage_timer)
	damage_timer.start()
	# timer de regenerare: la fiecare secundă adaugă hp_regen (0 până iei upgrade-ul)
	var regen_timer := Timer.new()
	regen_timer.wait_time = 1.0
	regen_timer.timeout.connect(_regen)
	add_child(regen_timer)
	regen_timer.start()
	# timer pentru dâra de foc (Firewalker): lasă o băltoacă cât timp mergi
	var trail_timer := Timer.new()
	trail_timer.wait_time = 0.18
	trail_timer.timeout.connect(_drop_fire)
	add_child(trail_timer)
	trail_timer.start()
	# timer pentru dâra de gheață (Frostwalker): lasă gheață cât timp mergi
	var ice_timer := Timer.new()
	ice_timer.wait_time = 0.18
	ice_timer.timeout.connect(_drop_ice)
	add_child(ice_timer)
	ice_timer.start()

# Adaugă „traumă" (tremurat). Se cheamă de ex. la lovitură critică.
# ⚠️ Are un RĂGAZ MINIM între două zguduituri, și nu e cosmetic: fiecare critic adăuga 0.35
# traumă, iar trauma scade cu `shake_decay` (4.0) pe secundă. Peste ~11.4 atacuri pe secundă
# se aduna mai repede decât scădea, se lipea de 1.0 și ecranul tremura CONTINUU, fără oprire
# (raportat de Răzvan pe 2026-07-21, cu 12.92 atacuri/s și 9 proiectile — vezi session log).
# Cu răgazul de 0.12s intră cel mult ~2.9 traumă/s, deci sub cei 4.0 care se sting: tremuratul
# rămâne o pulsație, oricât de repede ai trage.
const SHAKE_MIN_GAP := 0.12
var _shake_next: float = 0.0

func add_shake(amount: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _shake_next:
		return
	_shake_next = now + SHAKE_MIN_GAP
	_trauma = min(1.0, _trauma + amount)

# Cutremur: tremurat SUSȚINUT `dur` secunde, care slăbește spre final. Nu e `add_shake` mai mare —
# ăla e un vârf care se stinge imediat; ăsta reîncarcă trauma în fiecare cadru (vezi `_process`).
func start_quake(dur: float, strength: float) -> void:
	_quake_total = max(0.01, dur)
	_quake_left = _quake_total
	_quake_strength = clampf(strength, 0.0, 1.0)

# Desenul de reglaj pentru sabie (doar cu sword_debug pornit): dreptunghiul roșu e chiar ce
# lovește. Desenăm pe player, care e la scale 2 în main.tscn, deci împărțim tot la scara lui
# ca să iasă pixeli reali (și liniile la grosimea cerută).
func _draw() -> void:
	if not sword_debug or weapon_type != "sword":
		return
	var ps: float = max(scale.x, 0.001)
	var dir := _sword_dir()
	var unghi := dir.angle()
	# dreptunghiul roșu = hitbox-ul, rotit după privire (îl ținem în sistemul artei, ca testul)
	var r := _sword_hit_rect()
	var colturi := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = (colturi[i] as Vector2).rotated(unghi) / ps
		var b2: Vector2 = (colturi[(i + 1) % 4] as Vector2).rotated(unghi) / ps
		draw_line(a, b2, Color(1, 0.25, 0.25, 0.9), 1.5 / ps)
	# crucea albastră = unde e agățată arta
	var c := _sword_offset(dir) / ps
	var b := 5.0 / ps
	draw_line(c - Vector2(b, 0), c + Vector2(b, 0), Color(0.3, 0.8, 1, 0.9), 1.5 / ps)
	draw_line(c - Vector2(0, b), c + Vector2(0, b), Color(0.3, 0.8, 1, 0.9), 1.5 / ps)
	# linia albă = direcția în care te uiți
	draw_line(Vector2.ZERO, dir * 30.0 / ps, Color(1, 1, 1, 0.5), 1.0 / ps)

func _process(delta: float) -> void:
	_update_slashes()  # tăieturile în curs se întorc după privire și lovesc pe unde mătură
	if sword_debug:
		queue_redraw()  # hitbox-ul se mișcă odată cu privirea → redesenăm în fiecare cadru
	if _cam == null:
		return
	# Cutremurul reîncarcă trauma cât ține, slăbind spre final → tremurat continuu, nu un vârf.
	if _quake_left > 0.0:
		_quake_left = max(0.0, _quake_left - delta)
		_trauma = max(_trauma, _quake_strength * (_quake_left / _quake_total))
	if _trauma > 0.0:
		_shaking = true
		_trauma = max(0.0, _trauma - shake_decay * delta)
		var amt := _trauma * _trauma  # pătrat = tremurat mai natural (mai brusc, se stinge lin)
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_max * amt
	elif _shaking:
		_shaking = false
		_cam.offset = Vector2.ZERO  # gata tremuratul: readucem camera o dată, apoi n-o mai atingem

func _physics_process(delta: float) -> void:
	var directie := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = directie * speed
	move_and_slide()
	if directie != Vector2.ZERO:
		_facing = directie.normalized()  # reținem direcția reală de privire (pt. tăietura sabiei)
		_update_anim(directie)
	else:
		var idle_nume := "idle_" + ultima_directie  # stă pe loc: poza statică pe ultima direcție
		if anim.animation != idle_nume:
			anim.play(idle_nume)

func _update_anim(directie: Vector2) -> void:
	var cadran := wrapi(int(round(directie.angle() / (PI / 4.0))), 0, 8)
	ultima_directie = DIRECTII[cadran]
	# Schimbăm animația DOAR când chiar diferă. Altfel, lângă granița dintre două
	# direcții (mai ales cu stick analog), play() ar reseta cadrul la 0 în fiecare
	# frame și animația de alergat ar părea înghețată.
	if anim.animation != ultima_directie:
		# păstrăm cadrul + progresul, ca pasul de alergare să curgă, nu să sară la 0
		# (toate animațiile de alergat au același număr de cadre)
		var cadru := anim.frame
		var progres := anim.frame_progress
		anim.play(ultima_directie)
		anim.set_frame_and_progress(cadru, progres)

# Mărimea armei ca factor de scalare: pixelii ceruți (Pufferfish) se traduc în scară
# raportat la glonțul de bază, apoi se aplică procentul (Rat's Burger).
func weapon_size_scale() -> float:
	return (1.0 + weapon_size_px / BULLET_BASE_PX) * weapon_size_mult

# Cât se înmulțește damage-ul unei lovituri, DUPĂ starea de acum: Cigarette Pack (mereu),
# Theo's Wrath (doar sub 20% viață) și Diesel Power (cu cât mergi mai repede). Gândit ca
# weapon_size_scale(): un factor derivat, citit la folosire, nu o valoare scrisă în player.
#
# De ce nu se scrie direct în bullet_damage, ca la The Nightclub: alea două depind de viața și
# viteza de ACUM, care se schimbă în fiecare secundă. Cigarette Pack ar putea fi scris direct,
# dar +5% peste un damage ÎNTREG se rotunjește urât (10 × 1.05 = 10.5 → 11, adică +10%, dublu
# cât scrie pe item), așa că stă tot aici, unde se adună exact.
#
# Se aplică pe damage-ul FINAL al lovturii, exact ca și criticul (crit_mult) — deci merge la
# toate armele, inclusiv Stingător și Cursed Sword. Dârele de foc/gheață nu-l primesc, la fel
# cum nu primesc nici upgrade-urile obișnuite de damage.
func damage_mult() -> float:
	var m := 1.0 + cig_bonus  # Cigarette Pack: mereu pornit
	# Theo's Wrath: doar cât ești sub pragul de viață (20% din max_hp)
	if theo_bonus > 0.0 and hp <= int(round(max_hp * theo_hp_threshold)):
		m += theo_bonus
	# Diesel Power: cu cât mergi mai repede
	if diesel_stacks > 0:
		m += diesel_per_stack * diesel_stacks * speed_ratio()
	return m

# Cât de repede mergi ACUM, raportat la viteza cu care ai pornit runda: 0 dacă stai pe loc,
# 1 la viteza de start, plafonat la speed_ratio_cap. Reperul lui Diesel Power ȘI al lui
# Megane's Katana — amândouă cresc la fel cu viteza, doar plătesc în monede diferite.
# `velocity` e viteza REALĂ, nu statistica `speed`: dacă te freci de un copac, scade și ea.
func speed_ratio() -> float:
	return clampf(velocity.length() / maxf(_speed_base, 1.0), 0.0, speed_ratio_cap)

# Șansa de critic de ACUM: cea fixă (Adrenaline) + cea care crește cu viteza (Megane's Katana).
# NU mai e plafonată la 100% — peste 100% intră multi-crit-ul (vezi roll_crit). Se citește la
# fiecare lovitură, din același motiv ca damage_mult(): partea de la Katana se schimbă la fiecare pas.
func crit_chance_now() -> float:
	# fără niciun item de crit, norocul n-are ce umfla (vezi `luck_bonus`)
	if crit_chance <= 0.0 and katana_stacks == 0:
		return 0.0
	var c := crit_chance + luck_bonus()
	if katana_stacks > 0:
		c += katana_per_stack * katana_stacks * speed_ratio()
	return c

# Instakill-ul (Hacksaw) cu norocul inclus. La fel: dacă n-ai itemul, rămâne 0.
func instakill_chance_now() -> float:
	if instakill_chance <= 0.0:
		return 0.0
	return instakill_chance + luck_bonus()

# MULTI-CRIT: peste 100% șansă, criticul se declanșează de mai multe ori. Partea ÎNTREAGĂ din
# șansă = crituri GARANTATE, partea fracționară = șansa de încă unul. Fiecare nivel înmulțește
# damage-ul cu crit_mult (2×): 100% → 2×, 200% → 4×, 300% → 8× ... 0 crituri → ×1 (fără critic).
# Întoarce {"tiers": int (câte crituri), "mult": float (multiplicatorul final de damage)}.
func roll_crit() -> Dictionary:
	var c := maxf(0.0, crit_chance_now())
	var tiers := int(floor(c))
	if randf() < c - float(tiers):
		tiers += 1
	return {"tiers": tiers, "mult": pow(crit_mult, tiers) if tiers > 0 else 1.0}

# Statusurile de ACUM, pregătite pentru panoul din meniul de level-up (stil Binding of Isaac).
# Fiecare rând: {"label", "value" (text gata formatat), "state" ∈ "same"/"up"/"down"}.
# "state" iese din comparația cu _stats_base (valorile de la start). La Attack Speed și Damage
# Taken „mai bun" înseamnă mai MIC (lower_better = true), de-aia acolo se compară invers.
func stat_lines() -> Array:
	var b = _stats_base
	if b.is_empty():
		return []
	return [
		_stat_row("Damage", bullet_damage, b["bullet_damage"], false, str(bullet_damage)),
		_stat_row("Attack Speed", fire_interval, b["fire_interval"], true, "%.2f/s" % (1.0 / max(fire_interval, 0.01))),
		# Crit și Instakill se afișează CU norocul inclus (`*_now()`), altfel panoul ar arăta
		# 15% după ce ai luat un trifoi care ți-a dus criticul real la 17%.
		_stat_row("Crit", crit_chance_now(), b["crit_chance"], false, "%d%%" % round(crit_chance_now() * 100.0)),
		_stat_row("Projectiles", projectiles_total(), b["bullet_count"], false, str(projectiles_total())),
		_stat_row("Pierce", pierce, b["pierce"], false, str(pierce)),
		_stat_row("Weapon Size", weapon_size_scale(), b["weapon_size"], false, "%d%%" % round(weapon_size_scale() * 100.0)),
		_stat_row("Knockback", knockback, b["knockback"], false, str(int(round(knockback)))),
		_stat_row("Instakill", instakill_chance_now(), b["instakill_chance"], false, "%.1f%%" % (instakill_chance_now() * 100.0)),
		# fără „.0" degeaba: 2.5 rămâne „2.5", dar 5.0 se scrie „5"
		_stat_row("Luck", luck, 0.0, false, ("%.1f" % luck).trim_suffix(".0")),
		_stat_row("Move Speed", speed, b["speed"], false, str(int(round(speed)))),
		_stat_row("Max HP", max_hp, b["max_hp"], false, str(max_hp)),
		_stat_row("HP Regen", hp_regen, b["hp_regen"], false, "%d/s" % hp_regen),
		_stat_row("Damage Taken", contact_damage, b["contact_damage"], true, str(contact_damage)),
	]

# Câte proiectile pleacă GARANTAT la o salvă: cele paralele + cele trase în alți inamici
# (Gunslinger / Twin Comets). Broken Watch NU intră aici — e pe șansă, nu garantat.
# Fără asta, rândul „Projectiles" din panou ar rămâne veșnic pe 1, deși itemele îl cresc.
func projectiles_total() -> int:
	return bullet_count + stacked_armory_stacks

func _stat_row(label: String, cur: float, base: float, lower_better: bool, disp: String) -> Dictionary:
	var state := "same"
	if not is_equal_approx(cur, base):
		var better := cur > base
		if lower_better:
			better = cur < base
		state = "up" if better else "down"
	return {"label": label, "value": disp, "state": state}

# Panic Button: cutremur + undă de șoc care pleacă din player, ca „Mama Mega" din Binding of Isaac.
# Damage fix — nu trece prin damage_mult() și nu poate da critic: e o detonare, nu o lovitură de armă.
#
# Damage-ul NU se mai aplică tuturor deodată: îl dă unda, pe măsură ce ajunge la fiecare inamic
# (`shockwave.gd`). Cei de lângă tine mor primii, apoi valul se rostogolește spre margini.
# Acoperirea rămâne aceeași — unda merge până dincolo de colțurile ecranului, deci tot ce se vede
# încasează. Ce e MAI DEPARTE de atât nu mai încasează, spre deosebire de varianta veche care lovea
# toată harta, inclusiv inamici pe care nici nu-i vedeai.
func panic_button(dmg: int) -> void:
	Audio.play("hurt", -2.0)  # bubuitura (placeholder)
	start_quake(0.9, 0.85)    # cutremurul ține cât mătură unda, plus puțin
	var w := Node2D.new()
	w.set_script(SHOCKWAVE)
	w.damage = dmg
	w.max_radius = _raza_ecran()
	get_parent().add_child(w)
	w.global_position = global_position

# Cât trebuie să se întindă unda ca să treacă de colțurile ecranului. Jumătatea de diagonală a zonei
# vizibile: viewport-ul împărțit la zoom-ul camerei (zoom 0.7 = se vede MAI MULT decât viewport-ul),
# plus o marjă. Calculat, nu o constantă — altfel se strică la alt zoom sau altă rezoluție de telefon.
func _raza_ecran() -> float:
	var vp := get_viewport_rect().size
	var zoom := Vector2.ONE
	if _cam != null and _cam.zoom.x > 0.0 and _cam.zoom.y > 0.0:
		zoom = _cam.zoom
	return (vp / zoom).length() * 0.5 + 64.0

# dispecer de tragere: fiecare tick face altceva după arma aleasă
func _fire() -> void:
	if weapon_type == "extinguisher":
		_aura_pulse()      # stingătorul nu trage gloanțe, ci pulsează o aură
	elif weapon_type == "sword":
		_sword_swing()     # sabia taie în conul din fața player-ului
	else:
		_fire_bullets()    # pistol / mage

# Pistol (simplu) și Mage Staff (AOE) trag gloanțe spre cel mai apropiat inamic.
func _fire_bullets() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var dir := (target.global_position - global_position).normalized()
	Audio.play("shoot", -6.0)
	_muzzle(global_position + dir * 34.0, dir)
	# damage-ul acestei salve, cu procentele care depind de starea de acum (Theo's / Cigarette / Diesel)
	var dmg_base := int(round(bullet_damage * damage_mult()))
	var ex_radius := explosion_radius
	var ex_damage := explosion_damage
	# Jean's Bomb: explozia = procent din damage-ul salvei, recalculat la fiecare tragere
	if explosion_damage_pct > 0.0:
		ex_damage = maxi(ex_damage, int(round(dmg_base * explosion_damage_pct)))
	# Mage Staff: fiecare glonț explodează AOE la impact (peste eventualul Jean's Bomb)
	if weapon_type == "mage":
		ex_radius = max(ex_radius, 110.0)
		ex_damage = max(ex_damage, int(dmg_base * 0.6))
	var any_crit := false
	# salva principală: `bullet_count` gloanțe paralele spre ținta cea mai apropiată
	if _fire_volley(global_position, dir, dmg_base, ex_radius, ex_damage, target):
		any_crit = true
	# Proiectile BONUS trase în ALȚI inamici la întâmplare — pleacă în direcții diferite deodată,
	# nu paralele între ele, dar FIECARE e o salvă completă:
	#  · Gunslinger (+1 pe luare) și Twin Comets (+2 pe luare): garantate,
	#    `stacked_armory_stacks` bucăți
	#  · Broken Watch: 50% șansă (broken_watch_chance) să tragă `broken_watch_stacks` bucăți
	var bonus := stacked_armory_stacks
	if broken_watch_stacks > 0 and randf() < broken_watch_chance + luck_bonus():
		bonus += broken_watch_stacks
	if bonus > 0:
		for tnode in _armory_targets(target, bonus):
			var enemy2 := tnode as Node2D
			var d2 := (enemy2.global_position - global_position).normalized()
			if _fire_volley(global_position, d2, dmg_base, ex_radius, ex_damage, enemy2):
				any_crit = true
	if any_crit:
		add_shake(0.35)

# O salvă de `bullet_count` gloanțe paralele, centrată pe `origin`, toate în direcția `dir`.
# Întoarce true dacă VREUNUL a fost critic. Folosită și de salva principală, și de proiectilele
# bonus. Momentan `bullet_count` e mereu 1 (niciun item nu-l mai crește) → o salvă = un glonț.
func _fire_volley(origin: Vector2, dir: Vector2, dmg_base: int, ex_radius: float, ex_damage: int, tinta: Node2D = null) -> bool:
	var perp := Vector2(-dir.y, dir.x)
	var any_crit := false
	for i in bullet_count:
		var offset := (i - (bullet_count - 1) / 2.0) * bullet_spacing
		if _spawn_one_bullet(origin + perp * offset, dir, dmg_base, ex_radius, ex_damage, tinta):
			any_crit = true
	return any_crit

# Creează un glonț cu toate proprietățile playerului, la poziția și în direcția date. Își rulează
# propriul critic (multi-crit) și întoarce true dacă a fost critic (pt. zguduitura camerei).
func _spawn_one_bullet(pos: Vector2, dir: Vector2, dmg_base: int, ex_radius: float, ex_damage: int, tinta: Node2D = null) -> bool:
	var bullet := bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = pos
	var cr := roll_crit()  # Adrenaline + Megane's Katana (cu viteza); peste 100% = multi-crit
	var is_crit: bool = cr["tiers"] > 0
	bullet.damage = int(round(dmg_base * cr["mult"]))
	bullet.is_crit = is_crit
	bullet.speed = bullet_speed
	bullet.pierce = pierce
	bullet.knockback = knockback
	bullet.instakill_chance = instakill_chance_now()
	bullet.explosion_radius = ex_radius
	bullet.explosion_damage = ex_damage
	bullet.thunder = thunder_stacks > 0 or plugged_in_stacks > 0  # Thunder God / Plugged In: curent la impact
	bullet.target = tinta   # glontul se corecteaza in zbor spre ea (vezi homing-ul din bullet.gd)
	if weapon_type == "mage":
		bullet.explosion_frames = _mage_boom_frames  # explozie violet la impact
		_make_mage_orb(bullet)                       # proiectil = sferă magică animată
	# scalează sprite-ul ȘI hitbox-ul (CollisionShape2D e copil al glonțului), plus sfera mage
	bullet.scale *= bullet_scale * weapon_size_scale()
	bullet.set_direction(dir)
	return is_crit

# Ținte pentru Gunslinger: `n` inamici, preferați ALȚII decât ținta principală. Dacă nu-s
# destui alți inamici, se repetă / cade pe ținta principală, ca toate proiectilele bonus să tragă.
func _armory_targets(primary: Node, n: int) -> Array:
	var others := []
	var toti := []
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy != null and enemy != primary:
			toti.append(enemy)
			# Preferam inamicii din RAZA UTILA. Inainte se alegeau la intamplare din toata harta,
			# deci cu multe proiectile bonus jumatate plecau spre celalalt capat al ecranului si
			# mureau de batranete (lifetime 2s x 700px/s = ~1400px) fara sa atinga nimic.
			if global_position.distance_squared_to(enemy.global_position) <= ARMORY_RANGE_SQ:
				others.append(enemy)
	if others.is_empty():
		others = toti   # nimeni aproape -> tragem oricum, ca inainte
	others.shuffle()
	var targets := []
	for i in n:
		if others.size() > 0:
			targets.append(others[i % others.size()])  # mai puțini decât n → se repetă
		else:
			targets.append(primary)                     # niciun alt inamic → ținta principală
	return targets

# Thunder God: fulger de la un inamic lovit spre TOȚI inamicii din rază — fiecare primește un arc
# electric + damage + tentă albastră. NU se lanțuie mai departe (arcurile nu declanșează alt
# Thunder), exact ca Jacob's Ladder.
# `thunder_from` primește nodul lovit (îl folosește ca origine + îl exclude); e apelată de sabie.
# `thunder_burst` lucrează pe POZIȚIE + id de exclus — așa poate fi apelată `call_deferred` de glonț
# (impactul se emite în timpul fizicii; omorârea vecinilor acolo strică starea → o amânăm).
func thunder_from(src: Node2D) -> void:
	if src != null and is_instance_valid(src):
		thunder_burst(src.global_position, src.get_instance_id())

func thunder_burst(origin: Vector2, exclude_id: int) -> void:
	# ATENȚIE: aici NU se verifică `thunder_stacks > 0`. Așa era înainte și făcea Plugged In complet
	# inutil: `thunder_active_on_hit()` trecea rostogolirea de 10%, apoi burst-ul ieșea imediat pe ușă
	# fiindcă `thunder_stacks` era 0. Decizia „se declanșează?" aparține lui `thunder_active_on_hit()`
	# (singurul apelant, pe toate cele 3 arme) — dublarea ei aici doar rupea itemul.
	if thunder_stacks <= 0 and plugged_in_stacks <= 0:
		return
	var dmg := thunder_damage()
	# Nodul de origine (inamicul lovit), ca arcul să-l urmărească dacă a supraviețuit impactului.
	# Poate fi deja mort (thunder_burst e deferred) → atunci rămâne punctul fix `origin`.
	var src_node := instance_from_id(exclude_id) as Node2D
	if src_node != null and not is_instance_valid(src_node):
		src_node = null
	# Câte arcuri DESENĂM din descărcarea asta. Damage-ul îl încasează toți din rază, ca înainte —
	# doar vizualul e plafonat. Într-o gloată de 300 de inamici, un singur impact năștea zeci de
	# arcuri, fiecare cu nodul și `_process`-ul lui; se ajungea la 4000 de arcuri vii deodată și
	# jocul cădea la 6 FPS. Peste vreo 10 suprapuse nici nu mai distingi ceva pe ecran.
	var arce_ramase := THUNDER_MAX_ARCE
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null or enemy.get_instance_id() == exclude_id:
			continue
		if origin.distance_to(enemy.global_position) > thunder_range:
			continue
		if arce_ramase > 0:
			_spawn_electric_arc(origin, enemy.global_position, src_node, enemy)
			arce_ramase -= 1
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
			if enemy.has_method("flash_electric"):
				enemy.flash_electric()   # tentă albastră electrică pe inamicul lovit de curent
			Fx.damage_number(enemy.global_position, dmg, false)

# Se declanșează lanțul la ACEST impact? Thunder God = mereu; Plugged In = șansă (10% per luare).
func thunder_active_on_hit() -> bool:
	if thunder_stacks > 0:
		return true
	if plugged_in_stacks > 0 and randf() < minf(1.0, plugged_in_stacks * plugged_in_chance_per + luck_bonus()):
		return true
	return false

# Variantă deferred pentru glonț: rulează rostogolirea (Thunder God / Plugged In) la momentul
# deferred și, dacă trece, pornește lanțul. Vezi thunder_burst pentru de ce e deferred.
func thunder_burst_maybe(origin: Vector2, exclude_id: int) -> void:
	if thunder_active_on_hit():
		thunder_burst(origin, exclude_id)

# Procentul din damage pe care îl face un arc: 25% la prima luare a lui Thunder God, +25% la
# fiecare repetare (2× = 50%, 3× = 75%...). Plugged In singur rămâne la 25% — el crește ȘANSA
# să pornească lanțul, nu cât lovește; de-aia se folosește `maxi(thunder_stacks, 1)`.
func thunder_damage_pct() -> float:
	return THUNDER_PCT_PER_STACK * float(maxi(thunder_stacks, 1))

# Damage-ul unui arc de Thunder God. `damage_mult()` intră în calcul (ca la Jean's Bomb), deci
# procentul e din damage-ul REAL al momentului, cu tot cu Theo's Wrath / Cigarette / Diesel.
func thunder_damage() -> int:
	return maxi(1, int(round(bullet_damage * damage_mult() * thunder_damage_pct())))

# Arcul electric vizual, întins între cele două capete. Rotirea/întinderea le face `electric_arc.gd`
# în fiecare cadru, ca arcul să stea LIPIT ca o frânghie între inamici cât timp aceștia se mișcă
# (înainte era întins o dată la spawn și rămânea în urmă). `n_from`/`n_to` sunt nodurile de urmărit;
# dacă unul e null sau moare, capătul lui rămâne la ultima poziție. Se joacă o dată și se distruge.
func _spawn_electric_arc(from: Vector2, to: Vector2, n_from: Node2D = null, n_to: Node2D = null) -> void:
	if _electric_frames == null or _electric_frames.get_frame_count("fx") == 0:
		return
	if from.distance_to(to) < 1.0:
		return
	if _arce_vii >= THUNDER_MAX_ARCE_VII:
		return   # plafon global: la gloată, arcurile se suprapun oricum într-o pată
	var fh := float(_electric_frames.get_frame_texture("fx", 0).get_height())
	var a := AnimatedSprite2D.new()
	a.set_script(load("res://electric_arc.gd"))
	a.sprite_frames = _electric_frames
	a.animation = "fx"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.z_index = 50  # peste inamici
	get_parent().add_child(a)
	a.setup(from, to, n_from, n_to, fh)
	a.play("fx")
	_arce_vii += 1
	a.animation_finished.connect(func() -> void:
		_arce_vii = maxi(0, _arce_vii - 1)
		a.queue_free())

# Stingător: aură care pulsează în jurul tău. Rază = bază + nivel × creștere;
# frecvența pulsului = fire_interval (scade cu upgrade-urile de cadență) → tot mai des.
func _aura_pulse() -> void:
	# raza aurei e și vizualul, și zona care lovește → aceeași valoare pentru amândouă (hitbox = sprite mereu)
	var radius := (aura_base_radius + level * aura_growth + weapon_size_px) * weapon_size_mult * foam_scale
	# aura scalează și cu upgrade-urile de damage, plus procentele de acum (Theo's / Cigarette / Diesel)
	var dmg := int(round((aura_damage + int(bullet_damage * 0.5)) * damage_mult()))
	var cr := roll_crit()                              # Adrenaline + Megane's Katana; peste 100% = multi-crit
	var is_crit: bool = cr["tiers"] > 0
	if is_crit:
		dmg = int(round(dmg * cr["mult"]))
	var hit := false
	var loviti: Array[Node2D] = []   # cine a încasat pulsul → din ei pornește Thunder God (vezi jos)
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(dmg)
			Fx.damage_number(enemy.global_position, dmg, is_crit)
			if knockback > 0.0 and enemy.has_method("apply_knockback"):
				enemy.apply_knockback((enemy.global_position - global_position).normalized() * knockback)
			loviti.append(enemy)
			hit = true
	if hit:
		Audio.play("shoot", -12.0)  # foșnet slab (placeholder până ai sunet de spumă)
		if is_crit:
			add_shake(0.35)  # zguduitură ca la gloanțele critice
		# Thunder God / Plugged In și pe Stingător. UN SINGUR lanț pe puls, dintr-un inamic lovit la
		# întâmplare — NU câte unul din fiecare. Aura lovește tot ce prinde deodată; un lanț de fiecare
		# ar da N×N arcuri pe puls (10 inamici = 90 de arcuri, de câteva ori pe secundă) — și ilizibil,
		# și greu. Un lanț per puls păstrează regula celorlalte arme: un impact = o descărcare.
		if thunder_active_on_hit():
			var vii := loviti.filter(func(n: Node2D) -> bool: return is_instance_valid(n))
			if not vii.is_empty():
				thunder_from(vii[randi() % vii.size()])
	_spawn_aura_ring(radius)

# Vizual placeholder al aurei: un nor bleu-alb care se extinde din player și se stinge.
func _spawn_aura_ring(radius: float) -> void:
	# preferăm animația de spumă (rândul 6); dacă nu e importată încă, cădem pe inelul gradient
	if _foam_frames != null and _foam_frames.get_frame_count("foam") > 0:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = _foam_frames
		a.animation = "foam"
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar
		a.modulate = Color(0.8, 0.95, 1.0, 0.9)  # ușor bleu, ca spuma
		a.z_index = -1  # sub player/inamici
		get_parent().add_child(a)
		a.global_position = global_position
		a.scale = Vector2.ONE * (radius * 2.0) / 64.0  # frame 64px → diametru = 2×rază = exact hitbox-ul
		a.play("foam")
		a.animation_finished.connect(a.queue_free)
		return
	# fallback: inel gradient (dacă frame-urile nu-s încă importate de Godot)
	if _aura_tex == null:
		return
	var s := Sprite2D.new()
	s.texture = _aura_tex
	s.modulate = Color(0.6, 0.9, 1.0, 0.5)
	s.z_index = -1
	get_parent().add_child(s)
	s.global_position = global_position
	var full := (radius * 2.0) / 256.0
	s.scale = Vector2.ONE * full * 0.25
	var t := create_tween()
	t.tween_property(s, "scale", Vector2.ONE * full, 0.28)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.32)
	t.tween_callback(s.queue_free)

# Cursed Sword: la fiecare tick pornește o tăietură. Ca în Megabonk, tăietura NU e o poză
# înghețată: cât ține animația se rotește după privire și mătură, lovind pe unde trece.
# Scalează cu upgrade-urile playerului: damage (bullet_damage), attack speed (fire_interval),
# crit (Adrenaline), knockback, instakill (Hacksaw) și mărime (Pufferfish/Rat's Burger).
func _sword_swing() -> void:
	# taie mai tare cu upgrade-urile de damage + procentele de acum (Theo's / Cigarette / Diesel).
	# Se fixează la începutul tăieturii, ca și criticul: o tăietură = un damage, cât mătură.
	var dmg := int(round((sword_base_damage + bullet_damage) * damage_mult()))
	var cr := roll_crit()                             # Adrenaline + Megane's Katana; peste 100% = multi-crit
	var is_crit: bool = cr["tiers"] > 0
	if is_crit:
		dmg = int(round(dmg * cr["mult"]))
	Audio.play("shoot", -10.0)  # foșnet de tăiere (placeholder)
	var nod := _spawn_sword_slash(_sword_dir())
	if nod == null:
		return
	# Tăietura rămâne VIE cât ține animația (_update_slashes o rotește și o lasă să lovească).
	# `loviti` = ID-urile inamicilor deja tăiați de ea, ca o tăietură să lovească pe fiecare
	# o SINGURĂ dată oricât ar mătura — altfel ar da damage în fiecare cadru.
	var t := {"nod": nod, "loviti": {}, "dmg": dmg, "crit": is_crit, "shake": false}
	_slashes.append(t)
	_sword_damage_pass(t)  # o trecere imediată, ca lovitura să se simtă pe loc

# O trecere de damage pentru o tăietură în curs: cine e în dreptunghiul ei, chiar acum.
# Dreptunghiul e mereu același (croit pe anvelopa animației), doar se întoarce după privire.
func _sword_damage_pass(t: Dictionary) -> void:
	var dir := _sword_dir()
	var rect := _sword_hit_rect()
	var loviti: Dictionary = t["loviti"]
	var dmg: int = t["dmg"]
	var is_crit: bool = t["crit"]
	var hit := false
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		var id := enemy.get_instance_id()  # ID, nu nodul: inamicul poate muri între treceri
		if loviti.has(id):
			continue
		if not _sword_rect_hit(dir, rect, enemy.global_position):
			continue
		loviti[id] = true
		# Hacksaw: șansă să ucidă instant (îi scoatem toată viața dintr-o lovitură)
		var ik := instakill_chance_now()
		var kill := ik > 0.0 and randf() < ik
		var dealt := dmg
		if kill and "hp" in enemy:
			dealt = int(enemy.hp)
		enemy.take_damage(dealt)
		Fx.damage_number(enemy.global_position, dealt, is_crit or kill)
		# Thunder God / Plugged In: sabia lovește un inamic → (mereu / cu șansă) curent spre ceilalți
		if thunder_active_on_hit():
			thunder_from(enemy)
		if knockback > 0.0 and enemy.has_method("apply_knockback"):
			# îl împingem dinspre PLAYER, nu dinspre centrul tăieturii
			var push := (enemy.global_position - global_position).normalized()
			if push == Vector2.ZERO:
				push = dir  # lipit de tine: îl împingem în direcția tăieturii
			enemy.apply_knockback(push * knockback)
		hit = true
	if hit and is_crit and not t["shake"]:
		t["shake"] = true  # o singură zguduitură per tăietură, nu una pe cadru
		add_shake(0.35)

# Cât se joacă, fiecare tăietură se întoarce după privire și mai dă o trecere de damage.
# Ăsta e „ca în Megabonk": sabia se mișcă odată cu tine, nu rămâne unde ai pornit-o.
func _update_slashes() -> void:
	if _slashes.is_empty():
		return
	var dir := _sword_dir()
	var ps: float = max(scale.x, 0.001)
	for i in range(_slashes.size() - 1, -1, -1):
		var t: Dictionary = _slashes[i]
		# validitatea se verifică ÎNAINTE de atribuirea într-o variabilă tipată: dacă animația
		# s-a terminat și nodul s-a auto-șters, `var nod: AnimatedSprite2D = ...` crapă cu
		# „Trying to assign invalid previously freed instance".
		if not is_instance_valid(t["nod"]):
			_slashes.remove_at(i)
			continue
		var nod: AnimatedSprite2D = t["nod"]
		nod.position = _sword_offset(dir) / ps
		nod.rotation = dir.angle() - PI + sword_art_rotation
		nod.scale = Vector2.ONE * (_sword_visual_size() / SWORD_FRAME_W) / ps
		_sword_damage_pass(t)

# Mărimea tăieturii pe ecran, în px (Pufferfish/Rat's Burger o cresc).
func _sword_visual_size() -> float:
	return sword_size * weapon_size_scale()

# Unde stă ancora tăieturii, în sistemul ARTEI (x = înainte, y = lateral), în pixeli reali.
# Scalează cu mărimea armei (Pufferfish/Rat's Burger), la fel ca sprite-ul — dacă uiți asta,
# arta pleacă în față la un size up și hitbox-ul rămâne în urmă (fix bug-ul reclamat de Răzvan).
# Sursă unică pentru artă, hitbox și debug, ca să nu se mai poată despărți.
func _sword_offset_art() -> Vector2:
	return Vector2(sword_reach, sword_lateral) * weapon_size_scale()

# Aceeași ancoră, întoarsă după privire (pentru așezat sprite-ul).
func _sword_offset(dir: Vector2) -> Vector2:
	return _sword_offset_art().rotated(dir.angle())

# Măsoară o dată, la pornire, cât ocupă animația: mărimea cadrului și ANVELOPA ei
# (dreptunghiul care cuprinde pixelii opaci ai TUTUROR cadrelor), în pixeli de artă.
# Din anvelopă se croiește hitbox-ul, deci dacă schimbi arta nu mai ai nimic de calculat de mână.
func _masoara_arta_sabiei() -> void:
	if _sword_frames == null:
		return
	var minim := Vector2.INF
	var maxim := -Vector2.INF
	for i in _sword_frames.get_frame_count("fx"):
		var tex: Texture2D = _sword_frames.get_frame_texture("fx", i)
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()  # get_pixel nu merge pe o imagine comprimată
		_sword_frame_px = Vector2(img.get_width(), img.get_height())
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a <= 0.08:
					continue
				minim = Vector2(min(minim.x, x), min(minim.y, y))
				maxim = Vector2(max(maxim.x, x), max(maxim.y, y))
	if minim.x > maxim.x:
		return  # animația e goală; lăsăm anvelopa pe zero
	_sword_env = Rect2(minim, maxim - minim + Vector2.ONE)

# Dreptunghiul care lovește, în sistemul ARTEI (x = înainte, y = lateral), în pixeli reali.
# De la player (x = 0) până la cel mai depărtat pixel al animației, în față și în lateral.
# Sprite-ul e rotit cu -PI (arta are fața spre vest), deci un x MIC în cadru = departe în FAȚĂ.
func _sword_hit_rect() -> Rect2:
	var s := _sword_visual_size() / SWORD_FRAME_W
	var c := _sword_frame_px * 0.5  # centrul cadrului: acolo e agățat sprite-ul
	var ancora := _sword_offset_art()  # ACEEAȘI ancoră ca sprite-ul, deci scalată la fel
	# rotația cu -PI întoarce semnele: (px, py) → (-(px-cx), -(py-cy))
	var fata := (c.x - _sword_env.position.x) * s + ancora.x
	var y1 := -(_sword_env.end.y - 1.0 - c.y) * s + ancora.y
	var y2 := -(_sword_env.position.y - c.y) * s + ancora.y
	var sus: float = min(y1, y2)
	return Rect2(0.0, sus, max(fata, 0.0), max(y1, y2) - sus)

# Inamicul e în dreptunghi? Îl aducem în sistemul artei (rotim invers cu privirea), apoi
# un simplu has_point — hitbox-ul are aceeași formă în toate direcțiile, doar întoarsă.
func _sword_rect_hit(dir: Vector2, rect: Rect2, punct: Vector2) -> bool:
	var local := (punct - global_position).rotated(-dir.angle())
	return rect.has_point(local)

# Direcția în care taie acum (aceeași pentru artă, hitbox și desenul de debug).
func _sword_dir() -> Vector2:
	if _facing == Vector2.ZERO:
		return Vector2.DOWN
	return _facing.normalized()

# Vizualul tăieturii: animația de slash, COPIL al player-ului → se mișcă odată cu el.
# Aici o așezăm doar la pornire; `_update_slashes` o ține întoarsă după privire în fiecare cadru
# cât se joacă (ca în Megabonk), deci `dir` de aici e doar poziția de start.
func _spawn_sword_slash(dir: Vector2) -> AnimatedSprite2D:
	if _sword_frames == null or _sword_frames.get_frame_count("fx") == 0:
		return null
	var a := AnimatedSprite2D.new()
	a.sprite_frames = _sword_frames
	a.animation = "fx"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sub player: e frate cu AnimatedSprite2D-ul lui (z 0), deci -1 îl lasă mereu în spate.
	# Altfel, când tai spre nord, tăietura e desenată peste cap și-l acoperă.
	a.z_index = -1
	add_child(a)  # copil al player-ului → tăietura îl urmează
	# player-ul e la scale 2 în main.tscn; împărțim la scara lui ca reach/scale să fie în pixeli reali
	var ps: float = max(scale.x, 0.001)
	a.position = _sword_offset(dir) / ps
	# cadrele au fața spre VEST (ca la Firewalker) → le întoarcem spre direcția de privire
	a.rotation = dir.angle() - PI + sword_art_rotation
	# scalăm cadrul (64 px lățime) la sword_size px, ca mărimea să nu depindă de arta pusă
	a.scale = Vector2.ONE * (_sword_visual_size() / SWORD_FRAME_W) / ps
	a.speed_scale = max(sword_anim_speed, 0.01)  # 0 ar îngheța tăietura pe ecran pentru totdeauna
	a.play("fx")
	a.animation_finished.connect(a.queue_free)
	return a

# Construiește animația de spumă din cele 14 frame-uri tăiate (stingator/frame_0..13.png).
func _build_foam_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if not sf.has_animation("foam"):
		sf.add_animation("foam")
	sf.set_animation_loop("foam", false)
	sf.set_animation_speed("foam", 24.0)  # 14 frame-uri la 24fps ≈ 0.58s
	for i in 14:
		var path := "res://stingator/frame_%d.png" % i
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				sf.add_frame("foam", tex)
	return sf

# --- efecte animate din gigapack (muzzle / explozie mage / sferă mage) ---
# Încarcă frame_0.png, frame_1.png ... dintr-un folder, într-o animație numită "fx".
func _load_fx_frames(dir: String, fps: float, loop: bool) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("fx")
	sf.set_animation_loop("fx", loop)
	sf.set_animation_speed("fx", fps)
	var i := 0
	while ResourceLoader.exists("%s/frame_%d.png" % [dir, i]):
		var tex := load("%s/frame_%d.png" % [dir, i]) as Texture2D
		if tex != null:
			sf.add_frame("fx", tex)
		i += 1
	return sf

# Joacă o animație one-shot în lume și o distruge la final.
func _play_effect(frames: SpriteFrames, pos: Vector2, sc: float, z: int, rot: float = 0.0) -> void:
	if frames == null or frames.get_frame_count("fx") == 0:
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.animation = "fx"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.z_index = z
	a.rotation = rot
	a.scale = Vector2.ONE * sc
	get_parent().add_child(a)
	a.global_position = pos
	a.play("fx")
	a.animation_finished.connect(a.queue_free)

# Fulger la țeavă: animația scifi dacă e importată, altfel fulgerul din cod (Fx).
func _muzzle(pos: Vector2, dir: Vector2) -> void:
	if _muzzle_frames != null and _muzzle_frames.get_frame_count("fx") > 0:
		_play_effect(_muzzle_frames, pos, muzzle_scale, 60, dir.angle())
	else:
		Fx.muzzle(pos)

# Înlocuiește vizualul glonțului mage cu sfera magică animată (loop).
func _make_mage_orb(bullet: Node) -> void:
	if _mage_orb_frames == null or _mage_orb_frames.get_frame_count("fx") == 0:
		bullet.modulate = Color(0.7, 0.5, 1.0)  # fallback mov dacă sfera nu e importată
		return
	var spr = bullet.get_node_or_null("Sprite2D")
	if spr != null:
		spr.visible = false  # ascundem glonțul normal
	var orb := AnimatedSprite2D.new()
	orb.sprite_frames = _mage_orb_frames
	orb.animation = "fx"
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	orb.modulate = Color(0.72, 0.45, 1.0)  # filtru mov ca să semene cu explozia mage_boom
	# Sfera e copil al glonțului, deci moștenește scale-ul lui (0.1). Împărțim la el
	# ca `mage_orb_size` să însemne chiar pixeli pe ecran, nu pixeli × 0.1.
	var fw := _mage_orb_frames.get_frame_texture("fx", 0).get_width()
	var parent_scale: float = max(bullet.scale.x, 0.001)
	orb.scale = Vector2.ONE * (mage_orb_size / float(max(fw, 1))) / parent_scale
	bullet.add_child(orb)
	orb.play("fx")

# Textură rotundă moale (gradient radial) — placeholder pentru spumă/aură.
func _make_radial_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex

func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var min_dist := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < min_dist:
			min_dist = d
			nearest = enemy
	return nearest

func _take_contact_damage() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Cât lovesc inamicii ACUM: `contact_damage` e statul TĂU (îl scade Vodka), iar
	# `Difficulty.enemy_damage_mult()` e cât de duri au devenit ei cu timpul (×1 în primele
	# 1:30, ×2 la minutul 10). Minimul de 1 ca un stat foarte bun să nu ducă damage-ul la 0.
	var dmg := maxi(1, int(round(contact_damage * Difficulty.enemy_damage_mult())))
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) < contact_range:
			take_damage(dmg)
			# Mike's Hedgehog: reflectă 100% din damage înapoi în inamic, cel mult o dată la 3s
			if hedgehog and now >= _hedgehog_next and enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
				_hedgehog_next = now + 3.0

func _regen() -> void:
	if hp_regen > 0 and hp > 0:
		hp = min(max_hp, hp + hp_regen)

# Firewalker: lasă o băltoacă de foc pe jos cât timp player-ul se mișcă.
# Dacă are ȘI Frostwalker, nu lăsăm foc separat — combinația devine Godwalker (vezi _drop_ice).
func _drop_fire() -> void:
	if fire_trail_time <= 0.0 or frost_trail_time > 0.0 or velocity.length() < 5.0:
		return
	var patch := FIRE_TRAIL.new()
	patch.duration = fire_trail_time     # cât rămâne (crește cu fiecare upgrade)
	patch.damage = fire_trail_damage
	patch.size = fire_trail_size * weapon_size_scale()  # mărimea (crește cu upgrade-urile + Pufferfish/Rat's Burger)
	patch.direction = velocity.normalized()  # focul se orientează în direcția de mers
	get_parent().add_child(patch)        # în World (y-sort). Nodul e putin DEASUPRA player-ului →
	patch.global_position = global_position - Vector2(0, 4)  # e desenat în SPATE, iar vizualul e coborât la picioare în firetrail.gd

# Frostwalker: lasă o dâră de gheață pe jos cât timp player-ul se mișcă.
func _drop_ice() -> void:
	if frost_trail_time <= 0.0 or velocity.length() < 5.0:
		return
	# are ȘI Firewalker → lasă Godwalker (foc + gheață) în locul gheții simple
	if fire_trail_time > 0.0:
		_drop_god()
		return
	var patch := ICE_TRAIL.new()
	patch.duration = frost_trail_time    # cât rămâne (crește cu fiecare upgrade)
	patch.damage = frost_trail_damage
	patch.size = frost_trail_size * weapon_size_scale()  # mărimea (crește cu upgrade-urile + Pufferfish/Rat's Burger)
	patch.slow_hold = frost_slow_time    # cât timp înghețăm inamicul (crește cu fiecare upgrade)
	patch.direction = velocity.normalized()
	get_parent().add_child(patch)
	patch.global_position = global_position - Vector2(0, 4)

# Godwalker: dâra combinată când player-ul are ȘI Firewalker ȘI Frostwalker.
# Face damage-ul combinat (foc + gheață) ȘI încetinește inamicii; o singură animație.
func _drop_god() -> void:
	var patch := GOD_TRAIL.new()
	patch.duration = max(fire_trail_time, frost_trail_time)  # rămâne cât cea mai lungă
	patch.damage = fire_trail_damage + frost_trail_damage    # damage foc + gheață
	patch.size = max(fire_trail_size, frost_trail_size) * weapon_size_scale()  # cât cea mai mare (+ Pufferfish/Rat's Burger)
	patch.slow_hold = frost_slow_time                        # slow-ul de la Frostwalker
	patch.direction = velocity.normalized()
	get_parent().add_child(patch)
	patch.global_position = global_position - Vector2(0, 4)

func take_damage(amount: int) -> void:
	hp -= amount
	Audio.play("hurt", -3.0)  # player lovit
	if hp <= 0:
		hp = 0
		die()

func die() -> void:
	if dead:
		return
	# Undying Spirit: prima moarte nu e finală. Te duce în Limbo (lumea alb-negru) și,
	# dacă reziști minutul, te întoarce aici. O SINGURĂ dată pe rundă — a doua oară
	# `undying_used` e deja true și cazi pe Game Over-ul normal de mai jos.
	if has_undying and not undying_used:
		var limbo := get_tree().get_first_node_in_group("limbo")
		if limbo != null and not limbo.active:
			undying_used = true
			limbo.enter(self)
			return
	dead = true
	var screen := get_tree().get_first_node_in_group("gameover_screen")
	if screen != null:
		screen.show_gameover(Difficulty.time, level)
	else:
		get_tree().reload_current_scene()  # fallback dacă n-ai adăugat încă ecranul de Game Over

func gain_xp(amount: int) -> void:
	xp += int(amount * xp_gain_mult)
	# while (nu if) ca să prindem și cazul în care un salt mare de XP trece peste mai multe niveluri
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()

func _level_up() -> void:
	level += 1
	Audio.play("levelup")  # jingle de nivel nou
	xp_to_next = int(xp_to_next * 1.2)  # pragul crește cu 20% la fiecare nivel
	var menu := get_tree().get_first_node_in_group("levelup_menu")
	if menu != null:
		menu.open()

# --- îmbunătățiri aplicate de ecranul de level up ---
func upgrade_max_hp(amount: int) -> void:
	max_hp += amount
	hp += amount  # te și vindecă cu cât ai crescut viața maximă

# Stolen Halo: pune aureola deasupra capului, unde rămâne tot restul rundei.
# Itemul se poate lua de mai multe ori (stivuiește damage/HP), dar aureola se pune O SINGURĂ dată
# — altfel s-ar suprapune mai multe una peste alta, în același loc.
func show_halo() -> void:
	if _halo != null and is_instance_valid(_halo):
		return
	var frames := _load_fx_frames("res://fx/halo fx", 12.0, true)  # loop = se rotește la nesfârșit
	if frames == null or frames.get_frame_count("fx") == 0:
		push_warning("Stolen Halo: nu găsesc cadrele din res://fx/halo fx")
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.animation = "fx"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.z_index = 1  # peste player, ca o aureolă adevărată
	add_child(a)   # copil al player-ului → îl urmează oriunde
	# player-ul e la scale 2 în main.tscn; împărțim la scara lui ca px-ii ceruți să fie px reali
	var ps: float = max(scale.x, 0.001)
	a.position = Vector2(halo_side, -halo_height) / ps
	a.scale = Vector2.ONE * (halo_size / HALO_FRAME_W) / ps  # cadrul de 64 px scalat la halo_size
	a.play("fx")
	_halo = a

func upgrade_fire_rate(factor: float) -> void:
	fire_interval *= factor              # factor < 1 → pauză mai mică între trageri = tragi mai des
	fire_timer.wait_time = fire_interval

# Aplică upgrade-urile permanente (meta-progresie) la începutul rundei.
func _apply_meta() -> void:
	max_hp += GameSettings.level_of("hp") * 15
	bullet_damage += GameSettings.level_of("damage") * 3
	speed += GameSettings.level_of("speed") * 15.0
	fire_interval *= pow(0.96, GameSettings.level_of("firerate"))
	xp_gain_mult = 1.0 + GameSettings.level_of("xp") * 0.08
	hp_regen += GameSettings.level_of("regen") * 1
