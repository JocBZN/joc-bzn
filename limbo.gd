extends CanvasLayer

# LIMBO — mecanica itemului „Undying Spirit" (upgrade_41).
#
# Când mori și ai itemul (o singură dată pe rundă), în loc de Game Over ești dus într-o
# lume goală, alb-negru: fără copaci, pietre, structuri, statui, cufere, portaluri sau poteci. Peste
# tine vine dintr-o dată un val mare de inamici. Trebuie să reziști LIMBO_TIME secunde, apoi ești
# trimis înapoi exact unde ai murit — ȘI ÎN DIMENSIUNEA în care ai murit (lumea normală, Nether
# sau Ender) — iar inamicii care erau pe tine în acel moment nu mai există.
#
# Cum e făcut: NU se încarcă altă scenă. Rămânem în aceeași lume, dar:
#   • generatoarele de decor (Props/Rocks/DesertStructures/Statues/Chests/EGTs/Monuments/Portals
#     + potecile) sunt oprite și golite;
#   • spawner-ul normal e oprit — inamicii îi scoatem noi, dar cu ritmul, viteza și damage-ul
#     lui, calculate din dificultatea de acum un minut (vezi `_diff_start` mai jos);
#   • dacă ai murit într-o dimensiune, ea nu se închide, ci se PUNE PE PAUZĂ
#     (`nether.gd::suspenda()` / `ender.gd::suspenda()`) și se reia la ieșire;
#   • un shader alb-negru acoperă ecranul.
# La ieșire se pune totul la loc. Așa nu pierdem starea rundei (upgrade-uri, XP, poziție).
#
# 🎬 AMÂNDOUĂ DRUMURILE TREC PRINTR-O CINEMATICĂ (de pe 2026-09-17, vezi „TRANZIȚIA" mai jos):
# diafragma din `iris.gd` — aceeași cu a morții și a începutului de rundă — se închide peste tine,
# sub negru se schimbă lumea, apoi se deschide în locul nou. Nu e doar de frumusețe: tot ce e greu
# (ștersul inamicilor, golitul și reaprinderea celor 13 generatoare, valul de 40) se face acolo,
# câte o bucată pe cadru. Înainte cădea tot într-un singur cadru, în văzul lumii: 71 ms la intrare,
# 76 + 33 ms la ieșire — „lagheaza pentru ca e prea rapida tranzitia", cum a zis Răzvan.

const ENEMY := preload("res://enemy.tscn")   # rezerva, dacă spawner-ul lipsește (scene de test)
const BW_SHADER := preload("res://limbo_bw.gdshader")
const IRIS := preload("res://iris.gd")        # diafragma, împărțită cu `gameover.gd` și `intro.gd`

# --- reglaje (schimbă-le liniștit) ---
const LIMBO_TIME := 60.0        # cât trebuie să reziști, în secunde
const DIFF_REWIND := 60.0       # dificultatea de acum câte secunde se folosește
const HP_ON_ENTER := 0.5        # cu cât din viața maximă te trezești (0.5 = jumătate)
const BURST := 40               # câți inamici apar DEODATĂ la intrare
const BURST_RADIUS := 520.0     # la ce distanță de tine apar (cerc în jurul tău)
const MAX_ENEMIES := 300        # plafon de siguranță, ca la `spawner.gd`
# --- TRANZIȚIA (secunde) ---
# Intrarea și ieșirea din Limbo se fac prin ACEEAȘI diafragmă ca moartea și ca începutul rundei
# (`iris.gd`) — și asta ȘI e: o moarte din care te întorci. Cercul se închide peste tine, sub
# negru se schimbă lumea, apoi se deschide în locul nou. Până pe 2026-09-17 nu exista nicio
# cinematică: lumea se golea și se umplea la loc într-un SINGUR cadru (măsurat: 71 ms la intrare,
# 76 + 33 ms la ieșire, adică 4-5 cadre pierdute), sub un simplu fade alb-negru de 0,6 s care nu
# apuca să acopere nimic. Acum munca grea e tăiată în bucăți, câte una pe cadru, și se face cât
# ecranul e negru (vezi `_porneste_tranzitie`).
#
# Timpii sunt mai scurți decât ai morții adevărate (acolo cercul cade în 1,39 s): aici trebuie să
# se simtă că runda CONTINUĂ, nu că s-a terminat.
const T_INCHIDERE := 0.34    # cercul mănâncă ecranul
const T_PRABUSIRE := 0.12    # ...și se prăbușește la zero
const T_NEGRU_MIN := 0.20    # cât stă negru cel puțin, chiar dacă munca s-a terminat mai devreme
const T_NEGRU_MAX := 1.40    # ...și cât cel mult, dacă mașina e slabă și coada încă lucrează
const T_DESCHIDERE := 0.55   # cercul se deschide în lumea nouă
const RAZA_MICA := 0.22      # pragul dintre „înghițire" și prăbușire (aceeași cifră ca la moarte)
const CULOARE_SPIRIT := Color(0.62, 0.82, 1.00)  # inelul: albastrul spiritului, nu roșul morții
const DB_TRANZITIE := -8.0   # whoosh-ul de sub cerc stă SUB tot, e mișcare, nu eveniment

