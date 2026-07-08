extends Node2D

# Dâră "Godwalker": apare DOAR când player-ul are ȘI Firewalker ȘI Frostwalker.
# Înlocuiește ambele animații (foc + gheață) cu una singură și aplică ambele efecte:
# damage (foc + gheață combinate) ȘI încetinire (slow-ul de la gheață, filtru albastru pe inamic).
# Feliez spritesheet-ul Godwalker.png în 4 cadre la runtime, ca la icetrail.gd.

const GOD_SHEET := "res://Upgrades/godwalker anim/Godwalker.png"  # spritesheet întreg (4 cadre pe orizontală)
const GOD_FRAME_COUNT := 4
const VISUAL_OFFSET := Vector2(0, 62)     # vizualul (și zona de efect) coborâte la picioarele player-ului
const GROUND_TILT_DEG := 45.0             # turtim vizualul pe Y → pare culcat pe sol (perspectivă +45° pe verticală)
const ANIM_FPS := 4.0                     # viteza animației (mică = se mișcă puțin stânga-dreapta)

# setate de player ÎNAINTE de add_child
var duration: float = 1.0     # cât rămâne pe jos (secunde)
var damage: int = 7           # damage pe tick (foc + gheață combinate)
var size: float = 80.0        # lățimea în px
var tick_interval: float = 0.4  # cât de des aplică damage + slow
var radius: float = 32.0      # raza de efect (derivată din `size`)
var slow_hold: float = 0.5    # cât timp stă înghețat inamicul (setat de player, crește cu fiecare upgrade)
var direction: Vector2 = Vector2.LEFT

static var _frames: SpriteFrames  # cadrele, construite o singură dată și refolosite

func _ready() -> void:
	z_index = -1
	radius = size * 0.4
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = _get_frames()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# scalăm ca dâra să fie lată `size` px, indiferent de rezoluția cadrului din sheet
	var fw := 32.0
	if anim.sprite_frames.get_frame_count("default") > 0:
		fw = float(anim.sprite_frames.get_frame_texture("default", 0).get_width())
	anim.scale = Vector2.ONE * (size / fw)
	# perspectivă pe verticală (+45°): turtim pe Y ca dâra să pară întinsă pe sol
	anim.scale.y *= cos(deg_to_rad(GROUND_TILT_DEG))
	anim.position = VISUAL_OFFSET
	anim.play("default")
	add_child(anim)

	var t := Timer.new()
	t.wait_time = tick_interval
	t.timeout.connect(_smite)
	add_child(t)
	t.start()

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
	# feliem spritesheet-ul în GOD_FRAME_COUNT cadre egale pe orizontală (fără fișiere separate)
	var sheet := load(GOD_SHEET) as Texture2D
	if sheet != null:
		var w := sheet.get_width()
		var h := sheet.get_height()
		# margini cu rotunjire → cadrele acoperă exact toată lățimea, fără drift stânga-dreapta
		# și fără cadru tăiat, chiar dacă W nu se împarte fix la GOD_FRAME_COUNT
		for i in GOD_FRAME_COUNT:
			var x0 := int(round(float(i) * w / GOD_FRAME_COUNT))
			var x1 := int(round(float(i + 1) * w / GOD_FRAME_COUNT))
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(x0, 0, x1 - x0, h)
			_frames.add_frame("default", at)
	return _frames

func _smite() -> void:
	var center := global_position + VISUAL_OFFSET
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null:
			continue
		if center.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(damage)        # damage combinat (foc + gheață)
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_hold)  # + încetinire (durata crește cu upgrade-urile)
