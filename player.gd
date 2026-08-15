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

# Viteza de mers. Pe 2026-07-27 a fost întâi înjumătățită (300 → 150), apoi urcată cu 35%
# (→ 202.5) și în final fixată de Răzvan la **215**, adică vreo 72% din cât era la început.
# Unde cade asta față de inamici (cifrele sunt pe 202.5, la 215 se mută cu puțin mai încolo):
#   • polițiștii pleacă de la 120 și urcă cu 3.5%/minut, dar în primele 10 minute nu trec de
#     162 — deci în toată faza 1 ești mai rapid. Te ajung abia în Final Swarm, pe la ~11:37,
#     iar la plafon (`SPEED_CAP` 2.2) fac 264, adică 1.30× cât tine;
#   • creaturile din Nether pleacă de la 190, deci te întrec de pe la minutul 2 al rundei —
#     practic mereu, fiindcă nu ajungi la un portal mai devreme.
# Cu alte cuvinte: în lume poți fugi, în Nether nu. Viteza rămâne un stat care merită luat
# din upgrade-uri (Rabbit's Foot, Alex's Protection, Hellas, Weird Concoction).
# (Cifrele de sus sunt pe viteza CURATĂ. Fiecare nivel de Speed din magazin adaugă încă 15 și
# le împinge mai încolo — vezi log-ul din CLAUDE.md pentru măsurătorile exacte.)
@export var speed: float = 215.0
@export var fire_interval: float = 0.75    # rescris de `_aplica_arma()` după arma aleasă
@export var bullet_damage: int = 15        # idem; crește la level up
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

# Horse Mask: la fiecare lovitură, șansă să „farmeci" un inamic — se întoarce împotriva alor lui
# și lovește alt inamic până îl omoară; cât e fermecat nu-ți mai face damage ție (dar îl poți
# omorî tu). +5% pe luare. Toată logica e în enemy.gd (`_try_charm`); aici stă doar șansa.
const HORSE_MASK_PER := 0.05
var horse_mask_stacks: int = 0

func horse_mask_chance() -> float:
	if horse_mask_stacks <= 0:
		return 0.0
	return minf(1.0, horse_mask_stacks * HORSE_MASK_PER + luck_bonus())

# Psychic Flip Flop („aimbot"): gloanțele se corectează în zbor spre ținta lor și țintesc UNDE
# VA FI, nu unde e. Urmărirea a fost o vreme (2026-07-21 → 07-22) pornită din oficiu la toate
# gloanțele; acum e efectul ACESTUI item — fără el gloanțele zboară drept, ca la început.
# Toată mecanica stă în `bullet.gd` (`homing_turn`); aici e doar cât de strâns virează.
const AIMBOT_TURN_PER := 8.0   # rad/s pe luare: 8 = 85% rată de lovire, 16 = 89% (măsurat)
var aimbot_stacks: int = 0

# Viteza de viraj pentru gloanțele trase ACUM. 0 = fără item → bullet.gd sare tot codul de urmărire.
func aimbot_turn() -> float:
	return aimbot_stacks * AIMBOT_TURN_PER

# Bloody Situation: fiecare lovitură CRITICĂ te vindecă. +2 HP pe luare.
# Regula: o vindecare per lovitură critică, nu per inamic atins. Contează la sabie și la coasă,
# care lovesc zeci de inamici cu ACELAȘI critic (unul singur rostogolit pe tăietură/tur): dacă ar
# vindeca de fiecare inamic, o tăietură critică în mijlocul gloatei te-ar umple instant de viață.
const BLOODY_HEAL_PER := 2
var bloody_stacks: int = 0

# Chemată de glonț / puls de aură / tăietură de sabie când lovitura CRITICĂ a atins un inamic.
func bloody_heal() -> void:
	if bloody_stacks <= 0 or hp >= max_hp:
		return
	hp = min(max_hp, hp + bloody_stacks * BLOODY_HEAL_PER)

# Borat's Mankini: la fiecare 5 secunde, șansă să-ți cadă geme de XP mici lângă tine, din senin.
# Ca la Broken Watch, repetarea NU crește ȘANSA, ci CÂTE geme cad (2 pe luare).
const MANKINI_GEM := preload("res://xp1.tscn")   # gema cea mai mică (valoare de bază 1)
const MANKINI_INTERVAL := 5.0
const MANKINI_CHANCE := 0.5
const MANKINI_GEME := 2        # câte geme pe luare
var mankini_stacks: int = 0

# Undying Spirit: prima moarte te trimite în Limbo în loc de Game Over (vezi limbo.gd).
# Se consumă la prima folosire — a doua oară mori normal, chiar dacă ai luat itemul de mai multe ori.
var has_undying: bool = false
var undying_used: bool = false

# --- tipul de armă (ales din meniu: pistol / mage / sword / scythe) ---
var weapon_type: String = "pistol"

# --- FIECARE ARMĂ CU AVANTAJUL ȘI DEZAVANTAJUL EI (cerut de Răzvan, 2026-07-27) ---
# Până acum toate porneau identic (10 damage, o lovitură la 0.5s) și se deosebeau doar prin
# FELUL în care lovesc. Acum alegi și între „rar și greu" și „des și slab":
#
#   armă             damage   pauză între lovituri   lovituri/s
#   pistol             15           0.75               1.33
#   mage staff         10           0.50               2.00   ← de 1.5× mai des ca pistolul
#   cursed sword       20           0.75               1.33
#   celesto's scythe   24           0.95               1.05   ← cea mai rară, dar taie în jur
#   throwing knife     12           0.55               1.82   ← cea mai deasă, dar cea mai slabă
#
# (STINGĂTORUL a fost ȘTERS din joc pe 2026-08-04, la cererea lui Răzvan — cu tot cu aura care
#  pulsa, spuma, iconița și cadrele ei. Sunetul lui a rămas: îl folosește acum sabia.)
#
# ⚠️ `damage` de aici e statul din panou (`bullet_damage`), nu neapărat cât intră în inamic:
# sabia adaugă `sword_base_damage` întreg (8 + 20 = 28 pe tăietură), iar coasa
# `scythe_base_damage` (12 + 24 = 36 pe măturat). Vezi tăietura sabiei și `_scythe_swing()`.
const ARME := {
	"pistol":       {"damage": 15, "interval": 0.75},
	"mage":         {"damage": 10, "interval": 0.50},
	"sword":        {"damage": 20, "interval": 0.75},
	"scythe":       {"damage": 24, "interval": 0.95},
	"knife":        {"damage": 12, "interval": 0.55},
}

# --- BONUSUL DE NIVEL AL FIECĂREI ARME (cerut de Răzvan pe 2026-08-05) ---
# „La fiecare nivel fiecare armă are un bonus specific." Nu e un item și nu se poate pierde: e
# felul în care arma pe care ai ales-o crește odată cu tine.
#
#   throwing knife   +1% ȘANSĂ DE CRITIC / nivel   (`crit_chance_now`)
#   cursed sword     +1% DAMAGE / nivel            (`damage_mult`)
#   pistol           +1% ATTACK SPEED / nivel      (`fire_interval_now`)
#   celesto's scythe +1% WEAPON SIZE / nivel       (`weapon_size_scale`)
#   mage staff       +1 NOROC / nivel              (`luck_total`)
#
# Se numără de la nivelul 1, nu de la 0: la nivelul 12 ai +12%. Nu se scriu nicăieri în stat-uri,
# se CALCULEAZĂ la folosire (ca `damage_mult` sau `weapon_size_scale`) — altfel ar trebui scăzut
# bonusul vechi și adunat cel nou la fiecare level up, și s-ar strica tăcut la primul upgrade
# care înmulțește statul.
#
# ⚠️ NOROCUL e singurul care nu e „%": el nu e un procent, e un număr de puncte (`luck`), iar 1%
# din el ar fi însemnat 1% din zero = nimic. Un punct de noroc valorează 0.4 puncte procentuale
# la toate șansele din joc (`LUCK_CHANCE_PER`), deci +1 noroc/nivel iese pe-aproape de „+1%/nivel"
# ca putere — și e comparabil cu +1% critic al cuțitului. Reglabil dintr-un singur loc, aici.
const BONUS_PE_NIVEL := 0.01
const LUCK_PE_NIVEL := 1.0

# Bonusul armei `pentru`, la nivelul de ACUM. 0 dacă joci cu altă armă — deci fiecare loc de
# folosire poate să-l adune fără să întrebe de două ori cu ce armă ești.
func bonus_arma(pentru: String) -> float:
	return level * BONUS_PE_NIVEL if weapon_type == pentru else 0.0

