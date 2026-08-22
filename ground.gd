extends Sprite2D

# Podea infinită cu 2 biome (iarbă + deșert). Podeaua e o pânză mare care urmărește
# player-ul, iar un SHADER (biome.gdshader) desenează deșertul în petice pătrate random
# (vezi biome_map.gd — latură 6..20 chunk-uri), după poziția reală din lume, cu margini soft.

@export var tile_size: float = 64.0
@export var chunk_size: float = 512.0   # mărimea unui chunk (px) — TREBUIE să fie ca în props.gd/rocks.gd
@export var blend_chunks: float = 1.5   # cât de soft e marginea deșertului (în chunk-uri) — mai mare = mai soft
@export var nether_tile_size: float = 96.0   # cât de mare se vede o dală de cărămidă în Nether
@export var ender_tile_size: float = 256.0   # cât de mare se vede o dală de nebuloasă în Ender
# Pavajul din Pușcărie. Fișierul e 209px (1254/6 — micșorat cu un factor ÎNTREG, ca să rămână
# tileabil, vezi extractorul). La 160 se vede ca lespezi mari de temniță, nu ca pietriș.
@export var prison_tile_size: float = 256.0

# Unduirea podelei în dimensiuni (`warp_*` din biome.gdshader; în lumea normală rămâne 0).
#
# ⚠️ În NETHER e STINSĂ (0), la cererea lui Răzvan pe 2026-08-03: cărămida are linii drepte și
# lungi, iar orice unduire pe ele se citește ca „mi se mișcă ecranul", nu ca aer fierbinte.
# Reglajele rămân aici, ca să se poată încerca din Inspector fără să se mai scrie cod — dar
# implicit e 0. Căldura Nether-ului se vede din scântei și din culoare, nu din podea.
#
# În ENDER e ținută MICĂ: nebuloasa n-are linii drepte, deci deformarea nu sare în ochi, dar
# tot a fost tăiată de la 46 la 14 în aceeași cerere.
@export var nether_warp: float = 0.0
@export var nether_warp_scale: float = 0.018
@export var nether_warp_speed: float = 0.9
@export var ender_warp: float = 14.0
@export var ender_warp_scale: float = 0.0022
@export var ender_warp_speed: float = 0.16

# --- MARGINEA LUMII: groapa din Nether / Ender ---
# Cerut de Răzvan pe 2026-08-06: „poate să fie finite nether și ender ca să găsești statuile mai
# ușor? Gradient spre negru ca să simuleze o groapă infinită ca în Minecraft — să fie undeva la
# 3000 de pixeli de spawn."
#
# ⚠️ De ce stau AICI și zidul, și negreala: sunt același lucru văzut din două părți. Marginea
# desenată o face `biome.gdshader` (podeaua asta), iar oprirea o cere `player.gd` tot de aici
# (`in_margine`). Dacă raza ar fi scrisă și în `player.gd`, s-ar putea despărți la prima
# schimbare — ai fi mers pe negru, sau te-ai fi oprit în aer, pe podea încă vizibilă.
#
# Discul e centrat pe PORTALUL prin care ai intrat, nu pe tine: acolo e și ieșirea, deci „spawn"
# și „centrul lumii" sunt același punct. Statuile de schimb ale Ender-ului stau într-un inel de
# 600–2000 (`ender_statues.gd`), adică bine înăuntru — de-aia se și găsesc acum.
const MARGINE_RAZA := 3000.0    # cât de departe de portal se termină lumea
const MARGINE_FADE := 700.0     # pe câți pixeli se stinge podeaua spre negru, până la margine

var margine_raza := 0.0         # 0 = fără margine (lumea normală și Limbo sunt tot infinite)
var margine_centru := Vector2.ZERO

var _mat: ShaderMaterial
var _grass: Texture2D
var _desert: Texture2D
var _brick: Texture2D
var _nebula: Texture2D
var _prison: Texture2D

