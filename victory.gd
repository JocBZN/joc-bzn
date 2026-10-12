extends CanvasLayer

# Ecranul de VICTORIE: apare după ce l-ai bătut pe SIR JOHN (cerut de Răzvan pe 2026-10-02).
#
#   YOU WIN!
#   ┌ THIS RUN ──────────┐  ┌ YOUR STATS ─────────┐
#   │ timp, nivel, kills, │  │ exact panoul de      │
#   │ cufere, gambles     │  │ level up (stat_lines)│
#   └─────────────────────┘  └──────────────────────┘
#          [ CONTINUE ]   [ MAIN MENU ]
#
# Construit tot din cod, ca `gameover.gd` și `pause.gd`, cu aceeași ramă de aramă și aceleași
# butoane — e al treilea ecran „de sfârșit", trebuie să arate ca frații lui.
#
# 🔑 NU apare în cadrul în care moare Sir John. Moartea lui are o animație de 1,6 s, iar premiul
# (5 niveluri, `final_boss.gd::_premiu_niveluri`) deschide ecranele de Level Up. Dacă victoria ar
# fi sărit peste ele, ai fi ales cele 5 upgrade-uri DUPĂ ce ți-am arătat statusurile — adică ți-am
# fi arătat niște cifre deja vechi. Așa că ecranul ăsta e creat la moartea boss-ului, stă ascuns
# și așteaptă (`_process`) până trece animația ȘI nu mai e niciun Level Up deschis.
#
# CONTINUE  → închide ecranul și runda merge mai departe (poarta castelului te lasă acum să pleci).
# MAIN MENU → runda se încheie ca o rundă câștigată: intră în leaderboard și monedele merg la bancă,
#             exact ce face Game Over-ul. (Pauza → Main Menu NU face asta: acolo abandonezi.)

# Paleta e ACEEAȘI ca în `pause.gd` / `menu.gd` (arama din `Border EGT.png`).
const ACCENT_CLAR := Color8(222, 152, 116)
const ACCENT_STINS := Color8(116, 62, 42)
const BTN_MAIN := Color8(26, 22, 28)
const OS_ALB := Color8(232, 224, 214)
const CENUSA := Color8(170, 160, 150)
const AUR := Color(1.0, 0.82, 0.35)           # același auriu ca pancarta „UNLOCKED" (`unlocks.gd`)
const VERDE := Color(0.44, 0.86, 0.44)        # aceleași verde/roșu ca la ruletă și Alba-Neagra
const ROSU := Color(0.92, 0.38, 0.36)

# --- coregrafia (secunde) ---
const ASTEPTARE := 2.0      # minimul după moartea lui Sir John: animația lui de moarte e 1,6 s
const T_FUNDAL := 0.45      # fundalul se întunecă
const T_PANOU := 0.40       # panoul „pocnește" în ecran
const T_NUMARA := 0.9       # cifrele rundei se numără de la 0 în sus
const T_RAND := 0.035       # pauza dintre rândurile din dreapta, când apar pe rând

# --- SPLASH-ul din colț (cerut de Răzvan pe 2026-10-02: „cum are Minecraft în main menu, gen
# Also Try Terraria") ---
# Rețeta e chiar a lui Minecraft: galben curat cu umbră galben-închis decalată (nu contur),
# înclinat ~20° în sus și „respirând" din mărime, ca o inimă — nu se mișcă din loc, doar pulsează.
# Stă PESTE colțul din dreapta-sus al ramei, nu înăuntru: tocmai faptul că iese din chenar îl
# face să pară lipit deasupra, ca un abțibild.
const SPLASH_TEXT := "More content coming soon"
const SPLASH_GALBEN := Color(1.0, 1.0, 0.0)
const SPLASH_UMBRA := Color(0.25, 0.25, 0.0)
const SPLASH_UNGHI := -20.0       # grade (negativ = urcă spre dreapta)
const SPLASH_PULS := 0.06         # cât crește în vârful pulsului (6%)
const SPLASH_RITM := 2.2          # pulsuri pe secundă
# Centrul lui, măsurat de la colțul din dreapta-sus al panoului (spre stânga și în jos).
# ⚠️ Pus așa încât capătul de jos să treacă FIX pe lângă „!" din YOU WIN! și peste „SIR JOHN HAS
# FALLEN" — prima încercare (-150, 46) tăia subtitlul. Măsurat pe poză, la 1152×648.
const SPLASH_LOC := Vector2(-100, 22)

