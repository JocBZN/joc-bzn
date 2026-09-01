extends Sprite2D

# SIGILIUL HOARDEI — cercul care se aprinde pe jos în jurul monumentului cât ține swarm-ul
# (cerut de Răzvan pe 2026-09-01: „la monumentul de swarm să aibă un cerc în timpul swarm-ului,
# să arate profesionist și să se vadă mai bine că ești în swarm").
#
# Până azi swarm-ul se vedea DOAR pe HUD: bannerul „Swarm has started" (trece în 3 secunde) și
# rândul „Swarm Timer: 0:10" de sub cronometru. Adică, în lume, nimic: te trezeai cu 103 creaturi
# în cap și singurul semn că e ceva special era un text mic sus, unde nu te uiți când fugi.
# Cercul mută informația AICI, unde se joacă jocul.
#
# Ce e, de fapt: UN singur Sprite2D pătrat, cu `swarm_ring.gdshader` pe el. Textura (8×8 alb) nu
# se citește niciodată — e doar suportul pe care motorul are ce deseneze; tot inelul e calculat în
# shader, din UV. De aia n-are nicio limită de rezoluție și de aia costă un singur draw call.
#
# Trei lucruri pe care le face și pentru care merită citit înainte să-l „simplifice" cineva:
#
#  1. E ȘI CRONOMETRU. Inelul se golește în sensul acelor de ceasornic, pornind din vârf, exact cât
#     mai are hoarda de curs — aceeași cifră pe care o scrie HUD-ul, doar că nu trebuie să-ți iei
#     ochii de pe jucător ca s-o citești. Nu-și numără singur timpul: îl HRĂNEȘTE monumentul, cadru
#     cu cadru, cu ceasul lui (vezi `monument.gd::_scoate_hoarda`).
#
#  2. NU FOLOSEȘTE `TIME` din shader. `TIME` e ceasul de perete al plăcii video și curge și când
#     jocul e pe pauză — iar în 10 secunde de hoardă aproape sigur prinzi un Level Up, care oprește
#     arborele (`levelup.gd`). Cu `TIME`, cât alegeai upgrade-ul, dinții s-ar fi învârtit voios în
#     spatele meniului. Uniforma `timp` e adunată din delta cadrelor de aici, deci stă pe loc pe
#     pauză, ca tot restul jocului. Aceeași grijă ca la ceasul hoardei din `monument.gd`.
#
#  3. SE ÎNCHIDE SINGUR DACĂ MONUMENTUL TACE. `_ttl` scade în fiecare cadru și e umplut la loc de
#     fiecare `alimenteaza()`; dacă trec `TTL` secunde fără vești, cercul se stinge din proprie
#     inițiativă. E FIX soluția de la cronometrul din HUD (`hud.gd::SWARM_TTL`) și rezolvă toate
#     cazurile în care monumentul dispare fără să apuce să spună „gata": mori, dai restart, sau
#     intri într-o dimensiune (Nether/Ender/pușcărie opresc generatoarele de decor, iar monumentul
#     e copilul unuia dintre ele → e eliberat, corutina lui iese pe `is_inside_tree()`, noi rămânem
#     în `World` fără nimeni care să ne hrănească).

const SHADER := preload("res://swarm_ring.gdshader")

# Unde stă inelul în pătratul shaderului. Legată de `raza` din shader — dacă o schimbi într-un loc
# și nu în celălalt, cercul iese de altă mărime decât cea cerută. Restul până la 1.0 e locul în care
# încap haloul și dinții din afară.
const RAZA_UV := 0.70

const TTL := 0.4          # cât mai trăiește fără vești de la monument (ca `hud.gd::SWARM_TTL`)
const APARITIE := 0.45    # cât ține deschiderea
const STINGERE := 0.55    # cât ține închiderea
const SCARA_START := 0.32 # de la ce mărime pornește (se umflă spre 1.0)

# Peste iarbă și peste poteci (`pathways.gd` e la z=-5), dar SUB umbre (z=-1) și sub tot ce umblă.
# Adică: e desenat pe pământ, iar creaturile care calcă peste el trec pe deasupra, cu umbră cu tot.
# Dacă îl urci peste -1, umbrele intră sub el și inamicii par că plutesc peste un abțibild.
const Z := -4

