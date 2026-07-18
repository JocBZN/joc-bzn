extends StaticBody2D

# Statuie fixă în lume. Imaginea + HITBOX-ul sunt în scena statue.tscn (editabile vizual în editor).
# Când player-ul se apropie apare butonul „Summon". La apăsare pornește SECVENȚA de invocare:
#   1) apare un simbol de alertă deasupra statuii,
#   2) statuia INTRĂ în pământ (coboară + se stinge) + CUTREMUR pe ecran (tremură camera),
#   3) din locul ei IESE ÎNCET un inamic din pământ, apoi pornește după player.
#
# Poziția nodului Statue = BAZA statuii (picioarele) → și linia de la care te acoperă (Y-sort).
#
# DE CE arta coboară sub originea nodului (vezi ACOPERIRE_JOS):
# Sprite-ul player-ului e CENTRAT pe punctul lui de sortare, adică se întinde ~64px SUB el.
# Dacă arta statuii s-ar termina fix pe originea ei, atunci în clipa în care player-ul trece
# în spatele statuii i-ar rămâne picioarele afară, sub piedestal — statuia l-ar tăia în două.
# Copacii rezolvă asta din `sort_anchor` (props.gd): arta lor coboară 73.8px sub linia de
# sortare, adică mai mult decât jumătatea player-ului, deci îl acoperă complet.
# Statuia folosește exact același truc.
#
# Dacă schimbi ACOPERIRE_JOS, mută și `CollisionShape2D.position` cu aceeași valoare
# (altfel hitbox-ul se dezlipește de statuie) și `Statue.position` din main.tscn în sens
# invers (altfel statuia se mută în lume).

const ENEMY := preload("res://garda.tscn")  # boss-ul „Garda", invocat DOAR de statuie

# Cele 3 variante de statuie. La fiecare statuie născută se alege una la întâmplare,
# după șansele de mai jos (trebuie să dea 100). Vrei alte proporții? Schimbi doar cifrele.
const VARIANTE := [
	{"tex": "res://harta/Statue Version 2.png", "sansa": 60},
	{"tex": "res://harta/Statue Version 1.png", "sansa": 30},
	{"tex": "res://harta/Statue Version 3.png", "sansa": 10},
]

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
@export var enemy_spawn_offset: Vector2 = Vector2(0, -66.415)  # unde apare față de statuie (Y negativ = mai spre NORD/sus)

# --- Simbolul de alertă deasupra statuii ---
@export var alert_scale: float = 0.9
@export var alert_fps: float = 18.0
const ALERT_DIR := "res://Upgrades/symbol_alert_002_large_red/"
const ALERT_FRAMES := 16  # frame0000.png … frame0015.png

var _summoned := false  # ca să nu poți apăsa Summon de mai multe ori

func _ready() -> void:
	_alege_varianta()
	# Butonul „Summon" NU mai e aici. Statuia doar se anunță în grupul „statue", iar
	# `interact_ui.gd` (un singur buton mare, în stânga ecranului) o găsește pe cea mai
	# apropiată. Motiv: pe telefon un butonaș deasupra statuii e greu de nimerit.
	add_to_group("statue")

# Mai poate fi invocată? (o singură dată per statuie)
func poate_invoca() -> bool:
	return not _summoned

# Alege la întâmplare una din cele 3 variante, după șansele din VARIANTE.
# Cum funcționează „roata norocului": tragem un număr între 0 și 100 și mergem prin
# listă scăzând șansa fiecăreia până când numărul devine negativ — acolo ne oprim.
func _alege_varianta() -> void:
	var sprite := $Sprite2D as Sprite2D
	var total := 0
	for v in VARIANTE:
		total += int(v["sansa"])
	var zar := randf() * float(total)
	for v in VARIANTE:
		zar -= float(v["sansa"])
		if zar <= 0.0:
			if ResourceLoader.exists(v["tex"]):
				sprite.texture = load(v["tex"])
				_aseaza_pe_origine(sprite)
			return

# Cât coboară arta statuii SUB linia de sortare (pixeli de ecran). Trebuie să fie mai mare
# decât jumătatea sprite-ului player-ului (~64px), altfel îi rămân picioarele afară când
# trece în spatele statuii. 74 = cât au și copacii.
const ACOPERIRE_JOS := 74.0

# Așază arta astfel încât baza ei să cadă cu ACOPERIRE_JOS sub originea nodului.
# Se recalculează la rulare fiindcă cele 3 variante nu se termină la același pixel
# (V2 la 113, V1/V3 la 112) — cu un `offset` fix din scenă, două din trei ar fi descentrate.
func _aseaza_pe_origine(sprite: Sprite2D) -> void:
	if sprite.texture == null or sprite.scale.y == 0.0:
		return
	var used := sprite.texture.get_image().get_used_rect()
	var jos := float(used.position.y + used.size.y)   # marginea de jos a artei, în pixeli de textură
	sprite.offset.y = ACOPERIRE_JOS / sprite.scale.y - (jos - float(sprite.texture.get_height()) * 0.5)

# Înălțimea vârfului statuii față de baza ei (negativ = în sus) — de aici se agață
# butonul „Summon". Ne uităm la CAPUL real al statuii, nu la marginea de sus a
# imaginii: variantele noi au ~30px de gol transparent deasupra, iar dacă măsurăm
# canvas-ul, butonul plutește undeva în aer. `get_used_rect()` ne dă exact zona
# desenată, deci merge la orice variantă, oricât gol ar avea în jur.
func _statue_top_y() -> float:
	var sprite := $Sprite2D as Sprite2D
	if sprite.texture == null:
		return -260.0
	var varf_px := float(sprite.texture.get_image().get_used_rect().position.y)
	return sprite.scale.y * (sprite.offset.y + varf_px - float(sprite.texture.get_height()) * 0.5)

# Pornește secvența de invocare. Chemată de `interact_ui.gd` când apeși butonul.
func invoca() -> void:
	if _summoned:
		return
	_summoned = true

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