# ITEMELE STRÂNSE ÎN RUNDA ASTA, în ordinea luării (id-uri din `levelup.gd::UPGRADES`).
#
# E un REGISTRU, nu un inventar: efectele nu stau aici, ele s-au aplicat pe statusuri în clipa
# luării (`levelup.gd::_apply`) și nu se mai pot desface. Lista asta e doar „ce am adunat" —
# până pe 2026-08-05 jocul nu ținea minte NIMIC din ce ai luat, fiindcă nimeni n-avea nevoie.
# Are nevoie statuia din Ender (`ender_statue.gd`), care îți arată itemele tale ca să le schimbi
# pe unele mai rare. Se umple dintr-un singur loc — `_apply` —, deci prinde toate sursele:
# level up, cufere, statuia însăși.
var run_items: Array = []

# Norocul TOTAL: cel strâns din iteme + bonusul de nivel al Mage Staff-ului. Ăsta e numărul pe
# care trebuie să-l citească toată lumea (`luck_bonus` aici, `_norocul_meu` în `levelup.gd`,
# panoul de statusuri) — `luck` gol e doar partea din iteme.
func luck_total() -> float:
	return luck + (level * LUCK_PE_NIVEL if weapon_type == "mage" else 0.0)

# Pauza REALĂ dintre lovituri: cea a armei, scurtată de bonusul de nivel al PISTOLULUI.
# `fire_interval` rămâne statul „curat" (îl scriu arma, meta, OP start și `upgrade_fire_rate`);
# ăsta e ce ajunge în `fire_timer` și în panou. Se ÎMPARTE, nu se scade: +10% attack speed
# înseamnă de 1.1 ori mai multe lovituri pe secundă, nu cu 10% mai puțină pauză.
func fire_interval_now() -> float:
	return fire_interval / (1.0 + bonus_arma("pistol"))

# Pune cadența de acum în timer. Se cheamă de fiecare dată când se schimbă `fire_interval` SAU
# nivelul — bonusul pistolului crește cu nivelul, deci un level up trebuie să miște și timer-ul.
func _seteaza_cadenta() -> void:
	if fire_timer != null:
		fire_timer.wait_time = fire_interval_now()
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

var _sword_frames: SpriteFrames             # cele 12 cadre din fx/cursed sword fx
var _sword_frame_px := Vector2(64, 55)      # mărimea unui cadru, în pixeli de artă (citită din textură)
var _sword_env := Rect2()                   # anvelopa animației (uniunea cadrelor), în pixeli de artă
var _slashes: Array = []                    # tăieturile în curs; le rotim după privire cât se joacă
var _facing: Vector2 = Vector2.DOWN         # ultima direcție reală în care s-a uitat player-ul (pt. tăietura sabiei)

# --- COASA LUI CELESTO: mătură un cerc COMPLET în jurul tău ---
#
# A doua armă de corp la corp, adusă din arta boss-ului Ender (`celesto.gd` aruncă aceeași lamă).
# Diferența față de sabie:
#   • SABIA taie doar ÎNAINTE, într-un dreptunghi lung — rază mare, dar trebuie să fii cu fața;
#   • COASA are rază FIXĂ și scurtă, dar taie DE JUR ÎMPREJUR, și lovește PE MĂSURĂ CE LAMA
#     AJUNGE la fiecare — nu toți deodată. De aia se și vede lama rotindu-se: ce e în spatele tău
#     încasează la sfârșitul turului, nu la început.
#
# Damage-ul se fixează la începutul măturatului (ca la sabie): un tur = un damage și un critic,
# oricât ar dura. `loviti` ține minte pe cine a prins deja turul ăsta, ca lama să nu dea de două
# ori în același inamic dacă el se mișcă în jurul tău.
# HITBOX-UL SE CROIEȘTE PE DESEN, ca la sabie și la Firewalker (reclamat de Răzvan pe
# 2026-08-04: „hitboxu la scythe nu e egal cu sprite-ul in sine"). Prima variantă lovea tot ce
# era într-un CERC PLIN de rază fixă în jurul tău, deși lama e o secere subțire care mătură pe o
# BANDĂ: prindea și inamici lipiți de tine, pe sub lamă, și alții de dincolo de vârful ei.
#
# Acum, la pornire, se măsoară din poză un CÂMP DE DISTANȚE (`_camp_distante`): pentru fiecare
# pixel, cât are până la cea mai apropiată bucată de lamă. „Lovește?" e o singură citire din el,
# deci hitbox-ul e chiar desenul, umflat cu `scythe_marja`. Tot din poză se scoate și AXA lamei
# (`_masoara_axa_coasei`), ca ea să cadă de-a lungul razei. `scythe_reach` spune unde ajunge VÂRFUL,
# iar lama se așază singură ca să iasă exact acolo. Schimbi arta, se recalculează tot.
const SCYTHE_ART := "res://harta/Portal Ender/Celesto/celesto throw.png"
@export var scythe_base_damage: int = 12      # se adună la bullet_damage, ca `sword_base_damage`
@export var scythe_reach: float = 130.0       # până unde ajunge VÂRFUL lamei, în pixeli
@export var scythe_sweep_time: float = 0.34   # cât durează un tur complet
@export var scythe_art_size: float = 150.0    # cât de lată e lama pe ecran, în pixeli
@export var scythe_art_rotation: float = 0.0  # reglaj fin, dacă lama nu cade cum trebuie pe cerc
# Cât iese hitbox-ul în afara desenului, de jur împrejurul benzii. Cerut de Răzvan: „poti chiar
# sa il faci cu 5pixeli peste sprite daca arata mai ok asa" — și chiar arată: fix pe pixel, lama
# trecea pe lângă inamici pe care ochiul îi vedea atinși.
@export var scythe_marja: float = 5.0
# Aceeași nuanță ca la coasa aruncată de Celesto (`scythe.gd`): peste 1 = mai luminoasă. Lama e
# aproape neagră, iar iarba e închisă — fără ea, arma pe care o învârți nu se vede.
@export var scythe_tint: Color = Color(1.15, 1.05, 1.35)
# Desenează banda care lovește peste joc, ca `sword_debug`: două arce roșii (marginile hitbox-ului)
# și o linie albă pe unde e lama acum. Cu el pornit se vede dintr-o privire dacă desenul și
# hitbox-ul mai stau împreună.
@export var scythe_debug: bool = false
var _scythe_tex: Texture2D
var _scythe_px := Vector2.ZERO   # mărimea pozei, în pixeli de artă
var _scythe_dist: PackedFloat32Array = PackedFloat32Array()   # distanța de la fiecare pixel la lamă
var _scythe_axa := Vector2.UP     # încotro „arată" lama în poză (spre vârf)
var _scythe_proj_max := 0.0       # cât se întinde desenul pe axa aia, spre vârf
var _scythe_proj_min := 0.0       # ...și spre coadă
var _sweeps: Array = []          # măturatele în curs (lama se rotește, damage-ul curge)

# --- upgrade-uri de armă ---
# --- Unusual Clover: NOROCUL. Face două lucruri complet diferite: ---
#  1. înclină șansele de RARITATE la level up (calculul e în levelup.gd, `_sanse_cu_noroc`);
#  2. adaugă puncte procentuale la șansele itemelor pe care LE AI deja (aici, `luck_bonus`).
# Ce NU face: nu-ți dă o șansă pe care n-ai luat-o niciodată. Fără Adrenaline criticul rămâne
# 0%, nu 2% — altfel norocul ți-ar strecura pe furiș mecanici pe care nu le-ai ales.
const LUCK_CHANCE_PER := 0.004   # +0.4 puncte procentuale per punct de noroc (5 noroc = +2%)
var luck: float = 0.0            # ZECIMAL, nu întreg: The Office dă +2.5

func luck_bonus() -> float:
	return luck_total() * LUCK_CHANCE_PER

