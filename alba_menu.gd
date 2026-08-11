extends CanvasLayer

# ALBA-NEAGRA („shell game") — interfața omului cu trei pahare din lume (`alba.gd`).
#
# Cum se leagă: apeși E pe el → `alba.gd::invoca()` → `open()` de aici. Jocul se OPREȘTE
# (`get_tree().paused`), exact ca la Level Up sau la cazinou, iar meniul merge mai departe fiindcă
# nodul are `PROCESS_MODE_ALWAYS`.
#
# ---------------------------------------------------------------------------
# REGULILE (cerute de Răzvan pe 2026-08-11)
# ---------------------------------------------------------------------------
# · Bila se pune sub un pahar, o vezi, apoi paharele se amestecă. Ghicești unde e.
# · Se joacă pe RUNDE, tot mai grele: la fiecare rundă sunt mai multe mutări și mai iuți.
# · Premiul crește cu șirul de ghiciri: 2 la rând = Common, 3 = Uncommon, 4 = Rare, 5 = Epic,
#   6 = Legendary. Peste Legendary nu mai există raritate, deci la 6 jocul se închide singur cu
#   premiul în mână (n-ai ce câștiga continuând).
# · Poți să te oprești oricând și să iei premiul de pe treapta la care ai ajuns.
# · Dacă mergi mai departe și GREȘEȘTI: nu primești nimic ȘI dificultatea jocului crește cu 10%
#   (`Difficulty.add_trade_penalty`, același mecanism ca la statuia Ender și la trade-up).
# · Un om se joacă o SINGURĂ dată pe rundă (vezi `alba.gd::consuma`).
#
# ---------------------------------------------------------------------------
# ARTA
# ---------------------------------------------------------------------------
# `harta/Alba Neagra/Alba Neagra Table.png` e o poză cu masa ȘI cele trei pahare desenate pe ea.
# Paharele trebuie să se miște separat, deci `tool_alba_assets.gd` taie din ea:
#   table.png — masa fără pahare (cu petice copiate din masa de lângă ele)
#   cup.png   — un pahar, decupat
# Bila e sfera de XP din joc (`xp/xp1.png`) — ideea lui Răzvan.
# ⚠️ Schimbi poza mare → rulezi unealta din nou ȘI remăsori constantele de geometrie de mai jos.

const TABLE_TEX := "res://harta/Alba Neagra/table.png"
const CUP_TEX := "res://harta/Alba Neagra/cup.png"
const BALL_TEX := "res://xp/xp1.png"

# --- GEOMETRIA, în pixelii pozei mari (1672×940) ---
# Cifrele sunt cele scoase de unealtă (casetele paharelor), nu ghicite: paharele stau la
# x = 396…642, 711…961, 1032…1277, cu vârful la y = 152.
const TABLE_W := 1672.0
const TABLE_H := 940.0
const SLOT_X := [519.0, 836.0, 1154.0]   # centrele celor trei locuri de pe masă
const CUP_Y := 276.0                     # centrul unui pahar așezat pe masă
const CUP_W := 250.0
const CUP_H := 247.0
# ⚠️ Bila a fost mărită după prima poză (era 104): ieșea cât o boabă de mazăre pe o masă de un
# ecran. Ridicarea, în schimb, NU poate trece de 152: un pahar ridicat mai sus și-ar scoate vârful
# afară din poza mesei (CUP_Y − RIDICARE − CUP_H/2 ≥ 0) și ar ajunge peste titlu. Încercarea cu
# 230 chiar asta a făcut — paharul plutea peste „WATCH THE CUPS".
const RIDICARE := 150.0                  # cât se ridică un pahar ca să se vadă dedesubt
const ARC := 120.0                       # cât de sus trece paharul care sare peste celălalt
const BILA_D := 150.0                    # cât de mare e bila pe masă
const BILA_Y := CUP_Y + CUP_H * 0.5 - BILA_D * 0.5 + 6.0   # așezată pe masă, la talpa paharului

