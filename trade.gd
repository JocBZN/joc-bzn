extends CanvasLayer

# MASA DE SCHIMB a statuii Ender (`ender_statue.gd`) — „negustorul" dimensiunii.
#
# Cum se leagă: apeși E pe statuie → `ender_statue.gd::invoca()` → `open(statuie)` de aici. Jocul
# se OPREȘTE (`get_tree().paused`), ca la Level Up și la cazinou, iar ecranul ăsta merge mai
# departe fiindcă nodul e pe `PROCESS_MODE_ALWAYS`. ESC (sau butonul Leave) pleacă fără schimb.
#
# Ce arată: `randuri` (3) dintre ITEMELE TALE, trase la întâmplare din registrul rundei
# (`player.run_items`), oricare le-ar fi raritatea — și, după o săgeată, CE POT DEVENI: un item
# tras la întâmplare din raritatea cu `trepte` (2) mai sus. **Alegi UN SINGUR rând** (scrie pe
# ecran), schimbul se face pe loc și masa se închide — o statuie face un singur schimb.
#
# PREȚUL: +`cost_procent`% dificultate, adică `Difficulty.add_trade_penalty()`. Vezi comentariile
# de la `Difficulty.trade_penalty` (de ce e multiplicator și nu secunde) și de la capul lui
# `ender_statue.gd` (de ce itemul dat dispare din registru, dar efectul lui îți rămâne).
#
# ---------------------------------------------------------------------------
# CUM ARATĂ (refăcut pe 2026-08-05: „vreau sa arate mai spooky, nu asa friendly... super
# profesional ca un joc deja scos pe Steam")
# ---------------------------------------------------------------------------
# Rama de lemn auriu (`Menu.png`) a plecat — ea era tot ce făcea ecranul prietenos. În locul ei,
# chenarele roșii ale lui Răzvan din `harta/Border Statuie Ender.png`: o PLANȘĂ de 5×4 chenare de
# 64×64, din care tăiem la rulare doar celulele care ne trebuie (vezi `_chenar`). Fiecare chenar
# are și interiorul lui aproape negru, deci ține loc și de ramă, și de fundal.
#
# Restul e disciplină de meniu comercial, nu decor:
#   · o singură culoare de accent (stacojiul artei) și una de text (os), nimic altceva;
#   · ierarhie clară pe mărime: titlu 36 → cost 22 → avertisment 17;
#   · rândurile sunt CADRE care se aprind la mouse (cenușiu → stacojiu plin, tween de 0.12s), nu dreptunghiuri
#     albe translucide — feedback-ul e din artă, nu peste ea;
#   · itemul pe care îl DAI e ținut la 70% opacitate, cel pe care îl PRIMEȘTI la 100%: se citește
#     dintr-o privire în ce direcție merge afacerea, fără să scrie nimeni „give" și „receive";
#   · titlul respiră încet (2.6s dus-întors) — cât să pară viu, nu cât să distragă.

const SHEET := "res://harta/Border Statuie Ender.png"
const CELULA := 64          # cât are o celulă din planșă

# Ce chenar din planșă folosim (coloană, rând), numărate de la 0 din stânga-sus.
const CH_PANOU := Vector2i(2, 0)    # colțuri în spirală + linie dublă — rama mare
const CH_RAND := Vector2i(1, 2)     # chenar subțire cu colțuri mici — un rând de ofertă

# Culorile luate din artă (stacojiul chenarelor) + un os pentru text.
const ACCENT := Color8(214, 64, 90)         # stacojiu aprins
const ACCENT_STINS := Color8(116, 30, 48)   # același, dat în întuneric
const OS_ALB := Color8(226, 218, 214)           # alb-os, pentru titlu și nume
const SANGE := Color8(206, 44, 44)          # roșu de preț
const CENUSA := Color8(150, 142, 148)       # gri stins, pentru avertisment

# Cum arată cadrul unui rând când NU e ales și când e. Nu e doar o diferență de transparență:
# la 0.45 alfa, stacojiul artei tot ieșea aprins pe negru și cele trei rânduri păreau la fel de
# vii — verificat pe captură. Așa, rândul neatins e TRAS SPRE CENUȘIU (înmulțire sub-unitară pe
# roșu/verde/albastru), deci pare piatră stinsă, iar cel de sub mouse revine la culoarea plină și
# chiar „se aprinde".
const RAND_STINS := Color(0.46, 0.40, 0.44, 0.92)
const RAND_APRINS := Color(1.0, 1.0, 1.0, 1.0)