@export var crit_chance: float = 0.0       # șansa (0..1) ca o lovitură să fie critică
@export var crit_mult: float = 2.0         # de câte ori mai mult damage la critic
@export var instakill_chance: float = 0.0  # șansa (0..1) ca o lovitură să ucidă instant inamicul (Hacksaw)
@export var pierce: int = 0                # prin câți inamici trece glonțul
# Aussie Special: de câte ori SARE glonțul la alt inamic după ce a terminat de străpuns.
# Nu e același lucru cu `pierce`: străpungerea îl duce mai departe DREPT, prin inamicii aflați
# pe traiectorie; ricoșeul îl ÎNTOARCE spre alt inamic ales din jur. Se aplică după ce
# străpungerea s-a epuizat (vezi `bullet.gd`), deci cele două se adună, nu se bat cap în cap.
@export var ricochet: int = 0
# Mărimea glonțului (1 = normal). Niciun upgrade nu-l mai schimbă de pe 2026-08-15 (Double Dose
# a trecut pe mărime de ARMĂ, procentual); rămâne ca reglaj de bază din inspector.
@export var bullet_scale: float = 1.0
# --- mărimea ARMEI (sprite + hitbox), comună tuturor armelor ---
# Pistol/Mage: mărește glonțul (și sfera mage, fiind copil al lui) — dar PLAFONAT, vezi
# `BULLET_SIZE_CAP`. Sabie: tăietura. Coasă: lama și raza cercului. Toate: dârele de foc/gheață.
const BULLET_BASE_PX := 27.0               # cât are glonțul de bază pe ecran (193px × 1.4 sprite × 0.1 root)
# Pixeli adăugați la mărimea armei. Niciun upgrade nu-l mai folosește de pe 2026-08-15
# (Pufferfish a trecut pe procent); rămâne ca reglaj de bază din inspector.
@export var weapon_size_px: float = 0.0
# Procent peste mărimea curentă: Pufferfish ×1.10, Double Dose ×1.05, Rat's Burger ×1.30 (se compun)
@export var weapon_size_mult: float = 1.0
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
# Cât îți ia o atingere de inamic, ÎNAINTE de `Difficulty.enemy_damage_mult()` și de `damage_mult`-ul
# inamicului. ⚠️ Din 2026-08-14 NU mai e status: nu se mai vede în panoul de la level up, nu mai poate
# fi pariat la cazinou și niciun item nu-l mai schimbă (Vodka scădea din el; acum dă altceva). E doar
# cifra de bază de la care pornește damage-ul de contact. A rămas `var`, nu `const`, ca scenele de test
# să-l poată pune pe 0 — vezi nota din CLAUDE.md despre grilele mari de dummy-uri.
var contact_damage: int = 5
@export var damage_interval: float = 0.5
@export var hedgehog: bool = false         # Mike's Hedgehog: reflectă damage-ul primit înapoi în inamic
var _hedgehog_next: float = 0.0            # momentul (sec) când reflectul redevine disponibil (cooldown 6s)
const HEDGEHOG_CD := 6.0                    # secunde între două block-uri Mike's Hedgehog
# Old Reliable: reflectă un PROCENT din damage-ul primit, DE FIECARE DATĂ când te lovește un
# inamic — fără cooldown și fără să blocheze lovitura (tu încasezi normal). Ăsta e tot ce-l
# deosebește de Mike's Hedgehog, care reflectă 100% dar o dată la 6s ȘI te apără de lovitura aia.
# Se adună cu el: la o lovitură prinsă de Hedgehog, inamicul mănâncă și cei 100%, și procentul.
@export var reflect_pct: float = 0.0
var _flash_mat: ShaderMaterial             # material de flash alb pe sprite (block-ul Hedgehog)
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
	# arma aleasă din meniu (pistol / mage / sword / scythe)
	weapon_type = GameSettings.weapon_type
	_aplica_arma()  # damage-ul și cadența de bază ale armei alese — ÎNAINTE de meta
	_apply_meta()  # upgrade-uri permanente cumpărate din meniu (meta-progresie)
	_aplica_op_start()  # cheat-ul din meniu — ULTIMUL, ca să scrie peste armă și peste meta
	# Reperul lui Diesel Power = viteza cu care PORNEȘTI runda, luată DUPĂ META. Așa itemul
	# măsoară viteza câștigată în rundă (Weird Concoction, Alex's Protection), nu ce ai cumpărat
	# din magazin — altfel cine are Speed-ul maxat ar începe cu bonusul deja pe jumătate dat.
	_speed_base = speed
	_muzzle_frames = _load_fx_frames("res://fx/muzzle", 26.0, false)
	_mage_boom_frames = _load_fx_frames("res://fx/mage_boom", 24.0, false)
	_mage_orb_frames = _load_fx_frames("res://fx/mage_orb", 18.0, true)  # loop = proiectil continuu
	_sword_frames = _load_fx_frames("res://fx/cursed sword fx", 22.0, false)  # animația de tăiere (12 cadre)
	# lama coasei: o singură poză, aceeași pe care o aruncă Celesto (n-are cadre, se rotește)
	if ResourceLoader.exists(SCYTHE_ART):
		_scythe_tex = load(SCYTHE_ART)
		_masoara_arta_coasei()   # din desenul ei ies și hitbox-ul, și felul cum se așază pe cerc
	_electric_frames = _load_fx_frames("res://fx/electricity fx", 30.0, false)  # arcul de Thunder God (14 cadre)
	_masoara_arta_sabiei()  # anvelopa animației → din ea se croiește dreptunghiul care lovește
	# (Cursed Sword avea aici un slow de 1.9× la început. A dispărut pe 2026-07-27: Răzvan a
	# cerut sabia cu ACEEAȘI cadență ca pistolul, iar dezavantajul ei nu mai e viteza, ci raza.)
	hp = max_hp
	# reperul panoului de statusuri: valorile de la START, DUPĂ meta + slow-ul sabiei
	_stats_base = {
		"bullet_damage": float(bullet_damage),
		# derivat, ca `weapon_size`: bonusul de nivel al pistolului e deja în el la nivelul 1,
		# altfel panoul ar arăta o săgeată verde permanentă la Attack Speed, fără să fi luat nimic
		"fire_interval": fire_interval_now(),
		"crit_chance": crit_chance,
		"bullet_count": float(bullet_count),
		"pierce": float(pierce),
		"weapon_size": weapon_size_scale(),
		"knockback": knockback,
		"instakill_chance": instakill_chance,
		"speed": speed,
		"max_hp": float(max_hp),
		"hp_regen": float(hp_regen),
	}
	anim.play("idle_south")  # pornim stând pe loc, uitându-ne în jos
	# material de flash alb pentru block-ul lui Mike's Hedgehog (vezi _show_block); flash=0 = normal
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = load("res://white_flash.gdshader")
	_flash_mat.set_shader_parameter("flash", 0.0)
	anim.material = _flash_mat
	fire_timer = Timer.new()
	fire_timer.wait_time = fire_interval_now()   # cu bonusul de nivel al pistolului inclus
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
	# timer pentru Borat's Mankini: merge tot timpul, dar nu face nimic până iei itemul
	var mankini_timer := Timer.new()
	mankini_timer.wait_time = MANKINI_INTERVAL
	mankini_timer.timeout.connect(_mankini_drop)
	add_child(mankini_timer)
	mankini_timer.start()
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
	if scythe_debug and weapon_type == "scythe":
		_deseneaza_banda_coasei()
		return
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

# Reglajul coasei. Hitbox-ul ei nu e o formă geometrică pe care s-o pot desena cu două linii — e
# chiar desenul lamei, umflat cu `scythe_marja` —, deci desenez ce contează de fapt: CINE e prins
# chiar acum. Fiecare inamic aflat sub lamă primește un cerc roșu. Cercul subțire e cât de departe
# ajunge vârful. Ca la sabie, desenăm pe player, care e la scale 2, deci împărțim la scara lui.
func _deseneaza_banda_coasei() -> void:
	var ps: float = max(scale.x, 0.001)
	draw_arc(Vector2.ZERO, (_scythe_banda().y + scythe_marja) / ps, 0.0, TAU, 64,
		Color(1, 0.25, 0.25, 0.3), 1.0 / ps)
	for t in _sweeps:
		var u: float = float(t["unghi0"]) + minf(float(t["parcurs"]), TAU)
		for e in get_tree().get_nodes_in_group("enemy"):
			var enemy := e as Node2D
			if enemy == null:
				continue
			var spre: Vector2 = enemy.global_position - global_position
			if _coasa_atinge(u, spre, _raza_corp(enemy)):
				draw_arc(spre / ps, (_raza_corp(enemy) + 4.0) / ps, 0.0, TAU, 20,
					Color(1, 0.25, 0.25, 0.95), 2.0 / ps)

func _process(delta: float) -> void:
	_update_slashes()  # tăieturile în curs se întorc după privire și lovesc pe unde mătură
	_update_sweeps(delta)  # coasa: lama se rotește în jurul tău și lovește pe cine ajunge
	if scythe_debug and weapon_type == "scythe":
		queue_redraw()   # lama se mișcă în fiecare cadru → și banda desenată
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

# Pași: redăm sunetul de pas la fiecare STEP_GAP secunde cât timp ne mișcăm.
# Footsteps.wav e UN singur pas (~0.35s), deci îl repetăm pe cadență (nu în buclă).
const STEP_GAP := 0.3
var _step_t := 0.0

# Burst de atacuri pentru SABIE și COASĂ: fiecare proiectil EXTRA (Gunslinger / Twin Comets /
# Broken Watch) = încă o tăietură/încă un tur, rapid DUPĂ primul, ca în Megabonk. Cu cât ai mai multe
# proiectile, cu atât pauza dintre ele e mai mică (le dă mai repede). Gloanțele NU folosesc asta —
# ele trag salve paralele spre inamici diferiți. Rulăm burst-ul cu un contor în _physics_process
# (nu cu await), ca la Garda: dacă player-ul moare/schimbă scena la mijloc, nu rămâne un await agățat.
const BURST_GAP0 := 0.16    # pauza între atacuri la 1 proiectil extra
const BURST_MIN := 0.045    # pauza minimă (cât de rapid poate deveni la multe proiectile)
var _burst_left := 0        # câte atacuri mai are burst-ul curent
var _burst_gap := 0.0       # pauza dintre ele (calculată la pornire)
var _burst_t := 0.0         # countdown până la următorul atac din burst
var _burst_kind := ""       # "sword" sau "scythe"
var _ground: Node = null    # podeaua, ținută minte: o întrebăm în FIECARE cadru de fizică unde e marginea

