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
# ARTA (refăcută pe 2026-08-12, cerută de Răzvan)
# ---------------------------------------------------------------------------
# Meniul arată ACEEAȘI poză cu care omul apare în lume (`Alba Neagra.png`, 128×128), doar mărită
# de `ART_ZOOM` ori — „o variantă zoomed in", cum a cerut-o. Nu mai există o poză separată de masă.
#
# Paharele trebuie să se miște singure, deci `tool_alba_assets.gd` taie din poză:
#   scene.png — omul și masa lui, cu paharele ȘTERSE (peticite din pixelii de lângă ele)
#   cup.png   — UN pahar, 14×16, decupat fix pe conturul lui negru
# Se desenează ACELAȘI pahar (cel din stânga, are silueta întreagă) pe toate cele trei locuri —
# așa a cerut Răzvan: „copiază paharul din stânga și dă copy-paste în celelalte locuri".
# Bila e sfera de XP din joc (`xp/xp1.png`) — ideea lui Răzvan.
#
# ⚠️ Schimbi `Alba Neagra.png` → rulezi unealta din nou ȘI iei cifrele pe care le tipărește
# (SLOT_X, CUP_W, CUP_H, TALPA). Nimic nu te avertizează dacă rămân vechi: paharele pur și simplu
# ajung lângă locul lor.
#
# ⚠️ `ART_ZOOM` trebuie să rămână ÎNTREG. La 3,5 pixelii ies inegali (unii lați de 3, alții de 4)
# și pixel art-ul arată murdar — se vede imediat pe conturul negru al omului.

const SCENE_TEX := "res://harta/Alba Neagra/scene.png"
const CUP_TEX := "res://harta/Alba Neagra/cup.png"
const BALL_TEX := "res://xp/xp1.png"

# --- GEOMETRIA, în pixelii pozei de 128×128 (cifrele vin din `tool_alba_assets.gd`) ---
const ART_CONTINUT := Rect2(18.0, 8.0, 90.0, 116.0)   # unde e desenat efectiv ceva în poză
const SLOT_X := [45.0, 64.0, 83.0]   # centrele celor trei locuri de pe masă
const TALPA := 96.0                  # linia pe care STAU paharele
const CUP_W := 14.0
const CUP_H := 16.0
const CUP_Y := TALPA - CUP_H * 0.5   # centrul unui pahar așezat pe masă
const RIDICARE := 10.0               # cât se ridică un pahar ca să se vadă dedesubt
                                     # ⚠️ Nu mai mult: bila e de 9, deci 10 o descoperă toată, iar
                                     # talpa paharului rămâne pe tăblie. La 16 paharul ajungea cu
                                     # totul în mâinile omului și părea că-l ține în palme, nu că-l
                                     # ridică de pe masă (la 26 urca de tot în pieptul lui).
const ARC := 11.0                    # cât de sus trece paharul care sare peste celălalt
const BILA_D := 9.0
const BILA_Y := TALPA - BILA_D * 0.5 + 0.5

# --- CÂT DE GREU E ---
# Runda 1 are `MUTARI_BAZA` schimburi, fiecare de `DURATA_START` secunde. La fiecare rundă se
# adaugă `MUTARI_PE_RUNDA` schimburi și fiecare devine cu `DURATA_PAS` mai scurt, până la
# `DURATA_MIN`.
#   runda 1:  5 schimburi × 0,36s      runda 4: 14 × 0,24s
#   runda 2:  8 × 0,32s                runda 5: 17 × 0,20s
#   runda 3: 11 × 0,28s                runda 6: 20 × 0,16s ≈ 3,2 secunde de învârteală
#
# Urcate pe 2026-08-12 („fă-l să fie mai greu puțin"): erau 4 + 2 pe rundă, de la 0,42s la 0,17s.
# ⚠️ `DURATA_MIN` sub ~0,12 nu mai face jocul mai greu, îl face IMPOSIBIL: paharele sar dintr-un
# loc în altul fără să apuci să le vezi drumul, deci nu mai ai ce urmări cu ochiul — rămâne
# ghicit din trei. Dacă vrei și mai greu, adaugă schimburi, nu viteză.
const MUTARI_BAZA := 5
const MUTARI_PE_RUNDA := 3
const DURATA_START := 0.36
const DURATA_PAS := 0.04
const DURATA_MIN := 0.14
# Cât stă bila descoperită la început, cât s-o vezi. Scăzut de la 0,75s: era timp de gândit, nu
# de văzut.
const ARATA_BILA := 0.5