func _ready() -> void:
	add_to_group("ground")   # ca `nether.gd` să poată schimba podeaua
	var shader := load("res://biome.gdshader") as Shader
	var grass := load("res://harta/grass-alternative-3.png") as Texture2D
	var desert := load("res://harta/desert-tile.png") as Texture2D
	if shader == null or grass == null or desert == null:
		push_warning("Biome: lipsește shaderul sau un tile — deschide Godot ca să importe desert-tile.png")
		return
	_grass = grass
	_desert = desert
	if ResourceLoader.exists("res://harta/nether/Brick32.png"):
		_brick = load("res://harta/nether/Brick32.png") as Texture2D
	if ResourceLoader.exists("res://harta/Portal Ender/misc_nebula.png"):
		_nebula = load("res://harta/Portal Ender/misc_nebula.png") as Texture2D
	if ResourceLoader.exists("res://harta/castle/castle_bg.png"):
		_prison = load("res://harta/castle/castle_bg.png") as Texture2D
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("grass_tex", grass)
	_mat.set_shader_parameter("desert_tex", desert)
	_mat.set_shader_parameter("tile_size", tile_size)
	_mat.set_shader_parameter("chunk_size", chunk_size)
	# Parametrii biomului vin din biome_map.gd → un SINGUR loc de reglat (vizualul urmează blocarea copacilor/pietrelor)
	_mat.set_shader_parameter("macro", BiomeMap.MACRO)
	_mat.set_shader_parameter("min_size", BiomeMap.MIN_SIZE)
	_mat.set_shader_parameter("max_size", BiomeMap.MAX_SIZE)
	_mat.set_shader_parameter("desert_percent", BiomeMap.DESERT_PERCENT)
	_mat.set_shader_parameter("edge_snap", BiomeMap.EDGE_SNAP)
	material = _mat

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	global_position = player.global_position  # podeaua urmărește player-ul (shaderul e legat de lume, deci nu tremură)
	if _mat != null:
		# le actualizăm live ca să poți regla din Inspector în timp ce joci
		_mat.set_shader_parameter("chunk_size", chunk_size)
		_mat.set_shader_parameter("blend_chunks", blend_chunks)

# Trece podeaua pe cărămida din Nether (și înapoi pe iarbă+deșert). Chemată din `nether.gd`.
#
# Trucul: shaderul amestecă `grass_tex` cu `desert_tex` după harta de biomuri. Dacă îi dăm
# ACEEAȘI textură pe amândouă, amestecul iese cărămidă peste tot — deci nu trebuie să scoatem
# materialul, nici să atingem harta de biomuri. `tile_size` rămâne singurul buton: cât de mare
# se vede o dală (fișierul e 128px; la 96 iese puțin mai mare decât iarba de 64).
func set_nether(on: bool) -> void:
	if _mat == null:
		return
	if on and _brick == null:
		push_warning("Nether: lipsește harta/nether/Brick32.png (rulează --headless --import)")
		return
	_mat.set_shader_parameter("grass_tex", _brick if on else _grass)
	_mat.set_shader_parameter("desert_tex", _brick if on else _desert)
	_mat.set_shader_parameter("tile_size", nether_tile_size if on else tile_size)
	_set_warp(on, nether_warp, nether_warp_scale, nether_warp_speed)

# Același truc, altă textură: podeaua Ender-ului e nebuloasa din `harta/Portal Ender/`.
# Chemată din `ender.gd`. Dala se vede MULT mai mare decât cărămida (256 față de 96): e un cer
# înstelat, nu un pavaj — la 96 s-ar vedea limpede că aceeași bucată se repetă la doi pași.
func set_ender(on: bool) -> void:
	if _mat == null:
		return
	if on and _nebula == null:
		push_warning("Ender: lipsește harta/Portal Ender/misc_nebula.png (rulează --headless --import)")
		return
	_mat.set_shader_parameter("grass_tex", _nebula if on else _grass)
	_mat.set_shader_parameter("desert_tex", _nebula if on else _desert)
	_mat.set_shader_parameter("tile_size", ender_tile_size if on else tile_size)
	_set_warp(on, ender_warp, ender_warp_scale, ender_warp_speed)