func _physics_process(delta: float) -> void:
	_tick_burst(delta)
	var directie := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = directie * speed
	move_and_slide()
	# Marginea Nether-ului / Ender-ului: te oprești pe buza gropii. NU e un zid de coliziune —
	# un StaticBody în cerc ar fi însemnat un al doilea adevăr despre unde e marginea, iar podeaua
	# (`ground.gd`) îl are deja pe primul, fiindcă tot ea o și desenează. În lumea normală și în
	# Limbo `in_margine` întoarce punctul neatins, deci linia asta nu costă nimic acolo.
	if _ground == null or not is_instance_valid(_ground):
		_ground = get_tree().get_first_node_in_group("ground")
	if _ground != null and _ground.has_method("in_margine"):
		global_position = _ground.in_margine(global_position)
	if directie != Vector2.ZERO:
		_facing = directie.normalized()  # reținem direcția reală de privire (pt. tăietura sabiei)
		_update_anim(directie)
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = STEP_GAP
			# pas de cărămidă în Nether, de nisip în deșert, de iarbă în pădure
			# (pitch-ul variază singur, să nu sune identic)
			var nether := get_tree().get_first_node_in_group("nether")
			var ender := get_tree().get_first_node_in_group("ender")
			var in_desert := BiomeMap.desertness_at_chunk(global_position / 512.0) >= 0.5
			# volume balansat: fișierele au loudness diferit (sand mai tare) → offset diferit,
			# ca pașii să sune la fel de tare pe toate terenurile (subtili, mult sub combat)
			# (în Ender nu există pas propriu — împrumută sunetul de cărămidă al Nether-ului)
			if (nether != null and nether.active) or (ender != null and ender.active):
				Audio.play("footsteps_nether", -7.0)
			elif in_desert:
				Audio.play("footsteps_sand", -9.0)
			else:
				Audio.play("footsteps_grass", -7.0)
	else:
		_step_t = 0.0   # oprit: următorul pas sună imediat când pornești din nou
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

# Mărimea armei ca factor de scalare: pixelii ceruți se traduc în scară raportat la glonțul de
# bază, apoi se aplică procentele (Pufferfish, Double Dose, Rat's Burger — toate în `weapon_size_mult`).
func weapon_size_scale() -> float:
	# Celesto's Scythe: +1% mărime pe nivel. Intră aici, în STATUL de mărime, nu doar în lama ei:
	# așa se vede și în panou, și crește tot ce ține de „cât de mare lovești" cu coasa în mână.
	return (1.0 + weapon_size_px / BULLET_BASE_PX) * weapon_size_mult * (1.0 + bonus_arma("scythe"))

# Cât de mare iese GLONȚUL, cu plafonul armei aplicat (cerut de Răzvan pe 2026-07-30).
# Pistolul trage un glonț mic și des: umflat de Pufferfish/Rat's Burger/Doză dublă ajungea să
# acopere jumătate de ecran, deci rămâne fix la 100%. Sfera mage e AOE și oricum mare, așa că
# poate crește, dar nu peste 250%. Plafonul e pe REZULTAT (bullet_scale × weapon_size_scale),
# nu pe stat: statul „Weapon Size" rămâne cum e și continuă să lucreze la dârele de foc/gheață,
# la tăietura sabiei și la lama coasei — se oprește doar creșterea glonțului.
const BULLET_SIZE_CAP := {
	"pistol": 1.0,
	"mage": 2.5,
	# Cuțitul e mic și se aruncă des, ca glonțul de pistol — dar e o LAMĂ, deci are voie să
	# crească puțin fără să pară absurd. 1.5 = cel mult jumătate mai mare decât iese din mână.
	"knife": 1.5,
}

func bullet_size_scale() -> float:
	var s := bullet_scale * weapon_size_scale()
	if BULLET_SIZE_CAP.has(weapon_type):
		s = minf(s, float(BULLET_SIZE_CAP[weapon_type]))
	return s

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
# toate armele, inclusiv Cursed Sword și coasa. Dârele de foc/gheață nu-l primesc, la fel
# cum nu primesc nici upgrade-urile obișnuite de damage.
func damage_mult() -> float:
	var m := 1.0 + cig_bonus  # Cigarette Pack: mereu pornit
	m += bonus_arma("sword")  # Cursed Sword: +1% damage pe nivel
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
	# Throwing Knife: +1% șansă de critic pe nivel. E chiar avantajul armei, deci contează și ca
	# „ai o mecanică de critic" — fără el, regula de mai jos ar întoarce 0 și cuțitul n-ar critica
	# niciodată, oricâte niveluri ai avea.
	var arma := bonus_arma("knife")
	# fără niciun item de crit (și fără cuțit), norocul n-are ce umfla (vezi `luck_bonus`)
	if crit_chance <= 0.0 and katana_stacks == 0 and arma <= 0.0:
		return 0.0
	var c := crit_chance + arma + luck_bonus()
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
	# ⚠️ Damage-ul se afișează CU procentele incluse (`damage_mult()`), nu `bullet_damage` gol.
	# Altfel Cigarette Pack (+5% damage, mereu pornit) pare stricat: îl iei, te uiți în panou și
	# scrie exact aceeași cifră, deși inamicii chiar încasau mai mult (raportat de Răzvan pe
	# 2026-08-04: „nu merge itemu de 5% damage increase, nu iti da nimic"). Aceeași regulă ca la
	# Crit și Instakill, care se arată de mult cu norocul inclus (`*_now()`): în panou scrie ce
	# face arma ACUM, nu ce scria pe ea la începutul rundei.
	#
	# Theo's Wrath și Diesel Power intră și ele, dar numai când sunt aprinse (sub 20% viață,
	# respectiv în mers) — și așa și trebuie: pe ecranul de level up stai pe loc și, de obicei,
	# cu viața plină, deci panoul arată cinstit că acum nu-ți dau nimic.
	var dmg_acum := int(round(bullet_damage * damage_mult()))
	return [
		_stat_row("Damage", dmg_acum, b["bullet_damage"], false, str(dmg_acum)),
		# Attack Speed se arată CU bonusul de nivel al pistolului (`fire_interval_now`), din
		# același motiv ca Damage și Crit: în panou scrie ce face arma ACUM.
		_stat_row("Attack Speed", fire_interval_now(), b["fire_interval"], true, "%.2f/s" % (1.0 / max(fire_interval_now(), 0.01))),
		# Crit și Instakill se afișează CU norocul inclus (`*_now()`), altfel panoul ar arăta
		# 15% după ce ai luat un trifoi care ți-a dus criticul real la 17%.
		_stat_row("Crit", crit_chance_now(), b["crit_chance"], false, "%d%%" % round(crit_chance_now() * 100.0)),
		_stat_row("Projectiles", projectiles_total(), b["bullet_count"], false, str(projectiles_total())),
		_stat_row("Pierce", pierce, b["pierce"], false, str(pierce)),
		_stat_row("Weapon Size", weapon_size_scale(), b["weapon_size"], false, "%d%%" % round(weapon_size_scale() * 100.0)),
		_stat_row("Knockback", knockback, b["knockback"], false, str(int(round(knockback)))),
		_stat_row("Instakill", instakill_chance_now(), b["instakill_chance"], false, "%.1f%%" % (instakill_chance_now() * 100.0)),
		# Norocul se arată TOTAL (iteme + bonusul de nivel al Mage Staff-ului), ca Crit și Damage.
		# Fără „.0" degeaba: 2.5 rămâne „2.5", dar 5.0 se scrie „5".
		_stat_row("Luck", luck_total(), 0.0, false, ("%.1f" % luck_total()).trim_suffix(".0")),
		_stat_row("Move Speed", speed, b["speed"], false, str(int(round(speed)))),
		_stat_row("Max HP", max_hp, b["max_hp"], false, str(max_hp)),
		_stat_row("HP Regen", hp_regen, b["hp_regen"], false, "%d/s" % hp_regen),
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
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)  # bubuitura (același cutremur ca la invocări)
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

# Câte atacuri EXTRA (peste primul) primește un burst de sabie/coasă, din upgrade-urile de
# proiectile. Aceeași socoteală ca la gloanțe (`_fire_bullets`): Gunslinger/Twin Comets garantate
# (`stacked_armory_stacks`) + Broken Watch pe șansă.
func _extra_attacks() -> int:
	var extra := stacked_armory_stacks
	if broken_watch_stacks > 0 and randf() < broken_watch_chance + luck_bonus():
		extra += broken_watch_stacks
	return extra

