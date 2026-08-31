extends Node

# UNEALTĂ DE PROFILARE — CAZUL GREU, CU ABLAȚII (se rulează ca SCENĂ):
#
#   godot --path <proiect> res://tool_profil_greu.tscn
#
# `tool_profil_lung.gd` a arătat CE NU e: nu e o scurgere. De la 3:00 la 11:00 totul e plat —
# noduri ~3000, orfani 0, memorie aproape neclintită — fiindcă inamicii ating plafonul de 300
# la minutul 3 și rămân acolo. Deci costul e AL DENSITĂȚII, nu al vechimii rundei.
#
# Rămâne întrebarea „cine plătește?". Aici o măsurăm prin ABLAȚIE: aceeași lume, și tăiem pe
# rând câte un sistem. Diferența față de scenariul de bază E costul acelui sistem — singura
# metodă cinstită, fiindcă un profiler pe funcții nu se poate porni din linia de comandă.
#
# PARTEA A — curba pe numărul de inamici (0 → 300). Spune cât costă UN inamic în plus, și cât
#            costă lumea chiar dacă n-ar fi niciunul (ordonata la origine).
# PARTEA B — ablații la 300 de inamici: cine mănâncă acel „chiar dacă n-ar fi niciunul".
#
# ⚠️ VSYNC SCOS. Cu el, tot ce e sub 7 ms arată identic (143 fps) și nu se vede cât rezervă mai
# ai. Fără el se vede prețul adevărat al fiecărui cadru.
#
# ⚠️ Numărul de inamici e ȚINUT FIX în fiecare cadru (`_completeaza`), și în sus și în jos.
# Fără asta, un scenariu în care player-ul omoară mai repede ar avea mai puțini inamici decât
# altul, iar comparația ar măsura tocmai diferența pe care încercăm s-o eliminăm.
#
# ⚠️ Nu ne uităm doar la media pe cadru: laggul se SIMTE pe cadrele lungi. De-aia se tipărește și
# ce procent din cadre trec de 16.7 ms (sub 60 fps) și de 33 ms (o smucitură vizibilă).
#
# ⚠️ Player NEMURITOR — moartea scrie în `user://scores.save`.

const MINUT := 9.0 * 60.0
const INCALZIRE := 2.5     # secunde de lăsat lumea să se așeze înainte de fiecare măsurătoare
const MASURA := 6.0        # secunde de măsurat per scenariu

# Un build de minutul 9 pus cu mâna, nu tras la sorți: exact itemele care COSTĂ pe cadru.
# cocaina/stroh/foite = attack speed (mai multe atacuri → mai multe treceri prin gloată);
# gloante_paralele/stacked_armory = mai multe proiectile; firewalker/frostwalker = dâre care
# scanează gloata la fiecare 0.4 s; thunder_god = arcuri; jean_bomb = explozii AOE.
const BUILD := [
	"cocaina", "cocaina", "stroh", "stroh", "foite", "foite", "foite",
	"gloante_paralele", "gloante_paralele", "stacked_armory",
	"strapungere", "strapungere", "critic", "critic", "critic",
	"jean_bomb", "thunder_god", "firewalker", "frostwalker",
	"pufferfish", "glont_mare", "seringa", "seringa", "vodca", "bere",
]

