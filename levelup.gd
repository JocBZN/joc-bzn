extends CanvasLayer

# Ecranul de LEVEL UP (stil Megabonk): la creșterea în nivel pune jocul pe PAUZĂ și
# arată 3 îmbunătățiri alese aleatoriu, ca o LISTĂ verticală în stânga panoului `Menu.png`.
# Fiecare rând = iconița pusă în border-ul RARITĂȚII + nume (colorat pe raritate) + stat.
# Dai click pe un rând → efectul se aplică pe player (vezi _apply) → jocul repornește.

const ICON_DIR := "res://Upgrades/"
const MENU_UI_DIR := "res://Upgrades/Menu UI/"

# Raritatea dă border-ul, numele afișat și culoarea textului.
# Culorile sunt luate EXACT din border-urile PNG (nuanța dominantă a fiecăruia).
const RARITIES := {
	"common":    {"border": "Border Common.png",    "nume": "Common",    "color": Color8(66, 75, 109)},
	"uncommon":  {"border": "Border Uncommon.png",  "nume": "Uncommon",  "color": Color8(131, 139, 165)},
	"rare":      {"border": "Border Rare.png",      "nume": "Rare",      "color": Color8(58, 160, 76)},
	"epic":      {"border": "Border Epic.png",      "nume": "Epic",      "color": Color8(122, 22, 225)},
	"legendary": {"border": "Border Legendary.png", "nume": "Legendary", "color": Color8(236, 114, 103)},
}