# --- CÂT DE GREU E ---
# Runda 1 are `MUTARI_BAZA` schimburi, fiecare de `DURATA_START` secunde. La fiecare rundă se
# adaugă `MUTARI_PE_RUNDA` schimburi și fiecare devine cu `DURATA_PAS` mai scurt, până la
# `DURATA_MIN`. Runda 6: 14 schimburi × 0,17s ≈ 2,4 secunde de învârteală.
const MUTARI_BAZA := 4
const MUTARI_PE_RUNDA := 2
const DURATA_START := 0.42
const DURATA_PAS := 0.05
const DURATA_MIN := 0.17

# Ce câștigi pentru un șir de N ghiciri. Sub 2 nu primești nimic.
const PREMII := {2: "common", 3: "uncommon", 4: "rare", 5: "epic", 6: "legendary"}
const SIR_MAXIM := 6
const PEDEAPSA := 0.10        # +10% dificultate dacă pierzi

# --- rama de meniu (aceeași planșă și aceleași culori ca la cazinou / meniu / level up) ---
const SHEET := "res://harta/EGT/Border EGT.png"
const CELULA := 64
const ZOOM := 2
const CH_PANOU := Vector2i(2, 0)
const ACCENT := Color8(198, 118, 80)
const ACCENT_CLAR := Color8(222, 152, 116)
const ACCENT_STINS := Color8(116, 62, 42)
const OS_ALB := Color8(232, 224, 214)
const CENUSA := Color8(150, 142, 138)
const BTN_MAIN := Color8(26, 22, 28)

# ---------------------------------------------------------------------------
var _stare := "intro"      # intro | amesteca | alege | castigat | gata
var _runda := 0
var _sir := 0              # câte ghiciri la rând
var _bila_cup := 0         # care pahar are bila
var _slot := [0, 1, 2]     # pe ce loc de pe masă stă fiecare pahar
var _cup_x := [SLOT_X[0], SLOT_X[1], SLOT_X[2]]   # poziția lui ACUM (pixeli de poză)
var _cup_y := [CUP_Y, CUP_Y, CUP_Y]
var _npc: Node = null      # omul din lume care a deschis meniul

var _masa: TextureRect
var _cupe := []            # TextureRect × 3
var _bila: TextureRect
var _zone := []            # butoanele transparente de peste cele trei locuri
var _lbl_runda: Label
var _lbl_stare: Label
var _lbl_risc: Label
var _trepte := []          # cele 5 chenare din scara de premii
var _btn_joaca: Button
var _btn_ia: Button
var _btn_pleaca: Button
var _premiu_box: HBoxContainer
var _premiu_icon: TextureRect
var _premiu_nume: Label
var _sheet_img: Image = null

