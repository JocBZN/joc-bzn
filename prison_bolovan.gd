extends Node2D

# ATACUL 2 al boss-ului din PUȘCĂRIE: un BOLOVAN care cade din cer peste locul în care ești.
# Arta: `harta/prison/boss/atac_bolovan/` — 9 cadre, din care 0..4 = căderea (cu dâre de mișcare)
# și 5..8 = impactul (țepi de piatră + praf).
#
# Îl are din faza 2. Spre deosebire de inel, ăsta te CAUTĂ: se aruncă spre locul unde ești în
# clipa lansării. Dar are un telegraf lung (căderea) — deci se evită mergând, ceea ce e și ideea:
# în faza 2 nu mai poți sta pe loc.
#
# 🔑 DAMAGE-UL E LA IMPACT, nu în timpul căderii. Bolovanul care cade e doar un semn de avertizare;
# ce doare e ce se întâmplă când atinge pământul. Așa atacul are un răspuns clar (pleacă de acolo)
# în loc să fie o taxă pe care o plătești orice ai face.
#
# ⚠️ Ținta se îngheață la lansare (nu urmărește player-ul în cădere): un bolovan care te urmărește
# până aterizează n-ar mai putea fi evitat deloc, deci n-ar mai fi un atac, ar fi o pedeapsă.

const ART := "res://harta/prison/boss/atac_bolovan/"
const CADRE_CADERE := 5     # frame_0 .. frame_4
const CADRE_IMPACT := 4     # frame_5 .. frame_8

@export var damage: int = 42
@export var raza_impact: float = 130.0
@export var inaltime: float = 460.0     # de la ce înălțime pleacă
@export var timp_cadere: float = 0.75
@export var timp_impact: float = 0.55

var _anim: AnimatedSprite2D
var _t := 0.0
var _in_impact := false

func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("cade")
	frames.set_animation_speed("cade", float(CADRE_CADERE) / maxf(0.05, timp_cadere))
	frames.set_animation_loop("cade", false)
	frames.add_animation("impact")
	frames.set_animation_speed("impact", float(CADRE_IMPACT) / maxf(0.05, timp_impact))
	frames.set_animation_loop("impact", false)
	var lipsa := 0
	for i in CADRE_CADERE:
		var tex := load("%sframe_%d.png" % [ART, i]) as Texture2D
		if tex == null:
			lipsa += 1
		else:
			frames.add_frame("cade", tex)
	for i in CADRE_IMPACT:
		var tex2 := load("%sframe_%d.png" % [ART, CADRE_CADERE + i]) as Texture2D
		if tex2 == null:
			lipsa += 1
		else:
			frames.add_frame("impact", tex2)
	if lipsa > 0:
		push_warning("Bolovan: lipsesc %d cadre din %s (rulează --headless --import)" % [lipsa, ART])
	if frames.get_frame_count("cade") == 0 and frames.get_frame_count("impact") == 0:
		queue_free()
		return
	_anim.sprite_frames = frames
	add_child(_anim)
	# ⚠️ Umbra care arată UNDE va cădea. Fără ea atacul e necinstit: vezi ceva căzând, dar nu ai
	# de unde ști unde. E un simplu cerc desenat pe jos, care se strânge pe măsură ce se apropie.
	# Cercul de avertizare (`_draw`) e PE PĂMÂNT, deci nodul stă jos de tot; bolovanul care cade
	# trebuie să treacă peste toată lumea, deci sprite-ul își ia z-ul lui, ABSOLUT (`z_as_relative`
	# fals) — altfel s-ar aduna cu -1 al părintelui și ar ajunge tot dedesubt.
	z_index = -1
	_anim.z_as_relative = false
	_anim.z_index = 61
	_anim.position = Vector2(0, -inaltime)
	_anim.play("cade")

func _process(delta: float) -> void:
	_t += delta
	if not _in_impact:
		var k := clampf(_t / timp_cadere, 0.0, 1.0)
		# accelerat, ca o cădere adevărată (nu liniar — altfel plutește)
		_anim.position = Vector2(0, -inaltime * (1.0 - k * k))
		queue_redraw()
		if k >= 1.0:
			_impact()
		return
	if _t >= timp_cadere + timp_impact:
		queue_free()

func _impact() -> void:
	_in_impact = true
	_t = timp_cadere
	_anim.position = Vector2.ZERO
	_anim.play("impact")
	queue_redraw()
	Audio.play("earthquake", Audio.QUAKE_DB - 14.0, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.dead:
		return
	# ⚠️ Ținta se citește ACUM, din `global_position`, NU dintr-o copie luată în `_ready()`.
	# Bug prins rulând (2026-08-17): cine naște bolovanul face `add_child` și ABIA APOI îi pune
	# poziția — adică `_ready()` rula pe poziția veche, iar bolovanul cădea la vedere peste tine
	# dar socotea damage-ul față de alt punct. Rezultat: atacul arăta perfect și nu lovea NICIODATĂ.
	# Nodul nu se mișcă pe orizontală (coboară doar sprite-ul), deci `global_position` E locul
	# impactului. Aceeași capcană ca la `scythe.gd` — vezi comentariul din `celesto.gd::_coasa`.
	if global_position.distance_to(player.global_position) <= raza_impact:
		player.take_damage(maxi(1, int(round(damage * Difficulty.enemy_damage_mult()))))

# Cercul de avertizare de pe pământ, cât cade bolovanul.
func _draw() -> void:
	if _in_impact:
		return
	var k := clampf(_t / maxf(0.01, timp_cadere), 0.0, 1.0)
	var col := Color(0.9, 0.25, 0.15, 0.20 + 0.35 * k)
	draw_arc(Vector2.ZERO, raza_impact, 0.0, TAU, 48, col, 3.0)
	draw_arc(Vector2.ZERO, raza_impact * (1.0 - k), 0.0, TAU, 32, Color(1.0, 0.5, 0.2, 0.5), 2.0)