# Cât lucrăm pe cadru cât ecranul e negru. Cifrele astea sunt tot ce desparte o tranziție lină de
# una care smucește: cu cât sunt mai mici, cu atât negrul ține mai mult, dar niciun cadru nu mai
# iese din buget.
const INAMICI_PE_CADRU := 60     # câți inamici ștergem odată
const BURST_PE_CADRU := 8        # câți inamici de Limbo scoatem odată (BURST = 40 → 5 cadre)
const CLOCK_SIZE := 64                          # mai mare decât cronometrul rundei (44)
const CLOCK_COLOR := Color(1.0, 0.10, 0.10)     # roșu aprins

# Nodurile care fac decorul. Sunt oprite cât ești în Limbo → „lume fără structuri".
# ⚠️ Lista asta se ține în oglindă cu cea din `nether.gd`: un generator nou pus în `World`
# (main.tscn) trebuie trecut în AMÂNDOUĂ. Dacă lipsește dintr-una, rămâne aprins acolo și-i vezi
# obiectele într-o dimensiune în care n-au ce căuta. S-a întâmplat de trei ori: cu „EGTs"
# (aparatele de cazinou, 2026-07-30) întâi în `nether.gd`, apoi și aici — și cu „Portals",
# lipsă de aici până pe 2026-08-06, adică în Limbo îți răsăreau portaluri Nether și fântâni
# Ender („nu vreau sa apara portalul de ender in limbo").
const WORLD_NODES := ["Props", "Rocks", "Bushes", "DesertStructures", "Statues", "Chests", "EGTs", "Monuments", "Portals", "PrisonGates", "AlbaNeagras", "Dubiosi"]
# `Paths` (potecile) NU e în `World`, ci frate cu el, direct în `main.tscn` — de aia are
# nevoie de listă separată. Exact ca în `nether.gd`.
const ROOT_NODES := ["Paths"]

var active := false

var _overlay: ColorRect
var _clock: Label        # numărătoarea inversă, desenată peste filtrul alb-negru
var _mat: ShaderMaterial
var _time_left := 0.0
var _spawn_acc := 0.0        # „sfert de inamic" rămas de la cadrul trecut (vezi `_process`)
var _player: Node2D = null
var _return_pos := Vector2.ZERO
var _spawner: Node = null
# Dimensiunea în care ai murit (`nether.gd` sau `ender.gd`), pusă pe pauză cât ești aici și
# reluată la ieșire. `null` = ai murit în lumea normală.
var _dimensiune: Node = null

# --- tranziția (vezi `_porneste_tranzitie`) ---
var _iris: ColorRect = null      # diafragma, aceeași cu a morții și a începutului de rundă
var _strat_iris: CanvasLayer = null   # stratul ei, peste al nostru (vezi `_ready`)
var _coada := []                 # pașii grei, câte unul pe cadru cât ecranul e negru
var _la_final := Callable()      # ce se cheamă în clipa în care cercul începe să se deschidă
var _in_tranzitie := false
var _negru := false
var _negru_t := 0.0
var _burst_ramas := 0
var _pauza_noastra := false   # noi am pus `get_tree().paused`? (vezi `_negru_start`)