# Ce câștigi pentru un șir de N ghiciri. Sub 2 nu primești nimic.
const PREMII := {2: "common", 3: "uncommon", 4: "rare", 5: "epic", 6: "legendary"}
const SIR_MAXIM := 6
const PEDEAPSA := 0.10        # +10% dificultate dacă pierzi

# ---------------------------------------------------------------------------
# ASPECTUL
# ---------------------------------------------------------------------------
# Ramele vin din aceeași planșă ca la cazinou (`Border EGT.png`, 5×4 celule de 64px). Fiecare
# celulă e o ramă întreagă, deci se folosește ca NinePatch: colțurile rămân întregi, laturile se
# întind. Meniul folosește trei celule diferite, ca să nu arate totul la fel:
const SHEET := "res://harta/EGT/Border EGT.png"
const CELULA := 64
const CH_PANOU := Vector2i(2, 0)     # rama mare din jurul ecranului (spirale în colțuri)
const CH_SCENA := Vector2i(3, 2)     # rama scenei (dublă, cu colțuri tăiate) — cea mai bogată
const CH_PANEL := Vector2i(1, 1)     # panourile laterale (dublă, simplă)
const CH_BUTON := Vector2i(1, 3)     # butoanele (subțire, cu bumbi în colțuri)
const CH_PLACA := Vector2i(0, 1)     # plăcuțele din scara de premii (colțuri pătrate)

const ACCENT := Color8(198, 118, 80)
const ACCENT_CLAR := Color8(222, 152, 116)
const ACCENT_STINS := Color8(116, 62, 42)
const OS_ALB := Color8(232, 224, 214)
const CENUSA := Color8(150, 142, 138)
const FUNDAL := Color8(17, 14, 20)

# Ecranul e desenat pe un plan de 1152×648 (rezoluția de bază a jocului) și apoi mutat/scalat ca
# să încapă în fereastră. Așa layout-ul arată la fel peste tot, în loc să se rearanjeze singur.
const PLAN := Vector2(1152.0, 648.0)

# ---------------------------------------------------------------------------
var _stare := "intro"      # intro | amesteca | alege | arata | castigat | gata
var _runda := 0
var _sir := 0              # câte ghiciri la rând
var _bila_cup := 0         # care pahar are bila
var _slot := [0, 1, 2]     # pe ce loc de pe masă stă fiecare pahar
var _cup_x := [SLOT_X[0], SLOT_X[1], SLOT_X[2]]   # poziția lui ACUM (pixeli de artă)
var _cup_y := [CUP_Y, CUP_Y, CUP_Y]
var _npc: Node = null      # omul din lume care a deschis meniul

var _k := 1.0              # cât de mare e planul de 1152×648 în fereastra de acum
var _off := Vector2.ZERO   # și unde începe

var _panou: NinePatchRect
var _scena_clip: Control
var _scena: TextureRect
var _cupe := []            # TextureRect × 3
var _umbre := []           # umbra de sub fiecare pahar
var _bila: TextureRect
var _zone := []            # butoanele transparente de peste cele trei locuri
var _rama_scena: NinePatchRect
var _reflector: TextureRect
var _titlu: Label
var _lbl_runda: Label
var _lbl_stare: Label
var _lbl_risc: Label
var _wrap_indiciu: Control
var _wrap_risc: Control
var _lbl_indiciu: Label
var _trepte := []          # cele 5 rânduri din scara de premii
var _btn_joaca: Button
var _btn_ia: Button
var _btn_pleaca: Button
var _premiu_box: VBoxContainer
var _premiu_icon: TextureRect
var _premiu_nume: Label
var _sheet_img: Image = null
var _puls := 0.0