# "desc" = statul afișat sub nume. "rar" = raritatea (border + culoare). Efectul e în _apply().
var UPGRADES := [
	{"id": "cocaina",   "nume": "Weird Concoction", "icon": "upgrade_15.png", "rar": "epic", "desc": "+speed - +fire rate"},
	{"id": "iarba",     "nume": "Wine",      "icon": "upgrade_13.png", "rar": "common",    "desc": "+3 HP/sec & heal 30"},
	{"id": "seringa",   "nume": "Last Resort", "icon": "upgrade_35.png", "rar": "uncommon",  "desc": "+7 Bullet damage"},
	{"id": "bere",      "nume": "Beer",      "icon": "upgrade_4.png", "rar": "common",    "desc": "+35 Max health"},
	{"id": "vodca",     "nume": "Vodka",     "icon": "upgrade_5.png", "rar": "uncommon",  "desc": "-3 Damage taken"},
	{"id": "stroh",     "nume": "Stroh",     "icon": "upgrade_6.png", "rar": "epic",      "desc": "+damage - +fire rate"},
	{"id": "foite",     "nume": "Rolling Papers", "icon": "upgrade_7.png", "rar": "common",    "desc": "+10% Attack speed"},
	{"id": "grinder",   "nume": "Grinder",   "icon": "upgrade_8.png", "rar": "common",    "desc": "-15% XP to level"},
	{"id": "jean_bomb", "nume": "Jean's Bomb", "icon": "upgrade_9.png", "rar": "legendary", "desc": "+20 damage & AOE for 15% of damage"},
	{"id": "firewalker", "nume": "Firewalker", "icon": "upgrade_10.png", "rar": "epic", "desc": "Burning trail while moving"},
	{"id": "frostwalker", "nume": "Frostwalker", "icon": "upgrade_11.png", "rar": "epic", "desc": "Freezing trail slows enemies"},
	{"id": "gloante_paralele", "nume": "Twin Comets", "icon": "upgrade_19.png", "rar": "legendary", "desc": "+2 projectiles at random enemies"},
	{"id": "strapungere", "nume": "Drill", "icon": "upgrade_16.png", "rar": "rare", "desc": "Bullets pierce +1 enemy"},
	{"id": "critic", "nume": "Adrenaline", "icon": "upgrade_3.png", "rar": "rare", "desc": "+15% Crit chance"},
	{"id": "glont_mare", "nume": "Double Dose", "icon": "upgrade_14.png", "rar": "uncommon", "desc": "Bigger bullets - +5 damage"},
	{"id": "recul", "nume": "Knockback Stick", "icon": "upgrade_22.png", "rar": "uncommon", "desc": "Bullets knock enemies back"},
	{"id": "pufferfish", "nume": "Pufferfish", "icon": "upgrade_17.png", "rar": "common", "desc": "+10 Weapon size"},
	{"id": "burger", "nume": "Rat's Burger", "icon": "upgrade_18.png", "rar": "rare", "desc": "+30% Weapon size"},
	{"id": "rabbit_foot", "nume": "Rabbit's Foot", "icon": "upgrade_20.png", "rar": "uncommon", "desc": "-5 Damage - +25% Move speed"},
	{"id": "hedgehog", "nume": "Mike's Hedgehog", "icon": "upgrade_21.png", "rar": "epic", "desc": "Reflect 100% damage (once/3s)"},
	{"id": "nightclub", "nume": "The Nightclub", "icon": "upgrade_25.png", "rar": "epic", "desc": "+35% Damage - -35% Attack speed"},
	{"id": "rusty_hacksaw", "nume": "Rusty Hacksaw", "icon": "upgrade_24.png", "rar": "uncommon", "desc": "1% instakill (+0.5% / stack)"},
	{"id": "doctor_hacksaw", "nume": "Doctor's Hacksaw", "icon": "upgrade_23.png", "rar": "legendary", "desc": "5% instakill (+2% / stack)"},
	{"id": "stolen_halo", "nume": "Stolen Halo", "icon": "upgrade_29.png", "rar": "rare", "desc": "+15 Damage - +5 Max HP"},
	{"id": "alex_protection", "nume": "Alex's Protection", "icon": "upgrade_28.png", "rar": "rare", "desc": "+25% Max HP - +15% Move speed"},
	{"id": "theo_wrath", "nume": "Theo's Wrath", "icon": "upgrade_30.png", "rar": "uncommon", "desc": "+15% Damage under 20% HP"},
	{"id": "cigarette_pack", "nume": "Cigarette Pack", "icon": "upgrade_31.png", "rar": "common", "desc": "+5% Damage"},
	{"id": "diesel_power", "nume": "Diesel Power", "icon": "upgrade_32.png", "rar": "uncommon", "desc": "+15% Damage - more if faster"},
	{"id": "megane_katana", "nume": "Megane's Katana", "icon": "upgrade_33.png", "rar": "rare", "desc": "+15% Crit - more if faster"},
	{"id": "panic_button", "nume": "Panic Button", "icon": "upgrade_34.png", "rar": "epic", "desc": "100 Damage to all enemies, once"},
	{"id": "broken_watch", "nume": "Broken Watch", "icon": "upgrade_36.png", "rar": "uncommon", "desc": "50% chance to fire +1 projectile"},
	# id-ul a rămas „stacked_armory": pe 2026-07-21 itemul a fost redenumit Gunslinger și a primit
	# altă iconiță (upgrade_47), dar efectul e neschimbat, iar id-ul ține legăturile vechi.
	{"id": "stacked_armory", "nume": "Gunslinger", "icon": "upgrade_47.png", "rar": "rare", "desc": "+1 projectile at a random enemy"},
	{"id": "lucky_die", "nume": "Lucky Die", "icon": "upgrade_48.png", "rar": "rare", "desc": "Reroll: a new page of items"},
	{"id": "death_sentence", "nume": "Death Sentence", "icon": "upgrade_49.png", "rar": "rare", "desc": "-35% speed, +20% damage & attack speed"},
	{"id": "thunder_god", "nume": "Thunder God", "icon": "upgrade_38.png", "rar": "legendary", "desc": "Chain lightning for 25% of damage (+25%/stack)"},
	{"id": "plugged_in", "nume": "Plugged In", "icon": "upgrade_39.png", "rar": "rare", "desc": "10% chance to chain lightning on hit"},
	# "unic": itemul dispare din listă după ce l-ai luat o dată — nu mai apare deloc în runda asta.
	# Undying Spirit se consumă la prima moarte și NU se stivuiește, deci a doua luare ar fi fost
	# un rând irosit (mai rău: un Legendary irosit).
	{"id": "undying_spirit", "nume": "Undying Spirit", "icon": "upgrade_41.png", "rar": "legendary", "desc": "Second chance", "unic": true},
	{"id": "unusual_clover", "nume": "Unusual Clover", "icon": "upgrade_43.png", "rar": "rare", "desc": "+5 Luck"},
	{"id": "the_office", "nume": "The Office", "icon": "upgrade_40.png", "rar": "uncommon", "desc": "+2.5 Luck - +5% Attack Speed"},
	{"id": "royal_flush", "nume": "Royal Flush", "icon": "upgrade_42.png", "rar": "epic", "desc": "+10 Luck"},
	{"id": "tome_knowledge", "nume": "Tome of Knowledge", "icon": "upgrade_44.png", "rar": "rare", "desc": "50% less XP to level up"},
	{"id": "duridama", "nume": "Duridama", "icon": "upgrade_45.png", "rar": "legendary", "desc": "1% to gild an enemy - next hit instakills"},
	{"id": "hellas", "nume": "Hellas", "icon": "upgrade_50.png", "rar": "uncommon", "desc": "+15% Move speed - +5% Crit chance"},
	{"id": "borat_mankini", "nume": "Borat's Mankini", "icon": "upgrade_51.png", "rar": "common", "desc": "50% chance for 2 XP gems every 5s"},
	{"id": "horse_mask", "nume": "Horse Mask", "icon": "upgrade_52.png", "rar": "epic", "desc": "5% to charm an enemy (+5% / stack)"},
]

const CELL := 120.0   # mărimea unei celule de border (cu iconița în interior)

