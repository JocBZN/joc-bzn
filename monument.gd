extends StaticBody2D

# MONUMENTUL — obeliscul din `harta/Monument Spawner.png`, sora mai rea a statuii.
# Stă în LUMEA NORMALĂ (îl naște `monuments.gd`, chunk cu chunk, ca statuile), dar nu poți
# apăsa pe el decât DUPĂ ce l-ai ucis pe Celesto în runda asta (`ender.gd::celesto_invins`).
# Până atunci deasupra lui scrie „Defeat Celesto to awaken it", nu „Press E to interact" —
# aceeași soluție ca la cufărul încuiat (vezi `chest.gd::eticheta()`): rămâne interactibil ca
# să aibă text, iar `invoca()` refuză.
#
# Când îl trezești, îți varsă în cap o HOARDĂ (cerut de Răzvan pe 2026-08-05):
#   · `enemy_count` (100) inamici AMESTECAȚI din toate dimensiunile — polițist, Police Skinny,
#     creatură din Nether, creatură din Ender — indiferent unde ai ajuns cu runda;
#   · `boss_count` (3) Gărzi, boss-ul statuii, care ies din pământ ca la invocarea normală.
# Nu apar deodată: curg unul câte unul, în ritm egal, pe `spawn_duration` (10) secunde, iar
# monumentul rămâne în picioare cât îi varsă și abia apoi intră în pământ.
# Toți primesc aceleași trei modificări, față de un inamic obișnuit DIN CLIPA INVOCĂRII:
#   · ×`xp_mult` (2) XP la moarte,   · ×`speed_mult` (3) viteză,   · ×`damage_mult_h` (3) damage.
#
# „Din clipa invocării" nu e o vorbă în vânt: viteza se coace o singură dată, în `_ready`-ul
# inamicului (`speed * Difficulty.enemy_speed_mult()`), deci un inamic al monumentului rămâne
# de 3× cât unul născut ODATĂ CU EL. Ai chemat hoarda la minutul 2? Rămâne o hoardă de minutul
# 2, oricât ai fugi de ea. Damage-ul, în schimb, se socotește la fiecare mușcătură
# (`player._take_contact_damage`), deci crește cu dificultatea ca la toți — dar tot ×3.
#
# Poziția nodului = BAZA monumentului (talpa) → și linia de la care te acoperă (Y-sort).
# Arta coboară `ACOPERIRE_JOS` sub origine din același motiv ca la statuie și la copaci
# (vezi comentariul lung din `statue.gd`): altfel player-ul trecut prin spate rămâne cu
# picioarele afară, sub piedestal.

const GARDA := preload("res://garda.tscn")
# Din ce e făcută hoarda. Ponderile sunt egale (câte 1) = „random din orice dimensiune", cum
# s-a cerut. Vrei mai puțini enderi (sunt cei mai duri)? Le scazi ponderea lor de aici, nu
# trebuie să umbli în altă parte.
const FELURI := [
	{"scena": "res://enemy.tscn", "pondere": 1.0},                # polițistul lumii normale
	{"scena": "res://enemy_police_skinny.tscn", "pondere": 1.0},  # Police Skinny
	{"scena": "res://enemy_nether.tscn", "pondere": 1.0},         # creatura din Nether
	{"scena": "res://enemy_ender.tscn", "pondere": 1.0},          # creatura din Ender
]

@export var interact_range: float = 200.0    # cât de aproape trebuie să fii ca să apară textul

# --- Hoarda ---
@export var enemy_count: int = 100           # câți inamici obișnuiți
@export var boss_count: int = 3              # câte Gărzi (boss-ul statuii)
@export var xp_mult: float = 2.0             # cât XP lasă, față de un inamic normal
@export var speed_mult: float = 3.0          # de câte ori sunt mai rapizi
@export var damage_mult_h: float = 3.0       # de câte ori lovesc mai tare
# Unde apar, față de monument. Minimul e cam cât un ecran, ca să nu se materializeze în brațele
# tale; maximul ține hoarda strânsă, altfel jumătate din ea ar veni la pas, minute în șir.
@export var spawn_min_dist: float = 620.0
@export var spawn_max_dist: float = 1150.0
@export var boss_dist: float = 480.0         # Gărzile ies mai aproape, la 120° una de alta
# În cât timp iese TOATĂ hoarda. Nu apare deodată, ci se scurge unul câte unul, în ritm egal,
# pe atâtea secunde (103 creaturi în 10s = una la ~0,097s). Scazi cifra → năvală; o crești → asediu.
@export var spawn_duration: float = 10.0

