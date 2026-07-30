extends CanvasLayer

# CAZINOUL („Let's go gambling") — interfața aparatului EGT din lume (`egt.gd`).
#
# Cum se leagă: apeși E pe aparat → `egt.gd::invoca()` → `open()` de aici. Jocul se OPREȘTE
# (`get_tree().paused`), exact ca la ecranul de Level Up, iar meniul merge mai departe fiindcă
# nodul are `PROCESS_MODE_ALWAYS`. ESC te întoarce un pas înapoi (de la masă la meniu, din meniu
# afară din cazinou).
#
# Două ecrane:
#   1. „Let's go gambling" + Gamble your stats / Gamble your items (al doilea încă nu e făcut).
#   2. MASA DE RULETĂ: poza din `harta/EGT/Roulette Table.png`, cu zone de click peste FIECARE
#      număr și peste toate pariurile exterioare (roșu/negru, par/impar, duzini, coloane).
#      În dreapta bifezi ce statusuri bagi în joc.
#
# MIZA (cerută de Răzvan pe 2026-07-30): „totul sau nimic". Câștigi → fiecare status bifat se
# DUBLEAZĂ. Pierzi → se ÎNJUMĂTĂȚEȘTE. La fel indiferent pe ce ai pariat: un număr plin plătește
# cât roșu/negru. Vezi `CASTIG_MULT` / `PIERDERE_MULT` dacă vrei plăți diferite pe tip de pariu.
#
# RULETA E CINSTITĂ: numărul iese din `randi() % 37` (0–36, ruletă europeană cu un singur zero),
# tras ÎNAINTE de animație. Roata care se învârte e doar decor: ordinea numerelor desenate pe
# ea e inventată de artist (apare „38", iar „29" de două ori), deci nu se poate opri fix pe
# buzunarul câștigător fără să mintă. De-aia rezultatul se anunță în butucul roții și prin
# evidențierea căsuței câștigătoare de pe masă.

const MENU_UI_DIR := "res://Upgrades/Menu UI/"
# Cele trei imagini sunt SCOASE din poza mare `harta/EGT/Roulette Table.png` de `tool_egt_assets.gd`
# (masa cu fundalul alb făcut transparent, discul roții decupat rotund, jetonul roșu).
# Schimbi poza mare → rulezi unealta din nou ȘI remăsori constantele de geometrie de mai jos.
const TABLE_TEX := "res://harta/EGT/table.png"
const WHEEL_TEX := "res://harta/EGT/wheel.png"
const CHIP_TEX := "res://harta/EGT/chip_red.png"

const ACCENT := Color(0.95, 0.85, 0.55)   # auriul ramei ornate (ca în pause.gd / levelup.gd)
const BTN_MAIN := Color("9e603f")         # umplutura butoanelor (lemn, ca în meniu)
const BTN_SECOND := Color("594232")       # conturul lor

# Cât se ÎNMULȚEȘTE un status bifat dacă pariul iese — pe TIP de pariu (cerut de Răzvan pe
# 2026-07-30; până atunci toate plăteau 2×, deci un număr plin nu avea niciun rost).
const CASTIG_MULT := {
	"numar": 20.0,    # număr plin — o șansă din 37
	"rosu": 2.0,
	"negru": 2.0,
	"par": 2.0,
	"impar": 2.0,
	"jos": 3.0,       # căsuța scrisă „1-12" pe poză (vezi JOS_MAXIM)
	"sus": 3.0,       # „19-36"
	"duzina": 3.0,    # 1st 12 / 2nd 12 / 3rd 12
	"coloana": 3.0,   # cele trei „2 to 1"
}
# Dacă pierzi, statusul se înjumătățește — la fel pentru orice pariu.
const PIERDERE_MULT := 0.5

# ---------------------------------------------------------------------------
# GEOMETRIA MESEI, în pixelii pozei (1648×954). Toate zonele de click de mai jos sunt date în
# acești pixeli și se transformă în ANCORE (fracții din poză), ca masa să meargă identic la
# orice rezoluție. Cifrele sunt MĂSURATE pe liniile albe din poză, nu ghicite — dacă schimbi
# poza mesei, remăsoară-le (unealta care le-a scos căuta coloanele/rândurile de pixeli albi).
# ---------------------------------------------------------------------------
const TABLE_W := 1648.0
const TABLE_H := 954.0