var _player: Node2D = null
var _spawner: Node = null
var _main: Node = null
var _tinta := 300
var _rezultate := []
var _forteaza_acelasi_cadru := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(0.8).timeout

	_player = get_tree().get_first_node_in_group("player") as Node2D
	_spawner = _main.get_node_or_null("Spawner")
	if _player == null or _spawner == null:
		print("LIPSESTE PLAYER SAU SPAWNER")
		get_tree().quit()
		return
	_player.max_hp = 99999999
	_player.hp = _player.max_hp

	var lv := get_tree().get_first_node_in_group("levelup_menu")
	for id in BUILD:
		lv._apply(id, _player)
	# ⚠️ Vsync-ul se stinge DUPĂ ce a pornit `main.tscn`: `game_settings.gd::aplica_grafica()`
	# reașază fereastra și vsync-ul din setările salvate la pornirea scenei, deci orice
	# `window_set_vsync_mode` de dinainte e șters imediat. Prima rulare a ieșit exact 143.9 fps
	# la 0 inamici — adică plafonul ecranului, nu costul real.
	#
	# ⚠️ NU prin `GameSettings.set_vsync(false)`: ăla cheamă `_save()`, adică SCRIE în fișierul
	# real de setări (`user://scores.save`) și i-ar lăsa lui Răzvan v-sync-ul stins după ce
	# unealta a plecat. Punem câmpul direct și chemăm noi DisplayServer-ul: același efect în
	# rulare, zero urme pe disc.
	GameSettings.vsync = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("Build: %d iteme. Arma: %s. Fereastra: %s  vsync: %d" \
		% [BUILD.size(), _player.weapon_type, DisplayServer.window_get_size(), \
			DisplayServer.window_get_vsync_mode()])
	Difficulty.time = MINUT
	Difficulty.frozen = true   # ceasul sta: toate scenariile trebuie sa vada ACEEASI dificultate
	# Spawner-ul propriu e oprit: numarul de inamici il tinem NOI, exact (vezi `_completeaza`).
	if _spawner.timer != null:
		_spawner.timer.stop()

	print("\n--- PARTEA A: cat costa un inamic in plus ---")
	for n in [0, 75, 150, 225, 300]:
		_tinta = n
		await _scenariu("inamici: %d" % n, "nimic")

	print("\n--- PARTEA B: ablatii la 300 de inamici ---")
	_tinta = 300
	await _scenariu("B0. tot pornit (referinta)", "nimic")
	await _scenariu("B1. fara AI de inamic", "ai")
	await _scenariu("B2. fara desenul inamicilor", "desen")
	await _scenariu("B3. fara AI si fara desen", "ai+desen")
	await _scenariu("B4. fara DECOR (copaci/pietre)", "decor")
	await _scenariu("B5. fara HUD", "hud")
	await _scenariu("B6. fara ARMA player-ului", "arma")
	# ⚠️ Doar DIAGNOSTIC, nu o propunere: fără y-sort inamicii calcă peste copaci și peste tine,
	# adâncimea lumii dispare. E aici fiindcă sortarea a 300 de noduri care se mișcă e primul
	# suspect pentru „desenul costă de 3 ori cât AI-ul", iar suspectul se verifică, nu se crede.
	await _scenariu("B7. fara y-sort pe World", "ysort")

	# PARTEA C — straturile care costă pe TOT ecranul, nu pe inamic. Panta din partea A spune că
	# lumea goală costă ~6.4 ms, adică plafonul de 144 Hz (6.94 ms) e atins ÎNAINTE să apară vreun
	# inamic. Astea sunt suspecții: două straturi cât ecranul (glow, vignetă) și podeaua.
	# Se măsoară tot la 300 de inamici, fiindcă acolo suntem sub plafon și diferența se vede.
	print("\n--- PARTEA C: straturile cat tot ecranul (tot la 300 de inamici) ---")
	await _scenariu("C1. fara GLOW", "glow")
	await _scenariu("C2. fara VIGNETA", "vigneta")
	await _scenariu("C3. fara PODEA", "podea")
	await _scenariu("C4. fara glow SI fara vigneta", "glow+vigneta")

	# PARTEA D — de ce fiecare inamic e un draw call separat.
	#
	# La 300 de inamici se numără ~300 de draw call-uri, adică desenatorul NU-i grupează. Bănuiala:
	# `enemy_frames.tres` are 48 de PNG-uri separate (8 direcții × 6 cadre), și încă o dată atâtea
	# pentru fiecare fel de polițist. Doi inamici vecini în sortarea pe Y au aproape sigur alt
	# cadru, deci altă textură, deci lotul se rupe la fiecare.
	#
	# Testul: îi punem pe TOȚI pe aceeași planșă și pe același cadru. Dacă asta e cauza, numărul de
	# draw call-uri se prăbușește și cadrul scade. Dacă nu se schimbă nimic, ipoteza pică și n-are
	# rost să se coacă un atlas.
	#
	# ⚠️ 600 de inamici, nu 300: la 300 cadrul a coborât sub 6.94 ms (plafonul ecranului), și acolo
	# toate scenariile ies la fel. Ne trebuie o încărcare care depășește plafonul ca diferența să
	# aibă unde să se vadă. Nu e o cifră de joc — jocul plafonează la 300 — e o lupă.
	print("\n--- PARTEA D: de ce nu se grupeaza inamicii la desenare (600, ca sa trecem de plafon) ---")
	_tinta = 600
	await _scenariu("D0. 600 inamici, cum e acum", "nimic")
	await _scenariu("D1. 600, toti pe acelasi cadru", "acelasi_cadru")
	await _scenariu("D2. 600, fara desen", "desen")
	# ⚠️ D1 e CONTAMINAT și se citește doar pentru numărul de draw call-uri: reașezarea celor 600
	# de sprite-uri se face în fiecare cadru (altfel `enemy.gd` o desface cu `anim.play`), iar
	# ăla e cost de UNEALTĂ, nu de joc — de-aia D1 iese mai încet deși desenează mai puține loturi.
	# D3/D4 sunt perechea curată: la amândouă AI-ul și arma sunt oprite, deci gloata stă pe loc și
	# nimeni nu moare, reașezarea se face O SINGURĂ DATĂ, și singura diferență rămasă între ele
	# e câte texturi are gloata. Aia e întrebarea.
	await _scenariu("D3. 600 inghetati (referinta curata)", "inghetat")
	await _scenariu("D4. 600 inghetati, o textura", "inghetat+acelasi")

	print("\n=================== BILANT ===================")
	for r in _rezultate:
		print("%-32s cadru %6.2f ms (%6.1f fps)  proces %5.2f  fizica %5.2f  >16.7ms: %4.1f%%" \
			% [r["nume"], r["ms"], 1000.0 / r["ms"], r["proc"], r["fiz"], r["p16"]])
	get_tree().quit()