func _ready() -> void:
	add_to_group("alba_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12                # peste HUD și Level Up (10), sub meniul de pauză (15)
	visible = false

	var overlay := ColorRect.new()
	# aproape opac, ca la cazinou: masa e deschisă la culoare și orice se mișcă în spate fură ochiul
	overlay.color = Color(0.07, 0.06, 0.09, 0.985)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build()

# ---------------------------------------------------------------------------
# DESCHIDERE / ÎNCHIDERE
# ---------------------------------------------------------------------------
func open(npc: Node = null) -> void:
	if visible:
		return
	_npc = npc
	visible = true
	_runda = 0
	_sir = 0
	_stare = "intro"
	_reseteaza_masa()
	_actualizeaza()
	get_tree().paused = true
	Audio.pause_forest_ambient()
	Audio.play("levelup", -4.0, 0.0)

func _inchide() -> void:
	if _stare == "amesteca":
		return                # nu pleca din mijlocul amestecului
	# Ai un premiu câștigat și pleci? Îl iei — ar fi crud să pierzi un Legendary dintr-un ESC.
	if _stare == "castigat" and PREMII.has(_sir):
		_ia_premiul()
		return
	visible = false
	get_tree().paused = false
	Audio.resume_forest_ambient()

# ⚠️ Ca să nu se deschidă meniul de pauză PESTE noi, `pause.gd::_blocked()` întreabă și de grupul
# „alba_menu".
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_inchide()

# ---------------------------------------------------------------------------
# INTERFAȚA
# ---------------------------------------------------------------------------
func _build() -> void:
	var panel := _cadru(CH_PANOU, 16)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 18
	panel.offset_top = 14
	panel.offset_right = -18
	panel.offset_bottom = -14
	add_child(panel)

	# --- capul paginii ---
	var sus := VBoxContainer.new()
	sus.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sus.offset_left = 40
	sus.offset_right = -40
	sus.offset_top = 30
	sus.add_theme_constant_override("separation", 2)
	sus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sus)

	var titlu := Label.new()
	titlu.text = "ALBA NEAGRA"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.add_theme_font_size_override("font_size", 42)
	titlu.add_theme_color_override("font_color", OS_ALB)
	titlu.add_theme_color_override("font_outline_color", ACCENT_STINS)
	titlu.add_theme_constant_override("outline_size", 6)
	sus.add_child(titlu)

	sus.add_child(_linie(320.0, 10))

	# scara de premii: 2 → Common … 6 → Legendary. Se vede dintr-o privire cât mai ai de mers.
	var scara := HBoxContainer.new()
	scara.alignment = BoxContainer.ALIGNMENT_CENTER
	scara.add_theme_constant_override("separation", 10)
	scara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus.add_child(scara)
	_trepte.clear()
	for n in range(2, SIR_MAXIM + 1):
		scara.add_child(_treapta(n))

	var jos_cap := HBoxContainer.new()
	jos_cap.alignment = BoxContainer.ALIGNMENT_CENTER
	jos_cap.add_theme_constant_override("separation", 18)
	jos_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus.add_child(jos_cap)

	_lbl_runda = Label.new()
	_lbl_runda.add_theme_font_size_override("font_size", 17)
	_lbl_runda.add_theme_color_override("font_color", ACCENT)
	_contur(_lbl_runda)
	jos_cap.add_child(_lbl_runda)

	_lbl_stare = Label.new()
	_lbl_stare.add_theme_font_size_override("font_size", 17)
	_lbl_stare.add_theme_color_override("font_color", OS_ALB)
	_contur(_lbl_stare)
	jos_cap.add_child(_lbl_stare)

	# --- masa cu paharele ---
	_masa = TextureRect.new()
	_masa.texture = load(TABLE_TEX)
	_masa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_masa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_masa.stretch_mode = TextureRect.STRETCH_SCALE
	_masa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_masa)

	# bila stă SUB pahare în ordinea de desenare, ca paharul s-o acopere când coboară peste ea
	_bila = TextureRect.new()
	_bila.texture = load(BALL_TEX)
	_bila.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bila.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bila.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bila.visible = false
	_masa.add_child(_bila)

	_cupe.clear()
	for i in 3:
		var c := TextureRect.new()
		c.texture = load(CUP_TEX)
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_masa.add_child(c)
		_cupe.append(c)

	# Zonele de click sunt fixe, peste cele trei LOCURI de pe masă — nu peste pahare. Așa e și în
	# realitate (arăți cu degetul un loc, nu un obiect care fuge), iar butoanele nu trebuie mutate
	# la fiecare cadru de animație.
	_zone.clear()
	for i in 3:
		var b := Button.new()
		b.flat = true
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _lumina(0.14))
		b.add_theme_stylebox_override("pressed", _lumina(0.22))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_alege.bind(i))
		_masa.add_child(b)
		_zone.append(b)

	# --- josul paginii ---
	var jos := VBoxContainer.new()
	jos.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	jos.offset_left = 40
	jos.offset_right = -40
	jos.offset_top = -132
	jos.offset_bottom = -26
	jos.alignment = BoxContainer.ALIGNMENT_END
	jos.add_theme_constant_override("separation", 6)
	panel.add_child(jos)

	# premiul câștigat (iconița + numele), apare la final
	_premiu_box = HBoxContainer.new()
	_premiu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_premiu_box.add_theme_constant_override("separation", 12)
	_premiu_box.visible = false
	_premiu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jos.add_child(_premiu_box)

	_premiu_icon = TextureRect.new()
	_premiu_icon.custom_minimum_size = Vector2(52, 52)
	_premiu_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_premiu_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_premiu_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_premiu_box.add_child(_premiu_icon)

	_premiu_nume = Label.new()
	_premiu_nume.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_premiu_nume.add_theme_font_size_override("font_size", 22)
	_premiu_nume.add_theme_color_override("font_color", OS_ALB)
	_contur(_premiu_nume)
	_premiu_box.add_child(_premiu_nume)

	_lbl_risc = Label.new()
	_lbl_risc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_risc.add_theme_font_size_override("font_size", 14)
	_lbl_risc.add_theme_color_override("font_color", CENUSA)
	_contur(_lbl_risc)
	jos.add_child(_lbl_risc)

	var butoane := HBoxContainer.new()
	butoane.alignment = BoxContainer.ALIGNMENT_CENTER
	butoane.add_theme_constant_override("separation", 14)
	jos.add_child(butoane)

	_btn_joaca = _buton("PLAY", _joaca)
	butoane.add_child(_btn_joaca)
	# textul lui se scrie în `_actualizeaza` („TAKE COMMON", „TAKE EPIC"…), deci pornește gol
	_btn_ia = _buton("", _ia_premiul)
	butoane.add_child(_btn_ia)
	_btn_pleaca = _buton("Leave", _inchide)
	butoane.add_child(_btn_pleaca)

	get_viewport().size_changed.connect(_relayout)