const GRID_X0 := 658.0     # marginea stângă a grilei de numere (1–36)
const GRID_X1 := 1486.0    # marginea dreaptă
const GRID_Y0 := 306.0     # marginea de sus
const GRID_Y1 := 545.0     # marginea de jos
const COL_W := (GRID_X1 - GRID_X0) / 12.0   # lățimea unei coloane (12 coloane)
const ROW_H := (GRID_Y1 - GRID_Y0) / 3.0    # înălțimea unui rând (3 rânduri)

const ZERO_RECT := Rect2(598, 306, 60, 239)   # căsuța rotunjită cu „0", în stânga grilei
const COL2_X0 := 1486.0                        # coloana de „2 to 1", în dreapta grilei
const COL2_X1 := 1546.0
const DOZ_Y0 := 547.0      # rândul cu 1st 12 / 2nd 12 / 3rd 12
const DOZ_Y1 := 623.0
const OUT_Y0 := 626.0      # rândul de jos: 1-12 / EVEN / roșu / negru / ODD / 19-36
const OUT_Y1 := 703.0

const WHEEL_CENTER := Vector2(265, 652)   # centrul discului roții în poza mare
const WHEEL_R := 173.0                    # raza discului decupat (wheel.png e 346×346)

# Numerele ROȘII de pe o ruletă europeană (restul, în afară de 0, sunt negre).
# Poza mesei le respectă exact — verificat număr cu număr.
const ROSII := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# ⚠️ Căsuța din stânga jos scrie „1-12" pe poză, deși pe o masă adevărată acolo scrie „1-18".
# Am lăsat-o să facă exact ce scrie pe ea (câștigă la 1–12), ca să nu pară că jocul trișează.
# Vrei regula adevărată de ruletă? Schimbă cifra de mai jos în 18.
const JOS_MAXIM := 12

# ---------------------------------------------------------------------------
# STATUSURILE care se pot paria. Apar în dreapta mesei DOAR dacă valoarea lor de acum e > 0 —
# n-are rost să bifezi un status pe 0 (dublul lui e tot 0, deci ar fi un pariu fără risc).
# `jos_e_bine` = la statusul ăsta MAI MIC înseamnă mai bun (tragi mai des / încasezi mai puțin),
# deci la CÂȘTIG valoarea se împarte, nu se înmulțește.
# ---------------------------------------------------------------------------
const STATS := [
	{"id": "damage",    "nume": "Damage"},
	{"id": "atkspeed",  "nume": "Attack Speed", "jos_e_bine": true},
	{"id": "crit",      "nume": "Crit"},
	{"id": "proj",      "nume": "Projectiles"},
	{"id": "pierce",    "nume": "Pierce"},
	{"id": "wsize",     "nume": "Weapon Size"},
	{"id": "knockback", "nume": "Knockback"},
	{"id": "instakill", "nume": "Instakill"},
	{"id": "luck",      "nume": "Luck"},
	{"id": "speed",     "nume": "Move Speed"},
	{"id": "maxhp",     "nume": "Max HP"},
	{"id": "regen",     "nume": "HP Regen"},
	{"id": "dmgtaken",  "nume": "Damage Taken", "jos_e_bine": true},
]

# ---------------------------------------------------------------------------
var _pagina := "intro"
var _pariu = null              # dicționarul pariului curent (vezi `_castiga`), sau null
var _pariu_rect := Rect2()     # zona lui pe masă, în pixelii pozei (acolo se pune jetonul)
var _evid_rect := Rect2()      # căsuța numărului ieșit (se evidențiază după învârtire)
var _alese := {}               # id status -> true, ce e bifat în dreapta
var _se_invarte := false

var _pag_intro: Control
var _pag_masa: Control
var _masa: TextureRect
var _roata: TextureRect
var _jeton: TextureRect
var _evid: Panel
var _bila: Label               # numărul ieșit, scris în butucul roții
var _panou: NinePatchRect
var _lista_stat: VBoxContainer
var _lbl_pariu: Label
var _lbl_plata: Label          # cât plătește pariul ales (×20, ×3, ×2)
var _btn_spin: Button
var _rezultat: VBoxContainer
var _banner: Label

func _ready() -> void:
	add_to_group("casino")
	process_mode = Node.PROCESS_MODE_ALWAYS   # merge și când jocul e pe pauză
	layer = 12                                # peste HUD și Level Up (10), sub meniul de pauză (15)
	visible = false

	var overlay := ColorRect.new()
	# aproape opac: la 0.93 se mai citea cronometrul din HUD prin bannerul cu rezultatul
	overlay.color = Color(0.07, 0.06, 0.09, 0.985)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build_intro()
	_build_masa()
	_arata_pagina("intro")
	get_viewport().size_changed.connect(_relayout)

