extends CanvasLayer

# HUD-ul, construit din cod dar îmbrăcat în arta jocului (revamp 2026-08-24):
#   - PLĂCUȚA DE VIAȚĂ sus-stânga: ramă de aramă cu nituri, viața în roșu-sânge, fantoma care
#     coboară în urma loviturii și cifrele („214 / 320") scrise peste ea;
#   - BARA DE XP jos, cu INSIGNA nivelului prinsă în capătul din stânga;
#   - cronometrul rundei, cronometrul hoardei, kill-urile și cheile.
#
# Ramele vin din aceeași planșă ca meniul principal, pauza, cazinoul, Alba-Neagra și level up-ul
# (`harta/EGT/Border EGT.png`); cărămida comună e `hud_bara.gd` — citește acolo cum e făcută o
# bară. HUD-ul se ocupă doar de AȘEZARE și de REACȚII (clipit la lovitură, puls la viață mică,
# insigna care sare la level up).
#
# ⚠️ Player-ul nu are semnale pentru viață și XP, deci HUD-ul citește valorile la fiecare cadru
# și le compară cu cele din cadrul trecut (`_hp_ultim`, `_nivel_ultim`). De-acolo știe dacă ai
# încasat, dacă te-ai vindecat sau dacă ai urcat un nivel. Dacă adaugi vreodată semnale pe
# player, aici e locul care se simplifică.

const BARA := preload("res://hud_bara.gd")

var hp_bara: Control        # plăcuța de viață (o instanță de `hud_bara.gd`)
var xp_bara: Control        # bara de XP de jos
var level_label: Label      # cifra din insignă
var _insigna: Control       # insigna cu nivelul, călare pe capătul din stânga al barei de XP

# Ce era în cadrul trecut, ca să prindem schimbările (vezi nota de sus).
var _hp_ultim := -1
var _hp_max_ultim := -1
var _nivel_ultim := -1
var _puls := 0.0            # ceasul pulsului de viață mică

var timer_label: Label      # cronometrul mare, sus-centru
var swarm_label: Label      # cronometrul hoardei de la monument, chiar sub cel de sus
var kills_label: Label      # numărul de inamici uciși, sus-dreapta
var keys_label: Label       # câte chei de cufăr ai (sub kill-uri), lângă iconița de cheie

const TIMER_NORMAL := Color(1, 1, 1)             # alb cât e liniște
const TIMER_WARN := Color(1.0, 0.75, 0.2)        # galben sub 1 minut rămas
const TIMER_SWARM := Color(1.0, 0.25, 0.25)      # roșu în Final Swarm
const TIMER_SIZE := 44                           # mărimea cronometrului de rundă
const SWARM_SIZE := 24                           # mărimea cronometrului de hoardă (mai mic, e secundar)
# Cât mai stă pe ecran cronometrul hoardei fără vești de la monument. Vezi `swarm_timer()`.
const SWARM_TTL := 0.4
var _swarm_ttl := 0.0       # >0 = monumentul încă varsă hoardă (scade singur, vezi `_update_swarm`)

# --- Banner mare pe ecran (anunțuri de val: "VALUL 3", "BOSS!", ...) ---
var banner: Label
var banner_sub: Label
var _banner_box: VBoxContainer
var _banner_tween: Tween