func _ready() -> void:
	add_to_group("limbo")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5   # peste lume și HUD, dar SUB ecranul de Game Over (care e pe 20)
	_mat = ShaderMaterial.new()
	_mat.shader = BW_SHADER
	_mat.set_shader_parameter("amount", 0.0)
	_overlay = ColorRect.new()
	_overlay.material = _mat
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	# Cronometrul de Limbo. Stă în ACEEAȘI CanvasLayer, adăugat DUPĂ overlay → se desenează
	# peste filtrul alb-negru și rămâne roșu. Dacă l-am lăsa în HUD (care e sub filtru),
	# ar ieși gri, oricât roșu i-am da. Cât ține Limbo, HUD-ul își ascunde cronometrul lui.
	_clock = Label.new()
	_clock.anchor_left = 0.0
	_clock.anchor_right = 1.0
	_clock.offset_top = 8
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", CLOCK_SIZE)
	_clock.add_theme_color_override("font_color", CLOCK_COLOR)
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_clock.add_theme_constant_override("outline_size", 9)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.visible = false
	add_child(_clock)

	# Diafragma. Stă în CanvasLayer-ul EI, unul peste al nostru (6 > 5), nu lângă overlay: ambele
	# shadere citesc `hint_screen_texture`, iar două astfel de noduri în ACELAȘI strat citesc
	# aceeași copie de ecran — adică diafragma ar fi desenat imaginea de DINAINTE de filtrul
	# alb-negru și l-ar fi anulat cât ține tranziția (văzut pe 2026-09-17: Limbo se deschidea în
	# culori și abia după ce se termina cercul se făcea gri). Un strat separat = altă copie, deci
	# cercul cade PESTE alb-negru, cum trebuie.
	# Stă ascunsă când nu e nicio tranziție: shaderul ei citește tot ecranul în fiecare cadru.
	_strat_iris = CanvasLayer.new()
	_strat_iris.layer = layer + 1
	add_child(_strat_iris)
	_iris = IRIS.new()
	_iris.culoare_inel = CULOARE_SPIRIT
	_iris.visible = false
	_strat_iris.add_child(_iris)

# ---------- INTRARE ----------
# Chemată din player.die() în locul ecranului de Game Over.
#
# Aici rămâne DOAR ce trebuie făcut în clipa morții; golitul lumii, ștersul inamicilor și valul de
# la intrare intră în coada tranziției și se fac sub negru, câte o bucată pe cadru.
func enter(player: Node2D) -> void:
	if active or _in_tranzitie or player == null:
		return
	_player = player
	_return_pos = player.global_position
	_time_left = LIMBO_TIME
	_spawn_acc = 0.0

	# Dificultatea de acum un minut, ÎNGHEȚATĂ pe loc pentru tot Limbo-ul. Se citește ÎNAINTE de
	# orice altceva, fiindcă de aici încolo o rescriem noi.
	#
	# ⚠️ Pornim de la `Difficulty.mult_time()` (dificultatea pe care o SIMȚEAI acum), nu de la
	# `Difficulty.time` (ceasul rundei), cum era până pe 2026-08-06. În Nether și în Ender ceasul
	# rundei e înghețat din secunda în care ai intrat, deci `time - 60` te dădea cu minute bune
	# înapoi și te trezeai în Limbo cu inamici de început de rundă — exact reclamația lui Răzvan
	# („in limbo nu sunt inamicii destul de op").
	var diff_start := maxf(0.0, Difficulty.mult_time() - DIFF_REWIND)

	# Nu mai ești mort: te ridici cu jumătate de viață. Se face ACUM, nu sub negru — cât se închide
	# cercul lumea stă pe pauză, deci oricum nu te mai poate lovi nimeni, dar nu vrem să rămâi o
	# jumătate de secundă „mort" pentru restul codului.
	player.dead = false
	player.hp = maxi(1, int(round(player.max_hp * HP_ON_ENTER)))

	var pasi := []
	pasi.append(_pas_intrare_start.bind(diff_start))
	pasi.append(_pas_sterge_inamici)
	pasi.append_array(_pasi_generatoare(false))
	pasi.append(_pas_burst)
	_porneste_tranzitie(pasi, _dupa_intrare, "death_sweep")