# Pornește burst-ul: `extra` atacuri rapide după primul. Pauza dintre ele scade cu numărul de
# proiectile (mai multe = mai repede), limitată la BURST_MIN.
func _start_burst(kind: String) -> void:
	var extra := _extra_attacks()
	if extra <= 0:
		_burst_left = 0
		return
	_burst_kind = kind
	_burst_left = extra
	_burst_gap = clampf(BURST_GAP0 / float(extra), BURST_MIN, BURST_GAP0)
	_burst_t = _burst_gap

# Scurge burst-ul în timp: la fiecare `_burst_gap`, mai face o tăietură/pulsare.
func _tick_burst(delta: float) -> void:
	if _burst_left <= 0:
		return
	_burst_t -= delta
	while _burst_t <= 0.0 and _burst_left > 0:
		_burst_left -= 1
		_burst_t += _burst_gap
		if _burst_kind == "sword":
			_sword_swing()
		elif _burst_kind == "scythe":
			_scythe_swing()

# dispecer de tragere: fiecare tick face altceva după arma aleasă
func _fire() -> void:
	if weapon_type == "sword":
		_sword_swing()              # prima tăietură acum
		_start_burst("sword")         # proiectilele extra = tăieturi rapide după ea
	elif weapon_type == "scythe":
		_scythe_swing()             # primul măturat acum
		_start_burst("scythe")        # proiectilele extra = încă un tur de lamă, imediat după
	else:
		_fire_bullets()    # pistol / mage (trag salve paralele, nu burst)

# Pistol (simplu) și Mage Staff (AOE) trag gloanțe spre cel mai apropiat inamic.
func _fire_bullets() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var dir := (target.global_position - global_position).normalized()
	# pistol/mage; se trage des → ținut moderat (reglabil).
	# −12.5 dB = de 1.5 ori mai încet decât −9 dB. Decibelii nu se împart, se SCAD:
	# „de N ori mai încet" înseamnă −20·log10(N) dB, iar pentru 1.5 asta face −3.5 dB.
	# Mage Staff are sunetul lui (un „vuiet" magic), pistolul rămâne pe Bullet.mp3.
	if weapon_type == "mage":
		Audio.play("mage_shoot", -12.0)
	elif weapon_type == "knife":
		Audio.play("sword", -9.0)   # șuieratul de lamă al săbiei; un cuțit aruncat nu bubuie
	else:
		Audio.play("shoot", -12.5)
	# Fulgerul la țeavă e al armelor de FOC. Cuțitul nu are țeavă — se aruncă din mână.
	if weapon_type != "knife":
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
	bullet.ricochet = ricochet   # Aussie Special: de câte ori sare la alt inamic după străpungere
	bullet.knockback = knockback
	bullet.instakill_chance = instakill_chance_now()
	bullet.explosion_radius = ex_radius
	bullet.explosion_damage = ex_damage
	bullet.thunder = thunder_stacks > 0 or plugged_in_stacks > 0  # Thunder God / Plugged In: curent la impact
	# Ținta + cât de strâns virează spre ea. Fără Psychic Flip Flop, `aimbot_turn()` e 0 și
	# glonțul ignoră ținta complet — zboară drept, ca înainte de urmărire.
	bullet.target = tinta
	bullet.homing_turn = aimbot_turn()
	if weapon_type == "mage":
		bullet.explosion_frames = _mage_boom_frames  # explozie violet la impact
		_make_mage_orb(bullet)                       # proiectil = sferă magică animată
	elif weapon_type == "knife":
		_make_knife(bullet)                          # proiectil = cuțitul, învârtindu-se în zbor
	# scalează sprite-ul ȘI hitbox-ul (CollisionShape2D e copil al glonțului), plus sfera mage
	bullet.scale *= bullet_size_scale()   # cu plafonul armei: pistol 100%, mage 250%
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
	Audio.play("sword", -4.0)  # tăietura săbiei
	var nod := _spawn_sword_slash(_sword_dir())
	if nod == null:
		return
	# Tăietura rămâne VIE cât ține animația (_update_slashes o rotește și o lasă să lovească).
	# `loviti` = ID-urile inamicilor deja tăiați de ea, ca o tăietură să lovească pe fiecare
	# o SINGURĂ dată oricât ar mătura — altfel ar da damage în fiecare cadru.
	var t := {"nod": nod, "loviti": {}, "dmg": dmg, "crit": is_crit, "shake": false, "bloody": false}
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
		# cu raza corpului: un boss mare e lovit când îl ATINGE tăietura, nu când îi intri în centru
		if not _sword_rect_hit(dir, rect, enemy.global_position, _raza_corp(enemy)):
			continue
		loviti[id] = true
		_lovitura_melee(enemy, dmg, is_crit, dir)
		hit = true
	if hit and is_crit and not t["shake"]:
		t["shake"] = true  # o singură zguduitură per tăietură, nu una pe cadru
		add_shake(0.35)
	# Bloody Situation: la fel, o singură vindecare per TĂIETURĂ critică. Flag separat de `shake`,
	# ca să nu se lege una de alta: tăietura face mai multe treceri de damage cât ține animația.
	if hit and is_crit and not t["bloody"]:
		t["bloody"] = true
		bloody_heal()

# O lovitură de CORP LA CORP peste un inamic: instakill, damage, numărul care sare, curentul lui
# Thunder God și knockback-ul. Comună săbiei și coasei — scrisă o dată, ca cele două să nu poată
# ajunge cu reguli diferite (era copiată, până a apărut coasa pe 2026-08-04).
# `dir_rezerva` = încotro îl împingem dacă e lipit de tine, adică n-are direcție proprie.
func _lovitura_melee(enemy: Node2D, dmg: int, is_crit: bool, dir_rezerva: Vector2) -> void:
	# Hacksaw: șansă să ucidă instant (îi scoatem toată viața dintr-o lovitură).
	# Boss-ii sunt imuni, exact ca la gloanțe (vezi nota din `bullet.gd`).
	var ik := instakill_chance_now()
	var kill := ik > 0.0 and not enemy.is_in_group("boss") and randf() < ik
	var dealt := dmg
	if kill and "hp" in enemy:
		dealt = int(enemy.hp)
	enemy.take_damage(dealt)
	Fx.damage_number(enemy.global_position, dealt, is_crit or kill)
	# Thunder God / Plugged In: lovitura prinde un inamic → (mereu / cu șansă) curent spre ceilalți
	if thunder_active_on_hit():
		thunder_from(enemy)
	if knockback > 0.0 and enemy.has_method("apply_knockback"):
		# îl împingem dinspre PLAYER, nu dinspre centrul loviturii
		var push := (enemy.global_position - global_position).normalized()
		if push == Vector2.ZERO:
			push = dir_rezerva  # lipit de tine: îl împingem în direcția loviturii
		enemy.apply_knockback(push * knockback)

# ---------- COASA LUI CELESTO ----------
# Un tur complet de lamă în jurul player-ului. Damage-ul și criticul se fixează ACUM, la pornire,
# ca la sabie: un tur = o lovitură pentru fiecare inamic prins, oricât ar dura turul.
func _scythe_swing() -> void:
	var dmg := int(round((scythe_base_damage + bullet_damage) * damage_mult()))
	var cr := roll_crit()                             # Adrenaline + Megane's Katana; peste 100% = multi-crit
	var is_crit: bool = cr["tiers"] > 0
	if is_crit:
		dmg = int(round(dmg * cr["mult"]))
	Audio.play("sword", -4.0)   # aceeași tăietură ca la sabie: tot o lamă e
	# Turul PORNEȘTE din spatele tău și se închide tot acolo, ca lama să treacă întâi prin fața ta:
	# acolo te uiți și acolo ai, de obicei, inamicii.
	var unghi0 := facing_dir().angle() - PI
	var t := {
		"nod": _spawn_scythe_blade(unghi0),
		"loviti": {}, "dmg": dmg, "crit": is_crit,
		"unghi0": unghi0, "parcurs": 0.0, "shake": false, "bloody": false,
	}
	_sweeps.append(t)

# Măsoară o dată, la pornire, TOT ce trebuie știut despre desenul lamei: câmpul de distanțe (din
# el iese hitbox-ul) și axa ei (din ea iese cum se așază pe cerc). Arta e sursa unică pentru desen
# și pentru zona lovită — la fel ca `_masoara_arta_sabiei`. Schimbi poza, se recalculează tot.
func _masoara_arta_coasei() -> void:
	var img := _scythe_tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()   # `get_pixel` nu merge pe o imagine comprimată
	_scythe_px = Vector2(img.get_width(), img.get_height())
	_scythe_dist = _camp_distante(img)
	_masoara_axa_coasei(img)

