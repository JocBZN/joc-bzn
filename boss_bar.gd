extends CanvasLayer

# Bara de viață a boss-ului, în stilul Dark Souls: o bandă lată și subțire jos pe ecran,
# cu numele deasupra ei. Apare când boss-ul e chemat, dispare când moare (sau când e
# scos din scenă, ex. ieși din Nether).
#
# O folosește `saratalin.gd`. E scrisă general (`arata(nume, hp_max)`), deci dacă mai apare
# un boss cu bară — Garda, de exemplu — o poate chema la fel, fără să schimbi nimic aici.
#
# ⚠️ `process_mode = ALWAYS`: cinematica de la jumătatea vieții ÎNGHEAȚĂ jocul
# (`get_tree().paused = true`), iar tween-urile de aici trebuie să meargă mai departe.
# Un tween e legat de nodul care l-a creat și se oprește dacă acel nod e pe pauză.

const LATIME := 0.56          # cât din lățimea ecranului ocupă bara (0..1)
const INALTIME := 20.0        # grosimea barei, în pixeli
const DE_JOS := 74.0          # cât de sus stă față de marginea de jos

const C_FUNDAL := Color(0.06, 0.04, 0.06, 0.85)   # golul din spatele barei
const C_CONTUR := Color(0.55, 0.47, 0.36)         # rama, auriu-șters ca în Dark Souls
const C_VIATA := Color(0.72, 0.10, 0.22)          # roșu-sânge
const C_URMA := Color(0.95, 0.55, 0.75, 0.55)     # „urma" albă-roz care rămâne în urma damage-ului

@export var urma_viteza: float = 0.55   # cât de repede coboară urma spre viața reală (fracție/sec)

var _nume: Label
var _bara: ProgressBar
var _urma: ProgressBar     # a doua bară, DESUB, care coboară cu întârziere (efectul din Dark Souls)
var _hp_max := 1.0

func _ready() -> void:
	add_to_group("boss_bar")
	layer = 6                                  # peste HUD (nether e 4), sub Level Up / Game Over
	process_mode = Node.PROCESS_MODE_ALWAYS    # vezi nota de sus: cinematica rulează pe pauză

	var radacina := Control.new()
	radacina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radacina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(radacina)

	# numele, deasupra barei
	_nume = Label.new()
	_nume.anchor_left = 0.5
	_nume.anchor_right = 0.5
	_nume.anchor_top = 1.0
	_nume.anchor_bottom = 1.0
	# DEASUPRA barei, nu peste ea: bara ocupă [-DE_JOS-INALTIME, -DE_JOS]
	_nume.offset_top = -DE_JOS - INALTIME - 42.0
	_nume.offset_bottom = -DE_JOS - INALTIME - 8.0
	_nume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nume.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_nume.add_theme_font_size_override("font_size", 24)
	_nume.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	_nume.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_nume.add_theme_constant_override("outline_size", 6)
	_nume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(_nume)

	# Urma stă DEDESUBT și ține fundalul + rama; viața reală se desenează peste ea, dar FĂRĂ
	# fundal — altfel dreptunghiul ei opac ar acoperi tocmai urma pe care vrem s-o vedem.
	_urma = _fa_bara(radacina, C_URMA, true)
	_bara = _fa_bara(radacina, C_VIATA, false)
	visible = false

func _fa_bara(parinte: Control, culoare: Color, cu_fundal: bool) -> ProgressBar:
	var b := ProgressBar.new()
	b.anchor_left = 0.5 - LATIME * 0.5
	b.anchor_right = 0.5 + LATIME * 0.5
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_top = -DE_JOS - INALTIME
	b.offset_bottom = -DE_JOS
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = 1.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cu_fundal:
		b.add_theme_stylebox_override("background", _stil(C_FUNDAL, C_CONTUR))
	else:
		b.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("fill", _stil(culoare, Color(0, 0, 0, 0)))
	parinte.add_child(b)
	return b

func _stil(umplere: Color, contur: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = umplere
	if contur.a > 0.0:
		sb.border_color = contur
		sb.set_border_width_all(2)
	return sb

# ---------- ce cheamă boss-ul ----------
func arata(nume: String, hp_max: int) -> void:
	_nume.text = nume
	_hp_max = maxf(float(hp_max), 1.0)
	_bara.value = 1.0
	_urma.value = 1.0
	visible = true

func set_hp(hp: int) -> void:
	_bara.value = clampf(float(hp) / _hp_max, 0.0, 1.0)

func ascunde() -> void:
	visible = false

# Urma coboară cu întârziere spre viața reală — de aia se vede cât ai mușcat dintr-o lovitură.
func _process(delta: float) -> void:
	if not visible:
		return
	if _urma.value > _bara.value:
		_urma.value = maxf(_bara.value, _urma.value - urma_viteza * delta)
	else:
		_urma.value = _bara.value
