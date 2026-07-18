extends Node2D

# Frunze care cad de la un copac. Se agață de un singur copac (e copil al lui) și
# nu se vede decât la ~10% dintre copaci — vezi `props.gd`, care decide la încărcarea
# chunk-ului care copac „pierde frunze".
#
# Zona de cădere vine gata calculată din `props.gd` (`leaf_zone`), după dreptunghiurile
# pe care le-a desenat Răzvan peste doi copaci în `harta/Tree Leaf Area.png`: lățimea
# plină a copacului, de la ~31% din înălțimea lui (de la vârf) până puțin sub rădăcină.
# Adică frunzele cad peste trunchi și coroana de jos, nu pe iarbă lângă copac.
#
# Cât coboară, se sting: aproape de sol transparența ajunge la 0, ca și cum s-ar
# topi în iarbă (nu dispar brusc).

const LEAF_TEX := "res://harta/Leaf Overlay.png"
const LEAF_SIZE := 16          # o celulă din bandă
const LEAF_COUNT_IN_TEX := 5   # 5 frunze DIFERITE pe bandă (nu cadre de animație)

# --- Reglaje ---
const NR_FRUNZE := 8           # câte frunze cad odată de la un copac
const VITEZA_MIN := 22.0       # pixeli/secundă
const VITEZA_MAX := 45.0
const LEGANAT := 12.0          # cât se clatină stânga-dreapta în cădere
const ROTIRE := 0.8            # radiani/secundă
const SCALE_MIN := 1.0         # jumătate față de overlay-ul de dinainte (era 2.0–3.5)
const SCALE_MAX := 1.75
const ALPHA_MAX := 0.9
const PRAG_STINGERE := 0.8     # de la ce % din cădere începe să se stingă
                               # (0.8 = rămân vizibile aproape tot drumul și se topesc
                               #  abia în ultima cincime, lângă sol)
const PAUZA_MAX := 3.0         # cât așteaptă o frunză înainte să cadă din nou

var _zona_x: float = 0.0       # centrul zonei pe orizontală
var _zona_w: float = 40.0
var _start_y: float = 0.0
var _cadere: float = 60.0
var _frunze: Array = []

# Chemată de props.gd imediat după ce copacul e creat (ÎNAINTE de add_child).
# `zona` = dreptunghiul desenat, în coordonatele copacului.
func setup(zona: Rect2) -> void:
	_zona_x = zona.position.x + zona.size.x * 0.5
	_zona_w = zona.size.x
	_start_y = zona.position.y
	_cadere = zona.size.y

func _ready() -> void:
	if not ResourceLoader.exists(LEAF_TEX):
		push_warning("leaffall: lipsește %s" % LEAF_TEX)
		return
	var banda := load(LEAF_TEX)
	# PESTE copac: frunzele sunt copii ai copacului, iar cu z_index 0 unele intrau în
	# spatele coroanei. z_index 1 le ține mereu deasupra artei copacului.
	z_index = 1
	for i in NR_FRUNZE:
		var s := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = banda
		# fiecare frunză e aleasă separat din cele 5 → același copac scapă frunze diferite
		atlas.region = Rect2((randi() % LEAF_COUNT_IN_TEX) * LEAF_SIZE, 0, LEAF_SIZE, LEAF_SIZE)
		s.texture = atlas
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art clar, fără blur
		add_child(s)
		_frunze.append(_frunza_noua(s, true))

# Pregătește (sau repornește) o frunză de la începutul căderii.
# `imprastiat` = doar la pornire: o parte din frunze sunt deja în cădere, la înălțimi
# diferite, restul așteaptă — altfel toate ar porni în același moment, în bloc.
func _frunza_noua(s: Sprite2D, imprastiat := false) -> Dictionary:
	var sc := randf_range(SCALE_MIN, SCALE_MAX)
	s.scale = Vector2(sc, sc)
	s.rotation = randf() * TAU
	var deja_cade := imprastiat and randf() < 0.6
	var f := {
		"sprite": s,
		"x": _zona_x + randf_range(-_zona_w * 0.5, _zona_w * 0.5),
		"progres": randf() if deja_cade else 0.0,   # 0 = sus (la copac), 1 = jos (la sol)
		"viteza": randf_range(VITEZA_MIN, VITEZA_MAX),
		"faza": randf() * TAU,
		"rotire": randf_range(-ROTIRE, ROTIRE),
		"pauza": 0.0 if deja_cade else randf() * PAUZA_MAX,
	}
	_aseaza(f)  # sincronizăm sprite-ul imediat, ca să nu rămână la (0,0) cu alpha 1
	return f

# Pune sprite-ul unde trebuie și cu transparența potrivită, după `progres`.
func _aseaza(f: Dictionary) -> void:
	var s: Sprite2D = f["sprite"]
	var p: float = f["progres"]
	# se clatină stânga-dreapta cât coboară
	s.position = Vector2(
		f["x"] + sin(f["faza"] + p * 6.0) * LEGANAT,
		_start_y + p * _cadere
	)
	# aproape de sol se stinge lin până la 0
	var a := ALPHA_MAX
	if p > PRAG_STINGERE:
		a = ALPHA_MAX * (1.0 - (p - PRAG_STINGERE) / (1.0 - PRAG_STINGERE))
	s.modulate.a = a

func _process(delta: float) -> void:
	for i in _frunze.size():
		var f: Dictionary = _frunze[i]
		var s: Sprite2D = f["sprite"]
		# frunza „așteaptă" între două căderi → o ținem ascunsă
		if f["pauza"] > 0.0:
			f["pauza"] -= delta
			s.visible = false
			continue
		s.visible = true
		f["progres"] += (f["viteza"] * delta) / _cadere
		if f["progres"] >= 1.0:
			# a ajuns la sol → o luăm de la capăt, după o pauză, în alt loc
			var nou := _frunza_noua(s)
			nou["pauza"] = randf() * PAUZA_MAX
			_frunze[i] = nou
			continue
		_aseaza(f)
		s.rotation += f["rotire"] * delta