# ⚠️ TOATE cifrele de mai jos sunt în pixeli de ECRAN DE BAZĂ, adică 1152×648 (Godot desenează la
# rezoluția asta și întinde apoi imaginea — vezi `window/stretch/mode` din `project.godot`). Deci
# panoul trebuie să încapă în 1152×648, nu în rezoluția monitorului. Prima variantă avea 960×672
# și îi ieșeau colțurile de sus și de jos din ecran, exact fiindcă 672 > 648.
const PANOU_W := 940.0
const PANOU_H := 592.0
const CELL := 88.0          # cât de mare e o celulă de border+iconiță
const TEXT_W := 205.0       # lățimea coloanei de text a unui item
const RAND_H := 110.0       # înălțimea unui rând de ofertă

var _statuie: Node = null
var _perechi := []      # câte una pe rând: {"idx": poziția în run_items, "de_la": item, "la": item}
var _randuri := []      # nodurile fiecărui rând, ca să le umplem în `open`
var _cost_lbl: Label
var _sheet: Image = null

func _ready() -> void:
	add_to_group("trade_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS   # merge și cât jocul e înghețat
	layer = 10                                # ca ecranul de Level Up
	visible = false

	# Negru aproape total, COMPLET opac. La 0.985 (cât are cazinoul) prin fundal răzbătea
	# cronometrul Ender-ului — 64px de albastru aprins — și arăta a bug.
	var overlay := ColorRect.new()
	overlay.color = Color8(8, 6, 10)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var pw := PANOU_W
	var ph := PANOU_H
	var panel := _cadru(CH_PANOU, 16)
	panel.custom_minimum_size = Vector2(pw, ph)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -pw / 2.0
	panel.offset_right = pw / 2.0
	panel.offset_top = -ph / 2.0
	panel.offset_bottom = ph / 2.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ENDER TRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", OS_ALB)
	# contur STACOJIU, nu negru: la un titlu alb pe negru, conturul roșu ține loc de aureolă și
	# leagă textul de rama artei, fără shader și fără font nou.
	title.add_theme_color_override("font_outline_color", ACCENT_STINS)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	# respiră încet, ca lumina unei lumânări
	var puls := create_tween().set_loops()
	puls.tween_property(title, "modulate:a", 0.72, 1.3).set_trans(Tween.TRANS_SINE)
	puls.tween_property(title, "modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE)

	box.add_child(_linie(360.0, 10))

	# prețul — singurul lucru roșu-sânge de pe ecran, ca să nu poată fi ratat
	_cost_lbl = Label.new()
	_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_lbl.add_theme_font_size_override("font_size", 22)
	_cost_lbl.add_theme_color_override("font_color", SANGE)
	_contur(_cost_lbl)
	box.add_child(_cost_lbl)

	var avertisment := Label.new()
	avertisment.text = "You can only choose one"
	avertisment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avertisment.add_theme_font_size_override("font_size", 17)
	avertisment.add_theme_color_override("font_color", CENUSA)
	_contur(avertisment)
	box.add_child(avertisment)

	box.add_child(_spatiu(10))

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	box.add_child(lista)
	for i in 3:
		lista.add_child(_fa_rand(i))

	# Spațiul care se întinde: împinge butonul de plecare la baza panoului, oricâte rânduri ar
	# avea oferta. Fără el, un jucător cu un singur item ar fi avut butonul lipit sub primul rând.
	var umplut := _spatiu(4)
	umplut.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(umplut)

	var jos := HBoxContainer.new()
	jos.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(jos)
	jos.add_child(_buton("Leave", _inchide))

# ---------------------------------------------------------------------------
# CĂRĂMIZILE DE ASPECT
# ---------------------------------------------------------------------------
# Un chenar din planșă, gata de întins (nine-patch). Celula se decupează la rulare din PNG și se
# face textură proprie: `NinePatchRect` vrea o textură întreagă, iar un `AtlasTexture` nu e de
# încredere aici. `margine` = câți pixeli din margine NU se întind (colțurile ornamentate).
func _cadru(celula: Vector2i, margine: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _chenar(celula)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = margine * ZOOM
	np.patch_margin_right = margine * ZOOM
	np.patch_margin_top = margine * ZOOM
	np.patch_margin_bottom = margine * ZOOM
	return np

# ⚠️ Celula se MĂREȘTE de `ZOOM` ori (cu vecinul cel mai apropiat, deci rămâne pixel art curat)
# înainte să ajungă textură. Motivul e că nine-patch-ul ÎNTINDE doar mijlocul laturilor, nu și
# grosimea lor: o celulă de 64px pusă pe un panou de 940 lăsa linii de 1px, care la ecran arătau
# ca un chenar desenat cu pixul. Mărită întâi la 128, linia are 2px și rama capătă greutate.
const ZOOM := 2

func _chenar(celula: Vector2i) -> ImageTexture:
	if _sheet == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet = tex.get_image()
	var bucata := _sheet.get_region(Rect2i(celula.x * CELULA, celula.y * CELULA, CELULA, CELULA))
	bucata.resize(CELULA * ZOOM, CELULA * ZOOM, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bucata)

# Linia subțire de sub titlu. Se stinge spre capete (trei bucăți cu alfa diferit), ca să nu arate
# ca o bară desenată cu rigla peste artă.
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

func _spatiu(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# Un rând: [chenar de raritate + iconiță | raritate + nume]  ➜  [același, pentru ce primești],
# totul într-un cadru din planșă care se aprinde când treci cu mouse-ul peste el.
func _fa_rand(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, RAND_H)
	b.flat = true
	for stare in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(stare, StyleBoxEmpty.new())

	var cadru := _cadru(CH_RAND, 14)
	cadru.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cadru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadru.modulate = RAND_STINS      # cenușiu cât nu-l atingi
	b.add_child(cadru)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)

	var nod := {"cadru": cadru}
	_umple_jumatate(hb, nod, "a", 0.7)   # ce dai — ținut mai stins

	var sageata := Label.new()
	sageata.text = "➜"
	sageata.custom_minimum_size = Vector2(64, 0)
	sageata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sageata.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sageata.add_theme_font_size_override("font_size", 32)
	sageata.add_theme_color_override("font_color", ACCENT)
	sageata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(sageata)
	hb.add_child(sageata)

	_umple_jumatate(hb, nod, "b", 1.0)   # ce primești — la putere maximă

	b.pressed.connect(_alege.bind(i))
	b.mouse_entered.connect(_aprinde.bind(cadru, RAND_APRINS))
	b.mouse_exited.connect(_aprinde.bind(cadru, RAND_STINS))
	b.focus_entered.connect(_aprinde.bind(cadru, RAND_APRINS))
	b.focus_exited.connect(_aprinde.bind(cadru, RAND_STINS))
	nod["buton"] = b
	_randuri.append(nod)
	return b

func _aprinde(cadru: NinePatchRect, catre: Color) -> void:
	if not is_instance_valid(cadru):
		return
	var t := cadru.create_tween()
	t.tween_property(cadru, "modulate", catre, 0.12)

# O jumătate de rând (itemul tău sau cel primit). `cheie` = "a" ori "b".
func _umple_jumatate(hb: HBoxContainer, nod: Dictionary, cheie: String, opacitate: float) -> void:
	var grup := HBoxContainer.new()
	grup.add_theme_constant_override("separation", 10)
	grup.modulate.a = opacitate
	grup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(grup)

	var cell := Control.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grup.add_child(cell)

	var border := TextureRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(border)
	nod["border_" + cheie] = border

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 13
	icon.offset_top = 13
	icon.offset_right = -13
	icon.offset_bottom = -13
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	nod["icon_" + cheie] = icon

	var text := VBoxContainer.new()
	text.custom_minimum_size = Vector2(TEXT_W, 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grup.add_child(text)

	var rar := Label.new()
	rar.add_theme_font_size_override("font_size", 15)
	rar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(rar)
	text.add_child(rar)
	nod["rar_" + cheie] = rar

	var nume := Label.new()
	nume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nume.add_theme_font_size_override("font_size", 21)
	nume.add_theme_color_override("font_color", OS_ALB)
	nume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(nume)
	text.add_child(nume)
	nod["nume_" + cheie] = nume

# ---------------------------------------------------------------------------
# DESCHIDERE / ÎNCHIDERE
# ---------------------------------------------------------------------------
func open(statuie: Node) -> void:
	if visible or statuie == null:
		return
	_statuie = statuie
	_perechi = _fa_oferta()
	if _perechi.is_empty():
		return                      # n-are ce oferi → nici nu deschidem masa
	_cost_lbl.text = tr("Cost: +%d%% difficulty") % int(round(_cost()))
	for i in _randuri.size():
		var nod: Dictionary = _randuri[i]
		var are := i < _perechi.size()
		nod["buton"].visible = are
		if not are:
			continue
		nod["cadru"].modulate = RAND_STINS   # rândurile pornesc stinse la fiecare deschidere
		var per: Dictionary = _perechi[i]
		_pune_item(nod, "a", per["de_la"])
		_pune_item(nod, "b", per["la"])
	visible = true
	get_tree().paused = true
	Audio.pause_forest_ambient()
	Audio.play("levelup", -4.0, 0.0)

func _inchide() -> void:
	visible = false
	_statuie = null
	_perechi = []
	get_tree().paused = false
	Audio.resume_forest_ambient()

# ESC = pleci fără schimb. ⚠️ `pause.gd::_blocked()` ne întreabă și pe noi, ca să nu se deschidă
# meniul de pauză PESTE masă (aceeași grijă ca la cazinou).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_inchide()

# ---------------------------------------------------------------------------
# OFERTA
# ---------------------------------------------------------------------------
# Trage `randuri` POZIȚII DIFERITE din registrul rundei (nu id-uri diferite: dacă ai luat Beer de
# două ori, ai două beri de schimbat, și e cinstit să le vezi pe amândouă). Pentru fiecare caută
# un item cu `trepte` rarități mai sus. Rândurile fără pereche (raritate goală) se sar.
func _fa_oferta() -> Array:
	var p = get_tree().get_first_node_in_group("player")
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if p == null or lu == null or not ("run_items" in p):
		return []
	var libere := range(p.run_items.size())
	libere.shuffle()
	var out := []
	for idx in libere:
		if out.size() >= _randuri_cerute():
			break
		var de_la = lu.item_dupa_id(String(p.run_items[idx]))
		if de_la == null:
			continue
		var tinta: String = lu.raritate_mai_sus(String(de_la["rar"]), _trepte())
		var la = lu.item_random_de_raritate(tinta, [String(de_la["id"])])
		if la == null:
			continue
		out.append({"idx": idx, "de_la": de_la, "la": la})
	return out

func _pune_item(nod: Dictionary, cheie: String, u) -> void:
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	var rar: Dictionary = lu.RARITIES.get(u.get("rar", "common"), lu.RARITIES["common"])
	nod["border_" + cheie].texture = load("res://Upgrades/Menu UI/" + String(rar["border"]))
	nod["icon_" + cheie].texture = load(lu.icon_path(u))
	nod["rar_" + cheie].text = String(rar["nume"]).to_upper()
	nod["rar_" + cheie].add_theme_color_override("font_color", rar["color"])
	nod["nume_" + cheie].text = u["nume"]

# ---------------------------------------------------------------------------
# SCHIMBUL
# ---------------------------------------------------------------------------
func _alege(i: int) -> void:
	if not visible or i >= _perechi.size():
		return
	var p = get_tree().get_first_node_in_group("player")
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if p == null or lu == null:
		_inchide()
		return
	var per: Dictionary = _perechi[i]

	# Întâi scoatem itemul dat din registru, apoi îl dăm pe cel nou: `da_item` ADAUGĂ în aceeași
	# listă (prin `_apply`), iar dacă inversam ordinea indicele memorat ar fi rămas valid, dar
	# raționamentul ar fi depins de asta. Așa nu depinde.
	var idx := int(per["idx"])
	if idx >= 0 and idx < p.run_items.size():
		p.run_items.remove_at(idx)
	lu.da_item(per["la"], p)

	# prețul: +15% dificultate, pe loc și pe tot restul rundei
	Difficulty.add_trade_penalty(_cost() / 100.0)
	if _statuie != null and is_instance_valid(_statuie) and _statuie.has_method("consuma"):
		_statuie.consuma()
	Audio.play("teleport", -6.0, 0.0)
	_anunta()
	_inchide()

func _anunta() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("THE STATUE TAKES ITS PRICE", "The world grows harsher")

# --- reglajele vin de pe statuia pe care ai apăsat (fiecare poate avea altele) ---

func _cost() -> float:
	if _statuie != null and is_instance_valid(_statuie):
		return float(_statuie.cost_procent)
	return 15.0

func _trepte() -> int:
	if _statuie != null and is_instance_valid(_statuie):
		return int(_statuie.trepte)
	return 2

func _randuri_cerute() -> int:
	if _statuie != null and is_instance_valid(_statuie):
		return mini(int(_statuie.randuri), _randuri.size())
	return _randuri.size()

func _contur(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)

# Butonul de plecare: piatră întunecată cu muchie stacojie, nu lemnul cald din meniu.
func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 48)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", OS_ALB)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _sb(Color8(22, 18, 26), ACCENT_STINS))
	b.add_theme_stylebox_override("hover", _sb(Color8(38, 20, 30), ACCENT))
	b.add_theme_stylebox_override("pressed", _sb(Color8(52, 24, 36), ACCENT))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
