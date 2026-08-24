extends CanvasLayer

# Ecranul de LEVEL UP (stil Megabonk): la creșterea în nivel pune jocul pe PAUZĂ și arată 3
# îmbunătățiri alese aleatoriu, ca trei CARTONAȘE în panoul din stânga; în dreapta, statusurile de
# acum. Fiecare cartonaș = iconița pusă în chenarul RARITĂȚII + raritate / nume / efect.
# Dai click pe un cartonaș → efectul se aplică pe player (vezi _apply) → jocul repornește.
# Cum arată și de ce → secțiunea „CUM ARATĂ", mai jos.

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
	{"id": "cocaina",   "nume": "Weird Concoction", "icon": "upgrade_15.png", "rar": "epic", "desc": "+60 Speed +25% Attack Speed"},
	{"id": "iarba",     "nume": "Wine",      "icon": "upgrade_13.png", "rar": "common",    "desc": "+3 HP/sec, Heal 30 HP"},
	{"id": "seringa",   "nume": "Last Resort", "icon": "upgrade_35.png", "rar": "uncommon",  "desc": "+7 Bullet damage"},
	{"id": "bere",      "nume": "Beer",      "icon": "upgrade_4.png", "rar": "common",    "desc": "+35 Max HP"},
	{"id": "vodca",     "nume": "Vodka",     "icon": "upgrade_5.png", "rar": "uncommon",  "desc": "+3 Damage, Reflect 10% of damage taken"},
	{"id": "stroh",     "nume": "Stroh",     "icon": "upgrade_6.png", "rar": "epic",      "desc": "+10 Damage +18% Attack Speed"},
	{"id": "foite",     "nume": "Rolling Papers", "icon": "upgrade_7.png", "rar": "common",    "desc": "+10% Attack speed"},
	{"id": "grinder",   "nume": "Grinder",   "icon": "upgrade_8.png", "rar": "common",    "desc": "-15% XP to level"},
	{"id": "jean_bomb", "nume": "Jean's Bomb", "icon": "upgrade_9.png", "rar": "legendary", "desc": "+20 damage & AOE for 15% of damage"},
	{"id": "firewalker", "nume": "Firewalker", "icon": "upgrade_10.png", "rar": "epic", "desc": "Burning Trail"},
	{"id": "frostwalker", "nume": "Frostwalker", "icon": "upgrade_11.png", "rar": "epic", "desc": "Freezing Trail"},
	{"id": "gloante_paralele", "nume": "Twin Comets", "icon": "upgrade_19.png", "rar": "legendary", "desc": "+2 projectiles"},
	{"id": "strapungere", "nume": "Drill", "icon": "upgrade_16.png", "rar": "rare", "desc": "Bullets pierce +1 enemy"},
	{"id": "critic", "nume": "Adrenaline", "icon": "upgrade_3.png", "rar": "rare", "desc": "+7% Crit chance"},
	{"id": "glont_mare", "nume": "Double Dose", "icon": "upgrade_14.png", "rar": "uncommon", "desc": "+5% Weapon size +5 damage"},
	{"id": "recul", "nume": "Knockback Stick", "icon": "upgrade_22.png", "rar": "uncommon", "desc": "Bullets knock enemies back"},
	{"id": "pufferfish", "nume": "Pufferfish", "icon": "upgrade_17.png", "rar": "common", "desc": "+10% Weapon size"},
	{"id": "burger", "nume": "Rat's Burger", "icon": "upgrade_18.png", "rar": "rare", "desc": "+30% Weapon size"},
	{"id": "rabbit_foot", "nume": "Rabbit's Foot", "icon": "upgrade_20.png", "rar": "uncommon", "desc": "-5 Damage +25% Move speed"},
	{"id": "hedgehog", "nume": "Mike's Hedgehog", "icon": "upgrade_21.png", "rar": "epic", "desc": "Reflect 100% damage (once/6s)", "unic": true},
	{"id": "nightclub", "nume": "The Nightclub", "icon": "upgrade_25.png", "rar": "epic", "desc": "+35% Damage -35% Attack Speed"},
	{"id": "rusty_hacksaw", "nume": "Rusty Hacksaw", "icon": "upgrade_24.png", "rar": "uncommon", "desc": "1% instakill"},
	{"id": "doctor_hacksaw", "nume": "Doctor's Hacksaw", "icon": "upgrade_23.png", "rar": "legendary", "desc": "5% instakill"},
	{"id": "stolen_halo", "nume": "Stolen Halo", "icon": "upgrade_29.png", "rar": "rare", "desc": "+10 Damage +5 Max HP"},
	{"id": "alex_protection", "nume": "Alex's Protection", "icon": "upgrade_28.png", "rar": "rare", "desc": "+25% Max HP +15% Movement Speed"},
	{"id": "theo_wrath", "nume": "Theo's Wrath", "icon": "upgrade_30.png", "rar": "uncommon", "desc": "+15% Damage under 20% HP"},
	{"id": "cigarette_pack", "nume": "Cigarette Pack", "icon": "upgrade_31.png", "rar": "common", "desc": "+5% Damage"},
	{"id": "diesel_power", "nume": "Diesel Power", "icon": "upgrade_32.png", "rar": "uncommon", "desc": "+15% Damage while moving"},
	{"id": "megane_katana", "nume": "Megane's Katana", "icon": "upgrade_33.png", "rar": "rare", "desc": "+15% Crit while moving"},
	{"id": "panic_button", "nume": "Panic Button", "icon": "upgrade_34.png", "rar": "epic", "desc": "100 Damage to all enemies, once"},
	{"id": "broken_watch", "nume": "Broken Watch", "icon": "upgrade_36.png", "rar": "uncommon", "desc": "50% chance to fire +1 projectile"},
	# id-ul a rămas „stacked_armory": pe 2026-07-21 itemul a fost redenumit Gunslinger și a primit
	# altă iconiță (upgrade_47), dar efectul e neschimbat, iar id-ul ține legăturile vechi.
	{"id": "stacked_armory", "nume": "Gunslinger", "icon": "upgrade_47.png", "rar": "rare", "desc": "+1 projectile"},
	{"id": "lucky_die", "nume": "Lucky Die", "icon": "upgrade_48.png", "rar": "rare", "desc": "Reroll a new page of items"},
	{"id": "death_sentence", "nume": "Death Sentence", "icon": "upgrade_49.png", "rar": "rare", "desc": "-35% speed +20% damage & attack speed"},
	{"id": "thunder_god", "nume": "Thunder God", "icon": "upgrade_38.png", "rar": "legendary", "desc": "Get the power of Zeus"},
	{"id": "plugged_in", "nume": "Plugged In", "icon": "upgrade_39.png", "rar": "rare", "desc": "+10% to become Zeus"},
	# "unic": itemul dispare din listă după ce l-ai luat o dată — nu mai apare deloc în runda asta.
	# Undying Spirit se consumă la prima moarte și NU se stivuiește, deci a doua luare ar fi fost
	# un rând irosit (mai rău: un Legendary irosit).
	{"id": "undying_spirit", "nume": "Undying Spirit", "icon": "upgrade_41.png", "rar": "legendary", "desc": "Second chance", "unic": true},
	{"id": "unusual_clover", "nume": "Unusual Clover", "icon": "upgrade_43.png", "rar": "rare", "desc": "+5 Luck"},
	{"id": "the_office", "nume": "The Office", "icon": "upgrade_40.png", "rar": "uncommon", "desc": "+2.5 Luck +5% Attack Speed"},
	{"id": "royal_flush", "nume": "Royal Flush", "icon": "upgrade_42.png", "rar": "epic", "desc": "+10 Luck"},
	{"id": "tome_knowledge", "nume": "Tome of Knowledge", "icon": "upgrade_44.png", "rar": "rare", "desc": "50% less XP to level up"},
	{"id": "duridama", "nume": "Duridama", "icon": "upgrade_45.png", "rar": "legendary", "desc": "Make enemies golden"},
	{"id": "hellas", "nume": "Hellas", "icon": "upgrade_50.png", "rar": "uncommon", "desc": "+15% Move speed +5% Crit chance"},
	{"id": "borat_mankini", "nume": "Borat's Mankini", "icon": "upgrade_51.png", "rar": "common", "desc": "50% chance xp to drop every 5s"},
	{"id": "horse_mask", "nume": "Horse Mask", "icon": "upgrade_52.png", "rar": "epic", "desc": "5% to charm an enemy"},
	{"id": "psychic_flip_flops", "nume": "Psychic Flip Flop", "icon": "upgrade_53.png", "rar": "epic", "desc": "Aimbot"},
	{"id": "bloody_situation", "nume": "Bloody Situation", "icon": "upgrade_54.png", "rar": "common", "desc": "Crits heal you 2 HP"},
	{"id": "hermes_sandals", "nume": "Hermes' Sandals", "icon": "upgrade_56.png", "rar": "legendary", "desc": "+100 Movement Speed +10% Attack Speed"},
	{"id": "aussie_special", "nume": "Aussie Special", "icon": "upgrade_57.png", "rar": "legendary", "desc": "Projectiles ricochet +1 time"},
	{"id": "old_reliable", "nume": "Old Reliable", "icon": "upgrade_55.png", "rar": "common", "desc": "Reflect 15% of damage taken"},
	{"id": "tower_5g", "nume": "5G Tower", "icon": "upgrade_58.png", "rar": "epic", "desc": "Enemies drop 15% more xp"},
	{"id": "electrolytes", "nume": "Water and electrolytes", "icon": "upgrade_59.png", "rar": "uncommon", "desc": "+2 HP/sec +10% Move speed"},
	{"id": "big_cigar", "nume": "Big Black Cigar", "icon": "upgrade_60.png", "rar": "epic", "desc": "+40% Damage -25% Move speed"},
	{"id": "butterfly_knife", "nume": "Butterfly Knife", "icon": "upgrade_61.png", "rar": "common", "desc": "+5% Crit chance, Attack & Move speed"},
	{"id": "tome_witchcraft", "nume": "Tome of Witchcraft", "icon": "upgrade_62.png", "rar": "rare", "desc": "+10% Difficulty"},
	{"id": "bulletproof_vest", "nume": "Bulletproof Vest", "icon": "upgrade_63.png", "rar": "epic", "desc": "+100 Max HP -10% Move speed"},
	{"id": "casino_vip", "nume": "Casino VIP Pass", "icon": "upgrade_64.png", "rar": "legendary", "desc": "Indefinite access to the roulette wheel", "unic": true},
	{"id": "lightning_step", "nume": "Lightning Step", "icon": "upgrade_65.png", "rar": "legendary", "desc": "Dash once every 10 seconds", "unic": true},
]

