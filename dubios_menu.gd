extends CanvasLayer

# MENIUL DUBIOSULUI — cele 3 iteme pe care ți le scoate omul în palton (`dubiosu.gd`) când apeși
# E pe el. Arată ca ecranul de Level Up, dar cu chenarele lui verzi și cu ALTE iteme: cele patru
# de aici NU există în tragerea de la level up, în cufere, în cazinou sau la statuia Ender.
#
# Cum se leagă: E pe om → `dubiosu.gd::invoca()` → `open()` de aici. Jocul se OPREȘTE
# (`get_tree().paused`), iar meniul merge mai departe fiindcă nodul e `PROCESS_MODE_ALWAYS`.
# Un om îți scoate marfa o SINGURĂ dată (vezi `dubiosu.gd::consuma`).
#
# ⚠️ Toate patru sunt de ACEEAȘI calitate, iar calitatea aia NU se scrie nicăieri pe ecran (cerut
# de Răzvan) — de aia cartonașele n-au rând de raritate, spre deosebire de cele de la level up.
# Tot de aia nu există nici câmp „rar" în lista de mai jos: „aceeași calitate" înseamnă, la
# Arcane Magic, „tot din lista asta", și n-are nevoie de un nume ca s-o știe.
#
# ⚠️ Itemele astea sunt INVIZIBILE pentru cazinou (`casino.gd`) și pentru masa de schimb a
# statuii Ender (`trade.gd`): amândouă caută id-ul cu `levelup.item_dupa_id`, care întoarce null
# pentru ele, și sar peste. Așa și trebuie — nu se pariază și nu se schimbă pe altceva.

const ICON_DIR := "res://harta/Upgrade Dubios/"

# "desc" = ce scrie sub nume. Efectele reale sunt în `_apply`.
var UPGRADES := [
	{"id": "cursed_tome", "nume": "Cursed Tome", "icon": "Upgrade Dubios 1.png",
		"desc": "Increase Spawnrate by 25%"},
	{"id": "iron_helmet", "nume": "Iron Helmet", "icon": "Upgrade Dubios 2.png",
		"desc": "Take 100% Less Damage, Deal 25% Less Damage"},
	{"id": "blame_circle", "nume": "Blame Circle", "icon": "Upgrade Dubios 3.png",
		"desc": "Double one random stat, -25% of a random stat"},
	{"id": "arcane_magic", "nume": "Arcane Magic", "icon": "Upgrade Dubios 4.png",
		"desc": "Reset all your items with ones of the same quality"},
]

# Statusurile pe care le poate atinge Blame Circle. Numele sunt EXACT cele din panoul de statusuri
# (`player.stat_lines`), deci se traduc singure și îți spun în aceiași termeni ce ai pățit.
#
# ⚠️ Sunt doar statusuri care NU pot fi zero la începutul rundei. Crit și Luck pornesc de la 0, iar
# „dublu" din 0 tot 0 face — ai fi luat un item care nu face nimic și ai fi crezut că e stricat.
const BLAME_STATS := ["Damage", "Attack Speed", "Move Speed", "Max HP", "Weapon Size"]
const BLAME_UP := 2.0     # „double one random stat"
const BLAME_DOWN := 0.75  # „-25% of a random stat"