# --- Cutremur + scufundare (aceleași cifre ca la statuie, să se simtă la fel) ---
@export var shake_strength: float = 22.0
@export var shake_duration: float = 0.8
@export var sink_duration: float = 0.9
@export var sink_depth: float = 70.0

# --- Gărzile ies din pământ (ca la statuie) ---
@export var rise_duration: float = 1.0
@export var rise_depth: float = 55.0

# --- Simbolul de alertă deasupra monumentului (aceleași cadre ca la statuie) ---
@export var alert_scale: float = 0.9
@export var alert_fps: float = 18.0
const ALERT_DIR := "res://Upgrades/symbol_alert_002_large_red/"
const ALERT_FRAMES := 16

const ACOPERIRE_JOS := 74.0   # cât coboară arta sub linia de sortare (ca la statuie/copaci)

var _folosit := false         # un monument se trezește o singură dată

# Cât de sus stă textul de deasupra. `interact_ui.gd` îl citește dacă obiectul îl are (cufărul
# face la fel); cine nu-l are rămâne pe -175, adică pe la mijlocul obeliscului — textul ar cădea
# PESTE piatră. Se calculează în `_ready` din vârful REAL al artei, ca să nu fie o cifră scrisă
# de mână care se strică dacă schimbi poza.
var label_offset_y: float = -240.0

func _ready() -> void:
	add_to_group("monument")
	add_to_group("interactable")   # de aici vine textul de deasupra (`interact_ui.gd`)
	_aseaza_arta()
	label_offset_y = _varf_y() - 40.0

# Așază arta astfel încât baza ei desenată să cadă cu ACOPERIRE_JOS sub originea nodului.
# Calculat la rulare din pixelii chiar desenați (`get_used_rect`), nu dintr-un `offset` scris
# de mână: PNG-ul are gol transparent în jur, iar o cifră fixă s-ar strica dacă schimbi poza.
func _aseaza_arta() -> void:
	var sprite := $Sprite2D as Sprite2D
	if sprite == null or sprite.texture == null or sprite.scale.y == 0.0:
		return
	var used := sprite.texture.get_image().get_used_rect()
	var jos := float(used.position.y + used.size.y)
	sprite.offset.y = ACOPERIRE_JOS / sprite.scale.y - (jos - float(sprite.texture.get_height()) * 0.5)

# Înălțimea vârfului față de bază (negativ = în sus) — de acolo pornește simbolul de alertă.
func _varf_y() -> float:
	var sprite := $Sprite2D as Sprite2D
	if sprite == null or sprite.texture == null:
		return -260.0
	var varf_px := float(sprite.texture.get_image().get_used_rect().position.y)
	return sprite.scale.y * (sprite.offset.y + varf_px - float(sprite.texture.get_height()) * 0.5)

# L-ai ucis pe Celesto în runda asta? Steagul stă pe nodul `Ender` din `main.tscn` și — spre
# deosebire de `_boss_invins` — NU se stinge când ieși din dimensiune (vezi `ender.gd`).
func _celesto_batut() -> bool:
	var e := get_tree().get_first_node_in_group("ender")
	return e != null and e.get("celesto_invins") == true

# `interact_ui.gd` întreabă asta înainte să arate textul. Rămâne `true` și cât e încuiat —
# altfel monumentul n-ar avea niciun text deasupra și ar părea decor.
func poate_invoca() -> bool:
	return not _folosit

# Ce scrie deasupra. "" = „lasă textul obișnuit cu tasta". În ENGLEZĂ, ca tot ce se afișează
# (îl traduce Godot singur din `i18n.gd`).
func eticheta() -> String:
	return "" if _celesto_batut() else "Defeat Celesto to awaken it"