const CELL := 88.0    # latura chenarului de RARITATE (cu iconița în interior)

# ---------------------------------------------------------------------------
# CUM ARATĂ (refăcut pe 2026-08-11: „mai premium, ca la un studio mare")
# ---------------------------------------------------------------------------
# Ecranul a trecut pe ACELEAȘI chenare de aramă ca restul jocului (cazinou, statuia din Ender,
# meniul principal): `harta/EGT/Border EGT.png`, o planșă de 5×4 celule de 64×64 din care se
# taie la rulare doar celulele care trebuie (`_chenar`). Ce s-a schimbat față de varianta veche:
#
#   1. RAMA: lemnul beige-auriu din `Menu.png` → aramă. Era ultimul ecran rămas pe lemn, deci
#      singurul loc din joc unde paleta se rupea.
#   2. Cele 3 opțiuni sunt acum CARTONAȘE, fiecare în chenarul lui (celula (1,2)), nu text care
#      plutește pe panou. Un rând fără margini nu arată a lucru pe care poți da click.
#   3. ⚠️ NUMELE nu mai e colorat pe raritate, ci alb-os; raritatea rămâne singura colorată.
#      Culoarea de Common e #424B6D — albastru închis pe fundal aproape negru, adică numele
#      itemului era cel mai greu de citit lucru de pe ecran, exact la cea mai deasă raritate.
#      Descrierea a trecut pe cenușiu, din același motiv.
#   4. HOVER: rama cartonașului se aprinde din cenușă în aramă în 0,12s, iar numele în alb.
#      Înainte era un dreptunghi alb transparent peste rând, care nu se vedea pe fundal închis.
#   5. Panoul de STATS are aceeași înălțime și aceeași ramă ca cel de alegeri (două panouri de
#      înălțimi diferite arată a improvizație), iar rândurile stau într-un tabel cu dungi.
#
# ⚠️ Paleta e MĂSURATĂ din planșă (vezi `casino.gd`), nu aleasă din ochi. Dacă schimbi arta
# chenarelor, adu și culorile astea după ea.
const SHEET := "res://harta/EGT/Border EGT.png"
const CELULA_FOAIE := 64
const ZOOM := 2                       # celula se mărește ×2 NEAREST: vezi `_chenar`
const CH_PANOU := Vector2i(2, 0)      # colțuri în spirală — panourile mari
const CH_CARD := Vector2i(1, 2)       # chenar subțire — un cartonaș de upgrade
# ⚠️ NU folosi celulele (0,1) și (0,3): au pătrate ALBE în colțuri (sunt marcaje de planșă).
const RAMA_PANOU := 16                # cât din celulă e colț ornamentat (în pixeli de planșă)
const RAMA_CARD := 14