# Ține gloata exact la `_tinta`: naște ce lipsește, șterge ce e în plus (pe cei mai depărtați
# întâi, ca să nu golim tocmai ecranul).
func _completeaza() -> void:
	var vii := get_tree().get_nodes_in_group("enemy")
	var lipsa := _tinta - vii.size()
	if lipsa > 0:
		for i in mini(lipsa, 25):
			_spawner._spawn_enemy()
		return
	if lipsa >= 0:
		return
	var dupa_distanta := vii.duplicate()
	dupa_distanta.sort_custom(_mai_departe)
	for i in mini(-lipsa, 25):
		(dupa_distanta[i] as Node).queue_free()

# Câți din gloată sunt CHIAR pe ecran. Cifra asta hotărăște dacă merită reciclați cei rămași
# în urmă: dacă din 300 se văd 60, restul de 240 sunt cost curat, fără nimic pe ecran pentru el.
func _pe_ecran() -> int:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return -1
	var jum: Vector2 = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var dreptunghi := Rect2(cam.get_screen_center_position() - jum, jum * 2.0)
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if dreptunghi.has_point((e as Node2D).global_position):
			n += 1
	return n

func _mai_departe(a: Node, b: Node) -> bool:
	var pa := (a as Node2D).global_position.distance_squared_to(_player.global_position)
	var pb := (b as Node2D).global_position.distance_squared_to(_player.global_position)
	return pa > pb

func _scenariu(nume: String, taietura: String) -> void:
	_aplica(taietura, false)
	# încălzire: lăsăm lumea să se așeze după tăietură (dâre care se sting, gloanțe care mor,
	# gloata care ajunge la numărul cerut)
	var t := 0.0
	while t < INCALZIRE:
		t += await _cadru()
	var cadre := 0
	var suma := 0.0
	var peste16 := 0
	var peste33 := 0
	var inamici := 0
	# Cât din cadru e CPU. Contează separat, fiindcă ecranul plafonează cadrul la 144 fps
	# (6.94 ms) și acolo toate scenariile ies la fel — dar `TIME_PROCESS` nu e plafonat de
	# nimic, deci el arată costul chiar și sub plafon.
	var suma_proc := 0.0
	var suma_fiz := 0.0
	t = 0.0
	while t < MASURA:
		var dt := await _cadru()
		t += dt
		cadre += 1
		suma += dt
		suma_proc += Performance.get_monitor(Performance.TIME_PROCESS)
		suma_fiz += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		if dt > 1.0 / 60.0:
			peste16 += 1
		if dt > 1.0 / 30.0:
			peste33 += 1
		inamici += get_tree().get_nodes_in_group("enemy").size()
	_aplica(taietura, true)
	var n := maxi(1, cadre)
	var ms := suma / float(n) * 1000.0
	var p16 := float(peste16) * 100.0 / float(n)
	var p33 := float(peste33) * 100.0 / float(n)
	# Fereastra și draw call-urile se tipăresc la fiecare rând dinadins: dacă toate scenariile ies
	# la aceeași milisecundă, întrebarea e „măsor un cost sau un plafon?", iar astea două o
	# lămuresc pe loc (o fereastră care s-a micșorat pe parcurs face orice comparație o minciună).
	var proc := suma_proc / float(n) * 1000.0
	var fiz := suma_fiz / float(n) * 1000.0
	print("%-32s cadru %6.2f ms (%6.1f fps)  proces %5.2f  fizica %5.2f  >16.7ms: %4.1f%%  (inamici: %d, pe ecran: %d, draw: %d, fereastra: %s)" \
		% [nume, ms, 1000.0 / ms, proc, fiz, p16, inamici / n, _pe_ecran(), \
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), \
			DisplayServer.window_get_size()])
	_rezultate.append({"nume": nume, "ms": ms, "p16": p16, "p33": p33, "proc": proc, "fiz": fiz})

