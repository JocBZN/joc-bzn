@tool
extends Node

# UNEALTĂ: face podeaua ARENEI (`arena.gd`) din podeaua castelului — aceeași poză, alt colorit.
# Cerut de Răzvan pe 2026-10-28: „podeaua vreau să fie ca la Sir John doar că colorată altfel".
# Nu face parte din joc; se rulează o dată, când se schimbă arta:
#
#   "<godot.exe>" --path "<proiect>" res://tool_arena_podea.tscn
#   "<godot.exe>" --headless --path "<proiect>" --import      ← OBLIGATORIU după, altfel PNG-ul
#                                                               nou n-are `.import` și nu se încarcă
#
# CUM: o „colorare" ca în editoarele de poze, nu o rotire de nuanță. Pământul castelului e mai
# mult verde-mucegai, dar are și pete cenușii-maronii; o rotire simplă ar fi trimis verdele în roșu
# și maroul în MOV, adică două culori care se bat. Aici fiecare pixel primește aceeași nuanță
# (`NUANTA`, roșu-sânge), cu o urmă din nuanța lui veche (`URMA`) ca să nu iasă plat, iar
# LUMINOZITATEA rămâne neatinsă — deci petele, pietrișul și sclipirile rămân exact unde erau.
#
# Sursa NU se scrie niciodată — ieșirea merge în `harta/arena/`, deci unealta se poate re-rula
# oricât, cu alte cifre, fără să macine ce a măcinat deja.

const SURSA := "res://harta/castle/castle_bg.png"
const IESIRE := "res://harta/arena/arena_bg.png"

const NUANTA := 0.985      # roșu-sânge (0 = roșu, 0.33 = verde, 0.66 = albastru)
const URMA := 0.12         # cât din nuanța veche se mai simte (0 = toată podeaua o singură nuanță)
const SATURATIE := 1.9     # înmulțitorul saturației vechi...
const SATURATIE_MIN := 0.50  # ...dar măcar atât, altfel pietrișul cenușiu rămâne cenușiu
const LUMINA := 0.92       # puțin mai întunecată: roșul aprins pe toată podeaua ar obosi ochiul

func _ready() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SURSA))
	if img == null or img.is_empty():
		push_error("tool_arena_podea: nu pot citi " + SURSA)
		get_tree().quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var h := wrapf(NUANTA + (c.h - 0.30) * URMA, 0.0, 1.0)
			var s := clampf(maxf(c.s * SATURATIE, SATURATIE_MIN), 0.0, 1.0)
			var v := c.v * LUMINA
			img.set_pixel(x, y, Color.from_hsv(h, s, v, c.a))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://harta/arena"))
	var err := img.save_png(ProjectSettings.globalize_path(IESIRE))
	if err != OK:
		push_error("tool_arena_podea: nu pot scrie %s (eroare %d)" % [IESIRE, err])
		get_tree().quit(1)
		return
	print("tool_arena_podea: scris %s (%dx%d)" % [IESIRE, img.get_width(), img.get_height()])
	get_tree().quit()