var _asteapta := false
var _t := 0.0
var _arata := false

var _fundal: ColorRect
var _centru: CenterContainer
var _panou: Control
var _titlu: Label
var _randuri_run: Array = []      # [{"lbl": Label, "tinta": int, "format": Callable}]
var _randuri_stat: Array = []     # Control-urile din dreapta, ca să apară pe rând
var _btn_continua: Button
var _splash: Label
var _t_splash := 0.0

func _ready() -> void:
	add_to_group("victory_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 16      # peste pauză (15) și Level Up (10), sub Game Over (20)
	visible = false

# Chemată de `final_boss.gd::_die`. Doar pornește așteptarea — vezi comentariul de sus.
func porneste() -> void:
	_asteapta = true
	_t = 0.0

func _process(delta: float) -> void:
	if _splash != null and _splash.visible:
		_pulseaza_splash(delta)
	if not _asteapta:
		return
	var p := get_tree().get_first_node_in_group("player")
	# ai murit între timp (o undă rămasă, o săgeată) → nu mai e nicio victorie de arătat
	if p == null or p.get("dead") == true:
		queue_free()
		return
	_t += delta
	if _t < ASTEPTARE or get_tree().paused:
		return   # Level Up-ul de la premiu (sau alt meniu) ține jocul pe pauză: așteptăm să se închidă
	_asteapta = false
	_arata_ecranul(p)

# ---------- construcția ----------
func _arata_ecranul(p: Node) -> void:
	_construieste(p)
	visible = true
	_arata = true
	get_tree().paused = true
	Audio.pause_all()
	Gamepad.opreste_vibratia()
	Audio.play("chest_anim", -2.0, 0.0)
	Audio.play("levelup", -4.0, 0.0)
	_intrarea()

func _construieste(p: Node) -> void:
	_fundal = ColorRect.new()
	_fundal.color = Color(0.04, 0.03, 0.05, 0.0)
	_fundal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fundal)

	_centru = CenterContainer.new()
	_centru.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_centru)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panou = _rama(box)
	_centru.add_child(_panou)

	_titlu = Label.new()
	_titlu.text = "YOU WIN!"
	_titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titlu.add_theme_font_size_override("font_size", 56)
	_titlu.add_theme_color_override("font_color", AUR)
	_titlu.add_theme_color_override("font_outline_color", ACCENT_STINS)
	_titlu.add_theme_constant_override("outline_size", 8)
	box.add_child(_titlu)

	var sub := _eticheta("Sir John has fallen", 18, CENUSA)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	# CHALLENGE-UL rundei (2026-10-12): Sir John bătut = challenge terminat → bifa din CHOOSE MODE.
	# Se bifează AICI, la apariția ecranului, nu la MAIN MENU: CONTINUE e tot o rundă câștigată.
	if not Challenges.normal():
		Challenges.marcheaza_terminat()
		var ch := _eticheta(tr("Challenge complete: %s") % tr(Challenges.nume(Challenges.activ)), 20, VERDE)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(ch)
	box.add_child(_spatiu(12))

	var coloane := HBoxContainer.new()
	coloane.add_theme_constant_override("separation", 40)
	coloane.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(coloane)
	coloane.add_child(_coloana_runda(p))
	var linie := ColorRect.new()
	linie.color = ACCENT_STINS
	linie.custom_minimum_size = Vector2(2, 0)
	coloane.add_child(linie)
	coloane.add_child(_coloana_statusuri(p))

	box.add_child(_spatiu(18))
	var butoane := HBoxContainer.new()
	butoane.add_theme_constant_override("separation", 24)
	butoane.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(butoane)
	_btn_continua = _buton("CONTINUE", _on_continua)
	Gamepad.primul(_btn_continua)
	butoane.add_child(_btn_continua)
	butoane.add_child(_buton("Main Menu", _on_meniu))

	# Splash-ul e frate cu panoul, NU copil: `PanelContainer` și-ar fi așezat singur copilul în
	# chenar (și l-ar fi întins). Adăugat după `_centru`, deci se desenează deasupra ramei.
	_splash = Label.new()
	_splash.text = SPLASH_TEXT
	_splash.add_theme_font_size_override("font_size", 18)
	_splash.add_theme_color_override("font_color", SPLASH_GALBEN)
	_splash.add_theme_color_override("font_shadow_color", SPLASH_UMBRA)
	_splash.add_theme_constant_override("shadow_offset_x", 3)
	_splash.add_theme_constant_override("shadow_offset_y", 3)
	_splash.rotation_degrees = SPLASH_UNGHI
	_splash.visible = false
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_splash)

