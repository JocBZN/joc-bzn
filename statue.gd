extends StaticBody2D

# Statuie fixă în lume. Imaginea + HITBOX-ul sunt în scena statue.tscn (editabile vizual în editor).
# Când player-ul se apropie apare butonul „Summon". La apăsare pornește SECVENȚA de invocare:
#   1) apare un simbol de alertă deasupra statuii,
#   2) statuia INTRĂ în pământ (coboară + se stinge) + CUTREMUR pe ecran (tremură camera),
#   3) din locul ei IESE ÎNCET un inamic din pământ, apoi pornește după player.
#
# Poziția nodului Statue = BAZA statuii (picioarele) → și linia de la care te acoperă (Y-sort).

const STATUE_TEX := preload("res://harta/statue.png")
const ENEMY := preload("res://garda.tscn")  # boss-ul „Garda", invocat DOAR de statuie

@export var interact_range: float = 200.0    # cât de aproape trebuie să fii ca să apară butonul

# --- Cutremur ---
@export var shake_strength: float = 22.0     # cât de tare tremură camera (pixeli)
@export var shake_duration: float = 0.8      # cât ține cutremurul (secunde)

# --- Statuia intră în pământ ---
@export var sink_duration: float = 0.9       # cât durează scufundarea (secunde)
@export var sink_depth: float = 70.0         # cât de adânc se scufundă (pixeli) — se stinge oricum în paralel

# --- Inamicul iese din pământ ---
@export var rise_duration: float = 1.0       # cât durează ieșirea inamicului (secunde)
@export var rise_depth: float = 55.0         # de la ce adâncime iese (pixeli)
@export var enemy_spawn_offset: Vector2 = Vector2(0, -80)  # unde apare față de statuie (Y negativ = mai spre NORD/sus)

# --- Simbolul de alertă deasupra statuii ---
@export var alert_scale: float = 0.9
@export var alert_fps: float = 18.0
const ALERT_DIR := "res://Upgrades/symbol_alert_002_large_red/"
const ALERT_FRAMES := 16  # frame0000.png … frame0015.png

var _button: Button
var _summoned := false  # ca să nu poți apăsa Summon de mai multe ori

func _ready() -> void:
	# --- butonul „Summon", ascuns până te apropii ---
	_button = Button.new()
	_button.text = "Summon"
	_button.visible = false
	_button.add_theme_font_size_override("font_size", 14)  # buton mic
	_button.pressed.connect(_on_summon)
	add_child(_button)
	# îl centrăm deasupra vârfului statuii
	await get_tree().process_frame
	_button.position = Vector2(-_button.size.x * 0.5, _statue_top_y() - _button.size.y - 6.0)

func _process(_delta: float) -> void:
	if _summoned:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	# butonul apare doar când ești suficient de aproape
	_button.visible = global_position.distance_to(player.global_position) <= interact_range

# înălțimea vârfului statuii față de baza ei (negativ = în sus)
func _statue_top_y() -> float:
	var sprite := $Sprite2D as Sprite2D
	return -float(STATUE_TEX.get_height()) * sprite.scale.y

func _on_summon() -> void:
	if _summoned:
		return
	_summoned = true
	_button.visible = false

	# 1) simbol de alertă deasupra statuii
	_spawn_alert(global_position + Vector2(0, _statue_top_y()))

	# 2a) cutremur pe ecran (tremură camera player-ului)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			_shake_camera(cam)

	# 2b) statuia intră în pământ: nu mai e zid, coboară și se stinge
	var sprite := $Sprite2D as Sprite2D
	var col := $CollisionShape2D as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)
	var sink := sprite.create_tween()
	sink.set_ease(Tween.EASE_IN)
	sink.tween_property(sprite, "position:y", sprite.position.y + sink_depth, sink_duration)
	sink.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	await sink.finished

	# 3) iese un inamic din pământ, la locul statuii
	_rise_enemy()

	# statuia și-a făcut treaba → dispare
	queue_free()

# Tremură camera: un offset aleator care scade de la maxim la 0.
func _shake_camera(cam: Camera2D) -> void:
	var tw := cam.create_tween()
	tw.tween_method(_apply_shake.bind(cam), 1.0, 0.0, shake_duration)
	tw.tween_callback(_reset_cam.bind(cam))

func _apply_shake(amount: float, cam: Camera2D) -> void:
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * amount

func _reset_cam(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

# Instanțiază un inamic la baza statuii și îl face să „iasă" din pământ (urcă + apare), apoi pornește.
func _rise_enemy() -> void:
	var world := get_parent()
	if world == null:
		return
	var enemy := ENEMY.instantiate()
	world.add_child(enemy)
	enemy.global_position = global_position + enemy_spawn_offset
	enemy.set_physics_process(false)  # stă pe loc până termină de ieșit
	var spr := enemy.get_node_or_null("AnimatedSprite2D") as Node2D
	if spr == null:
		enemy.set_physics_process(true)
		return
	var end_y := spr.position.y
	spr.position.y = end_y + rise_depth  # pornește de sub pământ
	spr.modulate.a = 0.0
	var rise := enemy.create_tween()
	rise.tween_property(spr, "position:y", end_y, rise_duration)
	rise.parallel().tween_property(spr, "modulate:a", 1.0, rise_duration)
	rise.tween_callback(enemy.set_physics_process.bind(true))  # gata → pornește după player

# Simbol de alertă (cele 16 cadre), jucat o dată, apoi dispare. Pus în lume, la poziția dată.
func _spawn_alert(at_pos: Vector2) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", alert_fps)
	frames.set_animation_loop("default", false)
	for i in ALERT_FRAMES:
		var tex := load("%sframe%04d.png" % [ALERT_DIR, i]) as Texture2D
		if tex != null:
			frames.add_frame("default", tex)
	if frames.get_frame_count("default") == 0:
		push_warning("Alert: cadrele nu-s importate încă — deschide o dată proiectul în Godot ca să le importe.")
		return
	var alert := AnimatedSprite2D.new()
	alert.sprite_frames = frames
	alert.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	alert.scale = Vector2(alert_scale, alert_scale)
	alert.z_index = 100
	get_parent().add_child(alert)  # în lume, independent de statuie (care va dispărea)
	alert.global_position = at_pos
	alert.play("default")
	alert.animation_finished.connect(alert.queue_free)
