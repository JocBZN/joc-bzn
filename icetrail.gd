extends Node2D

# Dâră de gheață lăsată de player când merge (upgrade Frostwalker).
# Oglinda lui firetrail.gd: joacă animația de gheață (din "frostwalker anim/"),
# ÎNCETINEȘTE inamicii care o ating (cu filtru albastru pe ei) și le face PUȚIN damage
# (≈ jumătate cât Firewalker), apoi se topește după `duration` secunde.

const FROST_SHEET := "res://Upgrades/frostwalker anim/frostwalker.png"  # spritesheet întreg (4 cadre pe orizontală)
const FROST_FRAME_COUNT := 4
const VISUAL_OFFSET := Vector2(0, 62)     # vizualul (și zona de efect) coborâte la picioarele player-ului
const GROUND_TILT_DEG := 45.0             # turtim vizualul pe Y → pare culcat pe sol (perspectivă +45° pe verticală)
const ANIM_FPS := 6.0                     # viteza animației (mai mică = se mișcă mai puțin stânga-dreapta)
const DESATURATE := 0.5                   # cât scădem saturația culorii (0.5 = −50%)

static var _desat_tex: Texture2D          # sheet-ul cu saturația redusă, procesat o singură dată și refolosit

# setate de player ÎNAINTE de add_child (ca _ready să le folosească)
var duration: float = 1.0     # cât rămâne gheața pe jos (secunde)
var damage: int = 2           # damage pe tick (mic — ≈ jumătate din Firewalker)
var size: float = 80.0        # lățimea gheții în px (crește cu fiecare upgrade)
var tick_interval: float = 0.4  # cât de des aplică slow + damage
var radius: float = 32.0      # raza de efect (derivată din `size` în _ready)
var slow_hold: float = 0.5    # cât timp stă înghețat inamicul (setat de player, crește cu fiecare upgrade)
var direction: Vector2 = Vector2.LEFT  # direcția de mers a player-ului (păstrată pt. paritate cu focul)

static var _frames: SpriteFrames  # cadrele, construite o singură dată și refolosite

func _ready() -> void:
	z_index = -1  # mereu SUB actori (player/inamici), dar peste teren
	radius = size * 0.4  # zona de efect ≈ din lățimea gheții
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = _get_frames()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# scalăm ca gheața să fie lată `size` px, indiferent de rezoluția cadrului din sheet
	var fw := 32.0
	if anim.sprite_frames.get_frame_count("default") > 0:
		fw = float(anim.sprite_frames.get_frame_texture("default", 0).get_width())
	anim.scale = Vector2.ONE * (size / fw)
	# perspectivă pe verticală (+45°): turtim pe Y ca gheața să pară întinsă pe pământ, nu ridicată
	anim.scale.y *= cos(deg_to_rad(GROUND_TILT_DEG))
	anim.position = VISUAL_OFFSET  # coborâm vizualul la picioare (nodul e putin deasupra → y-sort: gheața în spate)
	anim.play("default")
	add_child(anim)

	# aplică slow + damage periodic cât timp gheața e activă
	var t := Timer.new()
	t.wait_time = tick_interval
	t.timeout.connect(_chill)
	add_child(t)
	t.start()

	# ține `duration` secunde, apoi se topește lin și dispare
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(anim, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

func _get_frames() -> SpriteFrames:
	if _frames != null and _frames.get_frame_count("default") > 0:
		return _frames
	_frames = SpriteFrames.new()
	_frames.set_animation_speed("default", ANIM_FPS)
	_frames.set_animation_loop("default", true)
	# feliem spritesheet-ul (deja desaturat pe pixeli) în FROST_FRAME_COUNT cadre egale pe orizontală
	var sheet := _get_desaturated_sheet()
	if sheet != null:
		var w := sheet.get_width()
		var h := sheet.get_height()
		# margini cu rotunjire → cadrele acoperă exact toată lățimea, fără drift stânga-dreapta
		# și fără cadru tăiat, chiar dacă W nu se împarte fix la FROST_FRAME_COUNT
		for i in FROST_FRAME_COUNT:
			var x0 := int(round(float(i) * w / FROST_FRAME_COUNT))
			var x1 := int(round(float(i + 1) * w / FROST_FRAME_COUNT))
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(x0, 0, x1 - x0, h)
			_frames.add_frame("default", at)
	return _frames

# Procesează sheet-ul o singură dată: scade saturația fiecărui pixel cu DESATURATE.
# „Baked" pe pixeli (nu shader) → sigur vizibil, fără interacțiuni cu AtlasTexture.
func _get_desaturated_sheet() -> Texture2D:
	if _desat_tex != null:
		return _desat_tex
	var src := load(FROST_SHEET) as Texture2D
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return src  # nu putem citi pixelii → folosim originalul (fără desaturare)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			c.r = lerpf(c.r, lum, DESATURATE)
			c.g = lerpf(c.g, lum, DESATURATE)
			c.b = lerpf(c.b, lum, DESATURATE)
			img.set_pixel(x, y, c)
	_desat_tex = ImageTexture.create_from_image(img)
	return _desat_tex

func _chill() -> void:
	var center := global_position + VISUAL_OFFSET  # zona de efect e pe gheață, nu pe nod
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if center.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(damage)        # damage mic (≈ jumătate din foc)
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_hold)  # + încetinire (durata crește cu upgrade-urile), filtru albastru