func _ready() -> void:
	add_to_group("hud")  # ca spawner-ul să ne găsească pentru anunțuri
	# ⚠️ `layer = 4`, nu 1 (implicitul), de pe 2026-08-24. Vinieta din `atmosphere.gd` stă pe
	# stratul 3 și întunecă MARGINILE ecranului — adică exact colțul în care stă plăcuța de viață
	# și toată banda de XP de jos. Cât barele erau roșu și cyan aprins mai treceau; rama de aramă,
	# care e o culoare de mijloc, ieșea maro-închis, aproape stinsă.
	# 4 e slotul liber dintre vinietă (3) și filtrul alb-negru din Limbo (5), care TREBUIE să
	# rămână peste HUD (vezi `_update_timer`). Tot acolo stau și cronometrele dimensiunilor
	# (`nether.gd`, `ender.gd`, `prison.gd`), din același motiv. Bara boss-ului e la 6.
	layer = 4
	_build_banner()

	_fa_viata()
	_fa_xp()
	_fa_dash()

	# --- Cronometrul (sus, centrat) ---
	# Întâi numără invers de la 10:00; după ce ajunge la 0 o ia în sus, cu roșu.
	timer_label = Label.new()
	timer_label.anchor_left = 0.0
	timer_label.anchor_right = 1.0
	timer_label.offset_top = 14
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", TIMER_SIZE)
	timer_label.add_theme_color_override("font_color", TIMER_NORMAL)
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	timer_label.add_theme_constant_override("outline_size", 7)
	add_child(timer_label)

	# --- Cronometrul HOARDEI (sub cel al rundei) ---
	# Cât își varsă monumentul hoarda, aici scrie cât mai are de curs. Nu-l numără HUD-ul: îl
	# hrănește `monument.gd` cadru cu cadru, cu ceasul LUI (vezi `_scoate_hoarda`) — altfel două
	# ceasuri separate ar arăta cifre diferite, fiindcă al monumentului stă pe loc pe pauză.
	# Se stinge singur când monumentul tace mai mult de `SWARM_TTL` (hoarda s-a terminat, ai murit,
	# ai dat restart) — așa nu rămâne agățat pe ecran dacă monumentul dispare pe neașteptate.
	swarm_label = Label.new()
	swarm_label.anchor_left = 0.0
	swarm_label.anchor_right = 1.0
	swarm_label.offset_top = 14 + TIMER_SIZE + 14   # sub cronometrul de rundă (care începe la 14)
	swarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swarm_label.add_theme_font_size_override("font_size", SWARM_SIZE)
	swarm_label.add_theme_color_override("font_color", TIMER_SWARM)
	swarm_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	swarm_label.add_theme_constant_override("outline_size", 5)
	swarm_label.visible = false
	add_child(swarm_label)

	# --- Kill count (sus-dreapta) ---
	kills_label = Label.new()
	kills_label.anchor_left = 1.0
	kills_label.anchor_right = 1.0
	kills_label.offset_left = -220
	kills_label.offset_right = -20
	kills_label.offset_top = 20
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills_label.add_theme_font_size_override("font_size", 22)
	kills_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	kills_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	kills_label.add_theme_constant_override("outline_size", 5)
	add_child(kills_label)

	# --- Chei de cufăr (sub kill-uri) ---
	# Doar iconița (`harta/Chest/key.png`) + numărul: n-are text de tradus și se înțelege în
	# orice limbă. Fără el n-ai avea cum să știi dacă poți deschide un cufăr sau nu.
	var keys_box := HBoxContainer.new()
	keys_box.anchor_left = 1.0
	keys_box.anchor_right = 1.0
	keys_box.offset_left = -220
	keys_box.offset_right = -20
	keys_box.offset_top = 52
	keys_box.alignment = BoxContainer.ALIGNMENT_END
	keys_box.add_theme_constant_override("separation", 6)
	keys_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_icon := TextureRect.new()
	key_icon.texture = load("res://harta/Chest/key_contur.png")   # varianta cu conturul galben
	key_icon.custom_minimum_size = Vector2(34, 34)
	key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	keys_box.add_child(key_icon)
	keys_label = Label.new()
	keys_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keys_label.add_theme_font_size_override("font_size", 22)
	keys_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	keys_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	keys_label.add_theme_constant_override("outline_size", 5)
	keys_box.add_child(keys_label)
	# Cifrele de sus-dreapta stau tot în colț, adică tot acolo unde vinieta le stingea înainte
	# de mutarea pe stratul 4. Le ducem înapoi cu aceeași `UMBRA` ca barele. Cronometrul NU:
	# el stă în mijloc, unde vinieta oricum nu ajungea, deci n-a pățit nimic.
	kills_label.modulate = BARA.UMBRA
	keys_box.modulate = BARA.UMBRA
	add_child(keys_box)

# ---------------------------------------------------------------------------
# CELE DOUĂ BARE
# ---------------------------------------------------------------------------
# Culorile: roșul e cel din bara boss-ului (aceeași familie de sânge), iar cyan-ul e cel vechi
# al XP-ului, doar puțin adâncit ca să nu țipe peste aramă.
const C_VIATA := Color8(184, 30, 44)          # roșu-sânge
const C_VIATA_URMA := Color8(232, 168, 176)   # fantoma care rămâne în urma loviturii
const C_XP := Color8(40, 158, 196)            # cyan, adâncit ca să nu domine verdele hărții
const C_XP_URMA := Color8(150, 226, 244)
const ACCENT := Color8(198, 118, 80)          # arama, ca în restul meniurilor
const ACCENT_CLAR := Color8(222, 152, 116)

