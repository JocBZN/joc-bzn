extends CanvasLayer

# Bara de viață a boss-ului: o plăcuță lată SUS pe ecran, cu numele sub ea.
# Apare când boss-ul e chemat, dispare când moare (sau când e scos din scenă, ex. ieși din Nether).
#
# **Sus, nu jos, de pe 2026-08-05** („vreau ca bara de hp si numele sa fie sus"). Era jos, în
# stilul Dark Souls, dar cinematica de intrare a lui Celesto ține camera strânsă pe el în
# jumătatea de sus a ecranului, iar bara rămânea singură tocmai la celălalt capăt.
#
# **Îmbrăcată în aramă pe 2026-08-24.** Era un dreptunghi cu chenar de 2px desenat din cod; acum
# e ACEEAȘI plăcuță ca viața playerului (celula (0,3) din `harta/EGT/Border EGT.png`, colțuri cu
# nituri), doar că la ZOOM 2 — de două ori mai groasă, de două ori mai grea. Așa se vede dintr-o
# privire că sunt din aceeași familie și care dintre ele e cea importantă. Cum e construită o
# bară scrie în `hud_bara.gd`; aici rămân doar așezarea, intrarea cinematică și numele.
#
# ⚠️ Numele stă SUB bară, nu deasupra ei: sus-centru e deja ocupat de cronometrul rundei
# (`hud.gd`, 44px de la y=14) și de cel al Ender-ului (`ender.gd`, 64px de la y=8), care coboară
# până pe la y≈85. De-acolo pornește `DE_SUS`. Dacă mai urci ceva sus-centru, verifică-le pe
# toate trei — se suprapun în tăcere, nimic nu te avertizează.
#
# O folosesc `saratalin.gd`, `celesto.gd`, `ender.gd`, `nether.gd`, `prison.gd`, `final_boss.gd`.
# E scrisă general (`arata(nume, hp_max)`), deci orice boss nou o poate chema la fel.
#
# ⚠️ `process_mode = ALWAYS`: cinematica de la jumătatea vieții ÎNGHEAȚĂ jocul
# (`get_tree().paused = true`), iar tween-urile de aici trebuie să meargă mai departe.
# Un tween e legat de nodul care l-a creat și se oprește dacă acel nod e pe pauză.

const BARA := preload("res://hud_bara.gd")

const LATIME := 0.56          # cât din lățimea ecranului ocupă bara (0..1)
const INALTIME := 64.0        # grosimea plăcuței (rama mănâncă 16 de fiecare parte, la ZOOM 2)
const DE_SUS := 88.0          # de la ce înălțime începe plăcuța (sub cele două cronometre)
const TREPTE := 10            # crestăturile de peste viață — se vede din ochi cât ai mai rupt

const C_VIATA := Color8(184, 30, 44)          # roșu-sânge
const C_URMA := Color8(232, 168, 176)         # fantoma care rămâne în urma loviturii
const C_NUME := Color8(232, 224, 214)         # alb-os, ca titlurile din meniuri

var _radacina: Control     # tot blocul (plăcuță + nume); intrarea cinematică îl mișcă pe el
var _nume: Label
var _bara: Control         # o instanță de `hud_bara.gd`
var _hp_max := 1.0
var _hp_ultim := -1.0      # ca să clipească doar când chiar a încasat (vezi `set_hp`)
var _intrare: Tween