# AXA LAMEI și cât se întinde de-a lungul ei. Fără asta, lama iese strâmbă pe cerc.
#
# Coasa e desenată pe DIAGONALĂ în pătratul ei, deci „sus în poză" nu e același lucru cu „spre
# vârful lamei". Prima variantă o așeza după axa Y a pozei și ieșea o nepotrivire măsurată de 39°
# între unde SE VEDE lama și unde LOVEȘTE turul: inamicul din spatele tău, de unde pornește
# măturatul, era prins ultimul, după un tur întreg.
#
# Axa o dă direcția în care desenul e cel mai LUNG (axa principală a pixelilor desenați), nu
# centrul lor de greutate: la o coasă, greutatea cade aproape fix în mijlocul pozei, deci direcția
# ei ar fi zgomot curat — încercat, tot 40° pe lângă. Sensul îl alege jumătatea cu mai mulți pixeli:
# la coasă, lama e mai grasă decât coada, deci partea aia iese în afară, cum și trebuie.
#
# `_proj_max/min` = cât se întinde desenul pe axa asta, din care iese unde trebuie așezat sprite-ul
# ca vârful să ajungă fix la `scythe_reach`.
func _masoara_axa_coasei(img: Image) -> void:
	var pixeli: Array[Vector2] = []
	var suma := Vector2.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a <= 0.08:
				continue
			var p := Vector2(x, y)
			pixeli.append(p)
			suma += p
	if pixeli.is_empty():
		return
	var g := suma / float(pixeli.size())
	# matricea de împrăștiere în jurul centrului de greutate
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for p in pixeli:
		var d := p - g
		sxx += d.x * d.x
		syy += d.y * d.y
		sxy += d.x * d.y
	# unghiul axei principale a unei matrice 2×2 simetrice
	var theta := 0.5 * atan2(2.0 * sxy, sxx - syy)
	_scythe_axa = Vector2(cos(theta), sin(theta))
	var c := _scythe_px * 0.5
	var plus := 0
	for p in pixeli:
		if (p - g).dot(_scythe_axa) > 0.0:
			plus += 1
	if plus * 2 < pixeli.size():
		_scythe_axa = -_scythe_axa   # partea grasă (lama) trebuie să iasă în afară
	_scythe_proj_max = -INF
	_scythe_proj_min = INF
	for p in pixeli:
		var proj := (p - c).dot(_scythe_axa)
		_scythe_proj_max = maxf(_scythe_proj_max, proj)
		_scythe_proj_min = minf(_scythe_proj_min, proj)

# CÂMPUL DE DISTANȚE al lamei: pentru fiecare pixel al pozei, cât de departe e (în pixeli de artă)
# cel mai apropiat pixel DESENAT. Se calculează o dată, la pornire.
#
# De ce nu un dreptunghi, ca la sabie: coasa e desenată pe DIAGONALĂ, deci dreptunghiul din jurul
# ei ar cuprinde și cele două colțuri goale — aproape dublul suprafeței. Cu câmpul ăsta, întrebarea
# „lovește?" devine o singură citire din tabel: „e vreun pixel de lamă mai aproape de N?". Adică
# hitbox-ul e chiar desenul, umflat cu `scythe_marja`, fix ce a cerut Răzvan.
#
# Metoda e clasicul chamfer în două treceri (o dată în jos-dreapta, o dată în sus-stânga): cost
# liniar, eroare sub un pixel — mai mult decât destul, când marja e de 5.
func _camp_distante(img: Image) -> PackedFloat32Array:
	const DIAG := 1.4142135624
	var w := img.get_width()
	var h := img.get_height()
	var d := PackedFloat32Array()
	d.resize(w * h)
	var mare := float(w + h)
	for y in h:
		for x in w:
			d[y * w + x] = 0.0 if img.get_pixel(x, y).a > 0.08 else mare
	for y in h:
		for x in w:
			var i := y * w + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - w] + 1.0)
				if x > 0:
					v = minf(v, d[i - w - 1] + DIAG)
				if x < w - 1:
					v = minf(v, d[i - w + 1] + DIAG)
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if x < w - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < h - 1:
				v = minf(v, d[i + w] + 1.0)
				if x < w - 1:
					v = minf(v, d[i + w + 1] + DIAG)
				if x > 0:
					v = minf(v, d[i + w - 1] + DIAG)
			d[i] = v
	return d

# Cât de mare e lama pe ecran, ca fracție din poză.
func _scythe_scale() -> float:
	if _scythe_px.x <= 0.0:
		return 1.0
	return scythe_art_size * weapon_size_scale() / _scythe_px.x

# BANDA pe care o mătură lama, ca (rază_interioară, rază_exterioară) în pixeli de lume. Doar
# pentru cercul de reglaj și pentru rapoarte — cine lovește de fapt e `_coasa_atinge`.
func _scythe_banda() -> Vector2:
	var s := _scythe_scale()
	var ext: float = scythe_reach * weapon_size_scale()
	return Vector2(max(ext - (_scythe_proj_max - _scythe_proj_min) * s, 0.0), ext)

# Unde stă CENTRUL sprite-ului, ca vârful lamei să ajungă exact la `scythe_reach`.
func _scythe_centru() -> float:
	return scythe_reach * weapon_size_scale() - _scythe_proj_max * _scythe_scale()

# Lama: o singură poză (cea aruncată de Celesto), COPIL al player-ului → turul îl urmează dacă
# fugi în timpul lui. `_update_sweeps` o plimbă pe cerc.
func _spawn_scythe_blade(unghi: float) -> Sprite2D:
	if _scythe_tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = _scythe_tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = scythe_tint
	s.z_index = -1   # sub player, ca tăietura săbiei: altfel îi acoperă capul când trece prin nord
	add_child(s)
	var ps: float = max(scale.x, 0.001)   # player-ul e la scale 2 în main.tscn
	s.scale = Vector2.ONE * _scythe_scale() / ps
	_aseaza_lama(s, unghi, ps)
	return s

# Lama stă pe cerc, cu tăișul spre exterior, și se rotește odată cu unghiul.
func _aseaza_lama(s: Sprite2D, unghi: float, ps: float) -> void:
	s.position = Vector2(_scythe_centru(), 0).rotated(unghi) / ps
	s.rotation = _scythe_rotatie(unghi)

# Rotația sprite-ului: exact atât cât să ducă AXA LAMEI (măsurată din poză) pe raza `unghi`.
# `scythe_art_rotation` rămâne deasupra, ca reglaj fin cu mâna.
func _scythe_rotatie(unghi: float) -> float:
	return unghi - _scythe_axa.angle() + scythe_art_rotation

# LOVEȘTE LAMA, chiar acum, inamicul aflat la `spre` (față de player)?
#
# Aici e tot răspunsul la „hitboxu nu e egal cu sprite-ul": nu întrebăm dacă inamicul e într-un
# cerc oarecare în jurul tău, ci dacă e sub DESEN. Îl aducem în sistemul artei (mutat în centrul
# sprite-ului, rotit invers cu rotația lui, împărțit la mărimea de pe ecran) și citim din câmpul
# de distanțe cât are până la cel mai apropiat pixel de lamă.
#
# Cercul corpului, nu punctul din centru: un boss mare încasează când îl ATINGE lama.
# `scythe_marja` (5px, cerut de Răzvan) e cât iese hitbox-ul în afara desenului — fix pe pixel,
# lama trecea peste inamici pe care ochiul îi vedea deja atinși.
func _coasa_atinge(unghi: float, spre: Vector2, raza_corp: float) -> bool:
	var s := _scythe_scale()
	if s <= 0.0 or _scythe_dist.is_empty():
		return false
	var centru := Vector2(_scythe_centru(), 0).rotated(unghi)
	# din lume în pixeli de artă: mutăm în centrul sprite-ului, rotim invers, împărțim la scară
	var local := (spre - centru).rotated(-_scythe_rotatie(unghi)) / s + _scythe_px * 0.5
	var w := int(_scythe_px.x)
	var h := int(_scythe_px.y)
	# în afara pozei nu există tabel: ne oprim pe margine și adăugăm cât mai e până acolo
	var pe_margine := Vector2(clampf(local.x, 0.0, w - 1.0), clampf(local.y, 0.0, h - 1.0))
	var dist: float = _scythe_dist[int(pe_margine.y) * w + int(pe_margine.x)] \
		+ pe_margine.distance_to(local)
	return dist <= (raza_corp + scythe_marja) / s

