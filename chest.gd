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
# ⚠️ Deschiderea e DEOCAMDATĂ doar animația: cufărul nu dă încă nimic (bani, viață,
# upgrade). Când vrei să dea, locul e la sfârșitul lui `invoca()`.
#
# Poziția nodului = linia de SORTARE (Y-sort), NU talpa artei: arta coboară `BASE_JOS`
# pixeli sub ea, ca player-ul care trece prin fața cufărului să fie desenat peste el.

@export var interact_range: float = 160.0    # cât de aproape trebuie să fii ca să apară textul
@export var label_offset_y: float = -125.0   # cât de sus stă textul (îl citește `interact_ui.gd`)
                                             # -125 = deasupra CAPACULUI RIDICAT (arta urcă până la -85),
                                             # nu doar deasupra cufărului închis
@export var open_fps: float = 7.0            # viteza animației de deschidere (3 cadre ≈ 0.43s)

# Cutia DESENATĂ a cufărului închis, în pixeli, față de originea nodului. Din ea calculează
# `chests.gd` cât să-l depărteze de potecă. Arta ocupă 102×91 px din textura de 128×128
# (restul e transparent), la `scale = 1` din `chest.tscn` — dacă schimbi scara sau imaginile,
# schimbă și cifrele astea, altfel distanța până la potecă iese greșită.
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

# Cutia desenată, față de originea nodului: X în jurul centrului, Y în sus de la talpă.
# `chests.gd` o folosește ca să lase EXACT distanța cerută între marginea potecii și
# marginea cufărului, pe oricare din cele 4 laturi ar cădea.
# `static` = se poate cere FĂRĂ să existe un cufăr (`preload("res://chest.gd").cutie()`),
# fiindcă generatorul are nevoie de mărime ca să afle UNDE să-l pună.
static func cutie() -> Rect2:
	return Rect2(-ART_W * 0.5, BASE_JOS - ART_H, ART_W, ART_H)

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
	# AICI se pune recompensa, când vrei să dea ceva:
	#   await spr.animation_finished
	#   GameSettings.add_coins(...)
