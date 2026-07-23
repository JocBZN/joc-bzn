extends RefCounted

# NU pun `class_name` aici: numele global se înregistrează doar când proiectul e deschis în editor,
# iar rularea directă a jocului (cum verific eu) crapă cu „Identifier not declared". Cei care o
# folosesc o iau cu `const GroundShadow := preload("res://ground_shadow.gd")`, ca la LEAFFALL.
#
# Umbra de la baza unui obiect așezat pe sol (copaci, cactuși). Stătea în `props.gd`, dar de pe
# 2026-07-19 o folosesc și cactușii din `desert_structures.gd` — și nu vreau două copii ale aceluiași
# scanat de pixeli care s-ar putea desincroniza.
#
# Tot ce e aici e STATIC și cache-uit per textură: scanarea pixelilor (`get_used_rect`, banda de
# trunchi) e scumpă, iar aceleași 6 texturi de copac / 1 de cactus se refolosesc la nesfârșit.

const SHADOW_TEX_SIZE := 128
# Ce fracție din înălțimea vizibilă, măsurată de jos, e „trunchi".
# 0.08 (nu 0.18): la copacii noi (2026-07-23) frunzișul de jos al unora (stejarul, tufele)
# cobora în banda de 18% → detectorul credea că trunchiul e lat cât coroana și ieșea un
# hitbox uriaș. Banda subțire prinde doar baza reală care atinge solul, unde frunzișul nu
# mai ajunge → lățimi realiste și consistente (trunchi gros la stejar, subțire la mesteacăn).
const TRUNK_BAND := 0.08

static var _trunk_cache := {}      # textură -> conturul trunchiului (Rect2i, pixeli de textură)
static var _used_cache := {}       # textură -> conturul opac
static var _tex_cache: GradientTexture2D = null  # o singură textură de umbră pentru toată lumea

# Conturul opac al texturii (fără marginile transparente).
static func used_rect(tex: Texture2D) -> Rect2i:
	if not _used_cache.has(tex):
		_used_cache[tex] = tex.get_image().get_used_rect()
	return _used_cache[tex]

# Conturul TRUNCHIULUI: scanăm doar banda de jos (ultimele TRUNK_BAND din înălțimea vizibilă) și
# luăm întinderea pixelilor opaci. Trunchiul e ce atinge solul — coroana (sau brațele cactusului)
# stau în altă parte, iar umbra centrată pe conturul întreg ieșea pe lângă obiect.
static func trunk_rect(tex: Texture2D) -> Rect2i:
	if _trunk_cache.has(tex):
		return _trunk_cache[tex]
	var img := tex.get_image()
	var used := used_rect(tex)
	var banda := maxi(1, int(round(float(used.size.y) * TRUNK_BAND)))
	var y0 := used.end.y - banda
	var min_x := used.end.x
	var max_x := used.position.x
	for y in range(y0, used.end.y):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.03:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	var r := used  # dacă banda iese goală (n-ar trebui), cădem pe conturul întreg
	if max_x >= min_x:
		r = Rect2i(min_x, y0, max_x - min_x + 1, banda)
	_trunk_cache[tex] = r
	return r

# Mijlocul trunchiului, în coordonatele nodului (Sprite2D e centrat, de aici scăderile).
static func trunk_center_x(tex: Texture2D, sprite: Sprite2D, scale: float) -> float:
	var trunk := trunk_rect(tex)
	var w := float(tex.get_width())
	return (sprite.offset.x + float(trunk.position.x) + float(trunk.size.x) * 0.5 - w * 0.5) * scale

# Linia solului: baza vizibilă a obiectului, în coordonatele nodului.
static func base_y(tex: Texture2D, sprite: Sprite2D, scale: float) -> float:
	var h := float(tex.get_height())
	return (sprite.offset.y + float(used_rect(tex).end.y) - h * 0.5) * scale

# Gradient radial negru, făcut o singură dată. Miez plin până la 72%, apoi margine moale.
static func shadow_texture() -> GradientTexture2D:
	if _tex_cache == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		g.add_point(0.72, Color(0, 0, 0, 1))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = SHADOW_TEX_SIZE
		t.height = SHADOW_TEX_SIZE
		_tex_cache = t
	return _tex_cache

# Elipsa turtită de la bază. `z_index = -1` o ține pe sol: sub obiect, sub player și sub celelalte
# obiecte, indiferent de sortarea pe Y. (Aceeași soluție ca la urmele de foc.)
# LĂȚIMEA o dă conturul întreg (coroana/brațele aruncă umbra), dar POZIȚIA o dă trunchiul.
static func make(tex: Texture2D, sprite: Sprite2D, scale: float,
		alpha: float, width_frac: float, squash: float, shift_y: float) -> Sprite2D:
	var sh := Sprite2D.new()
	sh.texture = shadow_texture()
	sh.z_index = -1
	sh.modulate = Color(1, 1, 1, alpha)
	var latime := float(used_rect(tex).size.x) * scale * width_frac
	var t := float(SHADOW_TEX_SIZE)
	sh.scale = Vector2(latime / t, latime * squash / t)
	sh.position = Vector2(trunk_center_x(tex, sprite, scale), base_y(tex, sprite, scale) + shift_y)
	return sh
