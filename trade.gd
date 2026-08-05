extends CanvasLayer

# MASA DE SCHIMB a statuii Ender (`ender_statue.gd`) — „negustorul" dimensiunii.
#
# Cum se leagă: apeși E pe statuie → `ender_statue.gd::invoca()` → `open(statuie)` de aici. Jocul
# se OPREȘTE (`get_tree().paused`), ca la Level Up și la cazinou, iar ecranul ăsta merge mai
# departe fiindcă nodul e pe `PROCESS_MODE_ALWAYS`. ESC (sau butonul Leave) pleacă fără schimb.
#
# Ce arată: `randuri` (3) dintre ITEMELE TALE, trase la întâmplare din registrul rundei
# (`player.run_items`), oricare le-ar fi raritatea — și, după o săgeată, CE POT DEVENI: un item
# tras la întâmplare din raritatea cu `trepte` (2) mai sus. Alegi un rând, schimbul se face pe loc
# și masa se închide: o statuie face un singur schimb (motivul e în `ender_statue.gd`).
#
# PREȚUL e în DIFICULTATE, nu în altceva: `Difficulty.add_penalty(cost)`. Vezi comentariile de la
# `Difficulty.penalty` (de ce nu intră în ceasul de pe ecran) și de la capul lui `ender_statue.gd`
# (de ce itemul dat dispare din registru, dar efectul lui îți rămâne).
#
# Ecranul e construit TOT din cod, ca `levelup.gd` și `casino.gd` — aceleași cărămizi: rama
# `Menu.png` întinsă nine-patch, border-ul rarității cu iconița în el, auriul ramei pe titluri.

const MENU_UI_DIR := "res://Upgrades/Menu UI/"
const ACCENT := Color(0.95, 0.85, 0.55)      # auriul ramei (ca în levelup.gd / pause.gd)
const COST_COLOR := Color(0.92, 0.38, 0.36)  # roșul „mai rău pentru tine" din panoul de statusuri
const BTN_MAIN := Color("9e603f")            # lemnul butoanelor din meniu
const BTN_SECOND := Color("594232")
const CELL := 96.0                            # cât de mare e o celulă de border+iconiță
const TEXT_W := 208.0                         # lățimea coloanei de text a unui item

var _statuie: Node = null
var _perechi := []      # câte una pe rând: {"idx": poziția în run_items, "de_la": item, "la": item}
var _randuri := []      # nodurile fiecărui rând, ca să le umplem în `open`
var _subtitlu: Label

func _ready() -> void:
	add_to_group("trade_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS   # merge și cât jocul e înghețat
	layer = 10                                # ca ecranul de Level Up
	visible = false

	var overlay := ColorRect.new()
	# COMPLET opac, nu „aproape". La 0.985 (cât are cazinoul) prin fundal răzbătea cronometrul
	# Ender-ului — 64px de albastru aprins cu contur de 9px, chiar în capul mesei: 1,5% dintr-un
	# text atât de mare se vede ca o fantomă și arată a bug. Aici nu e nimic de lăsat să se vadă:
	# jocul e oprit, iar dedesubt e o nebuloasă zgomotoasă. (Aceeași alegere ca la „YOU DIED".)
	overlay.color = Color(0.06, 0.05, 0.10, 1.0)   # violetul întunecat al nebuloasei
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var pw := 900.0
	var ph := 600.0
	var panel := NinePatchRect.new()
	panel.texture = load(MENU_UI_DIR + "Menu.png")
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.patch_margin_left = 46
	panel.patch_margin_right = 46
	panel.patch_margin_top = 46
	panel.patch_margin_bottom = 46
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
	margin.add_theme_constant_override("margin_top", 62)   # sub rama de sus, ca la levelup.gd
	margin.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ENDER TRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", ACCENT)
	_contur(title)
	box.add_child(title)

	# Prețul, scris o dată, sus: se citește mai bine decât dacă îl repetam pe fiecare rând.
	_subtitlu = Label.new()
	_subtitlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitlu.add_theme_font_size_override("font_size", 20)
	_subtitlu.add_theme_color_override("font_color", COST_COLOR)
	_contur(_subtitlu)
	box.add_child(_subtitlu)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	box.add_child(lista)
	for i in 3:
		lista.add_child(_fa_rand(i))

	var jos := HBoxContainer.new()
	jos.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(jos)
	jos.add_child(_buton("Leave", _inchide))

# Un rând: [border+iconiță | raritate+nume]  ➜  [border+iconiță | raritate+nume]
func _fa_rand(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, CELL + 8)
	b.flat = true
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _hover(0.10))
	b.add_theme_stylebox_override("pressed", _hover(0.18))
	b.add_theme_stylebox_override("focus", _hover(0.08))
	b.pressed.connect(_alege.bind(i))

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)

	var nod := {}
	_umple_jumatate(hb, nod, "a")

	# săgeata dintre cele două iteme — „ce poate deveni"
	var sageata := Label.new()
	sageata.text = "➜"
	sageata.custom_minimum_size = Vector2(56, 0)
	sageata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sageata.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sageata.add_theme_font_size_override("font_size", 40)
	sageata.add_theme_color_override("font_color", ACCENT)
	sageata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(sageata)
	hb.add_child(sageata)

	_umple_jumatate(hb, nod, "b")
	nod["buton"] = b
	_randuri.append(nod)
	return b

# O jumătate de rând (itemul tău sau cel primit). `cheie` = "a" ori "b".
func _umple_jumatate(hb: HBoxContainer, nod: Dictionary, cheie: String) -> void:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(cell)

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
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(text)

	var rar := Label.new()
	rar.add_theme_font_size_override("font_size", 16)
	rar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(rar)
	text.add_child(rar)
	nod["rar_" + cheie] = rar

	var nume := Label.new()
	nume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nume.add_theme_font_size_override("font_size", 22)
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
	_subtitlu.text = tr("Each trade: +%ds difficulty") % int(round(_cost()))
	for i in _randuri.size():
		var nod: Dictionary = _randuri[i]
		var are := i < _perechi.size()
		nod["buton"].visible = are
		if not are:
			continue
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
	nod["border_" + cheie].texture = load(MENU_UI_DIR + rar["border"])
	nod["icon_" + cheie].texture = load(lu.icon_path(u))
	nod["rar_" + cheie].text = rar["nume"]
	nod["rar_" + cheie].add_theme_color_override("font_color", rar["color"])
	nod["nume_" + cheie].text = u["nume"]
	nod["nume_" + cheie].add_theme_color_override("font_color", rar["color"])

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

	# prețul: dificultate, pe loc și pe tot restul rundei
	Difficulty.add_penalty(_cost())
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
		return float(_statuie.cost_dificultate)
	return 15.0

func _trepte() -> int:
	if _statuie != null and is_instance_valid(_statuie):
		return int(_statuie.trepte)
	return 2

func _randuri_cerute() -> int:
	if _statuie != null and is_instance_valid(_statuie):
		return mini(int(_statuie.randuri), _randuri.size())
	return _randuri.size()

# --- cărămizi de aspect (aceleași ca în levelup.gd / casino.gd) ---

func _contur(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)

func _hover(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(8)
	return sb

func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 50)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND))
	b.add_theme_stylebox_override("hover", _sb(BTN_MAIN.lightened(0.10), BTN_SECOND.lightened(0.10)))
	b.add_theme_stylebox_override("pressed", _sb(BTN_MAIN.lightened(0.20), BTN_SECOND.lightened(0.20)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