func _ready() -> void:
	add_to_group("alba_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12                # peste HUD și Level Up (10), sub meniul de pauză (15)
	visible = false

	var overlay := ColorRect.new()
	# aproape opac: scena e luminată și orice se mișcă în spate fură ochiul
	overlay.color = Color(FUNDAL.r, FUNDAL.g, FUNDAL.b, 0.99)
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
	Audio.enter_menu_muffle("alba")   # muzica lumii curge mai departe, dar se aude prin filtru
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
	Audio.exit_menu_muffle("alba")   # gata meniul → filtrul se deschide la loc

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
	_panou = _cadru(CH_PANOU, 2)
	add_child(_panou)

	# Titlul e ÎNTREBAREA jocului, nu numele lui („Where is the ball?", cerut de Răzvan pe
	# 2026-08-12). Un titlu scris „A L B A   N E A G R A" nu spunea nimic unui străin — numele
	# jocului de stradă românesc nu se traduce, deci în celelalte 8 limbi rămânea o formulă goală.
	# ⚠️ Scris FĂRĂ spații între litere: cu ele nu s-ar mai potrivi cheia din `i18n.gd` și titlul
	# ar rămâne englezesc în toate limbile.
	_titlu = _eticheta("Where is the ball?", 40, OS_ALB, HORIZONTAL_ALIGNMENT_CENTER)
	_titlu.add_theme_color_override("font_outline_color", ACCENT_STINS)
	_titlu.add_theme_constant_override("outline_size", 7)
	add_child(_titlu)

	add_child(_linie_ornament())

	_lbl_stare = _eticheta("", 21, OS_ALB, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_lbl_stare)

	# --- SCENA: poza omului, mărită, cu paharele peste ea ---
	_rama_scena = _cadru(CH_SCENA, 2, false)   # peste scenă: fără mijloc, altfel îi acoperă poza
	_scena_clip = Control.new()
	_scena_clip.clip_contents = true      # arta e mai mare decât rama; ce iese se taie
	_scena_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scena_clip)

	# lumina de deasupra mesei — un cerc cald, foarte slab; fără el scena e o poză lipită pe negru
	_reflector = TextureRect.new()
	_reflector.texture = _tex_radiala(96, Color(1.0, 0.86, 0.66), 0.22)
	_reflector.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reflector.stretch_mode = TextureRect.STRETCH_SCALE
	_reflector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scena_clip.add_child(_reflector)

	_scena = TextureRect.new()
	_scena.texture = load(SCENE_TEX)
	_scena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scena.stretch_mode = TextureRect.STRETCH_SCALE
	_scena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scena_clip.add_child(_scena)

	# umbrele stau SUB pahare: se micșorează când paharul se ridică, așa se vede că a decolat
	_umbre.clear()
	for i in 3:
		var u := TextureRect.new()
		u.texture = _tex_radiala(64, Color(0, 0, 0), 0.55)
		u.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		u.stretch_mode = TextureRect.STRETCH_SCALE
		u.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scena_clip.add_child(u)
		_umbre.append(u)

	# bila stă SUB pahare în ordinea de desenare, ca paharul s-o acopere când coboară peste ea
	_bila = TextureRect.new()
	_bila.texture = load(BALL_TEX)
	_bila.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bila.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bila.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bila.visible = false
	_scena_clip.add_child(_bila)

	_cupe.clear()
	for i in 3:
		var c := TextureRect.new()
		c.texture = load(CUP_TEX)
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scena_clip.add_child(c)
		_cupe.append(c)

	# Zonele de click sunt fixe, peste cele trei LOCURI de pe masă — nu peste pahare. Așa e și în
	# realitate (arăți cu degetul un loc, nu un obiect care fuge), iar butoanele nu trebuie mutate
	# la fiecare cadru de animație.
	_zone.clear()
	for i in 3:
		var b := Button.new()
		b.flat = true
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _lumina(0.13))
		b.add_theme_stylebox_override("pressed", _lumina(0.20))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_alege.bind(i))
		_scena_clip.add_child(b)
		_zone.append(b)

	add_child(_rama_scena)     # rama se desenează PESTE artă, ca poza să meargă până sub ea

	# --- panoul din STÂNGA: runda, riscul, premiul câștigat ---
	var stanga := _cadru(CH_PANEL, 1)
	add_child(stanga)
	_sep_stanga = _despartitor()
	add_child(_sep_stanga)
	_lbl_runda = _eticheta("", 20, ACCENT_CLAR, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_lbl_runda)
	_wrap_indiciu = _eticheta_rupta("Guess which cup hides the ball", 15, CENUSA)
	_lbl_indiciu = _wrap_indiciu.get_child(0) as Label
	add_child(_wrap_indiciu)
	_wrap_risc = _eticheta_rupta("", 14, CENUSA)
	_lbl_risc = _wrap_risc.get_child(0) as Label
	add_child(_wrap_risc)

	# premiul câștigat (iconița + numele), apare la final
	_premiu_box = VBoxContainer.new()
	_premiu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_premiu_box.add_theme_constant_override("separation", 4)
	_premiu_box.visible = false
	_premiu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_premiu_box)
	_premiu_icon = TextureRect.new()
	_premiu_icon.custom_minimum_size = Vector2(64, 64)
	_premiu_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_premiu_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_premiu_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_premiu_box.add_child(_premiu_icon)
	_premiu_nume = _eticheta("", 17, OS_ALB, HORIZONTAL_ALIGNMENT_CENTER)
	# ⚠️ Se rupe pe rânduri: în panoul strâns (174 px) un nume ca „Cursed Sword Mastery" nu mai
	# încape pe un rând și s-ar tăia la margine. Aici autowrap-ul e sigur (spre deosebire de
	# `_eticheta_rupta`), fiindcă VBox-ul îi dă lățimea înainte să-și calculeze înălțimea.
	_premiu_nume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_premiu_box.add_child(_premiu_nume)

	# --- panoul din DREAPTA: scara de premii + butoanele ---
	var dreapta := _cadru(CH_PANEL, 1)
	add_child(dreapta)
	_sep_dreapta = _despartitor()
	add_child(_sep_dreapta)
	var cap := _eticheta("PRIZE LADDER", 16, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(cap)
	_trepte.clear()
	for n in range(2, SIR_MAXIM + 1):
		_trepte.append(_treapta(n))

	_btn_joaca = _buton("PLAY", _joaca)
	add_child(_btn_joaca)
	# textul lui se scrie în `_actualizeaza` („TAKE COMMON", „TAKE EPIC"…), deci pornește gol
	_btn_ia = _buton("", _ia_premiul)
	add_child(_btn_ia)
	_btn_pleaca = _buton("Leave", _inchide)
	add_child(_btn_pleaca)

	# nodurile astea sunt așezate cu mâna, în `_layout`, nu de containere
	_asaza_totul(cap, stanga, dreapta)
	get_viewport().size_changed.connect(_layout)

# Reține nodurile care nu au variabilă proprie, ca `_layout` să le poată muta.
var _cap_scara: Control
var _panel_stanga: NinePatchRect
var _panel_dreapta: NinePatchRect
var _ornament: Control
var _sep_stanga: ColorRect
var _sep_dreapta: ColorRect

func _asaza_totul(cap: Control, stanga: NinePatchRect, dreapta: NinePatchRect) -> void:
	_cap_scara = cap
	_panel_stanga = stanga
	_panel_dreapta = dreapta
	_layout()

# O treaptă din scara de premii: „3  UNCOMMON", pe o plăcuță.
func _treapta(n: int) -> Dictionary:
	var placa := _cadru(CH_PLACA, 1, false)    # peste fundalul colorat al raritatii
	add_child(placa)
	var fundal := ColorRect.new()
	fundal.color = Color(1, 1, 1, 0.03)
	fundal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundal)
	move_child(fundal, placa.get_index())      # sub plăcuță
	var nr := _eticheta(str(n), 19, OS_ALB, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(nr)
	var info := _info_raritate(String(PREMII[n]))
	var rar := _eticheta(String(info["nume"]), 16, (info["color"] as Color).lerp(Color.WHITE, 0.2),
		HORIZONTAL_ALIGNMENT_LEFT)
	add_child(rar)
	return {"placa": placa, "fundal": fundal, "nr": nr, "rar": rar, "n": n,
		"culoare": info["color"] as Color}

# Numele și culoarea unei rarități, luate din `levelup.gd` (singurul loc unde trăiesc).
func _info_raritate(rar: String) -> Dictionary:
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if lu != null:
		return lu.RARITIES.get(rar, lu.RARITIES["common"])
	return {"nume": rar, "color": Color(1, 1, 1)}

# ---------------------------------------------------------------------------
# AȘEZAREA ÎN PAGINĂ
# ---------------------------------------------------------------------------
# Totul e scris în coordonatele planului de 1152×648 și trecut prin `_R`, care îl mută și-l scalează
# în fereastra de acum. Un singur loc de schimbat dacă vrei alt aranjament.
func _layout() -> void:
	if _panou == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	_k = minf(vp.x / PLAN.x, vp.y / PLAN.y)
	_off = (vp - PLAN * _k) * 0.5

	_pune(_panou, Rect2(6, 6, 1140, 636))
	_pune(_titlu, Rect2(0, 14, 1152, 52))
	_pune(_ornament, Rect2(366, 66, 420, 14))
	_pune(_lbl_stare, Rect2(330, 82, 492, 28))

	# --- CAROIAJUL (rescris pe 2026-08-12: „e puțin asimetric, fă-l profesionist") ---
	# Trei coloane pe același rând (y 112 → 624), cu aceleași cifre în oglindă:
	#   26 ┃ panou 262 ┃ 24 ┃ SCENĂ 528 ┃ 24 ┃ panou 262 ┃ 26
	# Adunate: 26+262+24+528+24+262+26 = 1152. Deci mijlocul scenei cade FIX pe 576, adică pe
	# mijlocul ecranului — acolo unde stau deja titlul, linia cu romb și eticheta de stare.
	# ⚠️ Înainte panourile erau de 210 și 280 și scena de 562: cu spații egale de 24, mijlocul
	# scenei ieșea pe 541, cu 35 px mai la stânga decât titlul de deasupra ei. Asta se vedea ca
	# „ceva nu e drept" fără să-ți dai seama ce, iar panoul din stânga, mic și plutind la jumătatea
	# înălțimii, lăsa toată greutatea desenului în dreapta.
	# Dacă umbli la vreo cifră de aici, ține suma la 1152 și cele două panouri EGALE.
	var scena_rama := Rect2(312, 112, 528, 512)
	_pune(_rama_scena, scena_rama)
	_pune(_scena_clip, scena_rama.grow(-9))

	# arta: mărire ÎNTREAGĂ, cât încape, centrată pe conținutul din poză (nu pe canvas)
	var interior := scena_rama.grow(-9).size
	var zoom := maxf(1.0, floorf(minf(interior.x / ART_CONTINUT.size.x, interior.y / ART_CONTINUT.size.y)))
	var dim := ART_CONTINUT.size * zoom
	_art_zoom = zoom
	_art_orig = (interior - dim) * 0.5 - ART_CONTINUT.position * zoom
	_scena.position = _art_orig * _k
	_scena.size = Vector2(128, 128) * zoom * _k
	_reflector.size = Vector2(interior.x, interior.y * 0.9) * _k
	_reflector.position = Vector2(0, -interior.y * 0.12) * _k

	# Cele două panouri au ACELEAȘI trei benzi pe înălțime, ca ochiul să le citească drept o
	# pereche, nu ca două cutii nimerite acolo:
	#   132–156  capul coloanei   (stânga „ROUND 1", dreapta „PRIZE LADDER")
	#   164–388  conținutul       (stânga indiciul / premiul, dreapta cele 5 trepte)
	#   398      linia despărțitoare, la aceeași înălțime în amândouă
	#   412–566  josul            (stânga avertismentul de risc, dreapta butoanele)
	# ⚠️ Rama e un NinePatch cu marginea de 15 px, deci scrisul începe la x+18, nu la x: 44 în
	# stânga (panou de la 26), 882 în dreapta (panou de la 864). Ambele coloane de scris sunt de
	# 226 px — dacă schimbi una, schimb-o și pe cealaltă, altfel se pierde tot ce e mai sus.
	#
	# Premiul stă PESTE indiciu, nu sub el: indiciul se vede cât joci, premiul abia la final, deci
	# nu sunt niciodată pe ecran în același timp (vezi `_actualizeaza`, care le și ascunde ca să fie
	# sigur). Așa banda din mijloc are un singur lucru în ea, oricare ar fi starea.
	_pune(_panel_stanga, Rect2(26, 112, 262, 512))
	_pune(_lbl_runda, Rect2(44, 128, 226, 32))
	_pune(_sep_stanga, Rect2(44, 398, 226, 2))
	_pune(_premiu_box, Rect2(44, 206, 226, 140))
	_pune(_wrap_indiciu, Rect2(44, 244, 226, 64))
	_pune(_wrap_risc, Rect2(44, 459, 226, 60))

	_pune(_panel_dreapta, Rect2(864, 112, 262, 512))
	_pune(_cap_scara, Rect2(882, 132, 226, 24))
	_pune(_sep_dreapta, Rect2(882, 398, 226, 2))
	for i in _trepte.size():
		var r := Rect2(882, 164 + i * 46, 226, 40)
		_pune(_trepte[i]["placa"], r)
		_pune(_trepte[i]["fundal"], r.grow(-4))
		_pune(_trepte[i]["nr"], Rect2(r.position.x + 12, r.position.y + 9, 26, 24))
		_pune(_trepte[i]["rar"], Rect2(r.position.x + 48, r.position.y + 11, 166, 22))
	_aseaza_butoane()
	_aseaza_paharele()

# Butoanele se string unul sub altul, sărind peste cele ascunse: „TAKE EPIC" apare doar când ai
# ce lua, iar fără asta rămânea o gaură cât un buton între PLAY și LEAVE.
func _aseaza_butoane() -> void:
	if _btn_joaca == null:
		return
	var y := 412.0
	for b in [_btn_joaca, _btn_ia, _btn_pleaca]:
		if not b.visible:
			continue
		_pune(b, Rect2(882, y, 226, 46))
		y += 54.0

var _art_zoom := 4.0
var _art_orig := Vector2.ZERO

func _pune(c: Control, r: Rect2) -> void:
	if c == null:
		return
	c.position = _off + r.position * _k
	c.size = r.size * _k

# Din pixeli de POZĂ în pixeli de ecran, în interiorul scenei.
func _art(v: Vector2) -> Vector2:
	return (_art_orig + v * _art_zoom) * _k

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
	tw.tween_interval(ARATA_BILA)
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
	_layout()

func _set_cup_y(v: float, i: int) -> void:
	_cup_y[i] = v

# ---------------------------------------------------------------------------
# TEXTELE ȘI BUTOANELE, după stare
# ---------------------------------------------------------------------------
func _actualizeaza() -> void:
	# tr() explicit: are %d. Înainte de prima rundă scrie „READY" — altfel panoul din stânga
	# rămâne complet gol când deschizi meniul și pare că nu s-a încărcat.
	_lbl_runda.text = "READY" if _runda == 0 else tr("Round %d") % _runda
	var pedeapsa := int(round(PEDEAPSA * 100.0))
	match _stare:
		"intro":
			_lbl_stare.text = "Guess which cup hides the ball"
			_lbl_indiciu.text = "Two in a row for the first prize"
			_lbl_risc.text = tr("If you lose, gain +%d%% Difficulty") % pedeapsa
		"amesteca":
			_lbl_stare.text = "Watch the cups"
			_lbl_risc.text = ""
		"alege", "arata":
			# ⚠️ NU „Where is the ball?": de când întrebarea e scrisă în TITLU, ar fi apărut de
			# două ori, una sub alta. Aici scrie ce ai de FĂCUT, nu ce se întreabă.
			_lbl_stare.text = "Pick a cup"
			_lbl_risc.text = tr("If you lose, gain +%d%% Difficulty") % pedeapsa
		"castigat":
			_lbl_stare.text = "YOU WIN!"
			# Panoul din stânga spune ce se câștigă mergând mai departe — altfel, de la a doua
			# ghicire încolo, banda lui din mijloc rămânea goală și panoul părea neterminat.
			# ⚠️ La `_sir == SIR_MAXIM` NU mai există treaptă următoare (`PREMII[7]` ar crăpa);
			# starea asta se închide oricum singură cu premiul în mână, vezi `_rezultat`.
			if not PREMII.has(_sir):
				_lbl_indiciu.text = "Two in a row for the first prize"
			elif PREMII.has(_sir + 1):
				# tr() explicit de două ori: textul e ASAMBLAT, deci nici el, nici numele
				# raritații din el nu mai trec singure prin traducere.
				_lbl_indiciu.text = tr("One more for %s") % tr(
					String(_info_raritate(String(PREMII[_sir + 1]))["nume"])).to_upper()
			else:
				_lbl_indiciu.text = ""
			_lbl_risc.text = tr("If you lose, gain +%d%% Difficulty") % pedeapsa
		"gata":
			var pierdut: bool = _sir == 0 and _runda > 0
			_lbl_stare.text = "YOU LOSE" if pierdut else ""
			_lbl_indiciu.text = ""
			# ⚠️ Pedeapsa TREBUIE scrisă pe ecran: e singurul lucru care se schimbă în restul rundei
			# și nu se vede nicăieri altundeva. tr() explicit: are %d.
			_lbl_risc.text = tr("The game got %d%% harder") % pedeapsa if pierdut else ""
	# ⚠️ Premiul e desenat PESTE cele două scrisuri (același loc în panou, vezi `_layout`). Ele sunt
	# oricum goale când apare el, dar le ascundem ca să nu depindă aspectul de asta.
	_wrap_indiciu.visible = not _premiu_box.visible
	_wrap_risc.visible = not _premiu_box.visible
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
	_aseaza_butoane()
	for b in _zone:
		b.disabled = _stare != "alege"

	# scara de premii: treapta următoare se aprinde, cele luate rămân pline
	for t in _trepte:
		var n: int = t["n"]
		var activa: bool = n == _sir + 1 and _stare != "gata"
		var luata: bool = n <= _sir
		var cul: Color = t["culoare"]
		(t["fundal"] as ColorRect).color = Color(cul.r, cul.g, cul.b, 0.22) if luata else Color(1, 1, 1, 0.03)
		(t["placa"] as Control).modulate = ACCENT_CLAR if activa else (
			Color(1, 1, 1) if luata else Color(0.55, 0.52, 0.55))
		(t["nr"] as Label).modulate = Color(1, 1, 1) if (activa or luata) else Color(0.7, 0.68, 0.7)
		(t["rar"] as Label).modulate = Color(1, 1, 1) if (activa or luata) else Color(0.7, 0.68, 0.7)

# ---------------------------------------------------------------------------
# CE SE MIȘCĂ ÎN FIECARE CADRU
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not visible:
		return
	_aseaza_paharele()
	# treapta următoare pulsează încet — singurul lucru care se mișcă în meniu când stai pe loc
	_puls += delta
	var p := 0.78 + 0.22 * sin(_puls * 3.0)
	for t in _trepte:
		if int(t["n"]) == _sir + 1 and _stare != "gata" and _stare != "amesteca":
			(t["placa"] as Control).modulate = ACCENT_CLAR * Color(p, p, p, 1.0)

# Paharele, umbrele, bila și zonele de click, din pixelii pozei în pixeli de ecran.
func _aseaza_paharele() -> void:
	if _scena_clip == null:
		return
	var z := _art_zoom * _k
	for i in 3:
		var c: TextureRect = _cupe[i]
		c.size = Vector2(CUP_W, CUP_H) * z
		c.position = _art(Vector2(_cup_x[i] - CUP_W * 0.5, _cup_y[i] - CUP_H * 0.5))
		# Umbra: cu cât paharul e mai sus, cu atât mai mică și mai palidă — ea vinde săritura.
		# ⚠️ Ține-o SLABĂ. Prima încercare (alpha 0,85, lată cât paharul + 5) punea trei pete
		# cenușii pe masă, de parcă scăpase cineva scrum acolo.
		var sus: float = clampf((CUP_Y - _cup_y[i]) / RIDICARE, 0.0, 1.0)
		var u: TextureRect = _umbre[i]
		var lat: float = (CUP_W + 1.0) * (1.0 - 0.3 * sus)
		u.size = Vector2(lat, lat * 0.34) * z
		u.position = _art(Vector2(_cup_x[i] - lat * 0.5, TALPA - lat * 0.17 + 0.5))
		u.modulate = Color(1, 1, 1, 0.42 - 0.26 * sus)
	var d := BILA_D * z
	_bila.size = Vector2(d, d)
	_bila.position = _art(Vector2(SLOT_X[_slot[_bila_cup]] - BILA_D * 0.5, BILA_Y - BILA_D * 0.5))
	for i in 3:
		var b: Button = _zone[i]
		var lat := CUP_W + 8.0
		var inalt := CUP_H + RIDICARE
		b.size = Vector2(lat, inalt) * z
		b.position = _art(Vector2(SLOT_X[i] - lat * 0.5, TALPA + 2.0 - inalt))

# ---------------------------------------------------------------------------
# CĂRĂMIZILE DE ASPECT
# ---------------------------------------------------------------------------
# O ramă din planșa `Border EGT.png`, ca NinePatch: colțurile rămân întregi, laturile se întind.
# `zoom` = de câte ori se mărește celula de 64px înainte de întindere (2 = ramă groasă, de ecran).
#
# ⚠️ `centru = false` e OBLIGATORIU pentru ramele puse PESTE ceva. Celulele din planșă NU au
# mijlocul transparent, au un bleumarin închis — o ramă desenată peste scenă îi acoperă complet
# poza și rămâi cu un dreptunghi gol (exact asta a pățit prima versiune a meniului nou).
func _cadru(celula: Vector2i, zoom: int, centru: bool = true) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _chenar(celula, zoom)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.draw_center = centru
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := 15 * zoom
	np.patch_margin_left = m
	np.patch_margin_right = m
	np.patch_margin_top = m
	np.patch_margin_bottom = m
	return np

func _chenar(celula: Vector2i, zoom: int) -> ImageTexture:
	if _sheet_img == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet_img = tex.get_image()
	var bucata := _sheet_img.get_region(Rect2i(celula.x * CELULA, celula.y * CELULA, CELULA, CELULA))
	bucata.resize(CELULA * zoom, CELULA * zoom, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bucata)

# Cercul de lumină / umbra de sub pahar: un gradient radial desenat o dată, în cod.
func _tex_radiala(dim: int, culoare: Color, putere: float) -> ImageTexture:
	var img := Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var c := (dim - 1) * 0.5
	for y in dim:
		for x in dim:
			var d := Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(culoare.r, culoare.g, culoare.b, a * a * putere))
	return ImageTexture.create_from_image(img)