# O treaptă din scara de premii: „3" + numele rarității, în culoarea ei.
func _treapta(n: int) -> Control:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.border_color = Color(ACCENT_STINS.r, ACCENT_STINS.g, ACCENT_STINS.b, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 7)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)

	var nr := Label.new()
	nr.text = str(n)
	nr.add_theme_font_size_override("font_size", 16)
	nr.add_theme_color_override("font_color", OS_ALB)
	_contur(nr)
	hb.add_child(nr)

	var rar := Label.new()
	var info := _info_raritate(String(PREMII[n]))
	rar.text = String(info["nume"])
	rar.add_theme_font_size_override("font_size", 15)
	rar.add_theme_color_override("font_color", (info["color"] as Color).lerp(Color.WHITE, 0.25))
	_contur(rar)
	hb.add_child(rar)

	_trepte.append({"box": pc, "sb": sb, "n": n})
	return pc

# Numele și culoarea unei rarități, luate din `levelup.gd` (singurul loc unde trăiesc).
func _info_raritate(rar: String) -> Dictionary:
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if lu != null:
		return lu.RARITIES.get(rar, lu.RARITIES["common"])
	return {"nume": rar, "color": Color(1, 1, 1)}

# ---------------------------------------------------------------------------
# JOCUL
# ---------------------------------------------------------------------------
func _joaca() -> void:
	if _stare == "amesteca":
		return
	# Omul se consumă la PRIMA rundă, nu la deschiderea meniului: dacă doar te uiți și pleci,
	# rămâne întreg (vezi `alba.gd::consuma`).
	if _runda == 0 and _npc != null and is_instance_valid(_npc) and _npc.has_method("consuma"):
		_npc.consuma()
	_runda += 1
	_stare = "amesteca"
	_premiu_box.visible = false
	_reseteaza_masa()
	_actualizeaza()

	# bila sub un pahar la întâmplare — trasă CINSTIT, înainte de orice animație (ca numărul de la
	# ruletă din `casino.gd`): amestecul de deasupra e doar spectacol.
	_bila_cup = randi() % 3
	_bila.visible = true

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # jocul e pe pauză, animația trebuie să meargă
	# 1. ridică paharul cu bila, ca s-o vezi
	tw.tween_method(_set_cup_y.bind(_bila_cup), CUP_Y, CUP_Y - RIDICARE, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.75)
	tw.tween_method(_set_cup_y.bind(_bila_cup), CUP_Y - RIDICARE, CUP_Y, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _bila.visible = false)
	tw.tween_interval(0.25)
	# 2. amestecul
	var dur := maxf(DURATA_MIN, DURATA_START - DURATA_PAS * float(_runda - 1))
	var cate := MUTARI_BAZA + MUTARI_PE_RUNDA * (_runda - 1)
	# ⚠️ Tot amestecul se CONSTRUIEȘTE acum, dintr-o bucată, dar se JOACĂ pe parcurs — deci aici
	# `_slot` e încă starea de la început și nu putem citi din el pozițiile schimbului al cincilea.
	# De aia ținem o copie „simulată" care înaintează odată cu construcția; la rulare, `_schimba`
	# face aceleași mutări, în aceeași ordine, pe `_slot`-ul adevărat.
	var sim := [0, 1, 2]
	for i in cate:
		var a := randi() % 3
		var b := (a + 1 + randi() % 2) % 3      # oricare altul
		var xa: float = SLOT_X[sim[a]]
		var xb: float = SLOT_X[sim[b]]
		var t: int = sim[a]
		sim[a] = sim[b]
		sim[b] = t
		tw.tween_callback(_schimba.bind(a, b))
		tw.tween_method(_muta_pereche.bind(a, b, xa, xb, ARC if i % 2 == 0 else 0.0), 0.0, 1.0, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_gata_amestecul)

