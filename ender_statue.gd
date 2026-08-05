extends StaticBody2D

# STATUIA ENDER — călugărul de piatră din `harta/Ender Statue.png`, negustorul dimensiunii.
# Apare NUMAI în Ender (o naște `ender_statues.gd`, un generator care merge doar cât `ender.active`
# — vezi acolo de ce nu putea intra pur și simplu în lista celorlalte generatoare).
#
# Apeși E pe ea → se deschide masa de schimb (`trade.gd`): îți arată `randuri` (3) dintre itemele
# tale, oricare ar fi raritatea lor, fiecare cu o săgeată spre ce POATE DEVENI — un item cu
# `trepte` (2) rarități mai sus. Alegi un rând și schimbul se face pe loc.
#
# PREȚUL nu e în bani (jocul n-are bani) și nici în viață: e în DIFICULTATE. Fiecare tranzacție
# adaugă `TRADE_COST` (15) secunde în `Difficulty.penalty`, adică inamicii devin pe loc mai mulți,
# mai iuți și mai tari — pentru tot restul rundei, în toate dimensiunile. Citește comentariul de
# la `Difficulty.penalty`: se adună în ceasul INAMICILOR, nu în cel de pe ecran, tocmai ca să nu
# poți cumpăra scor cu el.
#
# ⚠️ CE NU FACE schimbul: nu-ți IA înapoi efectul itemului dat. Efectele se aplică o singură dată,
# în clipa luării (`levelup.gd::_apply`), direct peste statusuri — nicăieri în joc nu există
# „scoate itemul înapoi", iar pentru jumătate din ele nici n-ar avea sens (Panic Button a explodat
# deja, Wine te-a vindecat deja). Deci itemul dispare din REGISTRU (`player.run_items`), nu din
# statusurile tale. Practic: schimbul e un câștig curat, plătit în dificultate — exact prețul
# cerut. Dacă vrei să te și coste puterea itemului dat, ăsta e locul de unde se pleacă, dar
# atunci trebuie scris un „dez-aplică" pentru toate cele 50 de iteme.
#
# O statuie face UN SINGUR schimb, apoi se stinge (rămâne pe loc, mai întunecată). Fără regula
# asta ai fi putut schimba la nesfârșit pe aceeași statuie: fiecare schimb îți lasă registrul la
# fel de mare (dai unul, primești unul), deci n-ar fi existat nicio limită naturală.
#
# Poziția nodului = TALPA statuii și linia de Y-sort; arta coboară `ACOPERIRE_JOS` sub ea, ca la
# statuia normală, la monument și la copaci (motivul lung e în `statue.gd`).

@export var interact_range: float = 200.0

# --- Reglajele schimbului (le citește `trade.gd`) ---
@export var randuri: int = 3          # câte iteme de-ale tale îți arată
@export var trepte: int = 2           # cu câte rarități urcă itemul primit
@export var cost_dificultate: float = 15.0   # secunde de dificultate per tranzacție

# Cât se stinge statuia după ce a făcut schimbul (1.0 = neatinsă).
@export var stins: float = 0.45
@export var stins_time: float = 0.6

const ACOPERIRE_JOS := 74.0

var _folosita := false

# Textul de deasupra stă la vârful REAL al artei, nu la o cifră scrisă de mână (aceeași socoteală
# ca la monument). Se calculează în `_ready`.
var label_offset_y: float = -240.0

func _ready() -> void:
	add_to_group("ender_statue")
	add_to_group("interactable")
	_aseaza_arta()
	label_offset_y = _varf_y() - 40.0

# Așază arta cu baza desenată la `ACOPERIRE_JOS` sub originea nodului. Calculat la rulare din
# pixelii chiar desenați (`get_used_rect`), ca să nu se strice dacă Răzvan schimbă poza.
func _aseaza_arta() -> void:
	var sprite := $Sprite2D as Sprite2D
	if sprite == null or sprite.texture == null or sprite.scale.y == 0.0:
		return
	var used := sprite.texture.get_image().get_used_rect()
	var jos := float(used.position.y + used.size.y)
	sprite.offset.y = ACOPERIRE_JOS / sprite.scale.y - (jos - float(sprite.texture.get_height()) * 0.5)

# Înălțimea vârfului față de talpă (negativ = în sus).
func _varf_y() -> float:
	var sprite := $Sprite2D as Sprite2D
	if sprite == null or sprite.texture == null:
		return -260.0
	var varf_px := float(sprite.texture.get_image().get_used_rect().position.y)
	return sprite.scale.y * (sprite.offset.y + varf_px - float(sprite.texture.get_height()) * 0.5)

# Câte iteme ai strâns în runda asta (registrul din `player.gd`).
func _cate_iteme() -> int:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not ("run_items" in p):
		return 0
	return p.run_items.size()

# Cât timp mai poate fi folosită, `interact_ui.gd` arată textul de deasupra. După schimb devine
# `false` și statuia rămâne o piatră fără text — semn că și-a făcut treaba.
func poate_invoca() -> bool:
	return not _folosita

# Ce scrie deasupra. "" = textul obișnuit cu tasta. Dacă n-ai încă niciun item, spune-o —
# altfel apeși E, nu se deschide nimic și pare stricată (aceeași grijă ca la cufărul încuiat).
func eticheta() -> String:
	return "" if _cate_iteme() > 0 else "Nothing to trade"

func invoca() -> void:
	if _folosita or _cate_iteme() == 0:
		return
	var masa = get_tree().get_first_node_in_group("trade_menu")
	if masa == null:
		return
	masa.open(self)

# Chemată de `trade.gd` după un schimb reușit.
func consuma() -> void:
	if _folosita:
		return
	_folosita = true
	var sprite := $Sprite2D as Sprite2D
	if sprite == null:
		return
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color(stins, stins, stins, 1.0), stins_time)