# Prima bucată de sub negru: de aici încolo chiar ești în Limbo.
func _pas_intrare_start(diff_start: float) -> void:
	active = true
	# Ai murit într-o dimensiune? N-o închidem — o punem pe pauză și o reluăm la ieșire, ca să te
	# întorci „fix din locul unde ai murit" (cerut pe 2026-08-06). Se face ÎNAINTE de ștergerea
	# inamicilor (pasul următor): pauza scoate boss-ul dimensiunii din grupul „enemy", altfel l-am
	# mătura noi și portalul de întoarcere n-ar mai avea cum să se deschidă vreodată.
	_dimensiune = _dimensiunea_activa()
	if _dimensiune != null:
		_dimensiune.suspenda()
	_set_spawner_enabled(false)
	# inamicii de aici au dificultatea de acum un minut, iar cronometrul rundei stă
	Difficulty.mult_time_override = diff_start
	Difficulty.frozen = true
	_burst_ramas = BURST
	# Alb-negrul se pune DINTR-O DATĂ, nu într-un fade: sub cercul închis n-are cine să vadă
	# trecerea, iar când el se deschide lumea trebuie să fie deja Limbo. (Până acum fade-ul de
	# 0,6 s era singura „tranziție" — și tocmai el lăsa la vedere lumea care se golea.)
	_overlay.visible = true
	_mat.set_shader_parameter("amount", 1.0)
	_clock.text = _mmss(_time_left)
	_clock.visible = true

func _dupa_intrare() -> void:
	_announce("LIMBO", "Survive 1:00 and you go back")
	Audio.play("levelup", -2.0)

# ---------- IEȘIRE ----------
func _exit_limbo() -> void:
	if not active or _in_tranzitie:
		return
	active = false
	_clock.visible = false
	# Decorul lumii normale se aprinde la loc DOAR dacă acolo te întorci. Dacă ai murit în Nether
	# sau în Ender, el trebuie să rămână stins — altfel ai ateriza într-o dimensiune plină de
	# copaci și cufere, iar `reia()` n-ar avea cum să-i mai stingă. Se hotărăște ACUM, nu în pas:
	# `_pas_iesire_start` uită dimensiunea după ce o repornește.
	var lumea_normala := _dimensiune == null
	var pasi := []
	pasi.append(_pas_sterge_inamici)      # ce era pe tine în Limbo nu vine cu tine
	pasi.append(_pas_iesire_start)
	pasi.append_array(_pasi_generatoare(lumea_normala))
	_porneste_tranzitie(pasi, _dupa_iesire, "teleport")

# ⚠️ Vine ÎNAINTEA generatoarelor din coadă, și nu degeaba: ele își construiesc pătratele în jurul
# player-ului, deci trebuie să fie deja mutat la loc când le vine rândul.
func _pas_iesire_start() -> void:
	_set_spawner_enabled(true)
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0
	if _player != null and is_instance_valid(_player):
		_player.global_position = _return_pos   # exact unde ai murit
	# ...și înapoi în dimensiunea în care ai murit, de unde a rămas: ceasul ei, portalul, boss-ul
	# la viața pe care i-o lăsaseși. `reia()` își pune la loc și dificultatea, deci vine ULTIMA,
	# peste neutralizarea de mai sus.
	if _dimensiune != null and is_instance_valid(_dimensiune):
		_dimensiune.reia()
	_dimensiune = null
	_mat.set_shader_parameter("amount", 0.0)
	_overlay.visible = false

func _dupa_iesire() -> void:
	_announce("YOU MADE IT", "The spirit sends you back")
	Audio.play("levelup", -2.0)

