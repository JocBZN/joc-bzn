extends Sprite2D

# Fantoma albă lăsată în urmă de DASH (upgrade-ul Lightning Step), ca la un speedster.
#
# Fiecare fantomă e o COPIE a cadrului pe care player-ul îl arăta chiar în clipa aia, albită
# de tot și lăsată să se stingă pe loc. Nu e artă desenată de mână, ci chiar modelul curent —
# deci merge la fel cu orice personaj (azi e unul singur, mâine vor fi mai multe) și cu orice
# animație de mers, fără să mai adaug nimic aici.
#
# De ce `Sprite2D` și nu `AnimatedSprite2D`: fantoma e un CADRU ÎNGHEȚAT. O copie animată ar
# continua pasul de alergare pe loc și n-ar mai arăta a urmă, ci a al doilea player.
#
# Albirea e `white_flash.gdshader` (același folosit de block-ul lui Mike's Hedgehog), cu
# `flash = 1.0`: aruncă culoarea și păstrează silueta. `modulate` singur NU ajunge — el
# ÎNMULȚEȘTE, deci un sprite închis la culoare ar fi rămas închis oricât de alb i-ai da.

const DURATA := 0.32        # cât se stinge o fantomă (secunde)
const ALFA_START := 0.80    # cât de tare se vede în clipa în care e lăsată

# Materialul de albire e UNUL SINGUR, împărțit de toate fantomele: parametrul lui nu se
# schimbă niciodată (flash rămâne 1.0), iar stingerea o face `modulate:a`, care e al fiecărui
# nod în parte. Așa un dash de 8 fantome nu compilează 8 materiale.
static var _mat: ShaderMaterial

# Copiază din AnimatedSprite2D-ul player-ului cadrul curent și felul cum e așezat.
# ⚠️ Se cheamă ÎNAINTE de `add_child`, deci `global_transform` de aici e de fapt cel local;
# fantoma se așază apoi la poziția player-ului, în World (vezi `_drop_dash_ghost` din player.gd).
func copiaza(sursa: AnimatedSprite2D) -> void:
	var sf := sursa.sprite_frames
	if sf == null or not sf.has_animation(sursa.animation):
		return
	var cate := sf.get_frame_count(sursa.animation)
	if cate <= 0:
		return
	texture = sf.get_frame_texture(sursa.animation, clampi(sursa.frame, 0, cate - 1))
	centered = sursa.centered
	offset = sursa.offset
	flip_h = sursa.flip_h
	flip_v = sursa.flip_v
	scale = sursa.scale
	rotation = sursa.rotation
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	z_index = -1   # sub actori, peste teren — exact ca dârele de foc și de gheață
	material = _material()
	modulate = Color(1, 1, 1, ALFA_START)
	# QUAD + EASE_IN: fantoma își ține lumina cât ține pasul și abia apoi cade brusc. Invers
	# (stingere rapidă la început) urma se topea până apuca ochiul să o vadă ca dâră.
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, DURATA) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

static func _material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://white_flash.gdshader")
		_mat.set_shader_parameter("flash", 1.0)   # 1 = complet alb, transparența păstrată
	return _mat