# Rotește lama și dă damage PE MĂSURĂ CE AJUNGE la fiecare inamic — ăsta e tot rostul armei.
#
# Cum se decide „a ajuns la el": ținem `parcurs`, câți radiani a măturat lama de la start (crește
# de la 0 la TAU, deci nu se poate învârti înapoi). Pentru fiecare inamic calculăm unde stă el pe
# cerc față de unghiul de PORNIRE, adus în [0, TAU) — dacă `parcurs` a trecut de el, l-a prins.
# Comparație de numere care doar cresc, deci nu există „a sărit peste el" la trecerea prin 360°,
# capcana obișnuită când compari unghiuri direct.
func _update_sweeps(delta: float) -> void:
	if _sweeps.is_empty():
		return
	var ps: float = max(scale.x, 0.001)
	for i in range(_sweeps.size() - 1, -1, -1):
		var t: Dictionary = _sweeps[i]
		t["parcurs"] = float(t["parcurs"]) + TAU * delta / max(scythe_sweep_time, 0.01)
		var parcurs: float = t["parcurs"]
		var unghi0: float = t["unghi0"]
		if is_instance_valid(t["nod"]):
			var nod: Sprite2D = t["nod"]
			nod.scale = Vector2.ONE * _scythe_scale() / ps
			_aseaza_lama(nod, unghi0 + minf(parcurs, TAU), ps)
		var loviti: Dictionary = t["loviti"]
		var dmg: int = t["dmg"]
		var is_crit: bool = t["crit"]
		var hit := false
		for e in get_tree().get_nodes_in_group("enemy"):
			var enemy := e as Node2D
			if enemy == null:
				continue
			var id := enemy.get_instance_id()   # ID, nu nodul: poate muri între cadre
			if loviti.has(id):
				continue
			var spre: Vector2 = enemy.global_position - global_position
			if not _coasa_atinge(unghi0 + minf(parcurs, TAU), spre, _raza_corp(enemy)):
				continue
			loviti[id] = true
			_lovitura_melee(enemy, dmg, is_crit, spre.normalized())
			hit = true
		if hit and is_crit and not t["shake"]:
			t["shake"] = true   # o singură zguduitură per tur, nu una pe cadru
			add_shake(0.35)
		if hit and is_crit and not t["bloody"]:
			t["bloody"] = true
			bloody_heal()       # Bloody Situation: o vindecare per tur critic
		if parcurs >= TAU:
			if is_instance_valid(t["nod"]):
				t["nod"].queue_free()
			_sweeps.remove_at(i)

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
# comparăm CERCUL lui de corp cu dreptunghiul — nu doar punctul din centru.
#
# ⚠️ De ce nu doar `has_point(centru)`: la inamicii mici (rază ~15 px) diferența nu se simte,
# dar la un boss ca SARATALIN (cerc de coliziune de 46 px, sprite de 224×240) însemna că
# tăietura dădea damage doar când CENTRUL lui intra în dreptunghi — adică vizual când erai
# aproape suprapus peste el. Lipit de corpul lui, dar cu centrul afară, sabia trecea prin el
# degeaba. Gloanțele n-au avut niciodată problema asta: ele lovesc prin fizică, deci pe cercul
# de coliziune. Acum sabia folosește ACELAȘI cerc → aceeași lungime a brațului pentru amândouă.
func _sword_rect_hit(dir: Vector2, rect: Rect2, punct: Vector2, raza: float = 0.0) -> bool:
	var local := (punct - global_position).rotated(-dir.angle())
	if raza <= 0.0:
		return rect.has_point(local)
	# cel mai apropiat punct AL DREPTUNGHIULUI de centrul inamicului; dacă e mai aproape decât
	# raza lui, cercul atinge dreptunghiul (test cerc–dreptunghi clasic, ține și pe colțuri)
	var p := Vector2(
		clampf(local.x, rect.position.x, rect.end.x),
		clampf(local.y, rect.position.y, rect.end.y))
	return local.distance_squared_to(p) <= raza * raza

# Raza corpului unui inamic, în pixeli de lume: cercul lui de coliziune (fix cel pe care îl
# lovesc gloanțele), înmulțit cu scara la care e pus în lume. O măsurăm o singură dată și o
# ținem în `meta` pe inamicul însuși — dispare odată cu el, deci nu ținem minte noduri moarte.
func _raza_corp(enemy: Node2D) -> float:
	if enemy.has_meta("raza_corp"):
		return float(enemy.get_meta("raza_corp"))
	var r := 0.0
	for c in enemy.get_children():
		var cs := c as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is CircleShape2D:
			r = max(r, (cs.shape as CircleShape2D).radius)
		elif cs.shape is RectangleShape2D:
			r = max(r, (cs.shape as RectangleShape2D).size.length() * 0.5)
	r *= max(enemy.global_scale.x, enemy.global_scale.y)
	enemy.set_meta("raza_corp", r)
	return r

# Direcția în care se uită player-ul ACUM (ultima direcție reală de mers; când stă pe loc rămâne
# cea de dinainte). Publică, fiindcă o citește și spawner-ul: inamicii apar doar din față.
func facing_dir() -> Vector2:
	if _facing == Vector2.ZERO:
		return Vector2.DOWN
	return _facing.normalized()

# Direcția în care taie acum (aceeași pentru artă, hitbox și desenul de debug).
func _sword_dir() -> Vector2:
	return facing_dir()

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
# THROWING KNIFE: proiectilul e chiar iconița armei, care se rotește în zbor.
#
# Nu e o scenă nouă de glonț, ci același `bullet.tscn` cu altă poză pe `Sprite2D` — exact ca sfera
# mage. Așa cuțitul primește pe gratis tot ce știe glonțul: străpungere, ricoșeu, urmărire,
# Thunder God, explozia lui Jean's Bomb. O scenă separată ar fi însemnat un al doilea loc de
# ținut la zi la fiecare item nou.
#
# ⚠️ Sprite-ul din scenă vine cu `rotation` și `scale` ale LUI (glonțul e desenat pe diagonală și
# umflat 2.1×). Le scriem pe amândouă de la zero, altfel cuțitul ar apărea strâmb și uriaș.
const KNIFE_ART := "res://weapons_icons/throwing knife.png"
@export var knife_size: float = 38.0    # cât de lat e cuțitul pe ecran, în pixeli
@export var knife_spin: float = 14.0    # cât de repede se învârte în zbor (radiani/s)

func _make_knife(bullet: Node) -> void:
	var spr := bullet.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or not ResourceLoader.exists(KNIFE_ART):
		return
	var tex := load(KNIFE_ART) as Texture2D
	if tex == null:
		return
	spr.texture = tex
	spr.rotation = 0.0
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Ca la sfera mage: sprite-ul e copil al glonțului (scale 0.1), deci împărțim la scara
	# părintelui ca `knife_size` să însemne chiar pixeli pe ecran.
	var parent_scale: float = max(bullet.scale.x, 0.001)
	spr.scale = Vector2.ONE * (knife_size / float(max(tex.get_width(), 1))) / parent_scale
	bullet.spin = knife_spin

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
	# Cât lovesc inamicii ACUM: `contact_damage` e cifra de bază, fixă (5, nu mai e status și
	# nimic n-o mai schimbă), iar `Difficulty.enemy_damage_mult()` e cât de duri au devenit ei
	# cu timpul (×1 în primele 1:30, ×2 la minutul 10). Minimul de 1 e o plasă de siguranță.
	var dmg_baza := contact_damage * Difficulty.enemy_damage_mult()
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		# ...și `damage_mult` e cât de tare lovește ĂSTA anume. Aproape toți au 1.0; creatura din
		# Ender are 2.0. Se socotește PER INAMIC, nu o dată pentru toți, tocmai ca doi inamici
		# diferiți lipiți de tine să te muște diferit.
		var putere: float = float(enemy.get("damage_mult")) if enemy.get("damage_mult") != null else 1.0
		var dmg := maxi(1, int(round(dmg_baza * putere)))
		# Horse Mask: cât e fermecat luptă de partea ta, deci nu-ți mai face damage la contact
		# (tu îl poți omorî în continuare — e tot inamic). Vezi enemy.charmed.
		if "charmed" in enemy and enemy.charmed:
			continue
		if global_position.distance_to(enemy.global_position) < contact_range:
			take_damage(dmg)
			# Old Reliable: reflectă un procent din damage înapoi, la FIECARE lovitură. Fără
			# cooldown și fără block — lovitura te-a atins oricum (`take_damage` de mai sus).
			# Minimul de 1 e pentru ca la damage mic (5 × 15% = 0.75) reflectul să nu fie rotunjit
			# la 0, adică itemul să nu pară stricat în primele minute.
			if reflect_pct > 0.0 and enemy.has_method("take_damage"):
				var refl := maxi(1, int(round(dmg * reflect_pct)))
				enemy.take_damage(refl)
				Fx.damage_number(enemy.global_position, refl)
			# Mike's Hedgehog: reflectă 100% din damage înapoi în inamic, cel mult o dată la HEDGEHOG_CD
			if hedgehog and now >= _hedgehog_next and enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
				_hedgehog_next = now + HEDGEHOG_CD
				_show_block()   # flash alb pe player + text „Blocked"

