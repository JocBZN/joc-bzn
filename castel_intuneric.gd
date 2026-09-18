extends Node2D

# Întunericul din jurul castelului lui Sir John (`castel_harta.gd`): între `interior` și `exterior`
# drumul de strajă se stinge treptat spre negru, iar dincolo de `exterior` e negru plin, până
# departe (camera nu vede niciodată capătul). Pătrat, nu rotund ca groapa din Nether/Ender
# (`ground.gd::MARGINE_*`): e o cetate, iar zidurile ei sunt drepte.

const DEPARTE := 12000.0

var interior := Rect2()
var exterior := Rect2()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var gol := Color(0, 0, 0, 0)
	var negru := Color(0, 0, 0, 1)
	var i0 := interior.position
	var i1 := interior.end
	var e0 := exterior.position
	var e1 := exterior.end
	# patru trapeze de stingere (sus, dreapta, jos, stânga)
	_trapez([Vector2(i0.x, i0.y), Vector2(i1.x, i0.y), Vector2(e1.x, e0.y), Vector2(e0.x, e0.y)], gol, negru)
	_trapez([Vector2(i1.x, i0.y), Vector2(i1.x, i1.y), Vector2(e1.x, e1.y), Vector2(e1.x, e0.y)], gol, negru)
	_trapez([Vector2(i1.x, i1.y), Vector2(i0.x, i1.y), Vector2(e0.x, e1.y), Vector2(e1.x, e1.y)], gol, negru)
	_trapez([Vector2(i0.x, i1.y), Vector2(i0.x, i0.y), Vector2(e0.x, e0.y), Vector2(e0.x, e1.y)], gol, negru)
	# negru plin dincolo
	var d := DEPARTE
	draw_rect(Rect2(e0.x - d, e0.y - d, exterior.size.x + 2 * d, d), negru)
	draw_rect(Rect2(e0.x - d, e1.y, exterior.size.x + 2 * d, d), negru)
	draw_rect(Rect2(e0.x - d, e0.y, d, exterior.size.y), negru)
	draw_rect(Rect2(e1.x, e0.y, d, exterior.size.y), negru)

# primele două puncte sunt pe marginea interioară (transparente), ultimele două pe cea exterioară
func _trapez(p: Array, a: Color, b: Color) -> void:
	draw_polygon(PackedVector2Array(p), PackedColorArray([a, a, b, b]))