const ACCENT := Color8(198, 118, 80)        # arama chenarelor
const ACCENT_CLAR := Color8(222, 152, 116)  # aceeași, aprinsă
const ACCENT_STINS := Color8(116, 62, 42)   # aceeași, în umbră (contururi)
const OS_ALB := Color8(232, 224, 214)       # titluri și nume de item
const CENUSA := Color8(150, 142, 138)       # text secundar (descrieri, etichete de stat)

# Mărimile, în pixeli de ECRAN DE BAZĂ (1152×648 — tot ce e mai mare se scalează singur).
const MARGINE_ECRAN := 26.0
const PANOU_W := 686.0
const PANOU_H := 556.0     # ⚠️ ambele panouri au ACEEAȘI înălțime, vezi punctul 5 de mai sus
const STATS_W := 366.0
const CARD_H := 116.0      # înălțimea unui cartonaș: 3 × 116 + 2 × 12 = 372, cât încape sub titlu

# Rama cartonașului: cenușie în repaus, aramă plină la hover (vezi `_hover`).
const CARD_REPAUS := Color(0.62, 0.60, 0.62)
const CARD_HOVER := Color(1, 1, 1)

# ȘANSELE PE RARITATE (în procente, per rând afișat).
# Până acum raritatea era DOAR culoare: cele 3 iteme se alegeau uniform din listă, deci un
# Legendary ieșea la fel de des ca un Common — ba chiar mai des pe categorie, fiindcă acolo
# sunt mai puține iteme. Acum se trage întâi RARITATEA, după procentele de mai jos, și abia
# apoi un item din raritatea aia. Deci câte iteme are o categorie nu-i mai schimbă șansa:
# adaugi un Legendary nou → Legendary rămâne tot 2.5%, doar se împarte între mai multe.
const RARITY_CHANCE := {
	"common": 40.0,
	"uncommon": 35.0,
	"rare": 15.0,
	"epic": 7.5,
	"legendary": 2.5,
}
const RARITY_TRIES := 12   # câte încercări până cădem pe plasa de siguranță (vezi _trage_unul)

# NOROCUL (Unusual Clover) mută procentele de mai sus: ia de la cele slabe și dă celor bune.
# Pe PUNCT de noroc — 5 noroc (o luare) = exact ce s-a cerut: −2.5 common, −2.5 uncommon,
# +2 rare, +2 epic, +1 legendary.
const LUCK_TAKE := {"common": 0.5, "uncommon": 0.5}                  # cât ia, per punct
const LUCK_GIVE := {"rare": 2.0, "epic": 2.0, "legendary": 1.0}      # în ce RAPORT împarte

var _buttons := []
var _cards := []        # NinePatchRect: rama de aramă a fiecărui cartonaș (se aprinde la hover)
var _lbl_nivel: Label   # „Level 7", sub titlu
var _sheet: Image = null   # planșa de chenare, citită o singură dată (vezi `_chenar`)
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

	# Fundal întunecat peste tot ecranul. Mai opac decât înainte (era 0.9 peste un gri): lumea
	# care se zbate în spate fura atenția tocmai când trebuie să citești trei iteme.
	var overlay := ColorRect.new()
	# ⚠️ 0.975, nu 0.9: la 0.94 se citeau încă prin el cronometrul din HUD (sus) și „LEVEL 1"
	# (jos-stânga) — două texte fantomă peste un meniu, exact semnul de interfață neterminată.
	overlay.color = Color(0.07, 0.06, 0.09, 0.975)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build_alegeri()
	_build_stats_panel()