# Schimbă LOGIC locurile celor două pahare. Animația care urmează doar arată mișcarea.
# ⚠️ Se cheamă ÎNAINTE de mișcare, iar `_muta_pereche` primește pozițiile de plecare ca argumente
# — dacă le-ar citi din `_slot` în timpul mișcării, ar citi deja locurile noi.
func _schimba(a: int, b: int) -> void:
	var t: int = _slot[a]
	_slot[a] = _slot[b]
	_slot[b] = t

# Mișcarea unei perechi, ca funcție de timp (0 → 1): unul trece pe deasupra (arc), celălalt drept.
func _muta_pereche(t: float, a: int, b: int, xa: float, xb: float, arc: float) -> void:
	_cup_x[a] = lerpf(xa, xb, t)
	_cup_x[b] = lerpf(xb, xa, t)
	_cup_y[a] = CUP_Y - sin(t * PI) * arc
	_cup_y[b] = CUP_Y

func _gata_amestecul() -> void:
	_stare = "alege"
	_actualizeaza()

# Ai apăsat pe LOCUL `slot` de pe masă.
func _alege(slot: int) -> void:
	if _stare != "alege":
		return
	_stare = "arata"
	var ales := _cup_de_pe_loc(slot)
	var corect: bool = ales == _bila_cup
	Audio.play("button", -6.0, 0.0)

	# ridicăm paharul ales; dacă ai greșit, îl ridicăm și pe cel cu bila, ca să vezi unde era
	_bila.visible = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_cup_y.bind(ales), CUP_Y, CUP_Y - RIDICARE, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not corect:
		tw.tween_interval(0.35)
		tw.tween_method(_set_cup_y.bind(_bila_cup), CUP_Y, CUP_Y - RIDICARE, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_rezultat.bind(corect))

func _rezultat(corect: bool) -> void:
	if corect:
		_sir += 1
		Audio.play("chest_anim", -3.0, 0.0)
		_stare = "castigat"
		# Peste Legendary nu mai e nimic de câștigat, deci nu te lăsăm să continui degeaba.
		if _sir >= SIR_MAXIM:
			_actualizeaza()
			var t := create_tween()
			t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t.tween_interval(0.8)
			t.tween_callback(_ia_premiul)
			return
	else:
		Audio.play("hurt", -2.0, 0.0)
		Difficulty.add_trade_penalty(PEDEAPSA)
		_sir = 0
		_stare = "gata"
	_actualizeaza()