# Stânga: ce ai FĂCUT în runda asta. Cifrele pornesc de la 0 și se numără (`_intrarea`).
func _coloana_runda(p: Node) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(280, 0)
	col.add_child(_cap("THIS RUN"))
	var secunde := int(Difficulty.time)
	_rand_run(col, "Time", secunde, _fmt_timp, OS_ALB)
	_rand_run(col, "Level", int(p.get("level")), _fmt_nr, OS_ALB)
	_rand_run(col, "Enemies killed", GameSettings.run_kills, _fmt_nr, OS_ALB)
	_rand_run(col, "Chests opened", GameSettings.run_chests, _fmt_nr, OS_ALB)
	_rand_run(col, "Successful gambles", GameSettings.run_gambles_won, _fmt_nr, VERDE)
	_rand_run(col, "Lost gambles", GameSettings.run_gambles_lost, _fmt_nr, ROSU)
	return col

func _fmt_nr(v: int) -> String:
	return str(v)

func _fmt_timp(v: int) -> String:
	return "%d:%02d" % [v / 60, v % 60]

func _rand_run(col: Control, nume: String, tinta: int, format: Callable, culoare: Color) -> void:
	var r := HBoxContainer.new()
	r.add_child(_eticheta(nume, 20, CENUSA))
	var gol := Control.new()
	gol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(gol)
	var v := _eticheta(format.call(0), 22, culoare)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # cifre, nu text
	r.add_child(v)
	col.add_child(r)
	_randuri_run.append({"lbl": v, "tinta": tinta, "format": format})

# Dreapta: statusurile de ACUM, citite din `player.gd::stat_lines()` — exact panoul de la Level Up,
# cu aceleași cifre și aceleași culori (verde = mai bun decât la start, roșu = mai prost). Nu le
# scriem a doua oară aici: un status nou adăugat în `stat_lines` apare singur și pe ecranul ăsta.
func _coloana_statusuri(p: Node) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.custom_minimum_size = Vector2(260, 0)
	col.add_child(_cap("YOUR STATS"))
	var linii: Array = p.stat_lines() if p.has_method("stat_lines") else []
	for s in linii:
		var r := HBoxContainer.new()
		r.add_child(_eticheta(String(s["label"]), 17, CENUSA))
		var gol := Control.new()
		gol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(gol)
		var stare := String(s.get("state", "same"))
		var c := VERDE if stare == "up" else (ROSU if stare == "down" else OS_ALB)
		var v := _eticheta(String(s["value"]), 17, c)
		v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # cifre, nu text
		r.add_child(v)
		col.add_child(r)
		_randuri_stat.append(r)
	return col