# Linia de sub titlu, cu un romb în mijloc — două ColorRect-uri și un pătrat rotit la 45°.
func _linie_ornament() -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ornament = wrap
	# ⚠️ Ancorele se scriu de mână, nu cu un preset: `PRESET_LEFT_WIDE` ancorează și marginea de jos
	# la 1, deci `offset_bottom = 8` înseamnă „cu 8 px MAI JOS decât fundul", nu „gros de 2 px" —
	# prima încercare a ieșit cu două bare grase cât o cărămidă.
	var st := ColorRect.new()
	st.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	st.anchor_left = 0.0
	st.anchor_right = 0.42
	st.anchor_top = 0.0
	st.anchor_bottom = 0.0
	st.offset_top = 6
	st.offset_bottom = 8
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(st)
	var dr := ColorRect.new()
	dr.color = st.color
	dr.anchor_left = 0.58
	dr.anchor_right = 1.0
	dr.anchor_top = 0.0
	dr.anchor_bottom = 0.0
	dr.offset_top = 6
	dr.offset_bottom = 8
	dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dr)
	var romb := ColorRect.new()
	romb.color = ACCENT_CLAR
	romb.set_anchors_preset(Control.PRESET_CENTER)
	romb.size = Vector2(9, 9)
	romb.pivot_offset = Vector2(4.5, 4.5)
	romb.rotation = PI * 0.25
	romb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(romb)
	wrap.resized.connect(func():
		romb.position = Vector2(wrap.size.x * 0.5 - 4.5, 2.5))
	return wrap

