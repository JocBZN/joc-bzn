extends CanvasLayer

# Ecranul de GAME OVER: apare când mori. Pune jocul pe pauză și arată
# timpul supraviețuit + nivelul atins + un buton de restart.
# Tot UI-ul e construit din cod (fără scenă de desenat).
#
# ⚠️ Din 2026-08-23 nu mai apare DINTR-O DATĂ. Între moarte și text e o cinematică de ~2 secunde:
# un CERC care se închide peste tine (o diafragmă de aparat foto), cu sunetul lipit de fiecare
# fază a ei. Lumea îngheață pe loc (`get_tree().paused`) și rămâne acolo, vizibilă, cât se strânge
# cercul: ultimul lucru pe care îl vezi ești tu, în mijloc, cu tot ce te-a omorât în jur.
#
# Coregrafia, în ordine. Toate cifrele sunt constantele de mai jos, și sunt ACELEAȘI pentru
# imagine și pentru sunet — de-aia se simte ca un singur lucru, nu ca „o animație cu un sunet":
#
#   t=0.00  lovitura   — lumea îngheață, bubuitura joasă (`death_hit`), muzica începe să se
#                        înfunde și ambientul de pădure se stinge. Cercul încă nu s-a mișcat:
#                        primele 0,16 s ești doar înghețat, ca să se audă lovitura singură.
#   t=0.16  înghițirea — cercul mănâncă ecranul repede (CUBIC/EASE_OUT: pornește tare, frânează),
#                        peste mătura care coboară (`death_sweep`) și huruitul care crește.
#   t=0.96  strângerea — se strânge încet în jurul tău. Vizual nu se mai întâmplă mare lucru, dar
#                        huruitul urcă spre vârf: e liniștea dinaintea închiderii.
#   t=1.46  închiderea — se prăbușește la zero în 0,09 s (CUBIC/EASE_IN) și, în cadrul în care
#                        ajunge la zero, cade `death_snap` și muzica tace.
#   t=1.55  tăcerea    — 0,45 s de negru și NIMIC. E cea mai importantă bucată din tot momentul.
#   t=2.00  textul     — stinger-ul de Game Over și textul care apare lin.
#
# Culoarea și lumina se scurg din imagine pe măsură ce cercul se strânge (`stins`, în shader), iar
# marginea lui arde slab, roșu. Nu sunt animate separat: se calculează DIN rază, deci n-au cum să
# iasă din sincron cu ea (vezi `_seteaza_raza`).

const IRIS_SHADER := preload("res://moarte_iris.gdshader")

# --- COREGRAFIA (secunde) ---
const T_LOVITURA := 0.16     # cât stă lumea înghețată înainte să pornească cercul
const T_INGHITIRE := 0.80    # cercul mănâncă ecranul
const T_STRANGERE := 0.50    # se strânge încet în jurul tău
const T_INCHIDERE := 0.09    # prăbușirea la zero
const T_TACERE := 0.45       # negru complet, fără niciun sunet
const T_TEXT := 0.55         # cât durează apariția textului
# Cât ține tot drumul cercului. Muzica se înfundă pe EXACT atât (vezi `Audio.death_muffle`).
const T_CERC := T_LOVITURA + T_INGHITIRE + T_STRANGERE + T_INCHIDERE

# Razele se măsoară în ÎNĂLȚIMI DE ECRAN (0.5 = de la mijloc până la marginea de sus), nu în
# pixeli: așa arată la fel pe orice rezoluție. Raza de pornire se calculează (colțul cel mai
# depărtat de player), ca să nu se vadă negru în primul cadru nici dacă mori într-un colț.
const RAZA_MICA := 0.22      # cât rămâne după înghițire
const RAZA_STRANSA := 0.13   # cât de strâns te ține înainte să se închidă

# --- MIXUL ---
# Fișierele sunt toate normalizate la vârf −1 dBFS (vezi lista din `audio.gd`), deci echilibrul
# dintre straturi e AICI. Se schimbă mixul fără să reexporți niciun sunet.
const DB_HIT := -2.0         # lovitura: cel mai tare lucru din moment, în afară de închidere
const DB_SWEEP := -7.0       # mătura stă SUB lovitură; e mișcare, nu eveniment
const DB_RUMBLE := -9.0      # huruitul se simte mai mult decât se aude (e numai bas)
const DB_SNAP := -1.0        # închiderea: ea trebuie să te facă să tresari
const DB_STINGER := 16.0     # `game_over` e înregistrat foarte încet — vezi `audio.gd`
const MUZICA_STINGERE := 0.18  # cât de repede tace muzica, pe închidere