# Feedback la block-ul lui Mike's Hedgehog: sprite-ul player-ului fulgeră alb (flash 1→0)
# și apare un „Blocked" plutitor deasupra capului.
func _show_block() -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash", 1.0)
		var t := create_tween()
		t.tween_property(_flash_mat, "shader_parameter/flash", 0.0, 0.35)
	Fx.text_popup(global_position + Vector2(0, -40), "Blocked", Color(1, 1, 1), 22)

func _regen() -> void:
	if hp_regen > 0 and hp > 0:
		hp = min(max_hp, hp + hp_regen)

# Borat's Mankini: la fiecare 5s, 50% șansă să pice `MANKINI_GEME × stacks` geme mici lângă tine.
# NU cad direct în buzunar, ci la câțiva pași, ca să le vezi cum vin (magnetul lor le aduce oricum).
# Valoarea urmează dificultatea, exact ca gemele lăsate de inamici (vezi enemy._drop_xp) — altfel
# la minutul 10 ar fi rămas niște firimituri.
func _mankini_drop() -> void:
	if mankini_stacks <= 0:
		return
	if randf() >= MANKINI_CHANCE + luck_bonus():
		return
	var parent := get_parent()
	if parent == null:
		return
	for i in MANKINI_GEME * mankini_stacks:
		var gem := MANKINI_GEM.instantiate()
		gem.value = int(round(gem.value * Difficulty.xp_mult()))
		parent.add_child(gem)
		gem.global_position = global_position + Vector2(randf_range(50.0, 100.0), 0).rotated(randf() * TAU)

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
	Audio.play("hurt", -4.5)  # player lovit
	if hp <= 0:
		hp = 0
		die()

func die() -> void:
	if dead:
		return
	# Undying Spirit: prima moarte nu e finală. Te duce în Limbo (lumea alb-negru) și,
	# dacă reziști minutul, te întoarce aici. O SINGURĂ dată pe rundă — a doua oară
	# `undying_used` e deja true și cazi pe Game Over-ul normal de mai jos.
	#
	# ⚠️ Se întreabă ÎNAINTEA ieșirii din dimensiune, și e invers față de cum a fost până pe
	# 2026-08-06. Atunci Nether-ul/Ender-ul se închideau primele, deci un minut de Limbo îți
	# mânca portalul, boss-ul și ceasul dimensiunii, iar la întoarcere te trezeai în lumea
	# normală. Acum Limbo le pune el pe pauză (`suspenda()`) și te dă înapoi fix de unde ai
	# murit, cum a cerut Răzvan. Dacă Limbo NU te prinde, dimensiunea se închide ca înainte,
	# mai jos.
	if has_undying and not undying_used:
		var limbo := get_tree().get_first_node_in_group("limbo")
		if limbo != null and not limbo.active:
			undying_used = true
			limbo.enter(self)
			return
	# Moarte adevărată. Ai murit în Nether → ieși ÎNTÂI din dimensiune (lumea, podeaua și
	# dificultatea se pun la loc), abia apoi ecranul de Game Over.
	var nether := get_tree().get_first_node_in_group("nether")
	if nether != null and nether.active:
		nether.exit_nether(false)
	# la fel pentru Ender (a treia dimensiune) — și el îngheață dificultatea și oprește decorul
	var ender := get_tree().get_first_node_in_group("ender")
	if ender != null and ender.active:
		ender.exit_ender(false)
	dead = true
	var screen := get_tree().get_first_node_in_group("gameover_screen")
	if screen != null:
		screen.show_gameover(Difficulty.time, level)
	else:
		get_tree().reload_current_scene()  # fallback dacă n-ai adăugat încă ecranul de Game Over

# 🔑 RESTUL SE PĂSTREAZĂ, nu se aruncă (2026-07-28). Înainte aici era `int(amount * mult)`, iar
# `int()` TAIE zecimalele: gema mică valorează 1, deci 1 × 1.15 = 1.15 → 1. Adică orice bonus de
# XP sub +100% era complet invizibil pe gemele mici — și ele sunt majoritatea. Nu doar itemul nou
# (5G Tower) era mort din start, ci și nivelurile de „XP gain" din magazinul permanent (+8% fiecare).
# Acum ce rămâne sub 1 se strânge în `_xp_rest` și intră în XP de îndată ce se adună un întreg:
# la +15%, a șaptea gemă de 1 aduce 2 în loc de 1. Pe termen lung totalul e exact cât spune procentul.
var _xp_rest := 0.0

func gain_xp(amount: int) -> void:
	# `+ 1e-9`: 1.15 nu se scrie exact în binar, așa că după 20 de geme suma ajunge la
	# 22.999999… în loc de 23, iar `int()` ar da 22. Punctul nu s-ar pierde (rămâne în rest și
	# iese la gema următoare), dar cifrele n-ar mai fi cele pe care le socotește jucătorul.
	var exact := amount * xp_gain_mult + _xp_rest + 1e-9
	var intreg := int(exact)
	_xp_rest = exact - float(intreg)
	xp += intreg
	# while (nu if) ca să prindem și cazul în care un salt mare de XP trece peste mai multe niveluri
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()

# Damage-ul și cadența de bază ale armei alese (vezi tabelul `ARME`). Se cheamă ÎNAINTE de
# `_apply_meta()`, ca upgrade-urile permanente să se adune PESTE valorile armei, nu invers —
# altfel arma ar șterge ce ai cumpărat din magazin.
func _aplica_arma() -> void:
	var a: Dictionary = ARME.get(weapon_type, ARME["pistol"])
	bullet_damage = int(a["damage"])
	fire_interval = float(a["interval"])

func _level_up(cu_sunet: bool = true) -> void:
	level += 1
	# Bonusul de nivel al armei crește ODATĂ cu nivelul. Cele patru procente se citesc la
	# folosire, deci se aplică singure; doar cadența trăiește într-un `Timer`, care trebuie
	# împins de mână (vezi `_seteaza_cadenta`).
	_seteaza_cadenta()
	if cu_sunet:
		Audio.play("levelup", -2.0)  # jingle de nivel nou
	xp_to_next = int(xp_to_next * 1.2)  # pragul crește cu 20% la fiecare nivel
	var menu := get_tree().get_first_node_in_group("levelup_menu")
	if menu != null:
		menu.open()

# Dăruiește `n` niveluri deodată, FĂRĂ XP — premiul pentru Saratalin (vezi `saratalin.gd`).
# Sunt niveluri ADEVĂRATE, nu doar n ecrane de ales: crește `level` și urcă pragul de XP
# exact ca o creștere normală. Altfel „nivel" ar fi însemnat aici altceva decât în rest.
# Ecranele se strâng singure: `levelup.open()` ține un contor și le arată pe rând.
# Jingle-ul îl dăm o singură dată — trei suprapuse în același cadru sună a bug, nu a premiu.
func da_niveluri(n: int, cu_sunet: bool = true) -> void:
	if n <= 0 or dead:
		return
	for i in n:
		_level_up(cu_sunet and i == 0)

# --- îmbunătățiri aplicate de ecranul de level up ---
func upgrade_max_hp(amount: int) -> void:
	max_hp += amount
	hp += amount  # te și vindecă cu cât ai crescut viața maximă

func upgrade_fire_rate(factor: float) -> void:
	fire_interval *= factor              # factor < 1 → pauză mai mică între trageri = tragi mai des
	_seteaza_cadenta()

# OP START — comutatorul din colțul meniului. Pornește runda cu statusuri de final, ca să se
# poată ajunge repede la ce e de testat.
#
# SCRIE, nu adună: dacă ar aduna, rezultatul ar depinde de armă și de cât ai cumpărat din
# magazin, iar butonul n-ar mai însemna aceleași trei cifre de fiecare dată. De aia se cheamă
# DUPĂ `_aplica_arma()` și `_apply_meta()` — ce se cheamă ultimul câștigă.
#
# Se citește o SINGURĂ dată, aici. Pornit în timpul unei runde, nu se întâmplă nimic până la
# următoarea — și așa și trebuie: e „OP **start**".
func _aplica_op_start() -> void:
	if not GameSettings.op_start:
		return
	bullet_damage = GameSettings.OP_DAMAGE
	# Butonul e scris în ATACURI PE SECUNDĂ (cum arată și panoul de statusuri), dar player-ul
	# lucrează cu pauza dintre atacuri. 2.5 atacuri/s = 0.4s pauză.
	fire_interval = 1.0 / GameSettings.OP_ATTACK_SPEED
	bullet_count = GameSettings.OP_PROJECTILES

# Aplică upgrade-urile permanente (meta-progresie) la începutul rundei.
func _apply_meta() -> void:
	max_hp += GameSettings.level_of("hp") * 15
	bullet_damage += GameSettings.level_of("damage") * 3
	speed += GameSettings.level_of("speed") * 15.0
	fire_interval *= pow(0.96, GameSettings.level_of("firerate"))
	xp_gain_mult = 1.0 + GameSettings.level_of("xp") * 0.08
	hp_regen += GameSettings.level_of("regen") * 1