const VIATA_RECT := Rect2(20, 18, 340, 38)    # unde stă plăcuța de viață
const XP_INALT := 30.0                        # grosimea barei de XP
const XP_DE_JOS := 16.0                       # cât o ridicăm de la marginea de jos
const INSIGNA := 46.0                         # latura insignei de nivel (pătrată)

# Sub ce fracțiune de viață începe plăcuța să pulseze roșu.
const PRAG_PERICOL := 0.30

func _fa_viata() -> void:
	hp_bara = BARA.new()
	# Celula (0,3) din planșă: colțuri cu nituri și linie dublă — plăcuță de metal bătut în cuie.
	# `zoom = 1`: la HUD rama trebuie să rămână SUBȚIRE. Boss-ul folosește aceeași celulă la
	# zoom 2, deci se vede că sunt din aceeași familie, doar că a lui e de două ori mai grea.
	hp_bara.construieste(Vector2i(0, 3), 1, 12, 8, C_VIATA, C_VIATA_URMA)
	hp_bara.position = VIATA_RECT.position
	hp_bara.size = VIATA_RECT.size
	hp_bara.set_font(15)
	add_child(hp_bara)

func _fa_xp() -> void:
	xp_bara = BARA.new()
	# Celula (3,3): doar o linie dublă, fără ornamente. Bara de XP stă pe toată lățimea ecranului
	# și e a doua ca importanță — o ramă bogată acolo ar fi tras ochiul de la joc.
	xp_bara.construieste(Vector2i(3, 3), 1, 10, 6, C_XP, C_XP_URMA)
	xp_bara.anchor_left = 0.0
	xp_bara.anchor_right = 1.0
	xp_bara.anchor_top = 1.0
	xp_bara.anchor_bottom = 1.0
	xp_bara.offset_left = INSIGNA * 0.7        # începe pe sub insignă
	xp_bara.offset_right = -20.0
	xp_bara.offset_top = -(XP_DE_JOS + XP_INALT)
	xp_bara.offset_bottom = -XP_DE_JOS
	xp_bara.set_font(13)
	xp_bara.set_trepte(10)                     # zece crestături: se vede din ochi cât mai ai
	xp_bara.porneste_licarirea()               # dunga de lumină care mătură partea plină
	add_child(xp_bara)

	# INSIGNA: un octogon cu spirale din aceeași planșă, călare pe capătul din stânga al barei.
	# Cifra nivelului stă în el, cu aramă aprinsă. Ține locul vechiului text „Level 7" scris
	# deasupra barei — același lucru, dar arată a joc, nu a etichetă.
	_insigna = Control.new()
	_insigna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insigna.anchor_top = 1.0
	_insigna.anchor_bottom = 1.0
	_insigna.offset_left = 12.0
	_insigna.offset_right = 12.0 + INSIGNA
	var mijloc := -(XP_DE_JOS + XP_INALT * 0.5)
	_insigna.offset_top = mijloc - INSIGNA * 0.5
	_insigna.offset_bottom = mijloc + INSIGNA * 0.5
	_insigna.pivot_offset = Vector2(INSIGNA, INSIGNA) * 0.5   # sare din centru la level up
	_insigna.modulate = BARA.UMBRA                            # stinsă la fel ca barele
	add_child(_insigna)

	var rama := NinePatchRect.new()
	rama.texture = BARA.chenar(Vector2i(3, 2), 1)
	rama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rama.patch_margin_left = 14
	rama.patch_margin_right = 14
	rama.patch_margin_top = 14
	rama.patch_margin_bottom = 14
	rama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insigna.add_child(rama)

	level_label = Label.new()
	level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 22)
	level_label.add_theme_color_override("font_color", ACCENT_CLAR)
	level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	level_label.add_theme_constant_override("outline_size", 5)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insigna.add_child(level_label)