# ---------------------------------------------------------------------------
# ASPECTUL
# ---------------------------------------------------------------------------
# Aceeași construcție ca la `levelup.gd` (citește acolo de ce arată așa), doar că planșa de
# chenare e cea din folderul dubiosului. E tot 5×4 celule de 64px, deci se taie la fel.
#
# ⚠️ Verdele e MĂSURAT din planșă, nu ales din ochi: culoarea care apare de cele mai multe ori pe
# chenare e #2C8A4D, iar fundalul lor #201E26. Schimbi arta → măsoară din nou (regula casei, vezi
# `casino.gd`).
const SHEET := "res://harta/Upgrade Dubios/Border Dubios.png"
const CELULA_FOAIE := 64
const ZOOM := 2
const CH_PANOU := Vector2i(2, 0)   # colțuri rotunjite cu bumbi — panoul mare
const CH_CARD := Vector2i(1, 2)    # chenar subțire — un cartonaș
const CH_ITEM := Vector2i(4, 0)    # chenarul din jurul iconiței (ține locul rarității de la level up)
# ⚠️ NU folosi celulele (0,1) și (0,3): au pătrate ALBE în colțuri (marcaje de planșă).
const RAMA_PANOU := 16
const RAMA_CARD := 14
const RAMA_ITEM := 14

const ACCENT := Color8(44, 138, 77)
const ACCENT_CLAR := Color8(120, 214, 150)
const ACCENT_STINS := Color8(20, 66, 44)
const OS_ALB := Color8(232, 224, 214)
const CENUSA := Color8(150, 142, 138)
const FUNDAL := Color8(32, 30, 38)

const CELL := 88.0         # latura chenarului cu iconița
const PANOU_W := 700.0
const PANOU_H := 512.0
const CARD_H := 116.0

const CARD_REPAUS := Color(0.62, 0.60, 0.62)
const CARD_HOVER := Color(1, 1, 1)

# Cât stă meniul deschis după ce alegi un item care are ceva de POVESTIT (Blame Circle spune ce
# stat a dublat, Arcane Magic câte iteme a schimbat). Fără pauza asta ecranul se închidea exact
# în clipa în care apărea singurul text care explica ce s-a întâmplat.
const PAUZA_REZULTAT := 1.8

var _buttons := []
var _cards := []
var _icons := []
var _name_labels := []
var _desc_labels := []
var _current := []
var _lbl_rezultat: Label
var _npc: Node = null
var _sheet: Image = null
var _asteapta := false     # cât se citește rezultatul: nu mai primim click-uri

func _ready() -> void:
	add_to_group("dubios_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12                # peste HUD și Level Up (10), sub meniul de pauză (15)
	visible = false

	var overlay := ColorRect.new()
	overlay.color = Color(FUNDAL.r, FUNDAL.g, FUNDAL.b, 0.975)
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
	_asteapta = false
	_lbl_rezultat.text = ""
	_show_choices()
	visible = true
	get_tree().paused = true
	Audio.pause_forest_ambient()
	Audio.play("levelup", -4.0, 0.0)

func _inchide() -> void:
	visible = false
	_asteapta = false
	get_tree().paused = false
	Audio.resume_forest_ambient()

# ⚠️ Ca să nu se deschidă meniul de pauză PESTE noi, `pause.gd::_blocked()` întreabă și de grupul
# „dubios_menu".
#
# ESC NU închide meniul, spre deosebire de Alba-Neagra: acolo poți pleca fără să joci, aici omul
# s-a consumat deja când a scos marfa, deci un ESC ar fi însemnat un om irosit din greșeală.
# Trebuie să alegi.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# INTERFAȚA
# ---------------------------------------------------------------------------
func _build() -> void:
	var panel := _cadru(CH_PANOU, RAMA_PANOU)
	panel.custom_minimum_size = Vector2(PANOU_W, PANOU_H)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANOU_W / 2.0
	panel.offset_right = PANOU_W / 2.0
	panel.offset_top = -PANOU_H / 2.0
	panel.offset_bottom = PANOU_H / 2.0
	add_child(panel)

	# ⚠️ Marginile trebuie să treacă de grosimea ramei desenate (16 × ZOOM = 32), altfel
	# conținutul se urcă pe ornament.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SHADY DEAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", OS_ALB)
	title.add_theme_color_override("font_outline_color", ACCENT_STINS)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	box.add_child(_linie(300.0, 12))

	# Rândul de sub linie are DOUĂ vieți: cât alegi scrie „Choose one", iar după ce ai ales scrie
	# ce ți-a ieșit (Blame Circle, Arcane Magic). Un al doilea rând, gol tot timpul cât alegi, ar
	# fi lăsat o gaură în panou.
	_lbl_rezultat = Label.new()
	_lbl_rezultat.text = "Choose one"
	_lbl_rezultat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_rezultat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_rezultat.add_theme_font_size_override("font_size", 16)
	_lbl_rezultat.add_theme_color_override("font_color", CENUSA)
	_add_outline(_lbl_rezultat)
	box.add_child(_lbl_rezultat)

	var spatiu := Control.new()
	spatiu.custom_minimum_size = Vector2(0, 12)
	spatiu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spatiu)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	box.add_child(list)
	for i in 3:
		list.add_child(_make_row(i))