# ---------------------------------------------------------------------------
# DESCHIDERE / ÎNCHIDERE
# ---------------------------------------------------------------------------
func open() -> void:
	if visible:
		return
	visible = true
	_arata_pagina("intro")
	get_tree().paused = true
	Audio.pause_forest_ambient()   # ambientul se oprește cât joci; se reia de unde a rămas
	Audio.play("levelup", -4.0, 0.0)

func _inchide() -> void:
	if _se_invarte:
		return                     # nu pleca din mijlocul unei învârtiri
	visible = false
	get_tree().paused = false
	Audio.resume_forest_ambient()

# ESC: de la masă înapoi la meniu, din meniu afară din cazinou.
# ⚠️ Ca să nu se deschidă meniul de pauză PESTE cazinou, `pause.gd::_blocked()` întreabă și de noi.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _pagina == "masa":
		if not _se_invarte:
			_arata_pagina("intro")
	else:
		_inchide()

func _arata_pagina(care: String) -> void:
	_pagina = care
	_pag_intro.visible = (care == "intro")
	_pag_masa.visible = (care == "masa")
	if care == "masa":
		_reseteaza_masa()
		_relayout()

# ---------------------------------------------------------------------------
# ECRANUL 1 — „Let's go gambling"
# ---------------------------------------------------------------------------
func _build_intro() -> void:
	_pag_intro = Control.new()
	_pag_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pag_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pag_intro)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pag_intro.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var titlu := Label.new()
	titlu.text = "Let's go gambling"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.add_theme_font_size_override("font_size", 54)
	titlu.add_theme_color_override("font_color", ACCENT)
	titlu.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	titlu.add_theme_constant_override("outline_size", 6)
	box.add_child(titlu)
	box.add_child(_spatiu(24))

	box.add_child(_buton("Gamble your stats", _on_stats))

	# „Gamble your items" încă nu e făcut: butonul există, dar e gri și nu face nimic.
	var b_items := _buton("Gamble your items", Callable())
	b_items.disabled = true
	box.add_child(b_items)

	var curand := Label.new()
	curand.text = "Coming soon"
	curand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curand.add_theme_font_size_override("font_size", 17)
	curand.add_theme_color_override("font_color", Color(0.62, 0.62, 0.66))
	box.add_child(curand)

	box.add_child(_spatiu(18))
	box.add_child(_buton("Leave", _inchide))

func _on_stats() -> void:
	_arata_pagina("masa")

# ---------------------------------------------------------------------------
# ECRANUL 2 — MASA DE RULETĂ
# ---------------------------------------------------------------------------
func _build_masa() -> void:
	_pag_masa = Control.new()
	_pag_masa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pag_masa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pag_masa)

	# poza mesei. `EXPAND_IGNORE_SIZE` + `STRETCH_SCALE` = se întinde exact cât îi spunem noi în
	# `_relayout()`, fără să-și impună mărimea texturii (1648×954, mult peste ecran).
	_masa = TextureRect.new()
	_masa.texture = load(TABLE_TEX)
	_masa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_masa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_masa.stretch_mode = TextureRect.STRETCH_SCALE
	_masa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pag_masa.add_child(_masa)

	_build_zone()

	# evidențierea căsuței câștigătoare (chenar auriu, fără umplutură)
	_evid = Panel.new()
	_evid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.9, 0.3, 0.28)
	sb.border_color = Color(1.0, 0.9, 0.3)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(4)
	_evid.add_theme_stylebox_override("panel", sb)
	_evid.visible = false
	_masa.add_child(_evid)

	# jetonul roșu, pus peste zona pe care ai pariat
	_jeton = TextureRect.new()
	_jeton.texture = load(CHIP_TEX)
	_jeton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_jeton.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_jeton.stretch_mode = TextureRect.STRETCH_SCALE
	_jeton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jeton.visible = false
	_masa.add_child(_jeton)

	# discul roții, peste roata din poză — el se învârte
	_roata = TextureRect.new()
	_roata.texture = load(WHEEL_TEX)
	_roata.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_roata.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_roata.stretch_mode = TextureRect.STRETCH_SCALE
	_roata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_masa.add_child(_roata)

	# numărul ieșit, scris în butucul roții
	_bila = Label.new()
	_bila.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bila.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bila.add_theme_color_override("font_color", Color(1, 1, 1))
	_bila.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_bila.add_theme_constant_override("outline_size", 6)
	_bila.visible = false
	_masa.add_child(_bila)

	# bannerul cu rezultatul, peste marginea de sus a ecranului
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 12
	_banner.offset_bottom = 52
	_pag_masa.add_child(_banner)

	_build_panou()