func _ready() -> void:
	add_to_group("boss_bar")
	layer = 6                                  # peste HUD (nether e 4), sub Level Up / Game Over
	process_mode = Node.PROCESS_MODE_ALWAYS    # vezi nota de sus: cinematica rulează pe pauză

	var radacina := Control.new()
	radacina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radacina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(radacina)
	_radacina = radacina

	_bara = BARA.new()
	_bara.construieste(Vector2i(0, 3), 2, 12, 8, C_VIATA, C_URMA)
	_bara.anchor_left = 0.5 - LATIME * 0.5
	_bara.anchor_right = 0.5 + LATIME * 0.5
	_bara.anchor_top = 0.0
	_bara.anchor_bottom = 0.0
	_bara.offset_top = DE_SUS
	_bara.offset_bottom = DE_SUS + INALTIME
	_bara.set_trepte(TREPTE)
	radacina.add_child(_bara)

	# numele, SUB plăcuță
	_nume = Label.new()
	_nume.anchor_left = 0.5
	_nume.anchor_right = 0.5
	_nume.anchor_top = 0.0
	_nume.anchor_bottom = 0.0
	_nume.offset_top = DE_SUS + INALTIME + 4.0
	_nume.offset_bottom = DE_SUS + INALTIME + 40.0
	_nume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nume.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_nume.add_theme_font_size_override("font_size", 26)
	_nume.add_theme_color_override("font_color", C_NUME)
	_nume.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_nume.add_theme_constant_override("outline_size", 7)
	_nume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(_nume)

	visible = false

# ---------- ce cheamă boss-ul ----------
func arata(nume: String, hp_max: int) -> void:
	_opreste_intrarea()
	_pregateste(nume, hp_max)
	_radacina.position.y = 0.0
	_radacina.modulate.a = 1.0
	visible = true

# INTRARE CINEMATICĂ: plăcuța COBOARĂ încet din afara ecranului și se aprinde odată cu numele.
# Cerută de Răzvan pe 2026-08-04 pentru Celesto („sa intre in cadru bara de hp cu numele lui asa
# slow cinematic"), dar scrisă general — orice boss o poate chema în loc de `arata()`.
#
# Se mișcă `_radacina`, nu plăcuța: ea e ancorată de marginea de sus cu offset-uri fixe, iar un
# `position` pus direct pe ea s-ar bate cu ancorele. Containerul, în schimb, e liber.
#
# `TWEEN_PAUSE_PROCESS` din același motiv ca `process_mode = ALWAYS` de mai sus: dacă vreodată se
# cheamă în timp ce jocul e pe pauză (cinematici), trebuie să meargă mai departe.
const INTRARE_DE_SUS := 90.0   # de câți pixeli mai SUS pornește (deci intră coborând)

func arata_cinematic(nume: String, hp_max: int, durata: float = 1.6) -> void:
	_opreste_intrarea()
	_pregateste(nume, hp_max)
	_radacina.position.y = -INTRARE_DE_SUS
	_radacina.modulate.a = 0.0
	visible = true
	_intrare = create_tween().set_parallel(true)
	_intrare.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intrare.tween_property(_radacina, "position:y", 0.0, durata) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# transparența urcă pe jumătatea a doua a drumului: plăcuța „se materializează" pe măsură ce
	# alunecă, nu apare întreagă din prima și apoi doar se mișcă
	_intrare.tween_property(_radacina, "modulate:a", 1.0, durata * 0.75)

# Ce e comun între cele două intrări: numele, viața plină și fantoma dusă la loc. Fără
# `sari_urma()` un boss nou ar începe cu fantoma rămasă de la cel de dinainte și ar arăta ca și
# cum ar fi încasat deja.
func _pregateste(nume: String, hp_max: int) -> void:
	_nume.text = nume
	_hp_max = maxf(float(hp_max), 1.0)
	_hp_ultim = _hp_max
	_bara.set_fractie(1.0)
	_bara.sari_urma()

func _opreste_intrarea() -> void:
	if _intrare != null and _intrare.is_valid():
		_intrare.kill()

func set_hp(hp: int) -> void:
	var v := float(hp)
	_bara.set_fractie(clampf(v / _hp_max, 0.0, 1.0))
	# clipit alb doar când SCADE: unii boși își pun viața la loc între faze, iar un fulger la
	# vindecare ar arăta ca și cum tocmai i-ai dat o lovitură
	if _hp_ultim >= 0.0 and v < _hp_ultim:
		_bara.fulgera(Color(1, 1, 1, 0.45), 0.20)
	_hp_ultim = v

func ascunde() -> void:
	_opreste_intrarea()
	visible = false