func _make_row(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, CARD_H)
	b.flat = true
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_on_choice.bind(i))
	b.mouse_entered.connect(_hover.bind(i, true))
	b.mouse_exited.connect(_hover.bind(i, false))
	b.focus_entered.connect(_hover.bind(i, true))
	b.focus_exited.connect(_hover.bind(i, false))
	_buttons.append(b)

	var cadru := _cadru(CH_CARD, RAMA_CARD)
	cadru.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cadru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadru.modulate = CARD_REPAUS
	b.add_child(cadru)
	_cards.append(cadru)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hb)

	# celula cu iconița. La level up chenarul ei spune raritatea; aici raritatea nu se scrie, deci
	# chenarul e mereu același — o celulă din aceeași planșă, ca să nu plutească iconița în aer.
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(cell)

	var rama := _cadru(CH_ITEM, RAMA_ITEM)
	rama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(rama)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 17
	icon.offset_top = 17
	icon.offset_right = -17
	icon.offset_bottom = -17
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	_icons.append(icon)

	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(text)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 25)
	name_lbl.add_theme_color_override("font_color", OS_ALB)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(name_lbl)
	text.add_child(name_lbl)
	_name_labels.append(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 17)
	desc_lbl.add_theme_color_override("font_color", CENUSA)
	desc_lbl.max_lines_visible = 2
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(desc_lbl)
	text.add_child(desc_lbl)
	_desc_labels.append(desc_lbl)

	return b

func _hover(i: int, pornit: bool) -> void:
	if i < 0 or i >= _cards.size() or _asteapta:
		return
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_cards[i], "modulate", CARD_HOVER if pornit else CARD_REPAUS, 0.12)
	_name_labels[i].add_theme_color_override("font_color", Color(1, 1, 1) if pornit else OS_ALB)

# ---------------------------------------------------------------------------
# ALEGEREA
# ---------------------------------------------------------------------------
# Trei din patru, la întâmplare. Nu se trage pe raritate ca la level up (`_trage_raritate`):
# toate patru sunt de aceeași calitate, deci toate au aceeași șansă.
func _show_choices() -> void:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	_current = pool.slice(0, 3)
	for i in 3:
		var u = _current[i]
		_icons[i].texture = load(ICON_DIR + String(u["icon"]))
		_cards[i].modulate = CARD_REPAUS
		_name_labels[i].add_theme_color_override("font_color", OS_ALB)
		_buttons[i].tooltip_text = String(u["nume"])
		_buttons[i].disabled = false
		_name_labels[i].text = String(u["nume"])
		_desc_labels[i].text = String(u["desc"])
	_lbl_rezultat.text = "Choose one"
	_lbl_rezultat.add_theme_color_override("font_color", CENUSA)