# Panoul din STÂNGA: titlul, nivelul la care ai ajuns și cele 3 cartonașe.
# Ancorat pe stânga-centru (nu centrat pe ecran) ca să lase loc panoului de STATS pe dreapta.
func _build_alegeri() -> void:
	var panel := _cadru(CH_PANOU, RAMA_PANOU)
	panel.custom_minimum_size = Vector2(PANOU_W, PANOU_H)
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = MARGINE_ECRAN
	panel.offset_right = MARGINE_ECRAN + PANOU_W
	panel.offset_top = -PANOU_H / 2.0
	panel.offset_bottom = PANOU_H / 2.0
	add_child(panel)

	# ⚠️ Marginile trebuie să treacă de grosimea ramei desenate (16 px de celulă × ZOOM = 32),
	# altfel conținutul se urcă pe ornament.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(box)

	var title := Label.new()
	title.text = "LEVEL UP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", OS_ALB)
	# contur de ARAMĂ, nu negru: la un titlu alb pe negru ține loc de aureolă și leagă textul de
	# rama din jur, fără shader și fără font nou (același truc ca la `casino.gd`).
	title.add_theme_color_override("font_outline_color", ACCENT_STINS)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	box.add_child(_linie(300.0, 12))

	# Nivelul la care tocmai ai ajuns. Textul se pune la fiecare deschidere (`_show_choices`),
	# fiindcă e ASAMBLAT cu `%d` și n-ar putea fi tradus singur de Godot — vezi i18n.gd.
	_lbl_nivel = Label.new()
	_lbl_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_nivel.add_theme_font_size_override("font_size", 18)
	_lbl_nivel.add_theme_color_override("font_color", ACCENT)
	_add_outline(_lbl_nivel)
	box.add_child(_lbl_nivel)

	var sub := Label.new()
	sub.text = "Choose one"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", CENUSA)
	_add_outline(sub)
	box.add_child(sub)

	var spatiu := Control.new()
	spatiu.custom_minimum_size = Vector2(0, 10)
	spatiu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spatiu)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	box.add_child(list)
	for i in 3:
		list.add_child(_make_row(i))

# Panoul de statusuri din dreapta ecranului (stil Binding of Isaac), în aceeași ramă de aramă și
# de ACEEAȘI ÎNĂLȚIME ca panoul de alegeri. Rândurile se umplu în `_refresh_stats`.
func _build_stats_panel() -> void:
	var panel := _cadru(CH_PANOU, RAMA_PANOU)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(STATS_W, PANOU_H)
	# ancoră pe dreapta-centru, apoi offset-uri care o lipesc de margine, centrată pe verticală
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_right = -MARGINE_ECRAN
	panel.offset_left = -MARGINE_ECRAN - STATS_W
	panel.offset_top = -PANOU_H / 2.0
	panel.offset_bottom = PANOU_H / 2.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 32)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var title := Label.new()
	title.text = "STATS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", OS_ALB)
	title.add_theme_color_override("font_outline_color", ACCENT_STINS)
	title.add_theme_constant_override("outline_size", 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	box.add_child(_linie(200.0, 12))

	_stats_box = VBoxContainer.new()
	# ATENȚIE: panoul are înălțime FIXĂ, iar rândurile nu se micșorează singure — la 13 rânduri
	# (de când există „Luck") spațierea 7 împingea ultimul rând peste ramă. Acum rândurile sunt
	# casete cu dungi, deci separarea e 0 și aerul vine din marginile lor. Dacă mai adaugi un
	# stat, verifică marginea de jos a panoului: fie scazi marginile din `_rand_stat`, fie fontul.
	_stats_box.add_theme_constant_override("separation", 0)
	# umple ce rămâne sub titlu și ține tabelul centrat pe verticală: dacă într-o zi rămân mai
	# puține rânduri, golul se împarte sus-jos în loc să cadă tot la fund
	_stats_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
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
	var i := 0
	for row in p.stat_lines():
		_stats_box.add_child(_rand_stat(row, i))
		i += 1

# Un rând din tabelul de statusuri: numele la stânga, valoarea la dreapta.
#
# ⚠️ NUMELE statului nu mai ia culoarea stării, doar VALOAREA. Cu amândouă colorate, un panou cu
# 6 statusuri crescute era un perete verde în care nu se mai citea nimic; acum verdele/roșul apar
# doar pe cifre, adică fix pe ce s-a schimbat.
#
# Dungile (un rând din doi cu fundal cu 3% alb) sunt tot ce desparte 13 rânduri strânse — fără
# ele ochiul pierde linia și citește valoarea altui stat.
func _rand_stat(row: Dictionary, idx: int) -> PanelContainer:
	var col: Color = STAT_COLORS.get(row["state"], STAT_COLORS["same"])
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03) if idx % 2 == 1 else Color(0, 0, 0, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	# 5, nu 2: cele 13 rânduri strânse lăsau un sfert de panou gol dedesubt, iar un panou pe
	# jumătate plin arată a listă neterminată. Cu aerul ăsta, tabelul umple rama.
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	pc.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)

	var name_lbl := Label.new()
	name_lbl.text = row["label"]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color8(186, 180, 174))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true      # un nume lung tradus scurtează, nu lățește panoul peste ramă
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(name_lbl)
	hb.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = row["value"]
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", col)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(val_lbl)
	hb.add_child(val_lbl)
	return pc

