class_name BiomeMap
extends RefCounted

# Harta biomurilor — COMUNĂ pentru copaci (props.gd), pietre (rocks.gd) și shaderul podelei (biome.gdshader).
# Lumea e împărțită în „macro-celule" de MACRO×MACRO chunk-uri. Fiecare macro-celulă poate conține
# UN petic de deșert PĂTRAT, cu latura aleasă RANDOM între MIN_SIZE și MAX_SIZE chunk-uri, plasat aleator
# în celulă. În deșert NU se generează copaci/pietre. Totul e determinist (hash pe coordonata celulei) →
# același loc are mereu același biom, chiar dacă pleci și te întorci.
#
# IMPORTANT: matematica de aici (hash + extragerea mărimii/poziției) trebuie să rămână IDENTICĂ cu cea
# din biome.gdshader, altfel deșertul desenat n-ar coincide cu locul unde blocăm copacii/pietrele.

const MACRO := 20           # câte chunk-uri are latura unei macro-celule (= dimensiunea MAXIMĂ a unui deșert)
const MIN_SIZE := 6         # latura minimă a unui petic de deșert (chunk-uri)
const MAX_SIZE := 20        # latura maximă a unui petic de deșert (chunk-uri)
const DESERT_PERCENT := 40  # aproximativ ce procent din macro-celule conțin deșert (0..100)
const BLEND_CHUNKS := 1.5   # lățimea gradientului soft (chunk-uri) — TREBUIE să fie ca blend_chunks din ground.gd / biome.gdshader
const MASK := 0xFFFFFFFF     # pentru aritmetică pe 32 de biți (ca uint în shader)

# Cât de aproape de marginea macro-celulei trebuie să ajungă un petic ca să-l LIPIM de ea.
# De ce: fiecare macro-celulă își pune peticul independent, așa că două petice vecine puteau
# rămâne la 1 chunk distanță → o fâșie subțire de iarbă tăia deșertul în două (și creșteau
# pietre pe ea, fiindcă `is_desert_chunk` zicea „iarbă"). Cu lipirea, marginea unui petic e
# ori exact pe granița celulei, ori la cel puțin EDGE_SNAP+1 chunk-uri de ea → distanța
# dintre două petice vecine e ori 0 (se unesc), ori ≥3 chunk-uri (culoar lat, arată intenționat).
# NU poate ieși 1 sau 2. TREBUIE să fie identic cu edge_snap din biome.gdshader.
const EDGE_SNAP := 2

# Marginile peticului pe o axă, în coordonate LOCALE de celulă (0..MACRO), după lipire.
static func _snap_axis(lo: int, size: int) -> Vector2i:
	var hi := lo + size
	if lo <= EDGE_SNAP:
		lo = 0
	if hi >= MACRO - EDGE_SNAP:
		hi = MACRO
	return Vector2i(lo, hi)

# Hash întreg pe 32 de biți. IDENTIC cu hashu() din biome.gdshader.
static func _hash(cx: int, cy: int) -> int:
	var x := cx & MASK
	var y := cy & MASK
	var h := (x * 374761393 + y * 668265263) & MASK
	h = ((h ^ (h >> 13)) * 1274126177) & MASK
	h = (h ^ (h >> 16)) & MASK
	return h

# Împărțire cu rotunjire în JOS (floor), corectă și pentru numere negative.
static func _floordiv(a: int, b: int) -> int:
	var q := a / b
	if (a % b != 0) and ((a < 0) != (b < 0)):
		q -= 1
	return q

# E chunk-ul (cx, cy) în deșert? (cx, cy = indici de chunk, exact ca în props.gd/rocks.gd)
static func is_desert_chunk(cx: int, cy: int) -> bool:
	var mx := _floordiv(cx, MACRO)
	var my := _floordiv(cy, MACRO)
	var h := _hash(mx, my)
	if (h % 100) >= DESERT_PERCENT:
		return false  # macro-celula asta n-are deșert deloc
	var span := MAX_SIZE - MIN_SIZE + 1          # câte mărimi posibile (6..20 = 15)
	var f := MIN_SIZE + int((h / 100) % span)    # latura peticului: MIN_SIZE..MAX_SIZE
	var room := MACRO - f + 1                    # câte poziții încap pe o axă
	var ox := int((h / 10000) % room)            # colțul peticului în celulă (X)
	var oy := int((h / 1000000) % room)          # colțul peticului în celulă (Y)
	var sx := _snap_axis(ox, f)                  # margini lipite de celulă dacă sunt aproape
	var sy := _snap_axis(oy, f)
	var lx := cx - mx * MACRO                     # poziția chunk-ului în macro-celulă (0..MACRO-1)
	var ly := cy - my * MACRO
	return lx >= sx.x and lx < sx.y and ly >= sy.x and ly < sy.y

