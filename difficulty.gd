extends Node

# ---------------------------------------------------------------------------
# "Creierul" dificultății. E un SINGLETON (autoload) — există o singură dată,
# global, și orice script poate citi din el: Difficulty.enemy_hp_mult(), etc.
#
# MODELUL (ca la Megabonk): runda are DOUĂ faze.
#
#   FAZA 1 — "cele 10 minute" (0 → 600s)
#     Cronometrul de pe ecran SCADE de la 10:00 la 0:00.
#     Inamicii cresc LINIAR: cu fiecare minut au mai multă viață, sunt puțin
#     mai rapizi și apar mai des. La minutul 10 sunt de ~6.5× mai tari ca la
#     început — greu, dar încă se poate.
#
#   FAZA 2 — "FINAL SWARM" (după 600s)
#     Cronometrul o ia de la 0:00 în SUS. De aici creșterea nu mai e liniară,
#     ci EXPONENȚIALĂ: viața inamicilor se DUBLEAZĂ la fiecare 45 de secunde.
#     Nu e menită să fie supraviețuibilă la nesfârșit — scorul tău e cât reziști.
#
# Toate butoanele de reglaj sunt constantele de mai jos.
# ---------------------------------------------------------------------------

const RUN_LENGTH := 600.0     # 10 minute = cât ține faza 1

# --- FAZA 1, PARTEA LINIARĂ: primele `RAMP_START` secunde (cât crește pe MINUT) ---
# Începutul rundei a rămas exact cum era — reclamația lui Răzvan era că DUPĂ 1:30
# inamicii rămân în urmă, nu că e greu la început.
const RAMP_START := 90.0      # 1:30 — de aici încolo creșterea devine COMPUSĂ
const HP_PER_MIN := 0.55
const SPEED_PER_MIN := 0.035
const SPAWN_PER_MIN := 0.28
const XP_PER_MIN := 0.30

# --- FAZA 1, PARTEA COMPUSĂ: după 1:30, fiecare minut ÎNMULȚEȘTE (nu adună) ---
# Liniarul urca prea încet: la minutul 10 inamicii aveau doar 6.5× viață, în timp ce
# build-ul tău se înmulțește (damage × crit × proiectile × AOE). Acum urcă și ei
# geometric: 1.40 pe minut → ~32× la minutul 10, cu accelerarea simțită treptat.
const HP_GROWTH_PER_MIN := 1.40
# Damage-ul de contact NU creștea deloc: un inamic de la minutul 10 lovea exact cât
# unul de la secunda 0. Acum crește compus, calibrat să ajungă la ×2 la minutul 10
# (2^(1/8.5), fiindcă din 1:30 până la 10:00 sunt 8.5 minute de rampă).
const DMG_GROWTH_PER_MIN := 1.0844

# --- FAZA 2 (Final Swarm): la câte SECUNDE se dublează fiecare lucru ---
# Mai mic = crește mai repede. Viața e cea care explodează; viteza urcă mult
# mai lent, altfel inamicii ar depăși instant player-ul și n-ai mai avea ce face.
const FS_HP_DOUBLE_EVERY := 45.0
const FS_SPEED_DOUBLE_EVERY := 300.0
const FS_SPAWN_DOUBLE_EVERY := 75.0
const FS_DMG_DOUBLE_EVERY := 120.0   # damage-ul de contact se dublează la fiecare 2 minute
const FS_SPAWN_JUMP := 3.0     # saltul brusc de spawn chiar în secunda în care începe Final Swarm
const SPEED_CAP := 2.2         # oricât ar trece, inamicii nu depășesc 2.2× viteza de bază

# Timpul scurs de la începutul rundei (secunde). Spawner-ul îl resetează la joc nou.
var time: float = 0.0

# --- LIMBO (itemul Undying Spirit) ---
# `frozen` = cronometrul rundei stă pe loc: minutul petrecut în Limbo nu-ți umflă scorul
# și nu împinge runda spre Final Swarm.
# `mult_time_override` >= 0 → inamicii se calculează după ACEL moment, nu după `time`.
# Așa cere itemul: în Limbo vin inamici de dificultatea de acum un minut.
# Ce se vede pe ecran (cronometru, anunțul de Final Swarm) rămâne pe `time`.
var frozen := false
var mult_time_override := -1.0