# Apăsarea tastei de interacțiune ajunge aici.
func invoca() -> void:
	if _folosit or not _celesto_batut():
		return
	_folosit = true

	# `monuments.gd` ține minte chunk-ul, ca monumentul să NU se întoarcă dacă te
	# îndepărtezi și revii (chunk-urile se descarcă și se regenerează).
	var gen := get_parent()
	while gen != null and not gen.has_method("marcheaza_folosit"):
		gen = gen.get_parent()
	if gen != null:
		gen.marcheaza_folosit(global_position)

	_anunta()
	_spawn_alert(global_position + Vector2(0, _varf_y()))
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			_shake_camera(cam)

	# Hoarda se naște în LUME (`World`), nu sub monument: containerul de chunk al monumentului
	# se șterge când te îndepărtezi, iar inamicii ar dispărea cu el. Aceeași grijă ca la cufăr.
	# ⚠️ Cu `await`, nu pe lângă: hoarda curge 10 secunde, iar așteptarea se face AICI, pe nodul
	# monumentului. Fără el, monumentul ar apuca să se elibereze (`queue_free` de mai jos) în timp
	# ce corutina lui încă are cadre în aer, adică o funcție reluată pe un nod mort. Efect
	# secundar dorit: obeliscul stă în picioare cât toarnă și se scufundă abia la sfârșit.
	var lume := player.get_parent() if player != null else null
	if lume != null:
		await _scoate_hoarda(lume)

	# monumentul și-a făcut treaba → intră în pământ și dispare (ca statuia după invocare)
	var sprite := $Sprite2D as Sprite2D
	var col := $CollisionShape2D as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)
	var sink := sprite.create_tween()
	sink.set_ease(Tween.EASE_IN)
	sink.tween_property(sprite, "position:y", sprite.position.y + sink_depth, sink_duration)
	sink.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	await sink.finished
	queue_free()

func _anunta() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("THE MONUMENT AWAKENS", "Double XP. Triple speed. Triple damage.")

# --- HOARDA ---------------------------------------------------------------------------

# Hoarda se scurge unul câte unul, în ritm EGAL, pe `spawn_duration` secunde (cerut de Răzvan pe
# 2026-08-05). Toate cele 103 într-un cadru ar însemna 103 seturi de animații construite la rând,
# adică o smucitură; și, mai important, monumentul trebuie să se simtă ca o robinet care curge,
# nu ca un teanc aruncat în cap.
#
# Bucla merge din CADRU în CADRU și, de fiecare dată, întreabă „câți ar fi trebuit să fie afară
# până acum" — nu numără pauze una după alta. Diferența contează: cu pauze înlănțuite, fiecare
# cadru întârziat s-ar aduna la coadă și cele 10 secunde s-ar întinde la 12–13; așa, dacă un
# cadru sare, următorul scoate doi și hoarda se termină tot la secunda 10.
#
# Ceasul e ADUNAT din delta cadrelor, nu citit din ceasul de perete, și stă pe loc cât jocul e
# pe pauză adevărată. În 10 secunde de hoardă aproape sigur prinzi un nivel, iar ecranul de Level
# Up oprește arborele (`get_tree().paused`, vezi `levelup.gd`) — cu ceasul de perete, cât alegeai
# upgrade-ul, timpul curgea, și la Resume ți se vărsa restul hoardei într-un singur cadru.
#
# Cele 3 Gărzi sunt înfipte în șir la 1/6, 1/2 și 5/6 din hoardă (≈1,6s, 5s și 8,4s): nu vin toate
# la început, iar prima nu cade peste cadrul cu alerta și cutremurul — exact vârful de care fugim.
func _scoate_hoarda(lume: Node) -> void:
	var centru := global_position
	var total := enemy_count + boss_count
	if total <= 0:
		return
	# La ce poziție din șir intră fiecare Gardă (cheie = locul, valoare = a câta e).
	var locuri_garzi := {}
	for k in boss_count:
		locuri_garzi[int(floor((float(k) + 0.5) * float(total) / float(boss_count)))] = k
	var pas := spawn_duration / float(total)   # cât ține un „loc" din șir
	var trecut := 0.0
	var scosi := 0
	while scosi < total:
		# Lumea poate dispărea sub noi cât așteptăm (moarte, restart, meniu).
		if not is_instance_valid(lume) or not is_inside_tree():
			return
		if not get_tree().paused:
			trecut += get_process_delta_time()
			var tinta := total if pas <= 0.0 else mini(total, int(floor(trecut / pas)) + 1)
			while scosi < tinta:
				if locuri_garzi.has(scosi):
					var k: int = locuri_garzi[scosi]
					var unghi := TAU * (float(k) / float(maxi(1, boss_count))) + randf_range(-0.3, 0.3)
					_naste_garda(lume, centru + Vector2(cos(unghi), sin(unghi)) * boss_dist)
				else:
					_naste_inamic(lume, centru + _offset_random())
				scosi += 1
		if scosi < total:
			await get_tree().process_frame