# Zonele de click: fiecare e un buton transparent, ancorat pe o fracție din poză (deci se mută
# și se redimensionează singur odată cu masa).
func _build_zone() -> void:
	# 0
	_zona(ZERO_RECT, {"tip": "numar", "n": 0}, "0")
	# 1–36
	for n in range(1, 37):
		_zona(_rect_numar(n), {"tip": "numar", "n": n}, str(n))
	# coloanele „2 to 1" (câte una pe rândul ei)
	var mod_rand := [0, 2, 1]   # rândul 0 = 3,6,…36 (n%3==0); rândul 1 = 2,5,…35; rândul 2 = 1,4,…34
	for r in 3:
		var rect := Rect2(COL2_X0, GRID_Y0 + r * ROW_H, COL2_X1 - COL2_X0, ROW_H)
		_zona(rect, {"tip": "coloana", "m": mod_rand[r]}, "2 to 1")
	# duzinile
	var doz_nume := ["1st 12", "2nd 12", "3rd 12"]
	for i in 3:
		var w := (GRID_X1 - GRID_X0) / 3.0
		_zona(Rect2(GRID_X0 + i * w, DOZ_Y0, w, DOZ_Y1 - DOZ_Y0), {"tip": "duzina", "i": i}, doz_nume[i])
	# rândul de jos, 6 căsuțe egale
	var w6 := (GRID_X1 - GRID_X0) / 6.0
	var jos := [
		[{"tip": "jos"}, "1-%d" % JOS_MAXIM],
		[{"tip": "par"}, "EVEN"],
		[{"tip": "rosu"}, "RED"],
		[{"tip": "negru"}, "BLACK"],
		[{"tip": "impar"}, "ODD"],
		[{"tip": "sus"}, "19-36"],
	]
	for i in jos.size():
		_zona(Rect2(GRID_X0 + i * w6, OUT_Y0, w6, OUT_Y1 - OUT_Y0), jos[i][0], jos[i][1])

# Un buton transparent peste o zonă a mesei. `r` e în pixelii pozei; îl legăm prin ANCORE, deci
# rămâne pe loc la orice mărime a mesei.
func _zona(r: Rect2, pariu: Dictionary, eticheta: String) -> void:
	var b := Button.new()
	b.flat = true
	b.anchor_left = r.position.x / TABLE_W
	b.anchor_right = (r.position.x + r.size.x) / TABLE_W
	b.anchor_top = r.position.y / TABLE_H
	b.anchor_bottom = (r.position.y + r.size.y) / TABLE_H
	b.offset_left = 0.0
	b.offset_top = 0.0
	b.offset_right = 0.0
	b.offset_bottom = 0.0
	b.tooltip_text = eticheta
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _lumina(0.22))
	b.add_theme_stylebox_override("pressed", _lumina(0.35))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_pune_pariu.bind(pariu, r, eticheta))
	_masa.add_child(b)