# ---------------------------------------------------------------------------
# CE SE ÎNTÂMPLĂ LA FIECARE CADRU
# ---------------------------------------------------------------------------
func _update_viata(p, delta: float) -> void:
	var maxim: int = maxi(int(p.max_hp), 1)
	var acum: int = clampi(int(p.hp), 0, maxim)
	var f := float(acum) / float(maxim)
	hp_bara.set_fractie(f)
	hp_bara.set_text("%d / %d" % [acum, maxim])

	# Crestăturile se refac doar când se schimbă viața MAXIMĂ (un item, un level up) — nu la
	# fiecare cadru: fiecare refacere înseamnă noduri șterse și făcute la loc.
	if maxim != _hp_max_ultim:
		_hp_max_ultim = maxim
		hp_bara.set_trepte(_cate_crestaturi(maxim))

	# Clipit ALB când încasezi, VERDE când te vindeci. Prima citire (`_hp_ultim < 0`) nu clipește:
	# altfel plăcuța ar fulgera degeaba în clipa în care apare pe ecran.
	if _hp_ultim >= 0 and acum != _hp_ultim:
		if acum < _hp_ultim:
			hp_bara.fulgera(Color(1, 1, 1, 0.55), 0.22)
		else:
			hp_bara.fulgera(Color(0.55, 1.0, 0.60, 0.40), 0.30)
	_hp_ultim = acum

	# Sub `PRAG_PERICOL` rama pulsează roșu. Se vede cu coada ochiului, fără să acopere jocul —
	# la un joc în care mori dintr-o lovitură, „mai am puțin" trebuie să se simtă, nu să se
	# citească. La 0 viață se oprește (ești deja mort, n-are pe cine avertiza).
	if f <= PRAG_PERICOL and acum > 0:
		_puls += delta * 6.0
		var s := 0.5 + 0.5 * sin(_puls)
		hp_bara.set_ton_rama(Color(1.0, 1.0 - 0.45 * s, 1.0 - 0.45 * s))
	else:
		_puls = 0.0
		hp_bara.set_ton_rama(Color.WHITE)

# Câte crestături pe bara de viață. Pasul pornește de la 25 de viață și se dublează până când
# ies cel mult 14 — altfel, cu 2000 de viață, bara ar fi fost un pieptene.
func _cate_crestaturi(maxim: int) -> int:
	var pas := 25
	while maxim / pas > 14:
		pas *= 2
	return clampi(int(round(float(maxim) / float(pas))), 2, 14)

func _update_xp(p) -> void:
	var prag: int = maxi(int(p.xp_to_next), 1)
	var acum: int = clampi(int(p.xp), 0, prag)
	xp_bara.set_fractie(float(acum) / float(prag))
	xp_bara.set_text("%d / %d" % [acum, prag])
	var niv := int(p.level)
	level_label.text = str(niv)
	if _nivel_ultim >= 0 and niv > _nivel_ultim:
		_sare_insigna()
	_nivel_ultim = niv

# Level up: bara se aprinde auriu și insigna sare o dată. Nu ține locul ecranului de level up —
# doar leagă momentul de HUD, ca să se vadă de unde a venit.
func _sare_insigna() -> void:
	xp_bara.fulgera(Color(1.0, 0.86, 0.45, 0.50), 0.42)
	var t := create_tween()
	t.tween_property(_insigna, "scale", Vector2(1.35, 1.35), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_insigna, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Construiește bannerul centrat pe ecran (ascuns până la primul anunț).
func _build_banner() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # să nu blocheze click-urile
	center.offset_top = -80  # puțin mai sus de mijloc
	add_child(center)

	_banner_box = VBoxContainer.new()
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_box.modulate.a = 0.0  # invizibil la start
	center.add_child(_banner_box)

	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 52)
	banner.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 8)
	_banner_box.add_child(banner)

	banner_sub = Label.new()
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.add_theme_font_size_override("font_size", 22)
	banner_sub.add_theme_color_override("font_color", Color(1, 1, 1))
	banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner_sub.add_theme_constant_override("outline_size", 5)
	_banner_box.add_child(banner_sub)

# Afișează un text mare care apare, ține câteva secunde, apoi se stinge.
func announce(text: String, sub: String = "") -> void:
	banner.text = text
	banner_sub.text = sub
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_box.modulate.a = 0.0
	_banner_box.scale = Vector2(0.7, 0.7)
	_banner_box.pivot_offset = _banner_box.size * 0.5
	_banner_tween = create_tween()
	# apare cu un mic "pop"
	_banner_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.2)
	_banner_tween.parallel().tween_property(_banner_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# ține pe ecran
	_banner_tween.tween_interval(1.6)
	# se stinge
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.6)