var time_label: Label
var level_label: Label
var kills_label: Label

var _mat: ShaderMaterial
var _center: CenterContainer
var _raza_start := 1.2       # se recalculează la moarte, din poziția player-ului pe ecran
var _pornit := false         # ca o a doua moarte în același cadru să nu pornească două cinematici

func _ready() -> void:
	add_to_group("gameover_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS  # merge și când jocul e pe pauză
	layer = 20                               # peste tot (inclusiv HUD și level up)
	visible = false

	# Cercul. Ține locul dreptunghiului negru opac de dinainte: acoperă tot ecranul, dar ce
	# desenează depinde de rază — la început nu se vede nimic din el, la sfârșit e negru complet.
	# ⚠️ Se adaugă PRIMUL, ca textul de mai jos să se deseneze peste el. Shader-ul citește ecranul
	# deja desenat, deci vede lumea și HUD-ul, dar nu și textul (care vine după) — exact ce vrem.
	_mat = ShaderMaterial.new()
	_mat.shader = IRIS_SHADER
	var iris := ColorRect.new()
	iris.material = _mat
	iris.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	iris.mouse_filter = Control.MOUSE_FILTER_IGNORE   # altfel ar mânca clicurile butoanelor
	add_child(iris)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.visible = false   # apare abia la capătul cinematicii (vezi `_arata_textul`)
	add_child(_center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_child(box)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.25))
	box.add_child(title)

	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	box.add_child(time_label)

	level_label = Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 24)
	box.add_child(level_label)

	kills_label = Label.new()
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_label.add_theme_font_size_override("font_size", 24)
	box.add_child(kills_label)

	# buton de restart (cu puțin spațiu deasupra)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)

	var btn := Button.new()
	btn.text = "PLAY AGAIN"
	btn.custom_minimum_size = Vector2(240, 60)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_restart)
	box.add_child(btn)

	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.custom_minimum_size = Vector2(240, 50)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(_on_menu)
	box.add_child(menu_btn)

# Chemată de player.die() când rămâi fără viață.
func show_gameover(secunde: float, nivel: int) -> void:
	if _pornit:
		return
	_pornit = true
	var kills := GameSettings.run_kills
	GameSettings.add_score(secunde, nivel, kills)  # salvează în leaderboard
	GameSettings.bank_run_coins()  # bagă monedele din rundă la bancă
	var m := int(secunde) / 60
	var s := int(secunde) % 60
	# tr(...) explicit peste tot unde textul are %d — cu numărul deja pus în el, traducerea
	# automată n-ar mai găsi cheia din i18n.gd
	time_label.text = tr("Survived: %d:%02d") % [m, s]
	# dacă a trecut de cele 10 minute, arătăm separat cât a rezistat în Final Swarm
	if secunde >= Difficulty.RUN_LENGTH:
		var o := int(secunde - Difficulty.RUN_LENGTH)
		time_label.text += tr("   (Final Swarm: +%d:%02d)") % [o / 60, o % 60]
	level_label.text = tr("Level reached: %d") % nivel
	kills_label.text = tr("Kills: %d") % kills

	# ⚠️ Cercul se așază ÎNAINTE de `visible = true`: altfel primul cadru s-ar desena cu razele
	# rămase de la moartea trecută (sau cu cele implicite din shader) și ar clipi negru.
	_aseaza_cercul()
	_center.visible = false
	visible = true
	get_tree().paused = true   # lumea îngheață aici și rămâne așa, sub cerc
	_cinematica()