# ---------- TRANZIȚIA ----------
# Un singur mecanism pentru amândouă drumurile: cercul se închide → ecranul e negru și coada de
# pași se scurge, câte unul pe cadru → cercul se deschide.
#
# 🔑 De ce o coadă și nu pur și simplu tot pe loc: lumea asta nu se schimbă „setând un bool". La
# intrare se șterg toți inamicii și se golesc 13 generatoare de decor; la ieșire se aprind la loc
# și fiecare își reconstruiește 49 de pătrate în cadrul în care e pornit. Făcute toate odată, alea
# sunt 70-80 ms într-un cadru — exact smucitura pe care a reclamat-o Răzvan. Tăiate câte una pe
# cadru, aceeași muncă se întinde pe ~20 de cadre de sub negru, unde nimeni n-o vede.
#
# ⚠️ Lumea stă pe PAUZĂ doar cât se închide cercul (ca la moarte: ultimul lucru pe care-l vezi e
# înghețat), și repornește în clipa în care ecranul devine negru — altfel generatoarele n-ar avea
# când să-și facă treaba, `_process`-ul lor e oprit de pauză.
func _porneste_tranzitie(pasi: Array, la_final: Callable, sunet: String) -> void:
	_coada = pasi
	_la_final = la_final
	_in_tranzitie = true
	_negru = false
	_negru_t = 0.0
	# Fără player n-avem pe ce centra cercul (scene de test): sărim direct la muncă, fără cinematică.
	if _player == null or not is_instance_valid(_player):
		_negru_start()
		return
	_iris.aseaza_pe_player()
	_iris.seteaza_raza(_iris.raza_start)
	_iris.visible = true
	# Lumea îngheață cât se strânge cercul — ultimul lucru pe care-l vezi stă pe loc, ca la moarte.
	# Ținem minte dacă noi am pus pauza: dacă era deja pusă de altcineva, nu e a noastră s-o ridicăm.
	_pauza_noastra = not get_tree().paused
	if _pauza_noastra:
		get_tree().paused = true
	Audio.enter_menu_muffle("limbo")   # muzica trece în spatele ușii cât ești între lumi
	if sunet != "":
		Audio.play(sunet, DB_TRANZITIE)
	var tw := create_tween()
	tw.tween_method(_raza, _iris.raza_start, RAZA_MICA, T_INCHIDERE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_raza, RAZA_MICA, 0.0, T_PRABUSIRE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_negru_start)

func _negru_start() -> void:
	_negru = true
	_negru_t = 0.0
	# ⚠️ Repornim lumea DOAR dacă noi am oprit-o. Pauza e o singură variabilă globală pe care se
	# bat mai mulți: Level Up-ul (`levelup.gd`), meniul de pauză (`pause.gd`), cazinoul. Poți ieși
	# din Limbo fix cu ecranul de Level Up deschis (cronometrul de aici merge și sub pauză) — un
	# `paused = false` orb ar porni jocul pe sub meniul ăla.
	if _pauza_noastra:
		_pauza_noastra = false
		var meniu := get_tree().get_first_node_in_group("pause_menu")
		if meniu == null or not meniu.visible:
			get_tree().paused = false

# Un pas pe cadru, cât ține negrul. Deschidem când coada s-a golit (dar nu înainte de
# `T_NEGRU_MIN`, ca negrul să nu clipească pe o mașină rapidă) sau când s-a atins `T_NEGRU_MAX`.
func _pas_tranzitie(delta: float) -> void:
	if not _negru:
		return
	_negru_t += delta
	if not _coada.is_empty():
		var pas: Callable = _coada.pop_front()
		if pas.is_valid():
			pas.call()
	if (_coada.is_empty() and _negru_t >= T_NEGRU_MIN) or _negru_t >= T_NEGRU_MAX:
		_deschide()

func _deschide() -> void:
	_negru = false
	# Ce a mai rămas în coadă (mașină slabă, s-a atins `T_NEGRU_MAX`) se termină ACUM, într-un
	# cadru: mai bine un cadru lung decât o lume care se aprinde pe jumătate sub ochii jucătorului.
	while not _coada.is_empty():
		var pas: Callable = _coada.pop_front()
		if pas.is_valid():
			pas.call()
	Audio.exit_menu_muffle("limbo")
	if _la_final.is_valid():
		_la_final.call()          # bannerul și sunetul pornesc odată cu deschiderea, nu după ea
	if _player == null or not is_instance_valid(_player) or not _iris.visible:
		_gata_tranzitie()
		return
	_iris.aseaza_pe_player()      # la ieșire te-ai mutat cât a fost negru: cercul se deschide de pe tine
	var tw := create_tween()
	tw.tween_method(_raza, 0.0, _iris.raza_start, T_DESCHIDERE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_gata_tranzitie)