func _process(delta: float) -> void:
	_update_timer()
	_update_swarm(delta)
	# tr(...) explicit peste tot unde textul are %d: cu numărul deja pus în el, traducerea
	# automată n-ar mai găsi cheia din i18n.gd. (Se reface la fiecare cadru, deci se
	# schimbă imediat dacă jucătorul schimbă limba.)
	kills_label.text = tr("Kills: %d") % GameSettings.run_kills
	keys_label.text = str(GameSettings.run_keys)   # doar cifra: iconița de lângă spune ce e
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_update_viata(player, delta)
	_update_xp(player)
	_update_dash(player)

# Cronometrul: numără invers cele 10 minute, apoi urcă de la 0 cu roșu (Final Swarm).
func _update_timer() -> void:
	# În Limbo cronometrul rundei e înghețat, deci n-are ce să arate. Numărătoarea de
	# acolo o desenează `limbo.gd`, nu HUD-ul — trebuie să stea DEASUPRA filtrului
	# alb-negru, altfel roșul ei iese gri (filtrul acoperă și HUD-ul).
	# La fel în Nether: cronometrul rundei e înghețat acolo, iar cel de 7:00 și-l desenează
	# `nether.gd` singur (tot într-un CanvasLayer al lui).
	var limbo := get_tree().get_first_node_in_group("limbo")
	var nether := get_tree().get_first_node_in_group("nether")
	var ender := get_tree().get_first_node_in_group("ender")   # la fel ca Nether-ul: 6:00-ul lui și-l desenează singur
	var prison := get_tree().get_first_node_in_group("prison") # ...și 5:00-ul Pușcăriei, tot al ei
	timer_label.visible = not ((limbo != null and limbo.active) \
		or (nether != null and nether.active) \
		or (ender != null and ender.active) \
		or (prison != null and prison.active))
	if not timer_label.visible:
		return
	if Difficulty.is_final_swarm():
		timer_label.text = "+" + _mmss(Difficulty.overtime())
		timer_label.add_theme_color_override("font_color", TIMER_SWARM)
	else:
		var ramas := Difficulty.time_left()
		timer_label.text = _mmss(ramas)
		# ultimul minut se face galben, ca avertisment că vine Final Swarm
		timer_label.add_theme_color_override("font_color", TIMER_WARN if ramas <= 60.0 else TIMER_NORMAL)

# `monument.gd` strigă asta la fiecare cadru cât curge hoarda, cu câte secunde mai are.
# Rotunjim în SUS, ca la Nether: în clipa invocării scrie 0:10, nu 0:09, și abia la capăt 0:00.
func swarm_timer(ramas: float) -> void:
	_swarm_ttl = SWARM_TTL
	swarm_label.text = tr("Swarm Timer: %s") % _mmss(ceilf(maxf(0.0, ramas)))

# Ține aprins cronometrul hoardei cât monumentul dă semne de viață. `timer_label.visible` e deja
# calculat de `_update_timer()` (rulează înaintea noastră): în Limbo/Nether/Ender cronometrul
# rundei e ascuns fiindcă dimensiunea își desenează unul propriu ÎN ACELAȘI LOC — dacă l-am lăsa
# pe al nostru, ar sta peste el.
func _update_swarm(delta: float) -> void:
	if _swarm_ttl <= 0.0:
		return
	_swarm_ttl -= delta
	swarm_label.visible = timer_label.visible and _swarm_ttl > 0.0


