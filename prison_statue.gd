extends StaticBody2D

# STATUIA DIN PUȘCĂRIE — structura care îl scoate pe THE WARDEN (`final_boss.gd`).
# Sora structurii de invocare din Nether (`summoning_portal.gd`) și a statuii din lumea normală
# (`statue.gd`): apeși E și pornește aceeași secvență — simbol de alertă, cutremur, structura
# intră în pământ, boss-ul apare.
#
# Diferența față de Nether: acolo Saratalin COBOARĂ DIN TAVAN, aici boss-ul IESE DIN PĂMÂNT — e
# statuia care prinde viață, deci trebuie să pară că se ridică chiar din locul ei. De aia se pune
# fix pe poziția statuii, nu deasupra ei.
#
# O statuie = un singur Warden. `prison.gd` pune una la fiecare intrare în pușcărie.
#
# Poziția nodului = BAZA statuii (talpa) → și linia de la care te acoperă (Y-sort).
# HITBOX-ul se reglează CU MÂNA în `prison_statue.tscn` (click pe `CollisionShape2D`), ca la
# celelalte structuri. Scriptul nu-l atinge niciodată.

const BOSS := preload("res://final_boss.tscn")

@export var interact_range: float = 210.0

@export var shake_strength: float = 26.0
@export var shake_duration: float = 1.1

@export var sink_duration: float = 1.1
@export var sink_depth: float = 90.0

@export var alert_scale: float = 1.0
@export var alert_fps: float = 18.0
const ALERT_DIR := "res://Upgrades/symbol_alert_002_large_red/"
const ALERT_FRAMES := 16

var _summoned := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("prison_statue")

func poate_invoca() -> bool:
	return not _summoned

# Vârful artei față de talpă (negativ = în sus), ca să agățăm simbolul de alertă acolo și nu în
# aer. Ne uităm la desenul REAL (`get_used_rect()`), nu la marginea pânzei — identic cu `statue.gd`.
func _varf_y() -> float:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return -260.0
	var varf_px := float(sprite.texture.get_image().get_used_rect().position.y)
	return sprite.scale.y * (sprite.offset.y + varf_px - float(sprite.texture.get_height()) * 0.5)

func invoca() -> void:
	if _summoned:
		return
	_summoned = true

	_spawn_alert(global_position + Vector2(0, _varf_y()))
	_anunta("THE WARDEN", "The statue is moving")
	Audio.play("levelup", -2.0)
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
	_zguduie_camera()

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)
	if sprite == null:
		_cheama_bossul()
		queue_free()
		return
	var sink := sprite.create_tween()
	sink.set_ease(Tween.EASE_IN)
	sink.tween_property(sprite, "position:y", sprite.position.y + sink_depth, sink_duration)
	sink.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	await sink.finished

	_cheama_bossul()
	queue_free()

# Boss-ul se agață de `World` (părintele nostru), nu de statuie — statuia dispare imediat după.
# `adoarme()` ÎNAINTE de `add_child`, ca `_ready` să nu ceară bara: o cere `trezeste()`, la
# capătul ieșirii din pământ (aceeași grijă ca la Celesto).
func _cheama_bossul() -> void:
	var world := get_parent()
	if world == null:
		return
	var boss := BOSS.instantiate()
	boss.adoarme()
	world.add_child(boss)
	boss.global_position = global_position
	boss.iesi_din_pamant()
	# spunem dimensiunii cine e boss-ul, ca busola să arate spre el și pauza de Limbo să-l prindă
	var prison := get_tree().get_first_node_in_group("prison")
	if prison != null and prison.has_method("boss_invocat"):
		prison.boss_invocat(boss)

func _zguduie_camera() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	tw.tween_method(_shake.bind(cam), 1.0, 0.0, shake_duration)
	tw.tween_callback(_shake_stop.bind(cam))

func _shake(amount: float, cam: Camera2D) -> void:
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * amount

func _shake_stop(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

func _spawn_alert(at_pos: Vector2) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", alert_fps)
	frames.set_animation_loop("default", false)
	for i in ALERT_FRAMES:
		var tex := load("%sframe%04d.png" % [ALERT_DIR, i]) as Texture2D
		if tex != null:
			frames.add_frame("default", tex)
	if frames.get_frame_count("default") == 0:
		return
	var alert := AnimatedSprite2D.new()
	alert.sprite_frames = frames
	alert.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	alert.scale = Vector2(alert_scale, alert_scale)
	alert.z_index = 100
	get_parent().add_child(alert)
	alert.global_position = at_pos
	alert.play("default")
	alert.animation_finished.connect(alert.queue_free)

func _anunta(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