func _on_choice(index: int) -> void:
	if _asteapta or index < 0 or index >= _current.size():
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		_inchide()
		return
	var mesaj := _apply(String(_current[index]["id"]), p)
	Audio.play("chest_anim", -3.0, 0.0)
	if mesaj == "":
		_inchide()
		return
	# Itemul are ceva de spus: îngheață cartonașele și lasă textul pe ecran o clipă.
	_asteapta = true
	for b in _buttons:
		b.disabled = true
	_lbl_rezultat.text = mesaj
	_lbl_rezultat.add_theme_color_override("font_color", ACCENT_CLAR)
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # jocul e pe pauză, altfel n-ar curge
	t.tween_interval(PAUZA_REZULTAT)
	t.tween_callback(_inchide)

# ---------------------------------------------------------------------------
# EFECTELE
# ---------------------------------------------------------------------------
# Întoarce textul care se arată după alegere, sau "" dacă itemul n-are nimic de povestit (ce face
# scrie deja pe cartonaș).
#
# Registrul rundei (`player.run_items`) se scrie ȘI de aici, exact ca în `levelup.gd::_apply` —
# altfel Arcane Magic n-ar ști că ai luat vreodată itemele astea.
func _apply(id: String, p) -> String:
	if p != null and "run_items" in p:
		p.run_items.append(id)
	match id:
		"cursed_tome":
			# mai mulți inamici pe secundă: și mai mult XP, și mai multe dinți. Se compune, deci
			# două tomuri fac ×1.5625, nu ×1.5.
			p.spawn_rate_mult *= 1.25
			return ""
		"iron_helmet":
			# ⚠️ „Take 100% Less Damage" e chiar 100%: cu casca pe cap nu mai încasezi NIMIC (vezi
			# `player.take_damage`). Dacă vrei doar o reducere, pune aici cât să rămână — 0.25
			# înseamnă „încasezi un sfert". Prețul e damage-ul tău, care se compune la fiecare
			# luare (0.75 × 0.75 = 0.5625 la a doua cască).
			p.damage_taken_mult = 0.0
			p.damage_dealt_mult *= 0.75
			return ""
		"blame_circle":
			return _blame_circle(p)
		"arcane_magic":
			return _arcane_magic(p)
	return ""

# Blame Circle: un stat se dublează, altul scade cu 25%. Cele două sunt mereu DIFERITE — altfel
# ai fi putut nimeri „dublu și minus 25% pe damage", adică un item care face ×1.5 pe un singur
# rând și pare că nu s-a întâmplat nimic.
func _blame_circle(p) -> String:
	var lista := BLAME_STATS.duplicate()
	lista.shuffle()
	var sus: String = lista[0]
	var jos: String = lista[1]
	_scaleaza_stat(p, sus, BLAME_UP)
	_scaleaza_stat(p, jos, BLAME_DOWN)
	# tr() explicit: textul e ASAMBLAT, deci nici el, nici numele statusurilor din el nu mai trec
	# singure prin traducere (vezi i18n.gd).
	return tr("%s doubled, %s down 25%%") % [tr(sus), tr(jos)]

# Înmulțește un status cu `f`. Numele sunt cele din panoul de statusuri, ca să se potrivească cu
# ce scrie pe ecran după aceea.
#
# ⚠️ Attack Speed merge INVERS: statul din player e pauza dintre lovituri, deci „de două ori mai
# multe lovituri pe secundă" înseamnă jumătate de pauză. De aia se împarte, nu se înmulțește.
func _scaleaza_stat(p, stat: String, f: float) -> void:
	match stat:
		"Damage":
			p.bullet_damage = maxi(1, int(round(p.bullet_damage * f)))
		"Attack Speed":
			p.upgrade_fire_rate(1.0 / f)
		"Move Speed":
			# aceeași plasă ca la restul jocului: sub 60 nu mai poți fugi de nimic
			p.speed = maxf(60.0, p.speed * f)
		"Max HP":
			var nou := maxi(10, int(round(p.max_hp * f)))
			var delta: int = nou - p.max_hp
			if delta > 0:
				p.upgrade_max_hp(delta)   # te și vindecă cu cât a crescut, ca la Beer
			else:
				p.max_hp = nou
				p.hp = mini(p.hp, p.max_hp)
		"Weapon Size":
			p.weapon_size_mult *= f