func _lumina(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(3)
	return sb

# Căsuța unui număr din grilă, în pixelii pozei.
# Rândul de sus e 3,6,…36 (n%3==0), mijlocul 2,5,…35 (n%3==2), josul 1,4,…34 (n%3==1).
func _rect_numar(n: int) -> Rect2:
	if n == 0:
		return ZERO_RECT
	var col := (n - 1) / 3
	var rand := 0
	if n % 3 == 2:
		rand = 1
	elif n % 3 == 1:
		rand = 2
	return Rect2(GRID_X0 + col * COL_W, GRID_Y0 + rand * ROW_H, COL_W, ROW_H)

func _pune_pariu(pariu: Dictionary, r: Rect2, eticheta: String) -> void:
	if _se_invarte:
		return
	Audio.play("button", -4.0, 0.0)
	_pariu = pariu
	_pariu_rect = r
	_lbl_pariu.text = tr("Bet: %s") % eticheta
	_lbl_plata.text = tr("Win x%s") % _text_plata(pariu)
	_jeton.visible = true
	_evid.visible = false
	_bila.visible = false
	_banner.text = ""
	_goleste_rezultat()
	_relayout()
	_actualizeaza_spin()

# ---------------------------------------------------------------------------
# PANOUL DIN DREAPTA — ce statusuri bagi în joc
# ---------------------------------------------------------------------------
func _build_panou() -> void:
	_panou = NinePatchRect.new()
	_panou.texture = load(MENU_UI_DIR + "Menu.png")
	_panou.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panou.patch_margin_left = 46
	_panou.patch_margin_right = 46
	_panou.patch_margin_top = 46
	_panou.patch_margin_bottom = 46
	_panou.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_pag_masa.add_child(_panou)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ⚠️ Marginile trebuie să treacă de grosimea ramei (`patch_margin` = 46), altfel textul se urcă
	# pe chenarul ornat. Erau 40, adică 6px SUB grosimea ramei — de aia se lipeau butoanele de ea.
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 58)
	margin.add_theme_constant_override("margin_bottom", 50)
	_panou.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var titlu := Label.new()
	titlu.text = "Gamble your stats"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titlu.add_theme_font_size_override("font_size", 17)
	titlu.add_theme_color_override("font_color", ACCENT)
	titlu.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	titlu.add_theme_constant_override("outline_size", 2)
	box.add_child(titlu)

	var sub := Label.new()
	sub.text = "Lose = half the stat"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.70, 0.70, 0.74))
	box.add_child(sub)

	# lista de statusuri, într-un ScrollContainer ca să încapă mereu, oricâte ar fi
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_lista_stat = VBoxContainer.new()
	_lista_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_stat.add_theme_constant_override("separation", 1)
	scroll.add_child(_lista_stat)

	# ⚠️ `autowrap` pe etichetele astea două nu e de frumusețe: o etichetă FĂRĂ autowrap își impune
	# lățimea textului ca mărime MINIMĂ, iar „Place your bet on the table" cerea 291px într-un panou
	# de 345 — împingea tot conținutul (inclusiv butoanele) cu 25px peste rama ornată.
	_lbl_pariu = Label.new()
	_lbl_pariu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_pariu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_pariu.add_theme_font_size_override("font_size", 14)
	_lbl_pariu.add_theme_color_override("font_color", ACCENT)
	box.add_child(_lbl_pariu)

	# cât plătește pariul ales (20× la număr plin, 3× la duzini/coloane, 2× la roșu/negru…)
	_lbl_plata = Label.new()
	_lbl_plata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_plata.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_plata.add_theme_font_size_override("font_size", 13)
	_lbl_plata.add_theme_color_override("font_color", Color(0.44, 0.86, 0.44))
	box.add_child(_lbl_plata)

	_btn_spin = _buton("SPIN", _spin)
	_btn_spin.custom_minimum_size = Vector2(0, 38)
	_btn_spin.add_theme_font_size_override("font_size", 17)
	box.add_child(_btn_spin)

	_rezultat = VBoxContainer.new()
	_rezultat.add_theme_constant_override("separation", 0)
	box.add_child(_rezultat)

	var inapoi := _buton("Back", _on_back)
	inapoi.custom_minimum_size = Vector2(0, 32)
	inapoi.add_theme_font_size_override("font_size", 15)
	box.add_child(inapoi)

func _on_back() -> void:
	if not _se_invarte:
		_arata_pagina("intro")

# Reumple lista de statusuri cu valorile de ACUM. Se cheamă la fiecare intrare pe masă și după
# fiecare învârtire: valorile s-au schimbat, iar un status ajuns pe 0 iese din listă.
func _umple_statusuri() -> void:
	for c in _lista_stat.get_children():
		_lista_stat.remove_child(c)
		c.queue_free()
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var vii := {}
	for s in STATS:
		if _valoare(p, s["id"]) <= 0.0:
			continue
		vii[s["id"]] = true
		var hb := HBoxContainer.new()
		var cb := CheckBox.new()
		cb.text = s["nume"]
		cb.button_pressed = _alese.has(s["id"])
		cb.add_theme_font_size_override("font_size", 13)
		cb.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94))
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.clip_text = true   # un nume lung scurtează, nu lățește panoul peste ramă
		cb.toggled.connect(_on_bifa.bind(s["id"]))
		hb.add_child(cb)
		var val := Label.new()
		val.text = _afisare(p, s["id"])
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", ACCENT)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(val)
		_lista_stat.add_child(hb)
	# un status care a picat pe 0 (ex. Pierce înjumătățit) nu mai există în listă → scoate-l și
	# din bifate, altfel ai fi pariat pe ceva ce nu se mai vede
	for id in _alese.keys():
		if not vii.has(id):
			_alese.erase(id)

func _on_bifa(bifat: bool, id: String) -> void:
	if bifat:
		_alese[id] = true
	else:
		_alese.erase(id)
	Audio.play("button", -8.0, 0.0)
	_actualizeaza_spin()