func _process(delta: float) -> void:
	if not frozen:
		time += delta

# Timpul din care se calculează CÂT DE TARI sunt inamicii (≠ timpul afișat).
func _mult_time() -> float:
	return mult_time_override if mult_time_override >= 0.0 else time

func _mult_is_fs() -> bool:
	return _mult_time() >= RUN_LENGTH

func _mult_overtime() -> float:
	return maxf(0.0, _mult_time() - RUN_LENGTH)

# --- Unde suntem în rundă ---

# true din secunda în care cele 10 minute s-au terminat
func is_final_swarm() -> bool:
	return time >= RUN_LENGTH

# Câte secunde au trecut DE CÂND a început Final Swarm (0 dacă n-a început).
func overtime() -> float:
	return maxf(0.0, time - RUN_LENGTH)

# Câte secunde mai sunt din cele 10 minute (0 după ce s-au terminat).
func time_left() -> float:
	return maxf(0.0, RUN_LENGTH - time)

# Minutele din faza 1, oprite la 10 (ca liniarul să nu curgă și în Final Swarm —
# acolo preia exponențiala).
func _phase1_minutes() -> float:
	return minf(_mult_time(), RUN_LENGTH) / 60.0

# Minutele din partea LINIARĂ (primele 1:30) — folosite de HP și XP ca punct de plecare.
func _lin_minutes() -> float:
	return minf(_phase1_minutes() * 60.0, RAMP_START) / 60.0

# Minutele din faza 1 de DUPĂ rampă — aici creșterea e compusă (pow, nu înmulțire liniară).
func _ramp_minutes() -> float:
	return maxf(0.0, minf(_mult_time(), RUN_LENGTH) - RAMP_START) / 60.0

# Factorul exponențial: 1.0 înainte de Final Swarm, apoi se dublează la fiecare
# `double_every` secunde.
func _fs_factor(double_every: float) -> float:
	if not _mult_is_fs():
		return 1.0
	return pow(2.0, _mult_overtime() / double_every)

# --- Multiplicatorii pe care îi citesc inamicii și spawner-ul ---

func enemy_hp_mult() -> float:
	return (1.0 + HP_PER_MIN * _lin_minutes()) \
		* pow(HP_GROWTH_PER_MIN, _ramp_minutes()) \
		* _fs_factor(FS_HP_DOUBLE_EVERY)

# Cât de tare lovesc inamicii (contact + bilele Gărzii), față de începutul rundei.
# 1.0 în primele 1:30, ×2 la minutul 10, apoi se dublează la fiecare 2 minute în Final Swarm.
func enemy_damage_mult() -> float:
	return pow(DMG_GROWTH_PER_MIN, _ramp_minutes()) * _fs_factor(FS_DMG_DOUBLE_EVERY)

func enemy_speed_mult() -> float:
	var m := (1.0 + SPEED_PER_MIN * _phase1_minutes()) * _fs_factor(FS_SPEED_DOUBLE_EVERY)
	return minf(m, SPEED_CAP)

func spawn_mult() -> float:
	var m := 1.0 + SPAWN_PER_MIN * _phase1_minutes()
	if _mult_is_fs():
		m *= FS_SPAWN_JUMP * _fs_factor(FS_SPAWN_DOUBLE_EVERY)
	return m

func xp_mult() -> float:
	# XP-ul urcă odată cu inamicii, ca să poți ține pasul cu upgrade-urile.
	# ⚠️ Primește ACELAȘI factor compus ca viața (`HP_GROWTH_PER_MIN`): dacă îl lăsam liniar,
	# la minutul 10 inamicii ar fi avut 32× viață și ar fi dat doar 4× XP — i-ai fi omorât de
	# 5 ori mai greu pentru aceleași niveluri, deci ritmul upgrade-urilor s-ar fi prăbușit și
	# ar fi ieșit „imposibil", nu „greu". În Final Swarm merge la fel ca viața lor.
	return 2.0 * (1.0 + XP_PER_MIN * _lin_minutes()) \
		* pow(HP_GROWTH_PER_MIN, _ramp_minutes()) \
		* _fs_factor(FS_HP_DOUBLE_EVERY)

# XP2 (rar) e deblocat după primele 2 minute
func xp2_unlocked() -> bool:
	return time >= 120.0
