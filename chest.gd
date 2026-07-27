extends StaticBody2D

# Cufăr găsit lângă poteci. Unde apar și cu ce șansă → `chests.gd`.
#
# Când te apropii, deasupra lui scrie „Press E to interact" — exact ca la statuie și la
# portal. Nu trebuie nimic special pentru asta: `interact_ui.gd` caută prin grupul
# „interactable" și cere doar `interact_range`, `poate_invoca()` și `invoca()`.
#
# La apăsarea tastei rulează animația de deschidere (cele 3 cadre din
# `harta/Chest/Chest Animation/`), capacul rămâne ridicat, iar textul dispare fiindcă
# `poate_invoca()` întoarce de-acum `false` — un cufăr se deschide o singură dată.
#
# Ce primești: **un upgrade la întâmplare din toate cele din joc**, aplicat pe loc, fără ecran
# de ales (`levelup.gd::da_random_acum()`). Deasupra cufărului pleacă efectul din `chest_fx.gd`:
# explozie de raze multicoloră → iconița itemului primit → se stinge.
#
# Poziția nodului = linia de SORTARE (Y-sort), NU talpa artei: arta coboară `BASE_JOS`
# pixeli sub ea, ca player-ul care trece prin fața cufărului să fie desenat peste el.

@export var interact_range: float = 160.0    # cât de aproape trebuie să fii ca să apară textul
@export var label_offset_y: float = -95.0    # cât de sus stă textul (îl citește `interact_ui.gd`)
                                             # E în pixeli de LUME, deci nu se micșorează odată cu
                                             # `scale`-ul cufărului (0.7 în scenă, adică vârful lăzii
                                             # închise e la -47). Schimbi scara → mută și cifra asta.
@export var open_fps: float = 7.0            # viteza animației de deschidere (3 cadre ≈ 0.43s)
@export var fx_offset_y: float = -120.0      # cât de sus deasupra cufărului pleacă explozia

const CHEST_FX := preload("res://chest_fx.gd")

# Cutia DESENATĂ a cufărului închis, în pixelii TEXTURII (nu ai lumii): arta ocupă 102×91 px
# din imaginea de 128×128, restul e transparent. Din ea calculează `chests.gd` cât să-l
# depărteze de potecă. Dacă schimbi imaginile, schimbă și cifrele — scara nodului NU trebuie
# băgată aici, o înmulțește `cutie()` singură.
const ART_W := 102.0
const ART_H := 91.0
const BASE_JOS := 24.0   # cât coboară talpa artei sub originea nodului (linia de sortare)

var _deschis := false

func _ready() -> void:
	# „interactable" = tot ce poate afișa „Press E to interact" (statui, portaluri, cufere).
	add_to_group("interactable")
	var spr := $AnimatedSprite2D as AnimatedSprite2D
	spr.sprite_frames.set_animation_speed("open", open_fps)
	spr.frame = 0   # cufăr închis; animația pornește abia când apeși E

# Cutia desenată în PIXELI DE LUME, față de originea nodului: X în jurul centrului, Y în sus
# de la talpă. `chests.gd` o folosește ca să lase exact distanța cerută între marginea potecii
# și marginea cufărului, pe oricare din cele 4 laturi ar cădea.
#
# ⚠️ Înmulțim cu `scale` (0.7 în `chest.tscn`), de aia NU mai e `static`: o cutie calculată la
# scara 1 ar fi crezut cufărul cu 43% mai mare decât e și l-ar fi împins cu ~15px prea departe
# de potecă. Generatorul măsoară un exemplar de probă — vezi `chests.gd::_cutie_cufar()`.
func cutie() -> Rect2:
	return Rect2(Vector2(-ART_W * 0.5, BASE_JOS - ART_H) * scale, Vector2(ART_W, ART_H) * scale)

# Mai poate fi deschis? `interact_ui.gd` întreabă asta înainte să arate textul.
func poate_invoca() -> bool:
	return not _deschis

# Apăsarea tastei de interacțiune ajunge aici.
func invoca() -> void:
	if _deschis:
		return
	_deschis = true
	var spr := $AnimatedSprite2D as AnimatedSprite2D
	spr.play("open")   # „open" nu e în buclă → se oprește singură pe ultimul cadru (capac ridicat)

	# Recompensa se dă ACUM, nu la sfârșitul animației: dacă mori sau pleci în timpul ei, tot
	# ai luat-o. Animația doar ARATĂ ce ai primit.
	var meniu := get_tree().get_first_node_in_group("levelup_menu")
	var primit = meniu.da_random_acum() if meniu != null else null
	var cale_icon: String = meniu.icon_path(primit) if primit != null else ""

	# Efectul se agață de LUME, nu de cufăr: containerul de chunk al cufărului se șterge când
	# te îndepărtezi, iar animația ar muri la jumătate. Lumea e locul unde `spawner.gd` pune
	# și inamicii — adică părintele player-ului.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var lume: Node = player.get_parent() if player != null else get_parent()
	var fx := CHEST_FX.new()
	lume.add_child(fx)
	fx.porneste(global_position + Vector2(0, fx_offset_y), cale_icon)