# smootherstep (quintic) — IDENTIC cu ss() din biome.gdshader.
static func _ss(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

# „Deșert-imea" (0 = iarbă, 1 = deșert) la o poziție CONTINUĂ de chunk (world_pos / chunk_size).
# Replică EXACT bucla din biome.gdshader (deșert + gradientul soft din jur), ca să știm unde
# arată podeaua vreun pic de deșert. Folosit ca să NU plantăm copaci pe gradient.
static func desertness_at_chunk(chunkf: Vector2) -> float:
	var base_mx := floori(chunkf.x / float(MACRO))
	var base_my := floori(chunkf.y / float(MACRO))
	var span := MAX_SIZE - MIN_SIZE + 1
	var d := 0.0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var mx: int = base_mx + dx
			var my: int = base_my + dy
			var h := _hash(mx, my)
			if (h % 100) >= DESERT_PERCENT:
				continue  # macro-celula asta n-are deșert
			var f := MIN_SIZE + int((h / 100) % span)
			var room := MACRO - f + 1
			var ox := int((h / 10000) % room)
			var oy := int((h / 1000000) % room)
			var sx := _snap_axis(ox, f)
			var sy := _snap_axis(oy, f)
			var lox := float(mx * MACRO + sx.x)
			var hix := float(mx * MACRO + sx.y)
			var loy := float(my * MACRO + sy.x)
			var hiy := float(my * MACRO + sy.y)
			var qx := maxf(maxf(lox - chunkf.x, chunkf.x - hix), 0.0)
			var qy := maxf(maxf(loy - chunkf.y, chunkf.y - hiy), 0.0)
			var dist := Vector2(qx, qy).length()
			d = maxf(d, 1.0 - _ss(0.0, BLEND_CHUNKS, dist))
	return d

# Cât de ADÂNC (în chunk-uri) e poziția în DEȘERTUL PLIN (pătratul hard, unde d==1), măsurat de la
# marginea unde se termină gradientul. <= 0 dacă poziția NU e în deșertul plin (e pe gradient sau iarbă).
# Folosit ca să ținem unele structuri (ex. house) la distanță de gradient. Înmulțește cu chunk_size → px.
static func desert_inset_chunk(chunkf: Vector2) -> float:
	var base_mx := floori(chunkf.x / float(MACRO))
	var base_my := floori(chunkf.y / float(MACRO))
	var span := MAX_SIZE - MIN_SIZE + 1
	var best := -1.0  # <= 0 = nu e în deșertul plin
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var mx: int = base_mx + dx
			var my: int = base_my + dy
			var h := _hash(mx, my)
			if (h % 100) >= DESERT_PERCENT:
				continue
			var f := MIN_SIZE + int((h / 100) % span)
			var room := MACRO - f + 1
			var ox := int((h / 10000) % room)
			var oy := int((h / 1000000) % room)
			var sx := _snap_axis(ox, f)
			var sy := _snap_axis(oy, f)
			var lox := float(mx * MACRO + sx.x)
			var loy := float(my * MACRO + sy.x)
			var hix := float(mx * MACRO + sx.y)
			var hiy := float(my * MACRO + sy.y)
			if chunkf.x >= lox and chunkf.x < hix and chunkf.y >= loy and chunkf.y < hiy:
				var inset := minf(minf(chunkf.x - lox, hix - chunkf.x), minf(chunkf.y - loy, hiy - chunkf.y))
				best = maxf(best, inset)  # union: cea mai adâncă apartenență contează
	return best

# Macro-celula care conține chunk-ul (cx, cy).
static func macro_of_chunk(cx: int, cy: int) -> Vector2i:
	return Vector2i(_floordiv(cx, MACRO), _floordiv(cy, MACRO))

# Dreptunghiul de deșert al unei macro-celule (în chunk-uri). size.x == 0 dacă macro-celula n-are deșert.
# Fiecare deșert e UNIC per macro-celulă → bun ca „identitate de deșert" pentru case/monument.
static func desert_rect_of_macro(mx: int, my: int) -> Rect2i:
	var h := _hash(mx, my)
	if (h % 100) >= DESERT_PERCENT:
		return Rect2i(0, 0, 0, 0)  # macro-celula asta n-are deșert
	var span := MAX_SIZE - MIN_SIZE + 1
	var f := MIN_SIZE + int((h / 100) % span)
	var room := MACRO - f + 1
	var ox := int((h / 10000) % room)
	var oy := int((h / 1000000) % room)
	var sx := _snap_axis(ox, f)
	var sy := _snap_axis(oy, f)
	return Rect2i(mx * MACRO + sx.x, my * MACRO + sy.x, sx.y - sx.x, sy.y - sy.x)