# Iei premiul de pe treapta la care ai ajuns și jocul se termină.
func _ia_premiul() -> void:
	if not PREMII.has(_sir):
		_stare = "gata"
		_actualizeaza()
		return
	var p = get_tree().get_first_node_in_group("player")
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if p == null or lu == null:
		_stare = "gata"
		_actualizeaza()
		return
	var u = lu.item_random_de_raritate(String(PREMII[_sir]))
	if u == null:
		# raritatea e goală (le-ai luat pe toate) — nu te lăsăm cu mâna goală degeaba
		_stare = "gata"
		_actualizeaza()
		return
	lu.da_item(u, p)
	_premiu_icon.texture = load(lu.icon_path(u))
	_premiu_nume.text = String(u["nume"])
	_premiu_box.visible = true
	Audio.play("chest_anim", -2.0, 0.0)
	_stare = "gata"
	_actualizeaza()

func _cup_de_pe_loc(slot: int) -> int:
	for i in 3:
		if _slot[i] == slot:
			return i
	return 0

func _reseteaza_masa() -> void:
	_slot = [0, 1, 2]
	for i in 3:
		_cup_x[i] = SLOT_X[i]
		_cup_y[i] = CUP_Y
	_bila.visible = false
	_relayout()

func _set_cup_y(v: float, i: int) -> void:
	_cup_y[i] = v

# ---------------------------------------------------------------------------
# TEXTELE ȘI BUTOANELE, după stare
# ---------------------------------------------------------------------------
func _actualizeaza() -> void:
	_lbl_runda.text = "" if _runda == 0 else tr("Round %d") % _runda   # tr() explicit: are %d
	match _stare:
		"intro":
			_lbl_stare.text = "Guess which cup hides the ball"
			_lbl_risc.text = tr("Lose and the game gets %d%% harder") % int(round(PEDEAPSA * 100.0))
		"amesteca":
			_lbl_stare.text = "Watch the cups"
			_lbl_risc.text = ""
		"alege":
			_lbl_stare.text = "Where is the ball?"
			_lbl_risc.text = tr("Lose and the game gets %d%% harder") % int(round(PEDEAPSA * 100.0))
		"castigat":
			_lbl_stare.text = "YOU WIN!"
			_lbl_risc.text = "" if PREMII.has(_sir) else "Two in a row for the first prize"
		"gata":
			var pierdut: bool = _sir == 0 and _runda > 0
			_lbl_stare.text = "YOU LOSE" if pierdut else ""
			# ⚠️ Pedeapsa TREBUIE scrisă pe ecran: e singurul lucru care se schimbă în restul rundei
			# și nu se vede nicăieri altundeva. tr() explicit: are %d.
			_lbl_risc.text = tr("The game got %d%% harder") % int(round(PEDEAPSA * 100.0)) if pierdut else ""
	var e_pierdut: bool = _stare == "gata" and _sir == 0 and _runda > 0
	_lbl_stare.add_theme_color_override("font_color",
		Color(0.44, 0.86, 0.44) if _stare == "castigat" else (
		Color(0.92, 0.38, 0.36) if e_pierdut else OS_ALB))
	_lbl_risc.add_theme_color_override("font_color", Color8(206, 74, 60) if e_pierdut else CENUSA)

	_btn_joaca.visible = _stare == "intro" or _stare == "castigat"
	_btn_joaca.text = "PLAY" if _stare == "intro" else "CONTINUE"
	_btn_ia.visible = _stare == "castigat" and PREMII.has(_sir)
	if _btn_ia.visible:
		# Scrie CE iei, nu doar „ia": altfel ar trebui să te uiți în altă parte ca să decizi.
		# ⚠️ `tr()` și pe numele rarității: textul e ASAMBLAT, deci Godot nu-l mai traduce singur.
		_btn_ia.text = tr("TAKE %s") % tr(String(_info_raritate(String(PREMII[_sir]))["nume"])).to_upper()
	_btn_pleaca.visible = _stare != "amesteca"
	for b in _zone:
		b.disabled = _stare != "alege"

	# scara de premii: treapta pe care ai ajuns se aprinde, cele trecute rămân stinse
	for t in _trepte:
		var activa: bool = int(t["n"]) == _sir + 1 and _stare != "gata"
		var luata: bool = int(t["n"]) <= _sir
		var sb: StyleBoxFlat = t["sb"]
		sb.border_color = ACCENT_CLAR if activa else Color(ACCENT_STINS.r, ACCENT_STINS.g, ACCENT_STINS.b, 0.7)
		sb.bg_color = Color(1, 1, 1, 0.10) if luata else Color(1, 1, 1, 0.03)
		(t["box"] as Control).modulate = Color(1, 1, 1) if (activa or luata) else Color(0.78, 0.76, 0.78)

