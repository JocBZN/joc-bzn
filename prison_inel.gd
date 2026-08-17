extends Node2D

# ATACUL 1 al boss-ului din PUȘCĂRIE: un INEL DE PIATRĂ care se lărgește din el.
# Arta: `harta/prison/boss/atac_inel/` (6 cadre, tăiate din foaia lui Răzvan).
#
# Îl are din faza 1, deci e atacul „de bază". Ideea lui e „dă-te de pe mine": nu te urmărește,
# dar te prinde dacă stai lipit — și cu cât e mai târziu în luptă, cu atât se lărgește mai mult.
#
# 🔑 DAMAGE-UL SE DĂ CÂND FRONTUL AJUNGE LA TINE, nu la începutul animației și nici o dată pe
# cadru. Inelul crește, deci `distanța <= raza curentă` devine adevărat EXACT în clipa în care
# unda te atinge; `_lovit` face să se întâmple o singură dată. Dacă apuci să fugi în afara razei
# maxime, nu te atinge deloc — asta e tot rostul atacului.
#
# ⚠️ Nu e Area2D și nu trece prin fizică: verific distanța în `_process`. Un Area2D adăugat în
# timpul pasului de fizică dă „Can't change this state while flushing queries" (vezi `enemy.gd`),
# iar boss-ul îl naște fix din `_physics_process`.

const ART := "res://harta/prison/boss/atac_inel/"
const CADRE := 6
# Cât de mare e inelul DESENAT în ultimul cadru, în pixeli de artă (rază, de la centru).
# Din ea iese scara: `raza_max / RAZA_ARTA`. Dacă schimbi foaia, ăsta e singurul număr de remăsurat.
const RAZA_ARTA := 196.0

@export var damage: int = 30
@export var raza_max: float = 520.0     # până unde ajunge frontul
@export var durata: float = 0.85        # în cât timp ajunge acolo
@export var grosime_lovire: float = 46.0   # cât de „gros" e frontul care lovește

var _t := 0.0
var _lovit := false
var _anim: AnimatedSprite2D

func _ready() -> void:
	z_index = -1   # pe jos, sub boss și sub player (e o undă pe pământ, nu un obiect)
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", float(CADRE) / maxf(0.05, durata))
	frames.set_animation_loop("default", false)
	var lipsa := 0
	for i in CADRE:
		var tex := load("%sframe_%d.png" % [ART, i]) as Texture2D
		if tex == null:
			lipsa += 1
			continue
		frames.add_frame("default", tex)
	if lipsa > 0:
		push_warning("Inel: lipsesc %d cadre din %s (rulează --headless --import)" % [lipsa, ART])
	if frames.get_frame_count("default") == 0:
		queue_free()
		return
	_anim.sprite_frames = frames
	add_child(_anim)
	_anim.play("default")
	# Pornim mic și creștem odată cu animația: cadrele desenează inelul crescând, dar ele singure
	# n-ar ajunge niciodată la `raza_max` — scara e cea care duce frontul până acolo.
	_anim.scale = Vector2.ONE * (raza_max / RAZA_ARTA)

func _process(delta: float) -> void:
	_t += delta
	if _t >= durata:
		queue_free()
		return
	if _lovit:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	# raza frontului ACUM (liniar, ca și cadrele)
	var raza := raza_max * (_t / durata)
	var d := global_position.distance_to(player.global_position)
	if d <= raza + grosime_lovire * 0.5:
		_lovit = true
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))