# Linia subțire care taie un panou în două. Stă la aceeași înălțime în amândouă (398) și taie
# fiecare panou acolo unde se schimbă rolul: în dreapta între ce POȚI câștiga și ce FACI, în stânga
# între starea jocului și prețul greșelii. Fără ea, jumătatea de jos a panourilor părea o rămășiță
# de loc gol, nu o bandă cu rost.
func _despartitor() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _eticheta(text: String, dim: int, culoare: Color, aliniere: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = aliniere
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", culoare)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# O etichetă care se rupe pe mai multe rânduri.
#
# ⚠️ NU o așeza direct cu `_pune`. O etichetă cu autowrap își calculează înălțimea minimă din
# lățimea pe care o are ÎN ACEL MOMENT — iar înainte de prima așezare lățimea ei e 0, adică „un
# cuvânt pe rând". Minimul ăla (439 px pentru un text de două rânduri!) rămâne agățat de ea și
# `size` nu mai poate coborî sub el: textul ajunge tocmai în mijlocul panoului. De aia eticheta stă
# într-un Control gol, ancorat pe tot cuprinsul lui: containerul primește mărimea, iar eticheta o
# moștenește DUPĂ ce lățimea e cunoscută.
func _eticheta_rupta(text: String, dim: int, culoare: Color) -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _eticheta(text, dim, culoare, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(l)
	return wrap

func _lumina(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(3)
	return sb

# Butoanele au rama din aceeași planșă, ca să nu iasă din stil.
func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", OS_ALB)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", _sb_buton(CH_BUTON, Color(1, 1, 1)))
	b.add_theme_stylebox_override("hover", _sb_buton(CH_BUTON, ACCENT_CLAR * Color(1.25, 1.25, 1.25, 1)))
	b.add_theme_stylebox_override("pressed", _sb_buton(CH_BUTON, ACCENT))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _sb_buton(CH_BUTON, Color(0.5, 0.5, 0.5)))
	if cb.is_valid():
		b.pressed.connect(func(): Audio.play("button", -3.0, 0.0))
		b.pressed.connect(cb)
	return b

func _sb_buton(celula: Vector2i, tenta: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _chenar(celula, 1)
	sb.modulate_color = tenta
	sb.set_texture_margin_all(15)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
