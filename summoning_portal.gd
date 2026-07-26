@tool
extends "res://hitbox_reglabil.gd"

# SUMMONING PORTAL — structura din Nether care îl cheamă pe SARATALIN (`saratalin.gd`).
# E sora statuii din lumea normală (`statue.gd`): apeși E și pornește aceeași secvență —
#   1) apare simbolul de alertă deasupra ei,
#   2) structura INTRĂ în pământ (coboară + se stinge) + CUTREMUR pe ecran,
#   3) ...doar că boss-ul NU iese din pământ ca Garda: SARATALIN COBOARĂ DIN TAVAN.
#      Pornește deasupra marginii de sus a ecranului, deci nu-l vezi apărând din nimic.
#
# O structură = un singur Saratalin. După invocare se scufundă și dispare; `nether.gd`
# pune una nouă la fiecare intrare în Nether.
#
# Poziția nodului = BAZA structurii (talpa) → și linia de la care te acoperă (Y-sort).
# Butoanele de hitbox (Nord/Sud/Est/Vest + Vezi Hitbox) vin din `hitbox_reglabil.gd`.

const BOSS := preload("res://saratalin.tscn")

# --- Cutremur (cât se scufundă structura) ---
@export var shake_strength: float = 24.0
@export var shake_duration: float = 0.9

# --- Structura intră în pământ ---
@export var sink_duration: float = 1.0
@export var sink_depth: float = 80.0

# --- Unde aterizează boss-ul, față de structură (Y negativ = mai spre nord/sus) ---
@export var boss_spawn_offset: Vector2 = Vector2(0, -120.0)

# --- Simbolul de alertă deasupra structurii (aceleași cadre ca la statuie) ---
@export var alert_scale: float = 0.9
@export var alert_fps: float = 18.0
const ALERT_DIR := "res://Upgrades/symbol_alert_002_large_red/"
const ALERT_FRAMES := 16   # frame0000.png … frame0015.png

var _summoned := false

# O singură invocare per structură.
func poate_invoca() -> bool:
	return not _summoned

# Vârful structurii față de talpa ei (negativ = în sus) — de acolo agățăm simbolul de
# alertă. Ne uităm la ARTA reală (`get_used_rect()`), nu la marginea imaginii: foaia are
# gol transparent deasupra, iar altfel simbolul ar pluti în aer. (Identic cu `statue.gd`.)
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

	# 1) simbolul de alertă, deasupra structurii
	_spawn_alert(global_position + Vector2(0, _varf_y()))
	_announce("SARATALIN", "It comes down from above")
	Audio.play("levelup", -2.0)

	# 2a) cutremur pe ecran
	_zguduie_camera()

	# 2b) structura intră în pământ: nu mai e zid, coboară și se stinge
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

	# 3) boss-ul coboară din tavan, în locul structurii
	_cheama_bossul()
	queue_free()   # structura și-a făcut treaba

# Pune boss-ul la locul lui și îl lasă să coboare. Îl agățăm de `World` (părintele nostru),
# nu de structură — structura dispare imediat după.
func _cheama_bossul() -> void:
	var world := get_parent()
	if world == null:
		return
	var boss := BOSS.instantiate()
	world.add_child(boss)
	boss.global_position = global_position + boss_spawn_offset
	boss.coboara_din_tavan()

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

# Simbolul de alertă (cele 16 cadre), jucat o dată, apoi dispare. Pus în lume, independent
# de structură (care oricum dispare).
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

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