# Arcane Magic: fiecare item pe care îl ai se schimbă pe ALTUL de aceeași calitate, din același
# pool — cele de la level up rămân în lista de la level up, cele de la dubios în lista de aici.
#
# ⚠️ NU se poate face desfăcând efectele: `_apply` scrie direct în statusuri, iar din „viteza e
# 275" nu mai afli ce a adunat-o acolo. Deci player-ul se întoarce la starea de la începutul
# rundei (`reset_la_start`, copia luată la capătul lui `player._ready`) și se rejoacă peste ea o
# listă nouă, item cu item. Singurul efect care NU se desface e XP-ul necesar pe nivel — vezi
# `NU_SE_RESETEAZA` în `player.gd`.
func _arcane_magic(p) -> String:
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if lu == null or not ("run_items" in p):
		return ""
	var vechi: Array = p.run_items.duplicate()
	vechi.pop_back()      # ultimul e chiar Arcane Magic, pus de `_apply` acum o clipă
	if vechi.is_empty():
		return tr("%d items rerolled") % 0
	# Itemele „unice" (Undying Spirit, Mike's Hedgehog) ies din carantina lor: nu le mai ai, deci
	# au voie să reintre în tragere. Fără asta, un unic pierdut aici n-ar mai fi putut fi luat
	# niciodată în runda aia.
	for id in vechi:
		lu.uita_unic(String(id))
	p.reset_la_start()
	p.run_items.clear()
	var cate := 0
	for id in vechi:
		var nou = _acelasi_fel(String(id), lu)
		if nou == null:
			continue
		if _item_dupa_id(String(nou["id"])) != null:
			_apply(String(nou["id"]), p)   # item de-al dubiosului → trece prin `_apply`-ul de aici
		else:
			lu.da_item(nou, p)             # item de level up → prin al lui, ca să țină „unicele"
		cate += 1
	p.run_items.append("arcane_magic")
	return tr("%d items rerolled") % cate

# Alt item, de aceeași calitate și din același pool ca `id`.
func _acelasi_fel(id: String, lu):
	if _item_dupa_id(id) != null:
		# de la dubios. ⚠️ Arcane Magic iese din tragere: altfel s-ar rechema pe el însuși, la
		# nesfârșit (aceeași regulă ca la Lucky Die în cufere, vezi `levelup.da_random_acum`).
		var pool := []
		for u in UPGRADES:
			if u["id"] != "arcane_magic" and u["id"] != id:
				pool.append(u)
		return pool[randi() % pool.size()] if not pool.is_empty() else null
	var vechi = lu.item_dupa_id(id)
	if vechi == null:
		return null    # id necunoscut (item șters între timp) — îl lăsăm pierdut, nu ghicim
	return lu.item_random_de_raritate(String(vechi["rar"]), [id])

func _item_dupa_id(id: String):
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return null

# ---------------------------------------------------------------------------
# CĂRĂMIZILE DE ASPECT (aceleași ca la `levelup.gd`)
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

# ⚠️ Celula se MĂREȘTE de ZOOM ori (nearest) înainte să ajungă textură: nine-patch-ul întinde doar
# mijlocul laturilor, nu și grosimea lor, iar o celulă de 64px pusă pe un panou de 700 lăsa linii
# de 1px — un chenar desenat cu pixul.
func _chenar(celula: Vector2i) -> ImageTexture:
	if _sheet == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet = tex.get_image()
	var bucata := _sheet.get_region(Rect2i(celula.x * CELULA_FOAIE, celula.y * CELULA_FOAIE,
		CELULA_FOAIE, CELULA_FOAIE))
	bucata.resize(CELULA_FOAIE * ZOOM, CELULA_FOAIE * ZOOM, Image.INTERPOLATE_NEAREST)
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

func _add_outline(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
