extends Control

# ECRANUL DE ÎNCĂRCARE — prima scenă a jocului, ÎNAINTE de meniu (cerut de Răzvan pe 2026-08-05).
#
# Cât stai aici, `PreloadAll` citește de pe disc toată arta și tot sunetul și le ȚINE în memorie.
# După asta, nici meniul, nici intrarea în joc, nici trecerea în Nether/Ender nu mai au ce citi de
# pe disc — de-asta dispare hop-ul de la primele secunde ale rundei și de la schimbarea dimensiunii.
#
# Ecranul ăsta se desenează din trei lucruri UȘOARE (cadrul static de fundal, un cadru de logo și
# niște dreptunghiuri colorate). Dacă și el ar aștepta arta grea, n-ar mai avea niciun rost.
#
# ⚠️ Bara NU se mișcă lin ca un ceas: sare mai mult la fișierele mari (cele 120 de cadre de fundal
# ale meniului sunt 1920×1080 fiecare). E normal — procentul e „câte fișiere din câte", nu „câți
# octeți din câți". `_afisat` face saltul mai blând, urmărind ținta din urmă.

const URMATOAREA := "res://menu.tscn"
const FUNDAL := "res://menu/bg_still.webp"
const LOGO := "res://menu/Title/title_1.png"

const CYAN := Color(0.2, 0.9, 1.0)
const AURIU := Color(0.95, 0.85, 0.55)

const BARA_LAT := 0.52     # cât din lățimea ecranului ocupă bara (0..1)
const BARA_INALT := 14.0
const BARA_DE_JOS := 120.0 # cât de sus stă față de marginea de jos
const LOGO_SIZE := 240.0
# Cât de repede ajunge bara desenată din urmă valoarea reală (fracțiune pe secundă).
const URMARIRE := 6.0
# Cât mai stă pe ecran după ce s-a terminat, ca să apuci să vezi „100%" în loc de o clipire.
const RESPIRO := 0.35

var _umplere: ColorRect
var _procent: Label
var _afisat := 0.0
var _iesim := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundal()
	_logo()
	_bara()
	PreloadAll.porneste()

func _fundal() -> void:
	var fund := ColorRect.new()
	fund.color = Color(0.03, 0.03, 0.06)
	fund.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fund)
	if not ResourceLoader.exists(FUNDAL):
		return
	var poza := TextureRect.new()
	poza.texture = load(FUNDAL)
	poza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poza.stretch_mode = TextureRect.STRETCH_SCALE
	poza.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	poza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# stins tare: e fundal, nu subiect — textul și bara trebuie să se vadă peste el
	poza.modulate = Color(1, 1, 1, 0.30)
	add_child(poza)

func _logo() -> void:
	if not ResourceLoader.exists(LOGO):
		return
	var l := TextureRect.new()
	l.texture = load(LOGO)
	l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_left = -LOGO_SIZE * 0.5
	l.offset_right = LOGO_SIZE * 0.5
	l.offset_top = -LOGO_SIZE * 0.5 - 60.0   # deasupra mijlocului: sub el stă bara
	l.offset_bottom = LOGO_SIZE * 0.5 - 60.0
	add_child(l)

func _bara() -> void:
	# șanțul barei
	var sant := ColorRect.new()
	sant.color = Color(0.06, 0.07, 0.12, 0.9)
	_pune_bara(sant)
	add_child(sant)
	# rama, ca să nu plutească pe fundal
	var rama := ColorRect.new()
	rama.color = Color(0, 0, 0, 0)
	_pune_bara(rama)
	add_child(rama)
	# umplerea: pornește de la lățime 0 și crește spre dreapta
	_umplere = ColorRect.new()
	_umplere.color = CYAN
	_pune_bara(_umplere)
	_umplere.anchor_right = _umplere.anchor_left
	add_child(_umplere)

	_procent = Label.new()
	_procent.anchor_left = 0.0
	_procent.anchor_right = 1.0
	_procent.anchor_top = 1.0
	_procent.anchor_bottom = 1.0
	_procent.offset_top = -BARA_DE_JOS - BARA_INALT - 46.0
	_procent.offset_bottom = -BARA_DE_JOS - BARA_INALT - 8.0
	_procent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_procent.add_theme_font_size_override("font_size", 22)
	_procent.add_theme_color_override("font_color", AURIU)
	_procent.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_procent.add_theme_constant_override("outline_size", 6)
	_procent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_procent.text = tr("LOADING %d%%") % 0
	add_child(_procent)

func _pune_bara(c: Control) -> void:
	c.anchor_left = 0.5 - BARA_LAT * 0.5
	c.anchor_right = 0.5 + BARA_LAT * 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_top = -BARA_DE_JOS - BARA_INALT
	c.offset_bottom = -BARA_DE_JOS
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if _iesim:
		return
	var terminat := PreloadAll.pas()
	var tinta := 1.0 if terminat else PreloadAll.progres()
	_afisat = move_toward(_afisat, tinta, URMARIRE * delta)
	if terminat and _afisat >= 0.999:
		_afisat = 1.0
	var stanga := 0.5 - BARA_LAT * 0.5
	_umplere.anchor_right = stanga + BARA_LAT * _afisat
	# `tr()`, nu text simplu: are `%d` înăuntru (vezi regula din CLAUDE.md)
	_procent.text = tr("LOADING %d%%") % int(round(_afisat * 100.0))
	if terminat and _afisat >= 1.0:
		_iesim = true
		await get_tree().create_timer(RESPIRO).timeout
		get_tree().change_scene_to_file(URMATOAREA)
		# Cadrele de fundal ale meniului sunt ținute doar până se deschide el (vezi
		# `PreloadAll.TEMPORARE`). Nodul ăsta e pe cale să dispară odată cu scena, deci
		# așteptarea o face autoload-ul, care rămâne.
		PreloadAll.preda_meniului()
