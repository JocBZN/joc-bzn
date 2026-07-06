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
const MASK := 0xFFFFFFFF     # pentru aritmetică pe 32 de biți (ca uint în shader)

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
	var lx := cx - mx * MACRO                     # poziția chunk-ului în macro-celulă (0..MACRO-1)
	var ly := cy - my * MACRO
	return lx >= ox and lx < ox + f and ly >= oy and ly < oy + f