# Un cadru: ține gloata la numărul cerut și plimbă player-ul, apoi întoarce cât a durat.
func _cadru() -> float:
	_completeaza()
	# Se reface în FIECARE cadru: `enemy.gd::_physics_process` cheamă `anim.play(DIRECTII[idx])`
	# de câte ori se schimbă direcția, deci o singură așezare la începutul scenariului s-ar
	# desface imediat.
	if _forteaza_acelasi_cadru:
		_acelasi_cadru()
	var unghi := float(Time.get_ticks_msec()) * 0.0007
	var d := Vector2(cos(unghi), sin(unghi))
	_apasa("move_right", d.x > 0.35)
	_apasa("move_left", d.x < -0.35)
	_apasa("move_down", d.y > 0.35)
	_apasa("move_up", d.y < -0.35)
	await get_tree().process_frame
	return get_process_delta_time()

func _apasa(actiune: String, da: bool) -> void:
	if da:
		Input.action_press(actiune)
	else:
		Input.action_release(actiune)

# --- ABLAȚIILE ---
# `pornit = false` taie sistemul, `true` îl pune la loc. Un singur loc pentru amândouă, ca
# tăietura și repunerea să nu se poată despărți.
func _aplica(ce: String, pornit: bool) -> void:
	match ce:
		"ai":
			_enemy_ai(pornit)
		"desen":
			_enemy_desen(pornit)
		"ai+desen":
			_enemy_ai(pornit)
			_enemy_desen(pornit)
		"decor":
			for nume in ["Props", "Rocks", "Bushes", "DesertStructures"]:
				var nod := _main.get_node_or_null("World/" + nume) as CanvasItem
				if nod != null:
					nod.visible = pornit
					nod.set_process(pornit)
		"hud":
			var hud := _main.get_node_or_null("HUD") as CanvasLayer
			if hud != null:
				hud.visible = pornit
		"arma":
			_timer_player("_fire", pornit)
		"ysort":
			var w := _main.get_node_or_null("World") as Node2D
			if w != null:
				w.y_sort_enabled = pornit
		"glow":
			_glow(pornit)
		"vigneta":
			_vigneta(pornit)
		"glow+vigneta":
			_glow(pornit)
			_vigneta(pornit)
		"podea":
			var g := _main.get_node_or_null("Ground") as CanvasItem
			if g != null:
				g.visible = pornit
		"acelasi_cadru":
			_forteaza_acelasi_cadru = not pornit
		"inghetat":
			_enemy_ai(pornit)
			_timer_player("_fire", pornit)
		"inghetat+acelasi":
			_enemy_ai(pornit)
			_timer_player("_fire", pornit)
			if not pornit:
				_acelasi_cadru()   # o singură dată: nimeni nu mai cheamă `anim.play` peste ea

func _glow(pornit: bool) -> void:
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null and atm._env != null:
		atm._env.glow_enabled = pornit and GameSettings.glow

func _vigneta(pornit: bool) -> void:
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null and atm._vignette != null:
		atm._vignette.visible = pornit and GameSettings.vignette

# Toți inamicii pe ACEEAȘI planșă și pe același cadru → o singură textură pentru toată gloata.
# Arată urât (toți merg spre sud, încremeniți), dar nu asta măsurăm: măsurăm dacă desenatorul
# îi poate grupa atunci când textura e comună.
func _acelasi_cadru() -> void:
	var toti := get_tree().get_nodes_in_group("enemy")
	if toti.is_empty():
		return
	var primul := (toti[0] as Node).get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if primul == null:
		return
	var foaie := primul.sprite_frames
	for e in toti:
		var a := (e as Node).get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if a == null:
			continue
		if a.sprite_frames != foaie:
			a.sprite_frames = foaie
		a.animation = &"south"
		a.frame = 0
		a.pause()

func _enemy_ai(pornit: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node).set_physics_process(pornit)

func _enemy_desen(pornit: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		var a := (e as Node).get_node_or_null("AnimatedSprite2D") as CanvasItem
		if a != null:
			a.visible = pornit

# Timer-ele player-ului nu au nume (sunt variabile locale din `_ready`), deci le găsim după
# METODA la care e legat `timeout`. Așa ablația lovește exact sistemul vrut, nu tot ce ticăie.
func _timer_player(metoda: String, pornit: bool) -> void:
	for c in _player.get_children():
		var t := c as Timer
		if t == null:
			continue
		for leg in t.timeout.get_connections():
			var cal: Callable = leg["callable"]
			if cal.get_method() == metoda:
				if pornit:
					t.start()
				else:
					t.stop()