# ȘANSELE PE RARITATE (în procente, per rând afișat).
# Până acum raritatea era DOAR culoare: cele 3 iteme se alegeau uniform din listă, deci un
# Legendary ieșea la fel de des ca un Common — ba chiar mai des pe categorie, fiindcă acolo
# sunt mai puține iteme. Acum se trage întâi RARITATEA, după procentele de mai jos, și abia
# apoi un item din raritatea aia. Deci câte iteme are o categorie nu-i mai schimbă șansa:
# adaugi un Legendary nou → Legendary rămâne tot 5%, doar se împarte între mai multe.
const RARITY_CHANCE := {
	"common": 30.0,
	"uncommon": 30.0,
	"rare": 20.0,
	"epic": 15.0,
	"legendary": 5.0,
}
const RARITY_TRIES := 12   # câte încercări până cădem pe plasa de siguranță (vezi _trage_unul)

# NOROCUL (Unusual Clover) mută procentele de mai sus: ia de la cele slabe și dă celor bune.
# Pe PUNCT de noroc — 5 noroc (o luare) = exact ce s-a cerut: −2.5 common, −2.5 uncommon,
# +2 rare, +2 epic, +1 legendary.
const LUCK_TAKE := {"common": 0.5, "uncommon": 0.5}                  # cât ia, per punct
const LUCK_GIVE := {"rare": 2.0, "epic": 2.0, "legendary": 1.0}      # în ce RAPORT împarte

var _buttons := []
var _borders := []      # TextureRect cu border-ul rarității
var _icons := []        # TextureRect cu iconița upgrade-ului (peste border)
var _rar_labels := []   # eticheta cu raritatea (colorată exact ca border-ul)
var _name_labels := []
var _desc_labels := []
var _current := []   # cele 3 upgrade-uri afișate acum
var _pending := 0    # câte niveluri mai avem de ales (dacă urci mai multe deodată)
var _reroll := false # Lucky Die: pagina se retrage, dar nivelul NU se consumă (vezi _on_choice)
# Id-urile itemelor marcate "unic" pe care le-ai luat deja în runda asta — nu mai intră în tragere.
# Se golește singur la rundă nouă: scena `main.tscn` se reîncarcă, deci scriptul o ia de la zero.
var _luate_unic := []

var _stats_box: VBoxContainer   # rândurile panoului de statusuri (dreapta ecranului)

# Culorile stării unui stat în panoul din dreapta.
const STAT_COLORS := {
	"same": Color(0.62, 0.62, 0.66),   # gri: neschimbat față de bază
	"up":   Color(0.44, 0.86, 0.44),   # verde: mai bun ca la bază
	"down": Color(0.92, 0.38, 0.36),   # roșu: mai slab ca la bază
}

func _ready() -> void:
	add_to_group("levelup_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS  # merge și când jocul e pe pauză
	layer = 10                               # deasupra HUD-ului
	visible = false

	# fundal întunecat peste tot ecranul — gri spre negru
	var overlay := ColorRect.new()
	overlay.color = Color(0.12, 0.12, 0.14, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# panoul ornat (Menu.png) ca ramă care se întinde curat (nine-patch).
	# Ancorat pe STÂNGA-centru (nu mai e centrat pe ecran) ca să lase loc panoului de STATS pe dreapta.
	var panel := NinePatchRect.new()
	panel.texture = load(MENU_UI_DIR + "Menu.png")
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.patch_margin_left = 46
	panel.patch_margin_right = 46
	panel.patch_margin_top = 46
	panel.patch_margin_bottom = 46
	var pw := 680.0
	var ph := 580.0
	panel.custom_minimum_size = Vector2(pw, ph)
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 40
	panel.offset_right = 40 + pw
	panel.offset_top = -ph / 2.0
	panel.offset_bottom = ph / 2.0
	add_child(panel)

	# marginile interioare, ca să stăm în interiorul ramei
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(box)

	var title := Label.new()
	title.text = "LEVEL UP!  Choose:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))  # auriu ca rama
	_add_outline(title)
	box.add_child(title)

	# împinge lista ~50px spre dreapta (titlul rămâne centrat)
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 50)
	box.add_child(list_margin)

	# lista verticală de sloturi (fiecare = border+iconiță | raritate + nume + stat)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list_margin.add_child(list)

	for i in 3:
		list.add_child(_make_row(i))

	_build_stats_panel()

# Panoul de statusuri din dreapta ecranului (stil Binding of Isaac): aceeași ramă Menu.png ca
# meniul, lipită de marginea dreaptă, centrată pe verticală. Rândurile se umplu în _refresh_stats.
func _build_stats_panel() -> void:
	var panel := NinePatchRect.new()
	panel.texture = load(MENU_UI_DIR + "Menu.png")
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.patch_margin_left = 46
	panel.patch_margin_right = 46
	panel.patch_margin_top = 46
	panel.patch_margin_bottom = 46
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := 386.0
	var h := 574.0
	panel.custom_minimum_size = Vector2(w, h)
	# ancoră pe dreapta-centru, apoi offset-uri care o lipesc de margine, centrată pe verticală
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_right = -16
	panel.offset_left = -16 - w
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# marginile trebuie să fie clar peste grosimea ramei (patch_margin = 46), ca textul să nu se
	# lipească de pereții chenarului
	margin.add_theme_constant_override("margin_left", 62)
	margin.add_theme_constant_override("margin_right", 62)
	margin.add_theme_constant_override("margin_top", 66)   # titlul coborât mai jos, sub rama de sus
	margin.add_theme_constant_override("margin_bottom", 58)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var title := Label.new()
	title.text = "STATS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))  # auriu ca rama
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(title)
	box.add_child(title)

	_stats_box = VBoxContainer.new()
	# ATENȚIE: panoul are înălțime FIXĂ, iar rândurile nu se micșorează singure — la 13 rânduri
	# (de când există „Luck") spațierea 7 împingea ultimul rând peste ramă. Dacă mai adaugi un
	# stat, verifică marginea de jos a panoului: fie scazi spațierea, fie fontul (19).
	_stats_box.add_theme_constant_override("separation", 3)
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_stats_box)