func _gata_tranzitie() -> void:
	_coada.clear()
	_in_tranzitie = false
	_negru = false
	_iris.visible = false

func _raza(r: float) -> void:
	_iris.seteaza_raza(r)

# ---------- PAȘII GREI ----------
# Ștergem inamicii în felii: la Final Swarm pot fi 300 pe ecran, iar 300 de `queue_free` odată se
# văd. Pasul se re-pune singur în capul cozii cât mai are de lucru.
func _pas_sterge_inamici() -> void:
	var lista := get_tree().get_nodes_in_group("enemy")
	var cati := mini(lista.size(), INAMICI_PE_CADRU)
	for i in cati:
		lista[i].queue_free()
	if lista.size() > cati:
		_coada.push_front(_pas_sterge_inamici)

# Valul de la intrare (BURST = 40), tot în felii. La fel: se re-pune singur cât mai are.
func _pas_burst() -> void:
	var cati := mini(_burst_ramas, BURST_PE_CADRU)
	for i in cati:
		_spawn_one()
	_burst_ramas -= cati
	if _burst_ramas > 0:
		_coada.push_front(_pas_burst)

# Câte un generator de decor pe cadru. Ăsta e pasul care a omorât smucitura de la ieșire: aprinse
# toate odată, cele 13 își construiau pătratele în ACELAȘI cadru.
func _pasi_generatoare(on: bool) -> Array:
	var pasi := []
	for nd in _noduri_decor():
		pasi.append(_toggle_generator.bind(nd, on))
	return pasi

# Ai murit în Limbo: eliberăm starea globală, dar NU te mutăm și NU stingem alb-negrul —
# mori acolo, cu tot cu atmosferă.
#
# Dimensiunea (dacă erai suspendat într-una) NU se reia aici: `player.die()` a chemat deja
# `exit_nether(false)` / `exit_ender(false)`, iar ele se trezesc singure din pauză (vezi
# `_suspendat` acolo). Noi doar uităm de ea, ca să nu rămână o referință moartă.
func _abort() -> void:
	active = false
	_dimensiune = null
	_clock.visible = false   # nu lăsăm numărătoarea agățată peste ecranul de Game Over
	# Dacă tocmai eram într-o tranziție, o rupem aici: cercul nostru n-are ce căuta peste cinematica
	# de moarte, care are diafragma ei. ⚠️ Pauza NU se atinge — de acum o ține `gameover.gd`.
	if _in_tranzitie:
		_coada.clear()
		_in_tranzitie = false
		_negru = false
		_pauza_noastra = false   # pauza e a ecranului de Game Over de acum, nu a noastră
		if _iris != null:
			_iris.visible = false
		Audio.exit_menu_muffle("limbo")
	_set_world_enabled(true)
	_set_spawner_enabled(true)
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0

func _process(delta: float) -> void:
	# Tranziția se uită PRIMA: ea merge și cât lumea e pe pauză (nodul ăsta e PROCESS_MODE_ALWAYS)
	# și înainte ca `active` să fie pus, fiindcă ea e cea care intră și iese din Limbo.
	if _in_tranzitie:
		_pas_tranzitie(delta)
		return
	if not active:
		return
	# Ai murit în Limbo → asta chiar e sfârșitul (Game Over-ul e deja pe ecran).
	# Nu te mai întoarcem, dar punem lumea și dificultatea la loc, ca să nu rămână
	# `frozen`/spawner oprit agățate peste ecranul de final.
	if _player == null or not is_instance_valid(_player) or _player.dead:
		_abort()
		return
	_time_left -= delta
	_clock.text = _mmss(_time_left)
	if _time_left <= 0.0:
		_exit_limbo()
		return
	# Inamicii curg în EXACT ritmul lumii de acum un minut. Până pe 2026-08-06 aici era un
	# firicel fix (unul la 1,4 secunde), care la minutul 8 de rundă însemna de zeci de ori mai
	# puțini decât afară — de-aia se simțea Limbo-ul mai ușor decât lumea din care veneai.
	# Rata o cere `spawner.gd::rata_curenta()`, ca formula să trăiască într-un singur loc; el e
	# oprit cât suntem aici, dar funcția merge oricând.
	#
	# Adunăm fracții de inamic în `_spawn_acc` în loc să numărăm pauze: la rate mari (Final
	# Swarm) un cadru poate datora și 3-4 inamici, iar cu pauze înlănțuite s-ar pierde restul.
	if get_tree().get_nodes_in_group("enemy").size() < MAX_ENEMIES:
		_spawn_acc += delta * _rata()
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			_spawn_one()
	else:
		_spawn_acc = 0.0