# SPIN merge doar dacă ai și pariat pe masă, și bifat cel puțin un status.
func _actualizeaza_spin() -> void:
	_btn_spin.disabled = _se_invarte or _pariu == null or _alese.is_empty()
	if _pariu == null:
		_lbl_pariu.text = "Place your bet on the table"
		_lbl_plata.text = ""

# Cât plătește pariul, scris scurt: „20", „3", „2" (fără „.0" degeaba).
func _text_plata(pariu: Dictionary) -> String:
	return ("%.1f" % _multiplicator(pariu)).trim_suffix(".0")

# Multiplicatorul de CÂȘTIG al unui pariu. Necunoscut → 2×, ca să nu iasă 0 dacă cineva adaugă
# un tip nou de pariu și uită să-l treacă în CASTIG_MULT.
func _multiplicator(pariu: Dictionary) -> float:
	return float(CASTIG_MULT.get(pariu["tip"], 2.0))

func _reseteaza_masa() -> void:
	_pariu = null
	_jeton.visible = false
	_evid.visible = false
	_bila.visible = false
	_banner.text = ""
	_goleste_rezultat()
	_umple_statusuri()
	_actualizeaza_spin()

func _goleste_rezultat() -> void:
	for c in _rezultat.get_children():
		_rezultat.remove_child(c)
		c.queue_free()

# ---------------------------------------------------------------------------
# ÎNVÂRTIREA
# ---------------------------------------------------------------------------
func _spin() -> void:
	if _se_invarte or _pariu == null or _alese.is_empty():
		return
	_se_invarte = true
	_btn_spin.disabled = true
	_evid.visible = false
	_bila.visible = false
	_banner.text = ""
	_goleste_rezultat()

	# AICI se trage numărul — cinstit, înainte de orice animație: 0–36, toate la fel de probabile.
	var n := randi() % 37

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # jocul e pe pauză, animația trebuie să meargă
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_roata, "rotation", _roata.rotation + TAU * randf_range(4.0, 7.0), 2.8)
	tw.tween_callback(_arata_rezultat.bind(n))