# Reumple panoul cu statusurile de ACUM (colorate pe stare). Chemat de fiecare dată când se
# deschide meniul, ca să reflecte și nivelurile luate între timp (dacă urci mai multe deodată).
func _refresh_stats() -> void:
	if _stats_box == null:
		return
	for c in _stats_box.get_children():
		_stats_box.remove_child(c)
		c.queue_free()
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("stat_lines"):
		return
	for row in p.stat_lines():
		var col: Color = STAT_COLORS.get(row["state"], STAT_COLORS["same"])
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl := Label.new()
		name_lbl.text = row["label"]
		name_lbl.add_theme_font_size_override("font_size", 19)
		name_lbl.add_theme_color_override("font_color", col)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_outline(name_lbl)
		hb.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = row["value"]
		val_lbl.add_theme_font_size_override("font_size", 19)
		val_lbl.add_theme_color_override("font_color", col)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_outline(val_lbl)
		hb.add_child(val_lbl)
		_stats_box.add_child(hb)

# Construiește un rând-buton: [border cu iconiță]  [nume / stat]. Salvează referințele.
func _make_row(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, CELL + 8)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.flat = true
	# fără chrome de buton normal; doar un highlight discret la hover/apăsare/focus
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _hover_box(0.10))
	b.add_theme_stylebox_override("pressed", _hover_box(0.18))
	b.add_theme_stylebox_override("focus", _hover_box(0.08))
	b.pressed.connect(_on_choice.bind(i))
	_buttons.append(b)

	# conținutul stă peste buton; îi lăsăm click-ul să treacă la buton (mouse ignore)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)

	# celula cu border + iconiță
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(cell)

	var border := TextureRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(border)
	_borders.append(border)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# marginile lasă iconița în „fereastra" din interiorul ramei
	icon.offset_left = 16
	icon.offset_top = 16
	icon.offset_right = -16
	icon.offset_bottom = -16
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	_icons.append(icon)

	# textul: nume (colorat pe raritate) + stat (verde)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(text)

	# raritatea (mic, sus), colorată exact ca border-ul
	var rar_lbl := Label.new()
	rar_lbl.add_theme_font_size_override("font_size", 17)
	rar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(rar_lbl)
	text.add_child(rar_lbl)
	_rar_labels.append(rar_lbl)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(name_lbl)
	text.add_child(name_lbl)
	_name_labels.append(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 19)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(desc_lbl)
	text.add_child(desc_lbl)
	_desc_labels.append(desc_lbl)

	return b

# contur negru de 2px pe text, ca să se citească pe orice fundal
func _add_outline(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)