# ---------------------------------------------------------------------------
# AȘEZAREA ÎN PAGINĂ (merge la orice rezoluție)
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if visible:
		_aseaza_paharele()

func _relayout() -> void:
	if _masa == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	# masa stă între capul paginii și butoane, păstrându-și proporțiile
	var zona := Rect2(60.0, vp.y * 0.20, maxf(100.0, vp.x - 120.0), maxf(100.0, vp.y * 0.60))
	var s: float = minf(zona.size.x / TABLE_W, zona.size.y / TABLE_H)
	var dim := Vector2(TABLE_W, TABLE_H) * s
	_masa.position = zona.position + (zona.size - dim) * 0.5
	_masa.size = dim
	_aseaza_paharele()

# Paharele, bila și zonele de click, din pixelii pozei în pixeli de ecran.
func _aseaza_paharele() -> void:
	if _masa == null or _masa.size.x <= 0.0:
		return
	var s: float = _masa.size.x / TABLE_W
	for i in 3:
		var c: TextureRect = _cupe[i]
		c.size = Vector2(CUP_W, CUP_H) * s
		c.position = (Vector2(_cup_x[i], _cup_y[i]) - Vector2(CUP_W, CUP_H) * 0.5) * s
	var d := BILA_D * s
	_bila.size = Vector2(d, d)
	_bila.position = (Vector2(SLOT_X[_slot[_bila_cup]], BILA_Y) - Vector2(BILA_D, BILA_D) * 0.5) * s
	for i in 3:
		var b: Button = _zone[i]
		b.size = Vector2(CUP_W, CUP_H + RIDICARE * 0.5) * s
		b.position = (Vector2(SLOT_X[i], CUP_Y + RIDICARE * 0.25) - Vector2(CUP_W, CUP_H + RIDICARE * 0.5) * 0.5) * s

# ---------------------------------------------------------------------------
# CĂRĂMIZILE DE ASPECT (aceleași ca la `casino.gd` — citește acolo de ce arată așa)
# ---------------------------------------------------------------------------
func _cadru(celula: Vector2i, margine: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _chenar(celula)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = margine * ZOOM
	np.patch_margin_right = margine * ZOOM
	np.patch_margin_top = margine * ZOOM
	np.patch_margin_bottom = margine * ZOOM
	return np

func _chenar(celula: Vector2i) -> ImageTexture:
	if _sheet_img == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet_img = tex.get_image()
	var bucata := _sheet_img.get_region(Rect2i(celula.x * CELULA, celula.y * CELULA, CELULA, CELULA))
	bucata.resize(CELULA * ZOOM, CELULA * ZOOM, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bucata)

func _linie(latime: float, inaltime: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, inaltime)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hb)
	for a in [0.15, 0.55, 0.15]:
		var r := ColorRect.new()
		r.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, a)
		r.custom_minimum_size = Vector2(latime / 3.0, 2)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(r)
	return wrap

func _contur(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)

func _lumina(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(3)
	return sb

func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", OS_ALB)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, ACCENT_STINS))
	b.add_theme_stylebox_override("hover", _sb(Color8(42, 30, 30), ACCENT))
	b.add_theme_stylebox_override("pressed", _sb(Color8(56, 36, 32), ACCENT_CLAR))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if cb.is_valid():
		b.pressed.connect(func(): Audio.play("button", -3.0, 0.0))
		b.pressed.connect(cb)
	return b

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)   # colțuri aproape drepte: pixel art, nu material design
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