# Un CARTONAȘ de ales: chenar de aramă, în el [chenarul de raritate cu iconița] [raritate / nume /
# descriere]. Salvează referințele, ca `_show_choices` să nu mai construiască nimic — doar umple.
func _make_row(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, CARD_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.flat = true
	# Butonul nu desenează NIMIC: tot ce se vede e chenarul din planșă, iar starea se citește din
	# aprinderea lui (vezi `_hover`). Un dreptunghi alb transparent peste un fundal aproape negru
	# — cum era înainte — nu se vedea nici la 18% alfa.
	for stare in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(stare, StyleBoxEmpty.new())
	b.pressed.connect(_on_choice.bind(i))
	# și mouse, și tastatură/gamepad: focusul aprinde cartonașul la fel ca trecerea cu mouse-ul
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

	# ⚠️ Marginile trebuie să treacă de grosimea ramei cartonașului (14 × ZOOM = 28 în lateral
	# desenat ~12), altfel iconița calcă pe ornament.
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
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hb)

	# celula cu chenarul de RARITATE + iconița
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
	# marginile lasă iconița în „fereastra" din interiorul chenarului de raritate (~13%, ca în
	# inventarul din cazinou)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	_icons.append(icon)

	# textul: raritate (singurul colorat) / nume / descriere
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(text)

	var rar_lbl := Label.new()
	rar_lbl.add_theme_font_size_override("font_size", 15)
	rar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(rar_lbl)
	text.add_child(rar_lbl)
	_rar_labels.append(rar_lbl)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 25)
	name_lbl.add_theme_color_override("font_color", OS_ALB)
	name_lbl.clip_text = true      # un nume lung tradus scurtează, nu lățește cartonașul
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(name_lbl)
	text.add_child(name_lbl)
	_name_labels.append(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 17)
	desc_lbl.add_theme_color_override("font_color", CENUSA)
	desc_lbl.max_lines_visible = 2   # două rânduri, cât încape pe cartonaș în orice limbă
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_outline(desc_lbl)
	text.add_child(desc_lbl)
	_desc_labels.append(desc_lbl)

	return b

# Trecerea cu mouse-ul (sau focusul) peste un cartonaș: rama se aprinde din cenușă în aramă plină,
# iar numele din alb-os în alb. 0,12s — cât să se simtă, nu cât să se aștepte.
func _hover(i: int, pornit: bool) -> void:
	if i < 0 or i >= _cards.size():
		return
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # jocul e pe pauză cât alegi
	t.tween_property(_cards[i], "modulate", CARD_HOVER if pornit else CARD_REPAUS, 0.12)
	_name_labels[i].add_theme_color_override("font_color", Color(1, 1, 1) if pornit else OS_ALB)

# contur negru de 2px pe text, ca să se citească pe orice fundal
func _add_outline(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)