# Al treilea rând de dale: pământul CASTELULUI (`harta/castle/castle_bg.png`). Același truc ca la
# Nether și Ender — aceeași textură pe ambele sloturi ale shaderului de biom, deci amestecul iese
# pavaj peste tot, fără să scoatem materialul și fără să atingem harta de biomuri.
#
# ⚠️ FĂRĂ unduire (`_set_warp(false, ...)`), din exact motivul pentru care e stinsă și în Nether:
# lespezile au muchii drepte și lungi, iar orice deformare pe ele se citește ca „mi se mișcă
# ecranul", nu ca atmosferă. Vezi comentariul de la `nether_warp`.
func set_prison(on: bool) -> void:
	if _mat == null:
		return
	if on and _prison == null:
		push_warning("Prison: lipsește harta/castle/castle_bg.png (rulează --headless --import)")
		return
	_mat.set_shader_parameter("grass_tex", _prison if on else _grass)
	_mat.set_shader_parameter("desert_tex", _prison if on else _desert)
	_mat.set_shader_parameter("tile_size", prison_tile_size if on else tile_size)
	_set_warp(false, 0.0, 0.0, 0.0)

# Aprinde/stinge unduirea. Stinsă înseamnă `warp_amount = 0`, adică shaderul sare complet
# peste calcul — lumea normală nu plătește nimic pentru efectul din dimensiuni.
func _set_warp(on: bool, amount: float, scale: float, speed: float) -> void:
	_mat.set_shader_parameter("warp_amount", amount if on else 0.0)
	_mat.set_shader_parameter("warp_scale", scale)
	_mat.set_shader_parameter("warp_speed", speed)

# ---------- MARGINEA (groapa) ----------
# Chemate din `nether.gd` / `ender.gd`, din exact aceleași patru locuri ca `set_nether`/`set_ender`:
# intrare, ieșire, `suspenda()` și `reia()`. Cât ești în Limbo marginea e stinsă — Limbo e altă
# lume, cu podeaua lui, iar o groapă din Nether desenată peste câmpia alb-negru n-ar avea sens.
func set_margine(centru: Vector2, raza: float = MARGINE_RAZA) -> void:
	margine_centru = centru
	margine_raza = raza
	_scrie_margine()

func opreste_margine() -> void:
	margine_raza = 0.0
	_scrie_margine()

func _scrie_margine() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("void_center", margine_centru)
	_mat.set_shader_parameter("void_radius", margine_raza)
	_mat.set_shader_parameter("void_fade", MARGINE_FADE)

# Punctul adus înapoi în lume. Player-ul se OPREȘTE pe buză (nu e împins înapoi și nu cade):
# `player.gd` o cheamă după `move_and_slide`.
func in_margine(p: Vector2) -> Vector2:
	if margine_raza <= 0.0:
		return p
	var d := p - margine_centru
	if d.length() <= margine_raza:
		return p
	return margine_centru + d.normalized() * margine_raza

# Loc de spawn care sigur cade în lume, nu în gol. Dacă cel cerut e peste margine îl OGLINDIM
# față de player — adică inamicul vine dinspre interior, nu de peste prăpastie, și rămâne la
# aceeași distanță de tine (deci tot dincolo de marginea ecranului, nu materializat în față).
# Abia dacă nici oglinditul nu e bun îl tragem pe buză.
func loc_in_margine(referinta: Vector2, poz: Vector2) -> Vector2:
	if margine_raza <= 0.0 or margine_centru.distance_to(poz) <= margine_raza:
		return poz
	var oglindit := referinta * 2.0 - poz
	if margine_centru.distance_to(oglindit) <= margine_raza:
		return oglindit
	return in_margine(poz)
