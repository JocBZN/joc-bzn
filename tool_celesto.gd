extends Node

# UNEALTĂ (se rulează ca scenă):
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool_taie_gifuri.ps1 \
#       -Src "<proiect>\harta\Portal Ender\Celesto" -Prefix walk
#   godot --headless --path <proiect> res://tool_celesto.tscn
#   godot --headless --path <proiect> --import
#
# CELESTO — foile de mers ale boss-ului nou din Ender. Unealta face două lucruri:
#
# 1. **OGLINDEȘTE direcțiile care lipsesc.** Răzvan a pus 6 GIF-uri; lipsesc `west` ȘI
#    `north_west` (el a observat doar vestul). Stânga e dreapta întoarsă, deci le facem din
#    `east`, respectiv `north_east` — aceeași soluție ca la Grasu (`tool_mirror_grasu.gd`).
#    ⚠️ După `flip_x` desenul se mută cu dublul decalajului lui față de mijlocul pânzei, iar
#    în joc ai vedea boss-ul SĂRIND lateral când schimbă direcția. De aia măsurăm conturul
#    opac înainte și după și îl **recentrăm** pe aceleași coloane.
#
# 2. **Pune conturul ALBASTRU de 1px** și scrie copiile în `frames_contur/`. Sursa din `frames/`
#    rămâne neatinsă, deci unealta se poate re-rula oricând fără să se îngroașe conturul (dacă ar
#    scrie peste sursă, a doua rulare ar contura conturul).
#    ⚠️ 2026-08-04: JOCUL NU MAI FOLOSEȘTE `frames_contur/`. Boss-ul se afișează la scale 3.2,
#    deci conturul copt de 1px se vedea gros de 3 pixeli pe ecran. Acum îl desenează
#    `contur_1px.gdshader` la rulare, în pixeli de ECRAN, iar `celesto.gd` citește `frames/`.
#    Partea asta a uneltei a rămas doar ca să poți compara variantele; punctul 1 (oglindirea) e
#    în continuare cel care scrie cadrele folosite în joc.
#
# De ce nu în `tool_contur_foaie.gd`: ăla conturează FOI (grile de cadre într-un singur PNG),
# aici avem fișiere separate, câte unul pe cadru. Aceeași culoare și același prag, ca să arate
# la fel cu boss-ul de dinainte.

const DIR := "res://harta/Portal Ender/Celesto/frames/"
const OUT := "res://harta/Portal Ender/Celesto/frames_contur/"
const PREFIX := "walk"
const CADRE := 8
const ALBASTRU := Color(0.15, 0.27, 0.78, 1.0)   # identic cu `tool_contur_foaie.gd`
const PRAG := 0.35                               # de la ce alfa în sus considerăm că e desen

# destinație <- sursă
const PERECHI := {
	"west": "east",
	"north_west": "north_east",
}

const DIRECTII := ["north", "north_east", "east", "south_east",
	"south", "south_west", "west", "north_west"]

func _ready() -> void:
	print("--- oglindesc direcțiile care lipsesc ---")
	for dest in PERECHI:
		for i in CADRE:
			_oglindeste(PERECHI[dest], dest, i)
	print("--- contur albastru de 1px ---")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for d in DIRECTII:
		var pixeli := 0
		var lipsa := 0
		for i in CADRE:
			var n := _contur(d, i)
			if n < 0:
				lipsa += 1
			else:
				pixeli += n
		if lipsa > 0:
			print("  %-11s LIPSESC %d cadre" % [d, lipsa])
		else:
			print("  %-11s %d cadre, %d pixeli de contur" % [d, CADRE, pixeli])
	print("gata")
	get_tree().quit()

func _cale(d: String, i: int, folder: String) -> String:
	return ProjectSettings.globalize_path("%s%s_%s_%d.png" % [folder, PREFIX, d, i])

func _oglindeste(sursa: String, dest: String, i: int) -> void:
	var img := Image.load_from_file(_cale(sursa, i, DIR))
	if img == null:
		print("  LIPSĂ: ", _cale(sursa, i, DIR))
		return
	var inainte := img.get_used_rect()
	img.flip_x()
	var dupa := img.get_used_rect()
	var dx := inainte.position.x - dupa.position.x
	if dx != 0:
		var mutat := Image.create_empty(img.get_width(), img.get_height(), false, img.get_format())
		mutat.fill(Color(0, 0, 0, 0))
		mutat.blit_rect(img, dupa, dupa.position + Vector2i(dx, 0))
		img = mutat
	img.save_png(_cale(dest, i, DIR))
	if i == 0:
		print("  %s_%d <- %s_%d   contur %s -> %s  (recentrat %d px)"
			% [dest, i, sursa, i, str(inainte), str(img.get_used_rect()), dx])

# Conturul unui cadru. Întoarce câți pixeli a desenat, sau -1 dacă fișierul lipsește.
func _contur(d: String, i: int) -> int:
	var img := Image.load_from_file(_cale(d, i, DIR))
	if img == null:
		return -1
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	# Întâi harta de „aici e desen", ca să nu conturăm conturul pe care tocmai l-am pus.
	var plin := PackedByteArray()
	plin.resize(w * h)
	for y in h:
		for x in w:
			plin[y * w + x] = 1 if img.get_pixel(x, y).a >= PRAG else 0
	var n := 0
	for y in h:
		for x in w:
			if plin[y * w + x] == 1:
				continue
			var vecin := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if plin[ny * w + nx] == 1:
						vecin = true
			if vecin:
				img.set_pixel(x, y, ALBASTRU)
				n += 1
	img.save_png(_cale(d, i, OUT))
	return n
