extends Node2D

# ATACUL 3 al lui SIR JOHN: TĂIETURA — semiluna de sabie care zboară spre tine.
# Arta: `harta/castle/boss/atac_taietura/` — 4 cadre, tăiate din `Attacks.gif` de
# `tool_taie_atacuri.gd` (celula 3,4 din atlas, oglindită ca să zboare cu burta înainte).
#
# A luat locul RAZEI Warden-ului (`prison_laser.gd`, șters pe 2026-08-22) și nu doar fiindcă arta
# veche nu mai există: o rază instantanee e arma unui turn, nu a unui cavaler cu sabie. Semiluna
# spune din desen cine a aruncat-o.
#
# 🔑 CE ÎL FACE CINSTIT: zboară cu viteză FINITĂ, deci se vede venind și se poate ocoli — spre
# deosebire de rază, care lovea tot ce era pe linie în clipa în care pleca. În schimb în faza 3
# vin TREI deodată, în evantai: un pas lateral nu mai ajunge, trebuie să te miști din timp.
#
# ⚠️ Nu e Area2D și nu trece prin fizică: verific distanța în `_process`. Un Area2D adăugat în
# timpul pasului de fizică dă „Can't change this state while flushing queries" (vezi `enemy.gd`),
# iar boss-ul o naște fix din `_physics_process`.

const ART := "res://harta/castle/boss/atac_taietura/"
const CADRE := 4
# Cât de „groasă" e semiluna desenată, în pixeli de artă, măsurat de la mijlocul pânzei (jumătatea
# înălțimii conturului: 54/2 = 27, tipărit de `tool_taie_atacuri.gd`). Din ea iese raza de lovire,
# ca hitbox-ul să fie MĂSURAT DIN ARTĂ, nu nimerit din ochi — aceeași regulă ca la sabia blestemată
# și la coasa lui Celesto. Puțin sub lățimea desenului: o semilună lovește cu tăișul, nu cu aerul
# dintre coarnele ei.
const RAZA_ARTA := 27.0

@export var damage: int = 55
@export var viteza: float = 430.0
@export var marime: float = 1.7          # de câte ori e mai mare decât desenul (pânză 96)
@export var lifetime: float = 2.2        # cât zboară până se stinge singură
@export var fps: float = 14.0

var _t := 0.0
var _dir := Vector2.RIGHT
var _lovit := false
var _anim: AnimatedSprite2D

# Se cheamă DUPĂ `add_child` și după ce i-ai pus poziția — ca la `prison_laser.gd::porneste`.
func porneste(directie: Vector2) -> void:
	if directie.length() > 0.001:
		_dir = directie.normalized()
	rotation = _dir.angle()   # 0 rad = est, exact cum e desenată semiluna

func _ready() -> void:
	z_index = 40   # trece peste tot: e în aer, nu pe jos ca unda
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	var lipsa := 0
	for i in CADRE:
		var tex := load("%sframe_%d.png" % [ART, i]) as Texture2D
		if tex == null:
			lipsa += 1
			continue
		frames.add_frame("default", tex)
	if lipsa > 0:
		push_warning("Tăietura: lipsesc %d cadre din %s (rulează --headless --import)" % [lipsa, ART])
	if frames.get_frame_count("default") == 0:
		queue_free()
		return
	_anim.sprite_frames = frames
	_anim.scale = Vector2.ONE * marime
	add_child(_anim)
	_anim.play("default")

func _process(delta: float) -> void:
	_t += delta
	position += _dir * viteza * delta
	if _t >= lifetime:
		queue_free()
		return
	if _lovit:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	if global_position.distance_to(player.global_position) <= RAZA_ARTA * marime:
		_lovit = true
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))
		# Trece MAI DEPARTE după ce a lovit (nu dispare): o tăietură de sabie nu se oprește în
		# tine. `_lovit` are grijă să nu te mai atingă a doua oară în același zbor.