# Un punct la întâmplare într-un inel în jurul monumentului: unghi uniform, rază între
# `spawn_min_dist` și `spawn_max_dist`.
func _offset_random() -> Vector2:
	var unghi := randf() * TAU
	return Vector2(cos(unghi), sin(unghi)) * randf_range(spawn_min_dist, spawn_max_dist)

# Un inamic obișnuit, de felul ales la întâmplare din `FELURI`, cu cele trei modificări.
#
# ⚠️ Toate se pun ÎNAINTE de `add_child`: `enemy.gd::_ready()` coace acolo viteza finală
# (`speed * Difficulty.enemy_speed_mult()`), deci o înmulțire de după ar rămâne pe dinafară.
func _naste_inamic(lume: Node, la: Vector2) -> void:
	var cale := _alege_fel()
	if not ResourceLoader.exists(cale):
		return
	var scena := load(cale) as PackedScene
	if scena == null:
		return
	var e := scena.instantiate()
	e.speed *= speed_mult
	e.damage_mult *= damage_mult_h   # e 1.0 la mai toți, 2.0 la creatura din Ender → rămâne relativ
	e.xp_drop_mult *= xp_mult
	lume.add_child(e)
	e.global_position = la

func _alege_fel() -> String:
	var total := 0.0
	for f in FELURI:
		total += float(f["pondere"])
	var zar := randf() * total
	for f in FELURI:
		zar -= float(f["pondere"])
		if zar <= 0.0:
			return String(f["scena"])
	return String(FELURI[0]["scena"])

# O Gardă (boss-ul statuii), cu aceleași trei modificări. `garda.gd` n-are `xp_drop_mult`:
# el lasă o singură gemă, de `xp_value`, deci acolo se înmulțește. Fulgerul lui e al treilea
# fel de damage din joc (nu e nici contact, nici glonț), așa că se scalează separat.
func _naste_garda(lume: Node, la: Vector2) -> void:
	var g := GARDA.instantiate()
	g.speed *= speed_mult
	g.damage_mult *= damage_mult_h        # damage-ul de CONTACT (vezi player._take_contact_damage)
	g.lightning_damage = int(round(g.lightning_damage * damage_mult_h))
	g.xp_value = int(round(g.xp_value * xp_mult))
	lume.add_child(g)
	g.global_position = la
	_iese_din_pamant(g)

# Iese încet din pământ (urcă + apare), ca la invocarea de la statuie, apoi pornește după tine.
func _iese_din_pamant(e: Node) -> void:
	e.set_physics_process(false)
	var spr := e.get_node_or_null("AnimatedSprite2D") as Node2D
	if spr == null:
		e.set_physics_process(true)
		return
	var end_y := spr.position.y
	spr.position.y = end_y + rise_depth
	spr.modulate.a = 0.0
	var rise := e.create_tween()
	rise.tween_property(spr, "position:y", end_y, rise_duration)
	rise.parallel().tween_property(spr, "modulate:a", 1.0, rise_duration)
	rise.tween_callback(e.set_physics_process.bind(true))

# --- efecte de ecran (copiate din `statue.gd`, ca invocarea să se simtă la fel) -----------

func _shake_camera(cam: Camera2D) -> void:
	var tw := cam.create_tween()
	tw.tween_method(_apply_shake.bind(cam), 1.0, 0.0, shake_duration)
	tw.tween_callback(_reset_cam.bind(cam))

func _apply_shake(amount: float, cam: Camera2D) -> void:
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * amount

func _reset_cam(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

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
		push_warning("Alert: cadrele nu-s importate încă — deschide o dată proiectul în Godot.")
		return
	var alert := AnimatedSprite2D.new()
	alert.sprite_frames = frames
	alert.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	alert.scale = Vector2(alert_scale, alert_scale)
	alert.z_index = 100
	get_parent().add_child(alert)   # în lume, independent de monument (care va dispărea)
	alert.global_position = at_pos
	alert.play("default")
	alert.animation_finished.connect(alert.queue_free)