# ---------------------------------------------------------------------------
# INSIGNA DE DASH (upgrade-ul Lightning Step)
# ---------------------------------------------------------------------------
# O plăcuță pătrată sub bara de viață: iconița itemului în ACELAȘI chenar-octogon ca insigna
# de nivel, cu un văl închis care coboară pe măsură ce pasul se reîncarcă.
#
# De ce există: un buton cu 10 secunde de așteptare fără nimic pe ecran înseamnă că jucătorul
# îl apasă pe ghicite în mijlocul unei hoarde. Sunetul de „gata" (`_dash_gata` din player.gd)
# spune CÂND, insigna spune CÂT MAI E.
#
# Apare doar cu itemul luat — până atunci n-ar avea ce arăta.
const DASH_ICON := "res://Upgrades/upgrade_65.png"
const DASH_BADGE := 46.0                      # latura plăcuței (cât insigna de nivel)
const DASH_INSET := 9.0                       # cât intră iconița în interiorul ramei
const DASH_STINS := Color(0.42, 0.44, 0.52)   # cât de stinsă e iconița cât se reîncarcă
var _dash_box: Control
var _dash_icon: TextureRect
var _dash_val: ColorRect      # vălul închis care scade de sus în jos pe măsură ce se încarcă
var _dash_gata_ultim := true  # ca să prindem CLIPA în care devine gata (o dată, nu în fiecare cadru)

func _fa_dash() -> void:
	_dash_box = Control.new()
	_dash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dash_box.position = Vector2(VIATA_RECT.position.x, VIATA_RECT.end.y + 10.0)
	_dash_box.size = Vector2(DASH_BADGE, DASH_BADGE)
	_dash_box.pivot_offset = Vector2(DASH_BADGE, DASH_BADGE) * 0.5   # sare din centru când e gata
	_dash_box.modulate = BARA.UMBRA          # stinsă la fel ca barele (vezi UMBRA din hud_bara.gd)
	_dash_box.visible = false                # până iei itemul, nu există
	add_child(_dash_box)

	# ⚠️ Rama e PRIMA, nu ultima: `NinePatchRect` își desenează și MIJLOCUL (interiorul închis
	# al celulei), deci pusă peste iconiță o acoperea de tot — badge-ul ieșea un pătrat negru,
	# se vedea doar în captură (prins pe 2026-08-24). Așa, interiorul ei ține loc de fundal.
	var rama := NinePatchRect.new()
	rama.texture = BARA.chenar(Vector2i(3, 2), 1)   # același octogon cu spirale ca insigna de nivel
	rama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rama.patch_margin_left = 14
	rama.patch_margin_right = 14
	rama.patch_margin_top = 14
	rama.patch_margin_bottom = 14
	rama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dash_box.add_child(rama)

	_dash_icon = TextureRect.new()
	_dash_icon.texture = load(DASH_ICON)
	_dash_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dash_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dash_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dash_icon.position = Vector2(DASH_INSET, DASH_INSET)
	_dash_icon.size = Vector2(DASH_BADGE - DASH_INSET * 2.0, DASH_BADGE - DASH_INSET * 2.0)
	_dash_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dash_box.add_child(_dash_icon)

	# Vălul stă PESTE iconiță: e partea care NU s-a încărcat încă. Coboară, nu urcă — ochiul
	# citește „se golește ce e negru", ca la orice cooldown de abilitate.
	_dash_val = ColorRect.new()
	_dash_val.color = Color(0.03, 0.03, 0.05, 0.72)
	_dash_val.position = Vector2(DASH_INSET, DASH_INSET)
	_dash_val.size = Vector2(DASH_BADGE - DASH_INSET * 2.0, DASH_BADGE - DASH_INSET * 2.0)
	_dash_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dash_box.add_child(_dash_val)

func _update_dash(p) -> void:
	if _dash_box == null or not ("dash_unlocked" in p):
		return
	_dash_box.visible = bool(p.dash_unlocked)
	if not _dash_box.visible:
		return
	var incarcat: float = float(p.dash_charge())     # 0 = tocmai ai dat, 1 = gata
	var h: float = DASH_BADGE - DASH_INSET * 2.0
	_dash_val.size.y = h * (1.0 - incarcat)
	_dash_val.visible = incarcat < 1.0
	_dash_icon.modulate = Color.WHITE if incarcat >= 1.0 else DASH_STINS
	var gata: bool = incarcat >= 1.0
	if gata and not _dash_gata_ultim:
		_sare_dash()
	_dash_gata_ultim = gata

# Aceeași săritură ca la insigna de nivel: se vede cu coada ochiului că s-a întâmplat ceva bun.
func _sare_dash() -> void:
	var t := create_tween()
	t.tween_property(_dash_box, "scale", Vector2(1.3, 1.3), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_dash_box, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _mmss(secunde: float) -> String:
	var s := int(secunde)
	return "%d:%02d" % [s / 60, s % 60]