# ---------- animația de intrare ----------
func _intrarea() -> void:
	# fundalul
	create_tween().tween_property(_fundal, "color:a", 0.86, T_FUNDAL)

	# panoul: apare din 92% cu o mică depășire (BACK), ca o carte trântită pe masă
	_panou.modulate.a = 0.0
	await get_tree().process_frame   # o dată așezat de container, ca pivotul să fie centrul real
	_panou.pivot_offset = _panou.size * 0.5
	_panou.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panou, "modulate:a", 1.0, T_PANOU * 0.6)
	tw.tween_property(_panou, "scale", Vector2.ONE, T_PANOU).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# titlul „bate" o dată, după ce s-a așezat panoul
	await get_tree().process_frame
	_titlu.pivot_offset = _titlu.size * 0.5
	var tt := create_tween()
	tt.tween_interval(T_PANOU * 0.7)
	tt.tween_property(_titlu, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_SINE)
	tt.tween_property(_titlu, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)

	# rândurile din dreapta apar pe rând
	for i in _randuri_stat.size():
		var r: Control = _randuri_stat[i]
		r.modulate.a = 0.0
		var tr_ := create_tween()
		tr_.tween_interval(T_PANOU * 0.5 + i * T_RAND)
		tr_.tween_property(r, "modulate:a", 1.0, 0.18)

	# cifrele rundei se numără de la 0
	for d in _randuri_run:
		var tn := create_tween()
		tn.tween_interval(T_PANOU * 0.5)
		tn.tween_method(_scrie_cifra.bind(d), 0.0, float(d["tinta"]), T_NUMARA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# splash-ul se lipește ULTIMUL, după ce s-a așezat panoul: apare din nimic, cu o depășire
	_aseaza_splash()
	_splash.scale = Vector2.ZERO
	_splash.visible = true
	_t_splash = 0.0
	var ts := create_tween()
	ts.tween_interval(T_PANOU + 0.15)
	ts.tween_property(_splash, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Centrul lui pe colțul din dreapta-sus al panoului, cu `pivot_offset` în mijlocul textului — așa
# și rotația, și pulsul se fac în jurul centrului, nu al colțului din stânga-sus al etichetei.
# Lungimea textului diferă de la limbă la limbă, de-aia se măsoară, nu se scrie de mână.
func _aseaza_splash() -> void:
	var m := _splash.get_minimum_size()
	_splash.size = m
	_splash.pivot_offset = m * 0.5
	var colt := _panou.global_position + Vector2(_panou.size.x, 0.0)
	_splash.position = colt + SPLASH_LOC - m * 0.5

# „Respiră" ca splash-ul din Minecraft: |sin| dă un puls scurt și sec, nu o undă moale.
# Pornește abia după ce s-a terminat apariția (tween-ul de mai sus ține scara până atunci).
func _pulseaza_splash(delta: float) -> void:
	_t_splash += delta
	if _t_splash < T_PANOU + 0.5:
		return
	var s := 1.0 + SPLASH_PULS * absf(sin(_t_splash * PI * SPLASH_RITM * 0.5))
	_splash.scale = Vector2(s, s)

func _scrie_cifra(v: float, d: Dictionary) -> void:
	var f: Callable = d["format"]
	(d["lbl"] as Label).text = f.call(int(round(v)))

# ---------- butoanele ----------
func _on_continua() -> void:
	visible = false
	get_tree().paused = false
	Audio.resume_all()
	queue_free()

func _on_meniu() -> void:
	# runda se încheie CÂȘTIGATĂ: leaderboard + monede la bancă, exact ca la Game Over
	var p := get_tree().get_first_node_in_group("player")
	var nivel: int = int(p.get("level")) if p != null else 1
	GameSettings.add_score(Difficulty.time, nivel, GameSettings.run_kills)
	GameSettings.bank_run_coins()
	get_tree().paused = false
	Audio.resume_all()
	get_tree().change_scene_to_file("res://menu.tscn")

# ---------- ajutoare (aceleași ca în `pause.gd`) ----------
const SHEET := "res://harta/EGT/Border EGT.png"
const CELULA_FOAIE := 64
const ZOOM := 2
const RAMA_MARG := 16 * ZOOM
var _sheet: Image = null

func _rama(continut: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = _chenar(Vector2i(2, 0))
	sb.texture_margin_left = RAMA_MARG
	sb.texture_margin_right = RAMA_MARG
	sb.texture_margin_top = RAMA_MARG
	sb.texture_margin_bottom = RAMA_MARG
	sb.content_margin_left = 50
	sb.content_margin_right = 50
	sb.content_margin_top = 28
	sb.content_margin_bottom = 30
	p.add_theme_stylebox_override("panel", sb)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(continut)
	return p

func _chenar(celula: Vector2i) -> ImageTexture:
	if _sheet == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet = tex.get_image()
	var bucata := _sheet.get_region(Rect2i(celula.x * CELULA_FOAIE, celula.y * CELULA_FOAIE, CELULA_FOAIE, CELULA_FOAIE))
	bucata.resize(CELULA_FOAIE * ZOOM, CELULA_FOAIE * ZOOM, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bucata)

func _cap(text: String) -> Control:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 4)
	var l := _eticheta(text, 20, ACCENT_CLAR)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	c.add_child(l)
	var linie := ColorRect.new()
	linie.color = ACCENT_STINS
	linie.custom_minimum_size = Vector2(0, 2)
	c.add_child(linie)
	c.add_child(_spatiu(2))
	return c

func _eticheta(text: String, dim: int, culoare: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", culoare)
	return l

func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.90, 0.86, 0.82))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, ACCENT_STINS, 3))
	b.add_theme_stylebox_override("hover", _sb(Color8(50, 36, 36), Color8(198, 118, 80), 3))
	b.add_theme_stylebox_override("pressed", _sb(Color8(64, 42, 36), ACCENT_CLAR, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("button", -3.0, 0.0))
	b.pressed.connect(cb)
	return b

func _sb(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _spatiu(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
