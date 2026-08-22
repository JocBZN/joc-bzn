extends Node2D

# ATACUL 1 al lui SIR JOHN: UNDA care se lărgește din el când înfige sabia în lespezi.
# Arta: `harta/castle/boss/atac_inel/` — 4 cadre, tăiate din `Attacks.gif` de `tool_taie_atacuri.gd`
# (celula 0,4 din atlas): o PECETE, adică un cerc subțire cu crăpături în el. Prima alegere a fost
# un tor gros care creștea singur (celula 4,5) — mărit de opt ori ca să ajungă la raza atacului,
# ieșea o pată albastră pe jumătate de ecran. Un contur subțire rămâne citibil oricât îl mărești.
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

const ART := "res://harta/castle/boss/atac_inel/"
const CADRE := 4
# Cât de mare e cercul DESENAT, în pixeli de artă (rază, de la mijlocul pânzei). Din ea iese scara.
# Dacă schimbi foaia, ăsta e singurul număr de remăsurat — iar `tool_taie_atacuri.gd` îl tipărește
# („semi-lățime"), ca să nu-l măsoare nimeni de mână.
const RAZA_ARTA := 48.0
# Cât din durată se stinge la coadă. Ultimul sfert al undei e și cel mai mărit, deci cel mai
# pixelat: stins în timp ce se lărgește, se citește ca o undă care se pierde, nu ca o poză mică
# întinsă prea tare.
const STINGERE := 0.35

@export var damage: int = 30
@export var raza_max: float = 380.0     # până unde ajunge frontul
@export var durata: float = 0.85        # în cât timp ajunge acolo
@export var grosime_lovire: float = 46.0   # cât de „gros" e frontul care lovește
# Cinematica de intrare cheamă unda DOAR ca desen, cu jocul pe pauză (`final_boss.gd::unda_de_spectacol`).
# Fără steagul ăsta ar fi lovit player-ul cu 1 damage (`maxi(1, ...)` nu lasă niciodată zero) —
# adică boss-ul te-ar fi ciupit din filmuleț, înainte să înceapă lupta.
@export var fara_damage: bool = false

var _t := 0.0
var _lovit := false
var _anim: AnimatedSprite2D

func _ready() -> void:
	z_index = -1   # pe jos, sub boss și sub player (e o undă pe pământ, nu un obiect)
	_anim = AnimatedSprite2D.new()
	# ⚠️ LINIAR, nu NEAREST ca la restul jocului. Cadrele au 96 px, iar unda trebuie să ajungă la
	# `raza_max` — adică sunt mărite de vreo opt ori. La atâta, „cel mai apropiat pixel" nu mai arată
	# a pixel art, ci a blocuri de 8 px: verificat pe captură, inelul ieșea o pată pătrățoasă care
	# umplea ecranul. Filtrul liniar îl face ce și este — o suflare de energie, nu un obiect.
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	_creste(0.0)

func _process(delta: float) -> void:
	_t += delta
	if _t >= durata:
		queue_free()
		return
	# raza frontului ACUM (liniar)
	var k := _t / durata
	var raza := raza_max * k
	_creste(k)
	if _lovit or fara_damage:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	var d := global_position.distance_to(player.global_position)
	if d <= raza + grosime_lovire * 0.5:
		_lovit = true
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))

# 🔑 CERCUL DESENAT E MEREU EXACT CÂT FRONTUL CARE LOVEȘTE. Până pe 2026-08-22, arta creștea
# singură (cadrele desenau un inel de piatră tot mai mare) și scara era fixă; efectul nou din
# `Attacks.gif` e o pecete de mărime constantă, deci creșterea o face scara. Ieșit mai bine decât
# era: acum nu mai există niciun fel în care desenul și hitbox-ul să se despartă — aceeași regulă
# ca la sabia blestemată și la coasa lui Celesto, unde hitbox-ul se măsoară DIN artă.
func _creste(k: float) -> void:
	if _anim == null:
		return
	# nu pornim chiar de la zero: un cerc de 0 px sare în ochi ca o sclipire, nu ca o undă
	var raza := maxf(raza_max * k, RAZA_ARTA * 0.35)
	_anim.scale = Vector2.ONE * (raza / RAZA_ARTA)
	# stingerea de la coadă
	var p := (k - (1.0 - STINGERE)) / STINGERE
	_anim.modulate.a = 1.0 - clampf(p, 0.0, 1.0)