func _arata_rezultat(n: int) -> void:
	var castigat := _castiga(_pariu, n)
	var culoare := _culoarea(n)

	# numărul ieșit, în butucul roții, pe fundalul culorii lui
	_bila.text = str(n)
	var sb := StyleBoxFlat.new()
	sb.bg_color = culoare
	sb.border_color = Color(0.95, 0.85, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(999)
	_bila.add_theme_stylebox_override("normal", sb)
	_bila.visible = true

	# evidențiem căsuța lui de pe masă
	_evid_rect = _rect_numar(n)
	_evid.visible = true

	# `tr(...)` explicit: textul e ASAMBLAT din bucăți, deci auto-translate n-ar avea ce cheie să
	# caute (ar căuta „25 RED — YOU LOSE"). Vezi i18n.gd. Numele culorii rămâne netradus, ca pe masă.
	_banner.text = "%s %s  —  %s" % [str(n), _nume_culoare(n), tr("YOU WIN!") if castigat else tr("YOU LOSE")]
	_banner.add_theme_color_override("font_color", Color(0.44, 0.86, 0.44) if castigat else Color(0.92, 0.38, 0.36))
	Audio.play("chest_anim" if castigat else "hurt", -2.0, 0.0)

	_aplica_pariul(castigat)
	_umple_statusuri()
	_se_invarte = false
	_actualizeaza_spin()
	_relayout()

# Câștigă pariul dacă a ieșit numărul `n`? Zero pierde la toate pariurile exterioare — ca la
# ruleta adevărată, ăsta e avantajul casei.
func _castiga(pariu: Dictionary, n: int) -> bool:
	match pariu["tip"]:
		"numar":
			return n == int(pariu["n"])
		"rosu":
			return n != 0 and ROSII.has(n)
		"negru":
			return n != 0 and not ROSII.has(n)
		"par":
			return n != 0 and n % 2 == 0
		"impar":
			return n != 0 and n % 2 == 1
		"jos":
			return n >= 1 and n <= JOS_MAXIM
		"sus":
			return n >= 19 and n <= 36
		"duzina":
			return n >= 1 and n <= 36 and (n - 1) / 12 == int(pariu["i"])
		"coloana":
			return n >= 1 and n <= 36 and n % 3 == int(pariu["m"])
	return false

func _culoarea(n: int) -> Color:
	if n == 0:
		return Color(0.10, 0.45, 0.20)
	return Color(0.78, 0.13, 0.13) if ROSII.has(n) else Color(0.12, 0.12, 0.12)

func _nume_culoare(n: int) -> String:
	if n == 0:
		return "GREEN"
	return "RED" if ROSII.has(n) else "BLACK"

# ---------------------------------------------------------------------------
# EFECTUL PE STATUSURI
# ---------------------------------------------------------------------------
func _aplica_pariul(castigat: bool) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	# Câștigul depinde de PARIU (număr plin 20×, duzină/coloană 3×, roșu/negru 2×), pierderea nu:
	# oricum ai pariat, pierzi jumătate.
	var f: float = _multiplicator(_pariu) if castigat else PIERDERE_MULT
	for s in STATS:
		if not _alese.has(s["id"]):
			continue
		var inainte := _afisare(p, s["id"])
		_aplica(p, s["id"], f)
		var dupa := _afisare(p, s["id"])
		var l := Label.new()
		l.text = "%s  %s → %s" % [tr(s["nume"]), inainte, dupa]   # tr() explicit: text asamblat
		# autowrap din același motiv ca la `_lbl_pariu`: fără el, un rând lung („Move Speed
		# 230 → 4600") își impune lățimea și scoate tot panoul din rama ornată.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.44, 0.86, 0.44) if castigat else Color(0.92, 0.38, 0.36))
		_rezultat.add_child(l)

# Valoarea de ACUM a unui status (număr brut, folosit ca să știm dacă e > 0).
func _valoare(p, id: String) -> float:
	match id:
		"damage":    return float(p.bullet_damage)
		"atkspeed":  return p.fire_interval
		"crit":      return p.crit_chance
		"proj":      return float(p.bullet_count)
		"pierce":    return float(p.pierce)
		"wsize":     return p.weapon_size_mult
		"knockback": return p.knockback
		"instakill": return p.instakill_chance
		"luck":      return p.luck
		"speed":     return p.speed
		"maxhp":     return float(p.max_hp)
		"regen":     return float(p.hp_regen)
		"dmgtaken":  return float(p.contact_damage)
	return 0.0

# Cum se scrie statusul pe ecran — aceleași formate ca în panoul din meniul de Level Up.
func _afisare(p, id: String) -> String:
	match id:
		"damage":    return str(p.bullet_damage)
		"atkspeed":  return "%.2f/s" % (1.0 / maxf(p.fire_interval, 0.01))
		"crit":      return "%d%%" % round(p.crit_chance_now() * 100.0)
		"proj":      return str(p.projectiles_total())
		"pierce":    return str(p.pierce)
		"wsize":     return "%d%%" % round(p.weapon_size_scale() * 100.0)
		"knockback": return str(int(round(p.knockback)))
		"instakill": return "%.1f%%" % (p.instakill_chance_now() * 100.0)
		"luck":      return ("%.1f" % p.luck).trim_suffix(".0")
		"speed":     return str(int(round(p.speed)))
		"maxhp":     return str(p.max_hp)
		"regen":     return "%d/s" % p.hp_regen
		"dmgtaken":  return str(p.contact_damage)
	return ""

# Înmulțește un status cu `f` — factorul vine deja calculat din `_aplica_pariul()`: la câștig e
# plata pariului (20× / 3× / 2×), la pierdere e 0,5.
#
# Plafoanele de jos NU sunt cosmetice: fără ele o pierdere te poate lăsa cu 0 proiectile (nu mai
# tragi deloc) sau cu 0 viață maximă (mori pe loc), adică jocul s-ar termina de la o rotire —
# altceva decât „pierzi jumătate din status".
func _aplica(p, id: String, f: float) -> void:
	match id:
		"damage":
			p.bullet_damage = maxi(1, _intreg(p.bullet_damage, f))
		"atkspeed":
			# aici mai MIC = mai bun, deci la câștig se împarte. `upgrade_fire_rate` schimbă ȘI
			# cronometrul de tragere — dacă scrii direct în `fire_interval`, cadența nu se schimbă.
			var nou := clampf(p.fire_interval / f, 0.02, 5.0)
			p.upgrade_fire_rate(nou / p.fire_interval)
		"crit":
			p.crit_chance *= f
		"proj":
			p.bullet_count = maxi(1, _intreg(p.bullet_count, f))
		"pierce":
			p.pierce = maxi(0, _intreg(p.pierce, f))
		"wsize":
			p.weapon_size_mult *= f
		"knockback":
			p.knockback *= f
		"instakill":
			p.instakill_chance = clampf(p.instakill_chance * f, 0.0, 1.0)
		"luck":
			p.luck *= f
		"speed":
			p.speed = clampf(p.speed * f, 60.0, 4000.0)
		"maxhp":
			# viața de acum se mută cu aceeași cantitate ca maximul (ca la `upgrade_max_hp`), dar
			# nu sub 1: o înjumătățire nu trebuie să te omoare, doar să te lase fragil.
			var nou_hp := maxi(10, _intreg(p.max_hp, f))
			var delta: int = nou_hp - p.max_hp
			p.max_hp = nou_hp
			p.hp = clampi(p.hp + delta, 1, p.max_hp)
		"regen":
			p.hp_regen = maxi(0, _intreg(p.hp_regen, f))
		"dmgtaken":
			# și aici mai mic = mai bun. Minimul 1 ca să nu ajungi invulnerabil la atingere.
			p.contact_damage = maxi(1, _intreg(p.contact_damage, 1.0 / f))

# Înmulțire pe numere ÎNTREGI: la câștig rotunjim normal, la pierdere TĂIEM în jos (1 → 0),
# altfel `round(1 * 0.5)` ar da tot 1 și un status pe 1 n-ar putea fi pierdut niciodată.
func _intreg(v: int, f: float) -> int:
	if f >= 1.0:
		return int(round(float(v) * f))
	return int(floor(float(v) * f))

# ---------------------------------------------------------------------------
# AȘEZAREA ÎN PAGINĂ (merge la orice rezoluție)
# ---------------------------------------------------------------------------
func _relayout() -> void:
	if _masa == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var pan_w: float = clampf(vp.x * 0.30, 260.0, 380.0)
	_panou.offset_left = -pan_w - 10.0
	_panou.offset_right = -10.0
	_panou.offset_top = 10.0
	_panou.offset_bottom = -10.0

	# masa se întinde cât încape în ce rămâne la stânga panoului, PĂSTRÂND proporțiile pozei
	var zona := Rect2(12.0, 56.0, maxf(80.0, vp.x - pan_w - 34.0), maxf(80.0, vp.y - 70.0))
	var s: float = minf(zona.size.x / TABLE_W, zona.size.y / TABLE_H)
	var dim := Vector2(TABLE_W, TABLE_H) * s
	_masa.position = zona.position + (zona.size - dim) * 0.5
	_masa.size = dim
	_aseaza_suprapuse(s)

# Roata, jetonul, evidențierea și numărul ieșit — singurele care nu merg pe ancore, fiindcă se
# mută în timpul jocului (jetonul) sau au nevoie de pivot pentru rotire (roata).
func _aseaza_suprapuse(s: float) -> void:
	var d := WHEEL_R * 2.0 * s
	_roata.position = (WHEEL_CENTER - Vector2(WHEEL_R, WHEEL_R)) * s
	_roata.size = Vector2(d, d)
	_roata.pivot_offset = Vector2(d, d) * 0.5

	var bw := 108.0 * s
	_bila.position = WHEEL_CENTER * s - Vector2(bw, bw) * 0.5
	_bila.size = Vector2(bw, bw)
	_bila.add_theme_font_size_override("font_size", int(maxf(14.0, 54.0 * s)))

	if _pariu != null:
		var c := (_pariu_rect.position + _pariu_rect.size * 0.5) * s
		var j: float = clampf(minf(_pariu_rect.size.x, _pariu_rect.size.y) * s * 0.95, 14.0, 90.0)
		_jeton.position = c - Vector2(j, j) * 0.5
		_jeton.size = Vector2(j, j)

	if _evid.visible:
		_evid.position = _evid_rect.position * s
		_evid.size = _evid_rect.size * s

# ---------------------------------------------------------------------------
# HELPERE de interfață (aceeași croială ca butoanele din meniul de pauză)
# ---------------------------------------------------------------------------
func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 54)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND))
	b.add_theme_stylebox_override("hover", _sb(BTN_MAIN.lightened(0.10), BTN_SECOND.lightened(0.10)))
	b.add_theme_stylebox_override("pressed", _sb(BTN_MAIN.lightened(0.20), BTN_SECOND.lightened(0.20)))
	b.add_theme_stylebox_override("disabled", _sb(BTN_MAIN.darkened(0.45), BTN_SECOND.darkened(0.35)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if cb.is_valid():
		b.pressed.connect(func(): Audio.play("button", -3.0, 0.0))
		b.pressed.connect(cb)
	return b

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _spatiu(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