var raza: float = 480.0   # raza în pixeli de lume; o pune monumentul înainte de `add_child`

var _mat: ShaderMaterial
var _timp := 0.0
var _f := SCARA_START     # scara și intensitatea de ACUM: de la ele pornește închiderea, chiar
var _i := 0.0             # dacă ea prinde deschiderea la jumătate (altfel cercul ar sări)
var _ttl := TTL
var _inchis := false
var _tw: Tween            # deschiderea sau închiderea; una singură deodată (vezi `inchide`)

static var _tex_cache: ImageTexture = null

# Pânza pe care desenăm: 8×8 pixeli albi, una singură pentru toate cercurile din viața procesului.
# Shaderul n-o citește, dar Sprite2D refuză să deseneze ceva fără textură.
static func _panza() -> ImageTexture:
	if _tex_cache == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		_tex_cache = ImageTexture.create_from_image(img)
	return _tex_cache

func _ready() -> void:
	texture = _panza()
	z_index = Z
	centered = true
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_seteaza_scara(SCARA_START)
	_mat.set_shader_parameter("progres", 1.0)
	_mat.set_shader_parameter("intensitate", 0.0)

	# Deschiderea: se umflă din centru cu frână la final (EASE_OUT) și se aprinde mai repede decât
	# se umflă, ca să se vadă din primul cadru că s-a întâmplat ceva. Merge pe `create_tween` pe
	# nodul nostru, deci se oprește singură pe pauză, la fel ca ceasul.
	_tw = create_tween()
	var t := _tw
	t.tween_method(_seteaza_scara, SCARA_START, 1.0, APARITIE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_seteaza_intensitatea, 0.0, 1.0, APARITIE * 0.55)

# Mărimea pătratului, ca `raza` în UV să cadă exact pe raza cerută în pixeli de lume.
# `_panza()` are 8 px, iar sprite-ul e centrat → jumătatea lui de lățime e `scale * 4`.
func _seteaza_scara(f: float) -> void:
	_f = f
	scale = Vector2.ONE * (raza / RAZA_UV / 4.0) * f

func _seteaza_intensitatea(v: float) -> void:
	_i = v
	if _mat != null:
		_mat.set_shader_parameter("intensitate", v)

func _process(delta: float) -> void:
	_timp += delta
	if _mat != null:
		_mat.set_shader_parameter("timp", _timp)
	if _inchis:
		return
	_ttl -= delta
	if _ttl <= 0.0:
		inchide()

# Chemată din `monument.gd` în fiecare cadru cât curge hoarda. `ramas` e 1.0 la început și 0.0 la
# sfârșit — adică FIX fracția pe care o scrie și HUD-ul, ca cele două să nu arate cifre diferite.
func alimenteaza(ramas: float) -> void:
	_ttl = TTL
	if _mat != null and not _inchis:
		_mat.set_shader_parameter("progres", clampf(ramas, 0.0, 1.0))

# Închiderea sigiliului: o clipire scurtă (inelul se aprinde mai tare decât a fost vreodată), apoi
# se stinge lărgindu-se puțin — se citește ca „s-a rupt", nu ca „a dispărut un obiect din scenă".
func inchide() -> void:
	if _inchis:
		return
	_inchis = true
	_mat.set_shader_parameter("progres", 0.0)
	# Hoarda poate muri în prima jumătate de secundă (mori, dai restart, intri într-un portal) —
	# atunci deschiderea încă rulează și ar trage scara înapoi peste închidere. O oprim întâi.
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	var t := _tw
	var f0 := _f
	t.tween_method(_seteaza_intensitatea, _i, 1.7, 0.10)
	t.parallel().tween_method(_seteaza_scara, f0, f0 * 1.035, 0.10)
	t.tween_method(_seteaza_intensitatea, 1.7, 0.0, STINGERE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(_seteaza_scara, f0 * 1.035, f0 * 1.09, STINGERE)
	t.tween_callback(queue_free)