# Câte secunde mai ai de rezistat (HUD-ul o afișează în loc de cronometrul rundei).
func time_left() -> float:
	return maxf(0.0, _time_left)

# ---------- ajutoare ----------

# În ce dimensiune ai murit? `null` = lumea normală. Nu poți fi în două deodată (`ender.gd` și
# `nether.gd` se refuză reciproc la intrare), deci primul găsit e cel bun.
func _dimensiunea_activa() -> Node:
	for g in ["nether", "ender", "prison"]:
		var d := get_tree().get_first_node_in_group(g)
		if d != null and d.get("active") == true and d.has_method("suspenda"):
			return d
	return null

# Câți inamici pe secundă, la dificultatea înghețată de la intrare. Vezi `spawner.gd`.
func _rata() -> float:
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner != null and _spawner.has_method("rata_curenta"):
		return _spawner.rata_curenta()
	return Difficulty.spawn_mult()

# Ce fel de inamic scoatem. Îl întrebăm tot pe spawner, ca să fie ACEIAȘI ca afară: dacă ai murit
# în Nether vin creaturile violete, dacă în Ender cele ale lui Celesto, iar în lumea normală
# polițiștii cu amestecul de Skinny/scăpați din Nether de la momentul ăla. (Dimensiunea rămâne
# `active` cât e suspendată, exact ca să meargă întrebarea asta.)
func _scena_inamic() -> PackedScene:
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner != null and _spawner.has_method("scena_inamic"):
		return _spawner.scena_inamic()
	return ENEMY

func _spawn_one() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var e := _scena_inamic().instantiate()
	var unghi := randf() * TAU
	_player.get_parent().add_child(e)
	e.global_position = _player.global_position \
		+ Vector2(cos(unghi), sin(unghi)) * BURST_RADIUS * randf_range(0.85, 1.25)

# Nodurile de decor, găsite o dată și date pe rând. `_set_world_enabled` le ia pe toate deodată
# (îl folosește doar `_abort`, unde ecranul de Game Over acoperă oricum cadrul lung); tranziția le
# ia din lista asta câte una pe cadru.
func _noduri_decor() -> Array:
	var out := []
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return out
	var parent := player.get_parent()
	if parent == null:
		return out
	for n in WORLD_NODES:
		var nd := parent.get_node_or_null(n)
		if nd != null:
			out.append(nd)
	# potecile stau LÂNGĂ `World`, nu în el (vezi ROOT_NODES)
	var root := parent.get_parent()
	if root != null:
		for n in ROOT_NODES:
			var nd := root.get_node_or_null(n)
			if nd != null:
				out.append(nd)
	return out

func _set_world_enabled(on: bool) -> void:
	for nd in _noduri_decor():
		_toggle_generator(nd, on)

# Oprește\repornește generatoarele de decor. Nu e destul să le ascunzi: hitbox-urile
# ar rămâne și te-ai lovi de copaci invizibili. Deci le și golim de ce au încărcat, iar
# `_loaded` (dicționarul lor de chunk-uri) trebuie golit odată cu ele — altfel, la
# repornire, ar crede că bucățile alea există deja și lumea ar rămâne goală pe veci.
func _toggle_generator(node: Node, on: bool) -> void:
	if node == null:
		return
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if not on:
		for c in node.get_children():
			c.queue_free()
		if node.get("_loaded") != null:
			node.set("_loaded", {})

func _set_spawner_enabled(on: bool) -> void:
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner != null:
		_spawner.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func _mmss(secunde: float) -> String:
	var s := int(ceil(maxf(0.0, secunde)))   # ceil: la intrare scrie 1:00, nu 0:59
	return "%d:%02d" % [s / 60, s % 60]

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