# Pune cercul peste player și îi dă raza de la care nu se vede nimic negru.
func _aseaza_cercul() -> void:
	var vp := get_viewport().get_visible_rect().size
	var centru := Vector2(0.5, 0.5)
	var pl := get_tree().get_first_node_in_group("player")
	if pl is Node2D and vp.x > 0.0 and vp.y > 0.0:
		# poziția player-ului PE ECRAN (nu în lume): transformarea lui, prin cameră, în pixeli
		centru = pl.get_global_transform_with_canvas().origin / vp
	# dacă ar muri cumva în afara ecranului, cercul tot trebuie să rămână pe undeva pe aproape
	centru.x = clampf(centru.x, -0.25, 1.25)
	centru.y = clampf(centru.y, -0.25, 1.25)
	var raport := Vector2(vp.x / maxf(vp.y, 1.0), 1.0)
	# Raza de pornire = colțul cel mai DEPĂRTAT de player, plus o idee. Se calculează, nu e „2.0
	# și gata": dacă mori într-un colț, colțul opus e la peste 1,2 înălțimi de ecran distanță.
	_raza_start = 0.0
	for colt in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		_raza_start = maxf(_raza_start, ((colt - centru) * raport).length())
	_raza_start += 0.02
	_mat.set_shader_parameter("centru", centru)
	_mat.set_shader_parameter("raport", raport)
	_seteaza_raza(_raza_start)

# Cinematica, într-un SINGUR lanț de tween-uri. Sunetele sunt `tween_callback`-uri în același lanț,
# nu temporizatoare separate: așa n-au cum să alunece față de imagine, oricât ar încetini jocul.
# `death_snap` e pus DUPĂ prăbușire, deci cade în cadrul în care cercul ajunge la zero.
func _cinematica() -> void:
	var tw := create_tween()
	tw.tween_callback(_sunet_lovitura)
	tw.tween_interval(T_LOVITURA)
	tw.tween_callback(_sunet_cerc)
	tw.tween_method(_seteaza_raza, _raza_start, RAZA_MICA, T_INGHITIRE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_seteaza_raza, RAZA_MICA, RAZA_STRANSA, T_STRANGERE).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_seteaza_raza, RAZA_STRANSA, 0.0, T_INCHIDERE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_sunet_inchidere)
	tw.tween_interval(T_TACERE)
	tw.tween_callback(_arata_textul)

# Un pas al animației. Culoarea care se scurge și inelul roșu se calculează DIN rază, nu din timp:
# cât de închis e ecranul urmează exact cât de mic e cercul, în orice fază.
func _seteaza_raza(r: float) -> void:
	_mat.set_shader_parameter("raza", r)
	var p := clampf(1.0 - r / maxf(_raza_start, 0.001), 0.0, 1.0)
	# `pow(p, 1.6)`: culoarea nu se scurge de la prima mișcare a cercului, ci pe măsură ce el chiar
	# se strânge. Liniar, lumea se făcea gri în prima jumătate de secundă și restului nu-i mai
	# rămânea unde să meargă.
	_mat.set_shader_parameter("stins", pow(p, 1.6))
	_mat.set_shader_parameter("rama", clampf(p * 1.3, 0.0, 1.0))

func _sunet_lovitura() -> void:
	Audio.play_ex("death_hit", DB_HIT)
	Audio.death_muffle(T_CERC)        # muzica se duce în spatele ușii, în ritmul cercului
	Audio.fade_out_forest_ambient()   # ...iar pădurea tace de tot

func _sunet_cerc() -> void:
	# `play_ex`, nu `play`: două straturi suprapuse, cu tonul variat aleator, s-ar dezacorda între
	# ele la fiecare moarte (aceeași regulă ca la magnet și la cinematici).
	Audio.play_ex("death_sweep", DB_SWEEP)
	Audio.play_ex("death_rumble", DB_RUMBLE)

func _sunet_inchidere() -> void:
	Audio.play_ex("death_snap", DB_SNAP)
	# Muzica NU se mai stinge lin 3 secunde peste negru, cum făcea înainte: se taie sub bubuitura
	# închiderii, care acoperă tăietura. După ea urmează liniște adevărată — dacă muzica s-ar auzi
	# stingându-se, tăcerea aia n-ar mai exista.
	Audio.stop_music(false, MUZICA_STINGERE)

func _arata_textul() -> void:
	Audio.play_ex("game_over", DB_STINGER)   # ton fix: un stinger nu se dezacordează de la sine
	_center.visible = true
	_center.modulate.a = 0.0
	create_tween().tween_property(_center, "modulate:a", 1.0, T_TEXT).set_trans(Tween.TRANS_SINE)

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")