# ---------------------------------------------------------------------------
# CĂRĂMIZILE DE ASPECT (aceleași ca la `casino.gd` / `menu.gd` — citește acolo de ce arată așa)
# ---------------------------------------------------------------------------
# Un chenar din planșă, gata de întins (nine-patch). `margine` = câți pixeli din margine NU se
# întind (colțurile ornamentate). Panourile au mărime FIXĂ, deci NinePatchRect e potrivit aici.
func _cadru(celula: Vector2i, margine: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _chenar(celula)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = margine * ZOOM
	np.patch_margin_right = margine * ZOOM
	np.patch_margin_top = margine * ZOOM
	np.patch_margin_bottom = margine * ZOOM
	return np

# ⚠️ Celula se MĂREȘTE de ZOOM ori (nearest, deci rămâne pixel art curat) înainte să ajungă
# textură: nine-patch-ul întinde doar MIJLOCUL laturilor, nu și grosimea lor, iar o celulă de
# 64px pusă pe un panou de 686 lăsa linii de 1px — un chenar desenat cu pixul.
func _chenar(celula: Vector2i) -> ImageTexture:
	if _sheet == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet = tex.get_image()
	var bucata := _sheet.get_region(Rect2i(celula.x * CELULA_FOAIE, celula.y * CELULA_FOAIE, CELULA_FOAIE, CELULA_FOAIE))
	bucata.resize(CELULA_FOAIE * ZOOM, CELULA_FOAIE * ZOOM, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bucata)

# Linia subțire de sub titlu. Se stinge spre capete (trei bucăți cu alfa diferit), ca să nu arate
# a bară trasă cu rigla peste artă.
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
	# `luck_total()`, nu `luck`: include și bonusul de nivel al Mage Staff-ului (+1 noroc/nivel),
	# ca norocul armei să încline și rarităţile, nu doar șansele itemelor.
	if p != null and p.has_method("luck_total"):
		return float(p.luck_total())
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

# Calea completă a iconiței unui item: numele scurte se caută în `Upgrades/`, căile care încep
# deja cu res:// se folosesc ca atare. O cere și `chest.gd`, ca să arate ce a scos din cufăr.
func icon_path(u) -> String:
	var p: String = u["icon"]
	return p if p.begins_with("res://") else ICON_DIR + p

# ---------------------------------------------------------------------------
# SCARA RARITĂȚILOR — o urcă statuia din Ender (`ender_statue.gd`), care schimbă un item de-al
# tău pe unul cu două trepte mai sus. Stă aici, lângă `RARITIES`, ca să existe UN SINGUR loc în
# care se știe ordinea: dacă mâine apare o raritate nouă, se adaugă în amândouă și gata.
# ---------------------------------------------------------------------------
const SCARA_RARITATI := ["common", "uncommon", "rare", "epic", "legendary"]

# Raritatea cu `trepte` mai sus. Se oprește la Legendary, fiindcă peste el nu mai e nimic: un
# Epic urcă o singură treaptă, iar un Legendary rămâne Legendary (adică îl schimbi pe ALTUL).
func raritate_mai_sus(rar: String, trepte: int) -> String:
	var i := SCARA_RARITATI.find(rar)
	if i < 0:
		return rar
	return SCARA_RARITATI[mini(i + trepte, SCARA_RARITATI.size() - 1)]

# Itemul cu id-ul dat, sau `null` dacă nu există.
func item_dupa_id(id: String):
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return null

# Un item la întâmplare dintr-o raritate anume. `exclude` = id-uri interzise (de obicei chiar
# itemul pe care îl dai la schimb — n-are rost să-l primești înapoi).
# Lucky Die iese din tragere din același motiv ca la cufăr (vezi `da_random_acum`): efectul lui
# e „mai dă-mi o pagină de iteme la level up", iar aici nu se deschide nicio pagină.
func item_random_de_raritate(rar: String, exclude: Array = []):
	var pool := []
	for u in UPGRADES:
		if u["rar"] == rar and not exclude.has(u["id"]) and u["id"] != "lucky_die" and _e_disponibil(u):
			pool.append(u)
	return pool[randi() % pool.size()] if pool.size() > 0 else null

# Dă un item ANUME, pe loc, fără ecran de ales — o cere statuia din Ender după schimb.
# Trece prin `_apply`, deci intră și în registrul rundei (`player.run_items`), și ține
# contabilitatea itemelor „unice" exact ca level up-ul și cufărul.
func da_item(u, p) -> void:
	if u == null or p == null:
		return
	_apply(u["id"], p)
	if u.get("unic", false) and not _luate_unic.has(u["id"]):
		_luate_unic.append(u["id"])

# ---------------------------------------------------------------------------
# UN UPGRADE LA ÎNTÂMPLARE, APLICAT PE LOC — îl cere CUFĂRUL (`chest.gd`), fără ecran de ales.
# ---------------------------------------------------------------------------
# Folosește ACEEAȘI tragere ca la level up (`_trage_unul`), deci rarităţile îşi păstrează
# şansele reale (Legendary 2.5%) şi norocul contează. Alternativa — „la fel de probabil oricare
# din cele 47" — ar fi făcut un Legendary de 4× mai probabil dintr-un cufăr decât dintr-un nivel.
# Întoarce dicționarul itemului (are `nume`, `icon`, `rar`) sau `null` dacă n-a rămas nimic.
func da_random_acum():
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return null
	# Lucky Die n-are ce căuta aici: efectul lui e „mai dă-mi o pagină de iteme", iar cufărul nu
	# deschide nicio pagină — ar fi fost un cufăr irosit. Îl scoatem din tragere.
	var fara := []
	for u2 in UPGRADES:
		if u2["id"] == "lucky_die":
			fara.append(u2)
	var u = _trage_unul(fara)
	if u == null:
		return null
	_apply(u["id"], p)
	if u.get("unic", false) and not _luate_unic.has(u["id"]):
		_luate_unic.append(u["id"])   # „unicele" ies din listă la fel ca la level up
	return u

func _show_choices(exclude: Array = []) -> void:
	_current = _trage_iteme(3, exclude)
	for i in 3:
		var u = _current[i]
		_icons[i].texture = load(icon_path(u))
		# border-ul + raritatea, cu culoarea EXACTĂ luată din border
		var rar = RARITIES.get(u.get("rar", "common"), RARITIES["common"])
		_borders[i].texture = load(MENU_UI_DIR + rar["border"])
		_rar_labels[i].text = rar["nume"]
		# ⚠️ DOAR raritatea se colorează pe raritate. Numele rămâne alb-os și descrierea cenușie:
		# Common e #424B6D, adică albastru închis pe fundal aproape negru — vezi capul fișierului.
		# eticheta se ia spre alb cu 30%: culoarea de Common (#424B6D) e prea închisă ca TEXT pe
		# fundal aproape negru. Chenarul desenat rămâne culoarea adevărată a rarității.
		_rar_labels[i].add_theme_color_override("font_color", (rar["color"] as Color).lerp(Color.WHITE, 0.3))
		_name_labels[i].add_theme_color_override("font_color", OS_ALB)
		# fiecare pagină nouă pornește cu toate cartonașele stinse, chiar dacă mouse-ul stătea
		# peste unul când ai ales (semnalul de ieșire nu mai vine, nodul nu se mișcă)
		_cards[i].modulate = CARD_REPAUS
		# textele
		_buttons[i].tooltip_text = u["nume"]
		_name_labels[i].text = u["nume"]
		_desc_labels[i].text = u["desc"]
	var p = get_tree().get_first_node_in_group("player")
	# tr() explicit: textul are %d, deci n-ar putea fi tradus singur de Godot (vezi i18n.gd)
	_lbl_nivel.text = tr("Level %d") % (int(p.level) if p != null and "level" in p else 1)
	_refresh_stats()
	visible = true
	get_tree().paused = true
	Audio.pause_forest_ambient()   # ambientul se oprește cât alegi; se reia de unde era la închidere
	# Muzica lumii nu se schimbă și nu se oprește (cerut pe 2026-08-22) — se aude doar ÎNFUNDATĂ,
	# ca prin ușă, cât ține alegerea (2026-08-23). Ecranul ăsta apare des și ține puțin, deci
	# tranziția scurtă a filtrului (0,2s) e exact cât trebuie: nu rupe melodia, dar face loc
	# sunetului de „Choose Item" și clicurilor. Vezi „Muzica în meniuri" din `audio.gd`.
	# ⚠️ Se cheamă la FIECARE pagină (mai multe niveluri deodată, reroll de la Lucky Die) — de-aia
	# `enter_menu_muffle` lucrează cu nume, nu cu numărător: de zece ori tot un meniu înseamnă.
	Audio.enter_menu_muffle("levelup")

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
		Audio.resume_forest_ambient()   # gata alegerea → ambientul continuă de unde a rămas
		Audio.exit_menu_muffle("levelup")   # ...și muzica iese din spatele ușii

# Efectele reale, tematice pe substanță. Modifică numerele cum vrei.
#
# Aici trec TOATE itemele, din orice sursă: level up, cufăr (`da_random_acum`), statuia din Ender.
# De-aia registrul rundei (`player.run_items`) se scrie tot de aici — un singur loc, deci nu se
# poate strecura un item luat pe altă ușă. Vezi comentariul de la `run_items` în `player.gd`.
func _apply(id: String, p) -> void:
	if p != null and "run_items" in p:
		p.run_items.append(id)
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
			# curaj lichid: lovești mai tare ȘI dai înapoi. Din 2026-08-14 — până atunci scădea
			# damage-ul primit, dar statul ăla a ieșit de tot din joc.
			# Reflexia e ACEEAȘI mecanică ca la Old Reliable (`reflect_pct`), deci cele două se
			# adună dacă le ai pe amândouă: 10% + 15% = 25% din fiecare lovitură, înapoi în inamic.
			p.bullet_damage += 3
			p.reflect_pct += 0.10
		"stroh":
			# 80% alcool, foc: damage + cadență. Glonțul rămâne normal;
			# doar ÎMPREUNĂ cu Weird Concoction devine glonțul combinat (sinergie ascunsă).
			p.has_stroh = true
			if p.has_weird:
				p.bullet_scene = load("res://bullet_combined.tscn")
			p.bullet_damage += 10
			p.upgrade_fire_rate(0.85)
		"foite":
			# tragi mai des: +10% attack speed (merge și la gloanțe, și la tăietură/măturat)
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
			# +7% șansă de CRIT. (Criticul înmulțește damage-ul cu crit_mult = 2×, de aici venea
			# vechea formulare „damage dublu" — dar e crit, se cumulează cu Megane's Katana și îl
			# umflă Norocul.) NU mai e plafonat la 100%: peste 100% intră multi-crit-ul
			# (vezi player.roll_crit) — 200% garantează ×4, 300% ×8 etc.
			p.crit_chance += 0.07
		"glont_mare":
			# arma crește cu 5% peste mărimea curentă (sprite + hitbox) și lovește puțin mai tare.
			# Procentual, ca Pufferfish/Rat's Burger — deci se compune dacă îl iei de mai multe ori.
			p.weapon_size_mult *= 1.05
			p.bullet_damage += 5
		"recul":
			# gloanțele împing inamicii înapoi
			p.knockback += 250.0
		"pufferfish":
			# arma se umflă cu 10% peste mărimea curentă: sprite ȘI hitbox
			# (glonț / sferă mage / tăietură / lama coasei). Se compune la fiecare luare.
			p.weapon_size_mult *= 1.10
		"burger":
			# arma crește cu 30% peste mărimea curentă (se compune dacă îl iei de mai multe ori)
			p.weapon_size_mult *= 1.30
		"rabbit_foot":
			# compromis: -5 damage pe proiectil, dar +25% viteză de MIȘCARE.
			# Procentul se aplică pe viteza CURENTĂ, deci se compune la fiecare luare (ca Alex's).
			p.bullet_damage = max(1, p.bullet_damage - 5)
			p.speed *= 1.25
		"hedgehog":
			# Mike's Hedgehog: când iei damage, îl reflecți 100% în inamic — o dată la 6s (HEDGEHOG_CD).
			# Unic: după ce-l iei o dată, nu mai apare în runda asta (nu se stack-uiește oricum).
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
			p.bullet_damage += 10
			p.upgrade_max_hp(5)
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
		"psychic_flip_flops":
			# șlapii psihici = AIMBOT. Gloanțele se corectează în zbor spre ținta lor și țintesc
			# UNDE VA FI, nu unde e. Urmărirea a fost din oficiu la toate gloanțele o zi
			# (2026-07-21 → 07-22); acum e efectul itemului ăstuia. Repetarea strânge virajul:
			# 8 rad/s la prima luare (85% rată de lovire), 16 la a doua (89%) — vezi aimbot_turn().
			p.aimbot_stacks += 1
		"bloody_situation":
			# situație sângeroasă: fiecare lovitură CRITICĂ te vindecă 2 HP, +2 pe fiecare luare.
			# Vindecarea se face la IMPACT, nu la tragere (un glonț critic care ratează nu dă nimic),
			# și o singură dată per lovitură — vezi player.bloody_heal().
			p.bloody_stacks += 1
		"plugged_in":
			# băgat în priză: ȘANSĂ să facă exact ce face Thunder God la impact. +10% pe luare
			# (prima = 10%), plafonat la 100%. Folosește același lanț (thunder_burst).
			# Crește doar ȘANSA: singur, arcul lui rămâne la 25% din damage.
			p.plugged_in_stacks += 1
		"hermes_sandals":
			# sandalele lui Hermes: viteză + cadență. Viteza e o valoare FIXĂ (+100), nu procent ca
			# la Hellas — de-aia e legendară: pe viteza de start (215) e aproape jumătate în plus,
			# dintr-o singură luare. Cadența urmează convenția din tot fișierul: `factor = 1 - procent`
			# (Rolling Papers +10% = 0.90), deci intervalul dintre trageri scade cu 10%.
			# Fiind pe viteză, umflă indirect și Diesel Power / Megane's Katana, ca Hellas.
			p.speed += 100.0
			p.upgrade_fire_rate(0.90)
		"aussie_special":
			# bumerangul: după ce a terminat de străpuns, glonțul SARE la alt inamic din jur
			# (până la 420px, inclusiv în spate) în loc să dispară. +1 săritură pe luare.
			p.ricochet += 1
		"tower_5g":
			# turnul 5G: +15% XP pe luare, peste multiplicatorul din magazinul permanent (se adună,
			# nu se înmulțesc). Prinde TOT XP-ul care intră, nu doar ce lasă inamicii — și gemele
			# de la Borat's Mankini, și cele din alte surse. Vezi `player.gain_xp()`: acolo se
			# păstrează și restul sub 1, altfel pe gemele mici procentul s-ar pierde la rotunjire.
			p.xp_gain_mult += 0.15
		"old_reliable":
			# Old Reliable: 15% din damage-ul primit se întoarce în inamicul care te-a lovit,
			# LA FIECARE lovitură (+15% pe luare). Fără cooldown, fără block — vezi `reflect_pct`
			# în player.gd pentru diferența față de Mike's Hedgehog, cu care se adună.
			p.reflect_pct += 0.15
		"electrolytes":
			# apă cu electroliți: hidratare = regenerare + picioare mai iuți.
			# Regenerarea se ADUNĂ (+2 HP/s pe luare), ca la Wine — care dă 3, dar e Common și te
			# și vindecă pe loc; aici plusul e că vine la pachet cu viteza. `hp_regen` e `int`,
			# deci trebuie să rămână număr întreg: nu-l face procent, s-ar pierde la rotunjire.
			# Viteza e PROCENT pe valoarea CURENTĂ (ca Hellas / Alex's Protection), deci se
			# compune la fiecare luare. Fiind pe viteză, umflă indirect și Diesel Power /
			# Megane's Katana, care se uită la cât de repede te miști față de viteza de start.
			p.hp_regen += 2
			p.speed *= 1.10
		"big_cigar":
			# trabucul: cel mai mare plus de damage dintr-o singură luare, plătit în viteză.
			# Amândouă sunt PROCENTE pe valoarea curentă (ca The Nightclub / Death Sentence),
			# deci se compun: a doua luare taie 25% din ce mai aveai, nu 50% din viteza de start.
			# ⚠️ Ca la Death Sentence, NU are plasă de siguranță pe viteză — luat de multe ori te
			# lasă aproape pe loc. Și e o pierdere dublă: încetinirea taie și din Diesel Power /
			# Megane's Katana, care măsoară viteza CURENTĂ față de cea de start (`speed_ratio()`).
			# Fratele mare al lui Cigarette Pack, dar pe altă mecanică: ăla adună în `cig_bonus`
			# (procent citit la fiecare lovitură), ăsta scrie direct în `bullet_damage`.
			p.bullet_damage = int(round(p.bullet_damage * 1.40))
			p.speed *= 0.75
		"butterfly_knife":
			# briceagul-fluture: trei plusuri mici pe cele trei statusuri de „mână iute". E Common
			# tocmai fiindcă niciunul nu e mare — dar toate trei se compun cu ce ai deja, deci
			# luat de mai multe ori devine coloana vertebrală a unui build pe critic.
			# Criticul se ADUNĂ (ca Adrenaline / Hellas), cadența și viteza sunt PROCENTE pe
			# valoarea CURENTĂ (ca Rolling Papers / Hellas), deci a doua luare dă tot 5%, dar din
			# mai mult. Fiind și pe viteză, umflă indirect Diesel Power / Megane's Katana.
			p.crit_chance += 0.05
			p.upgrade_fire_rate(0.95)
			p.speed *= 1.05
		"tome_witchcraft":
			# cartea de vrăjitorii: îi face pe INAMICI cu 10% mai tari, pe loc și până la capătul
			# rundei. E același canal prin care se plătește la statuia din Ender, la trade-up, la
			# Alba-Neagra, la Dubiosu și la cazinou (`Difficulty.trade_penalty`) — deci se
			# înmulțește cu ele, nu se adună: două cărți = ×1,21, nu +20%.
			#
			# Ce urcă, exact: viața, damage-ul de contact, viteza (până la `SPEED_CAP`) și CÂȚI
			# inamici apar. Ce NU urcă: XP-ul lor (`xp_mult` nu trece prin `trade_penalty`),
			# ceasul de pe ecran și scorul — vezi comentariul de la `Difficulty.trade_penalty`.
			#
			# ⚠️ Cum e scris azi, itemul e DOAR minus: nu-ți dă nimic în schimb. Singurul câștig
			# indirect e că 10% mai mulți inamici înseamnă și 10% mai multe geme pe jos. Dacă
			# vrei să fie un târg adevărat („mai greu, dar mai multă răsplată"), linia de adăugat
			# e `Difficulty.xp_bonus *= 1.10` — dar asta e o decizie de design, nu o scăpare.
			Difficulty.add_trade_penalty(0.10)
		"bulletproof_vest":
			# vesta antiglonț: cel mai mare plus de viață dintr-o singură luare (de trei ori Beer),
			# plătit în picioare. `upgrade_max_hp` te și VINDECĂ cu cele 100, deci luată la limită
			# te scoate din foc pe loc.
			# ⚠️ Viteza e PROCENT pe valoarea CURENTĂ (ca Big Black Cigar / Death Sentence): a doua
			# luare taie 10% din ce mai aveai, nu 20% din viteza de start — deci nu te lasă
			# niciodată pe loc, oricâte iei. Și, ca la orice încetinire, taie indirect și din
			# Diesel Power / Megane's Katana, care măsoară viteza curentă față de cea de start.
			p.upgrade_max_hp(100)
			p.speed *= 0.90
		"casino_vip":
			# Casino VIP Pass: masa de ruletă nu se mai închide. Nici jetoanele (cinci pe rundă),
			# nici banul de trei câștiguri la rând nu mai cad — vezi `_vip()` / `_masa_inchisa()`
			# din `casino.gd`, care întreabă steagul ăsta la fiecare verificare.
			# Luat DUPĂ ce ai fost dat afară, masa se redeschide: starea de ban rămâne scrisă, dar
			# e ocolită. „Indefinite access" înseamnă exact asta.
			# E „unic" fiindcă nu se stivuiește: al doilea pas n-ar face nimic, iar un Legendary
			# irosit doare mai tare decât unul comun.
			p.casino_vip = true
		"lightning_step":
			# Lightning Step: deblochează DASH-ul — un pas fulger în direcția în care te uiți,
			# o dată la 10 secunde (`DASH_COOLDOWN` din `player.gd`). Butonul (SPACE / RB) există
			# în InputMap de la pornirea jocului, deci nu trebuie legat nimic aici: steagul ăsta
			# e tot ce desparte „butonul nu face nimic" de „butonul te teleportează 300 px".
			#
			# E „unic" din același motiv ca Undying Spirit și Casino VIP Pass: efectul e un
			# COMUTATOR, nu un status. A doua luare n-ar face nimic, iar un Legendary irosit
			# doare mai tare decât un Common. Dacă vreodată vrei să se stivuiască, locul e
			# `DASH_COOLDOWN` (ex. −2 s pe luare), nu aici.
			p.dash_unlocked = true