# highlight semi-transparent, colțuri rotunjite (pentru hover/pressed/focus)
func _hover_box(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(8)
	return sb

# Chemată de player (player.gd -> _level_up) la fiecare creștere în nivel.
func open() -> void:
	_pending += 1
	if not visible:
		_show_choices()

# Trage o raritate după procentele din RARITY_CHANCE („roata norocului": tăiem un segment
# proporțional pentru fiecare și vedem unde cade săgeata).
func _trage_raritate() -> String:
	var sanse := _sanse_cu_noroc(_norocul_meu())
	var total := 0.0
	for k in sanse:
		total += sanse[k]
	var r := randf() * total
	for k in sanse:
		r -= sanse[k]
		if r <= 0.0:
			return k
	return "common"   # doar dacă se strecoară o eroare de virgulă la ultimul segment

func _norocul_meu() -> float:
	var p = get_tree().get_first_node_in_group("player")
	return float(p.luck) if p != null and "luck" in p else 0.0

# Șansele finale, după ce norocul ia de la common\uncommon și dă la rare\epic\legendary.
# Ce se ia se și dă — deci totalul rămâne mereu 100, oricât noroc ai.
# `minf` NU e cosmetic: la mult noroc (60+) common ar deveni NEGATIV, ceea ce ar strica
# roata (segment negativ = raritatea de după el ar înghiți diferența). Așa, când o categorie
# ajunge la 0 se oprește acolo, iar celelalte primesc doar cât s-a luat cu adevărat.
func _sanse_cu_noroc(luck: float) -> Dictionary:
	var out := RARITY_CHANCE.duplicate()
	if luck <= 0.0:
		return out
	var luat := 0.0
	for k in LUCK_TAKE:
		var scade: float = minf(LUCK_TAKE[k] * luck, out[k])
		out[k] -= scade
		luat += scade
	var total_give := 0.0
	for k in LUCK_GIVE:
		total_give += LUCK_GIVE[k]
	for k in LUCK_GIVE:
		out[k] += luat * (LUCK_GIVE[k] / total_give)
	return out

# Un item din raritatea trasă, care să nu fie deja pe ecran și să nu fie un „unic" deja luat.
func _trage_unul(deja: Array):
	for t in RARITY_TRIES:
		var rar := _trage_raritate()
		var candidati := []
		for u in UPGRADES:
			if u.get("rar", "common") == rar and not deja.has(u) and _e_disponibil(u):
				candidati.append(u)
		if not candidati.is_empty():
			return candidati[randi() % candidati.size()]
	# Plasă de siguranță: dacă raritatea trasă e goală de fiecare dată (s-ar întâmpla doar
	# dacă rămâne o categorie fără iteme), luăm orice a mai rămas — mai bine un rând cu
	# raritatea „greșită" decât un rând gol, care ar bloca alegerea.
	var rest := []
	for u in UPGRADES:
		if not deja.has(u) and _e_disponibil(u):
			rest.append(u)
	return rest[randi() % rest.size()] if not rest.is_empty() else null

# Un item „unic" (Undying Spirit) iese din joc după prima luare — nu-l mai poți primi în runda asta.
func _e_disponibil(u) -> bool:
	return not _luate_unic.has(u["id"])

# `exclude` = iteme interzise pe lângă cele deja trase în runda asta. Îl folosește Lucky Die,
# ca pagina de după reroll să fie chiar ALTA, nu aceleași iteme trase din nou.
func _trage_iteme(n: int, exclude: Array = []) -> Array:
	var out := []
	for i in n:
		var u = _trage_unul(out + exclude)
		if u != null:
			out.append(u)
	return out

func _show_choices(exclude: Array = []) -> void:
	_current = _trage_iteme(3, exclude)
	for i in 3:
		var u = _current[i]
		# iconița
		var icon_path: String = u["icon"]
		if not icon_path.begins_with("res://"):
			icon_path = ICON_DIR + icon_path   # numele scurte se caută în Upgrades/; căile res:// se folosesc direct
		_icons[i].texture = load(icon_path)
		# border-ul + raritatea, cu culoarea EXACTĂ luată din border
		var rar = RARITIES.get(u.get("rar", "common"), RARITIES["common"])
		_borders[i].texture = load(MENU_UI_DIR + rar["border"])
		_rar_labels[i].text = rar["nume"]
		_rar_labels[i].add_theme_color_override("font_color", rar["color"])
		_name_labels[i].add_theme_color_override("font_color", rar["color"])
		_desc_labels[i].add_theme_color_override("font_color", rar["color"])
		# textele
		_buttons[i].tooltip_text = u["nume"]
		_name_labels[i].text = u["nume"]
		_desc_labels[i].text = u["desc"]
	_refresh_stats()
	visible = true
	get_tree().paused = true

func _on_choice(index: int) -> void:
	var p = get_tree().get_first_node_in_group("player")
	_reroll = false
	var ales = _current[index]
	if p != null:
		_apply(ales["id"], p)
	# itemele „unice" ies din listă imediat ce le-ai luat (vezi _e_disponibil)
	if ales.get("unic", false) and not _luate_unic.has(ales["id"]):
		_luate_unic.append(ales["id"])
	if _reroll:
		# Lucky Die: pagină nouă pe loc, fără să consume nivelul — tot un item alegi la final.
		# Cele 3 iteme de pe pagina rerulată sunt excluse, ca reroll-ul să însemne chiar altceva.
		_show_choices(_current)
		return
	_pending -= 1
	if _pending > 0:
		_show_choices()          # mai ai un nivel de ales (ai urcat mai multe deodată)
	else:
		visible = false
		get_tree().paused = false

# Efectele reale, tematice pe substanță. Modifică numerele cum vrei.
func _apply(id: String, p) -> void:
	match id:
		"cocaina":
			# stimulent puternic: viteză + cadență. Glonțul rămâne normal;
			# doar ÎMPREUNĂ cu Stroh devine glonțul combinat (sinergie ascunsă).
			p.has_weird = true
			if p.has_stroh:
				p.bullet_scene = load("res://bullet_combined.tscn")
			p.speed += 60.0
			p.upgrade_fire_rate(0.8)
		"iarba":
			# chill / vindecare: regenerare + un plus de viață pe loc
			p.hp_regen += 3
			p.hp = min(p.max_hp, p.hp + 30)
		"seringa":
			# lovitură directă: mai mult damage pe fiecare proiectil
			p.bullet_damage += 7
		"bere":
			# tanky: mai multă viață maximă (te și vindecă)
			p.upgrade_max_hp(35)
		"vodca":
			# amorțeală / curaj lichid: primești mai puțin damage
			p.contact_damage = max(1, p.contact_damage - 3)
		"stroh":
			# 80% alcool, foc: damage + cadență. Glonțul rămâne normal;
			# doar ÎMPREUNĂ cu Weird Concoction devine glonțul combinat (sinergie ascunsă).
			p.has_stroh = true
			if p.has_weird:
				p.bullet_scene = load("res://bullet_combined.tscn")
			p.bullet_damage += 10
			p.upgrade_fire_rate(0.85)
		"foite":
			# tragi mai des: +10% attack speed (merge și la gloanțe, și la pulsul stingătorului)
			p.upgrade_fire_rate(0.90)
		"grinder":
			# eficiență: nivelezi mai repede (îți trebuie mai puțin XP)
			p.xp_to_next = max(5, int(p.xp_to_next * 0.85))
		"tome_knowledge":
			# tomul: jumătate din XP-ul necesar. Ca la Grinder, reducerea se propagă la toate
			# nivelurile următoare — pragul crește din valoarea deja tăiată (×1.2 pe nivel).
			# Se stivuiește: a doua luare înjumătățește iar (25% din original).
			p.xp_to_next = max(5, int(p.xp_to_next * 0.5))
		"jean_bomb":
			# LEGENDAR: +20 damage și gloanțele explodează AOE la impact.
			# Explozia NU mai face damage fix (25), ci un PROCENT din damage-ul salvei — așa
			# crește singură cu tot ce iei mai târziu pe damage, în loc să rămână în urmă.
			p.bullet_damage += 20                # partea directă: +20 la fiecare luare
			if p.explosion_damage_pct <= 0.0:
				p.explosion_radius = 130.0       # prima luare: raza de bază
				p.explosion_damage_pct = 0.15    # 15% din damage
			else:
				p.explosion_radius += 20.0       # repetare: rază mai mare
				p.explosion_damage_pct += 0.10   # și +10% din damage
		"firewalker":
			# lasă o dâră de foc când mergi; fiecare upgrade o ține mai mult și mai mare
			if p.fire_trail_time <= 0.0:
				p.fire_trail_time = 1.0    # prima dată: rămâne 1 secundă
				p.fire_trail_damage = 5
				p.fire_trail_size = 80.0   # mărimea de bază a focului (px)
			else:
				p.fire_trail_damage += 3   # +3 damage/tick la fiecare upgrade
				p.fire_trail_size *= 1.10  # +10% mărime la fiecare upgrade
				p.fire_trail_time += 0.3   # trail-ul durează +0.3s la fiecare upgrade
		"frostwalker":
			# lasa o dara de gheata cand mergi: incetineste inamicii (filtru albastru) + damage mic
			if p.frost_trail_time <= 0.0:
				p.frost_trail_time = 1.0
				p.frost_trail_damage = 2      # damage-ul rămâne fix la orice upgrade
				p.frost_trail_size = 80.0
				p.frost_slow_time = 0.5       # durata de bază a slow-ului (hold la maxim)
			else:
				p.frost_trail_time += 0.3     # trail-ul durează +0.3s la fiecare upgrade
				p.frost_slow_time += 0.5      # inamicii stau înghețați +0.5s la fiecare upgrade
				# damage și mărime rămân la fel
		"gloante_paralele":
			# +2 proiectile GARANTATE, trase în ALȚI inamici la întâmplare — exact mecanica de la
			# Gunslinger, doar că două odată (e legendary). NU mai sunt gloanțe paralele:
			# id-ul „gloante_paralele" a rămas doar ca să nu stric referințele vechi.
			p.stacked_armory_stacks += 2
		"strapungere":
			# glonțul trece prin încă un inamic înainte să dispară
			p.pierce += 1
		"critic":
			# +15% șansă de CRIT. (Criticul înmulțește damage-ul cu crit_mult = 2×, de aici venea
			# vechea formulare „damage dublu" — dar e crit, se cumulează cu Megane's Katana și îl
			# umflă Norocul.) NU mai e plafonat la 100%: peste 100% intră multi-crit-ul
			# (vezi player.roll_crit) — 200% garantează ×4, 300% ×8 etc.
			p.crit_chance += 0.15
		"glont_mare":
			# gloanțe mai mari (hitbox + sprite) și puțin mai puternice
			p.bullet_scale += 0.3
			p.bullet_damage += 5
		"recul":
			# gloanțele împing inamicii înapoi
			p.knockback += 250.0
		"pufferfish":
			# arma se umflă: +10px la sprite ȘI la hitbox (glonț / sferă mage / aura stingătorului)
			p.weapon_size_px += 10.0
		"burger":
			# arma crește cu 30% peste mărimea curentă (se compune dacă îl iei de mai multe ori)
			p.weapon_size_mult *= 1.30
		"rabbit_foot":
			# compromis: -5 damage pe proiectil, dar +25% viteză de MIȘCARE.
			# Procentul se aplică pe viteza CURENTĂ, deci se compune la fiecare luare (ca Alex's).
			p.bullet_damage = max(1, p.bullet_damage - 5)
			p.speed *= 1.25
		"hedgehog":
			# Mike's Hedgehog: când iei damage, îl reflecți 100% în inamic — o dată la 3s
			p.hedgehog = true
		"nightclub":
			# The Nightclub: +35% damage, dar -35% attack speed (tragi mai rar)
			p.bullet_damage = int(round(p.bullet_damage * 1.35))
			p.upgrade_fire_rate(1.35)
		"death_sentence":
			# condamnarea la moarte: te încetinești ca să lovești mai tare și mai des.
			# Toate trei sunt PROCENTE pe valoarea curentă (ca la The Nightclub), deci se compun
			# la fiecare luare: a doua oară -35% din ce mai aveai, nu -70% din viteza de start.
			# ⚠️ Nu are plasă de siguranță pe viteză: luat de multe ori te lasă aproape pe loc
			# (0.65^4 = 18% din viteza inițială). E intenționat — itemul e un pariu.
			p.speed *= 0.65                                    # -35% viteză de mișcare
			p.bullet_damage = int(round(p.bullet_damage * 1.20))  # +20% damage
			p.upgrade_fire_rate(0.80)                          # +20% attack speed (tragi mai des)
		"rusty_hacksaw":
			# 1% instakill la prima luare, apoi +0.5% la fiecare repetare
			if p._rusty_taken:
				p.instakill_chance += 0.005
			else:
				p.instakill_chance += 0.01
				p._rusty_taken = true
		"doctor_hacksaw":
			# 5% instakill la prima luare, apoi +2% la fiecare repetare
			if p._doctor_taken:
				p.instakill_chance += 0.02
			else:
				p.instakill_chance += 0.05
				p._doctor_taken = true
		"stolen_halo":
			# furat din rai: damage + viață, la fel la fiecare luare (stivuiește).
			# Aureola rămâne deasupra capului tot restul rundei; show_halo() o pune o singură dată.
			p.bullet_damage += 15
			p.upgrade_max_hp(5)
			p.show_halo()
		"alex_protection":
			# cască de protecție: mai multă viață și te miști mai repede.
			# Procentele se aplică pe valoarea CURENTĂ, deci se compun la fiecare luare
			# (ca la The Nightclub) — nu pe valoarea de start.
			p.upgrade_max_hp(int(round(p.max_hp * 0.25)))  # +25% viață maximă (te și vindecă)
			p.speed *= 1.15                                # +15% viteză de mișcare
		"theo_wrath":
			# furia lui Theo: cât ești sub 20% viață, dai mai mult damage.
			# +15% la prima luare, apoi +10% la fiecare repetare (ca la Hacksaw-uri).
			# Bonusul e DINAMIC — se citește în player.damage_mult() la fiecare lovitură,
			# fiindcă se aprinde și se stinge singur, după cum îți scade sau îți crește viața.
			if p._theo_taken:
				p.theo_bonus += 0.10
			else:
				p.theo_bonus = 0.15
				p._theo_taken = true
		"cigarette_pack":
			# pachetul de țigări: +5% damage, tot atâta la fiecare luare (5% → 10% → 15%).
			# Aditiv, nu compus, ca să fie exact cât scrie pe item (vezi player.damage_mult()).
			p.cig_bonus += 0.05
		"diesel_power":
			# motorină: cu cât mergi mai repede, cu atât dai mai mult damage. Stai pe loc = 0 bonus.
			# Cât dă și cât e plafonul se reglează din player.gd (diesel_per_stack, speed_ratio_cap).
			p.diesel_stacks += 1
		"megane_katana":
			# katana: cu cât mergi mai repede, cu atât critici mai des. Fratele lui Diesel Power —
			# aceeași viteză, altă monedă (vezi player.speed_ratio() / crit_chance_now()).
			# Stai pe loc = 0 bonus; se adună peste criticul fix de la Adrenaline.
			p.katana_stacks += 1
		"unusual_clover":
			# trifoiul: +5 noroc. Se stivuiește (a doua luare = 10 noroc). Norocul înclină
			# rarităţile la level up ȘI umflă șansele itemelor pe care le ai — vezi
			# `_sanse_cu_noroc()` aici și `player.luck_bonus()` dincolo.
			p.luck += 5.0
		"the_office":
			# biroul: noroc pe jumătate, dar vine la pachet cu cadență. Singurul item de noroc
			# care dă și altceva — de aia e Uncommon, nu Rare.
			p.luck += 2.5
			p.upgrade_fire_rate(0.95)   # +5% attack speed (ca la Rolling Papers, care e 0.90)
		"royal_flush":
			# chinta roială: dublu față de trifoi, fără nimic pe lângă.
			p.luck += 10.0
		"duridama":
			# aurirea: +1% șansă/lovitură să înghețe inamicul; următoarea lovitură = instakill + 2× XP.
			# Logica e în enemy.gd (`_try_golden` / moartea aurită); aici doar creștem șansa.
			p.duridama_stacks += 1
		"undying_spirit":
			# spiritul: prima moarte nu te termină, ci te trimite în Limbo (vezi limbo.gd).
			# Nu se stack-uiește — a doua luare nu-ți dă a doua viață, fiindcă `undying_used`
			# rămâne consumat. E o plasă de siguranță, o singură dată pe rundă.
			p.has_undying = true
		"panic_button":
			# butonul de panică: 100 damage la TOȚI inamicii de pe hartă, pe loc, o singură dată.
			# Nu lasă nimic în urmă — tot efectul lui se consumă aici. Îl iei iar, bubuie iar.
			p.panic_button(100)
		"broken_watch":
			# ceasul stricat: șansa (50%, fixă) să tragi proiectile bonus în ALȚI inamici la
			# întâmplare (ca Gunslinger, dar pe șansă). Nu crește ȘANSA la repetare, ci CÂTE
			# proiectile dai când se declanșează: +1, +2, +3 ...
			p.broken_watch_stacks += 1
		"lucky_die":
			# zarul norocos: nu atinge NIMIC pe player — cere doar o pagină nouă de iteme.
			# Nivelul nu se consumă (vezi `_reroll` din _on_choice), deci după reroll tot alegi
			# un item. Poate să reapară și el pe pagina nouă? NU: pagina veche e exclusă, deci
			# nu poți intra într-un lanț de reroll-uri la nesfârșit din aceeași alegere.
			_reroll = true
		"stacked_armory":
			# arsenalul: +1 proiectil GARANTAT, dar tras într-un ALT inamic la întâmplare — pleacă
			# în direcții diferite deodată. Aceeași mecanică pe care o dă și Twin Comets (+2);
			# se adună în același contor. Scalează numărul: +1, +2, +3 ...
			p.stacked_armory_stacks += 1
		"thunder_god":
			# zeul tunetului (LEGENDARY din 2026-07-21): la impact (glonț SAU sabie), curent
			# electric de la inamicul lovit spre TOȚI din rază (Jacob's Ladder). Damage-ul arcului
			# e un PROCENT din damage-ul playerului: 25% la prima luare, +25% la fiecare repetare
			# (vezi player.thunder_damage_pct) — deci acum se stivuiește, nu doar se activează.
			p.thunder_stacks += 1
		"hellas":
			# Hellas: viteză + puțin critic. Viteza e PROCENT pe valoarea curentă (ca Alex's
			# Protection), deci se compune la fiecare luare; criticul se adună (ca Adrenaline).
			# Fiind pe viteză, umflă indirect și Diesel Power / Megane's Katana.
			p.speed *= 1.15
			p.crit_chance += 0.05
		"borat_mankini":
			# mankini: la fiecare 5 secunde, 50% șansă să-ți pice 2 geme mici de XP lângă tine.
			# Șansa rămâne 50% oricâte iei (ca la Broken Watch) — crește numărul de geme: 2, 4, 6...
			p.mankini_stacks += 1
		"horse_mask":
			# masca de cal: 5% pe lovitură (+5% pe luare) să farmeci inamicul lovit — se întoarce
			# împotriva alor lui și lovește alt inamic până îl omoară, iar cât e fermecat nu-ți mai
			# face damage la contact. Rostogolirea și lupta sunt în enemy.gd (`_try_charm`).
			p.horse_mask_stacks += 1
		"plugged_in":
			# băgat în priză: ȘANSĂ să facă exact ce face Thunder God la impact. +10% pe luare
			# (prima = 10%), plafonat la 100%. Folosește același lanț (thunder_burst).
			# Crește doar ȘANSA: singur, arcul lui rămâne la 25% din damage.
			p.plugged_in_stacks += 1
