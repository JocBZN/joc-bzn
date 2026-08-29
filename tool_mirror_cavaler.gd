extends Node

# UNEALTĂ (se rulează ca scenă, după fiecare tăiere de GIF-uri ale CAVALERULUI):
#
#   godot --headless --path <proiect> res://tool_mirror_cavaler.tscn
#   godot --headless --path <proiect> --import          # OBLIGATORIU după
#
# Completează direcțiile care lipsesc din arta cavalerului de castel
# (`harta/castle/castle enemies/`). Răzvan a livrat pe 2026-08-29 numai ȘASE GIF-uri de mers —
# east, west, south, south-east, south-west, north — iar `enemy.gd` cere OPT.
#
# 🔑 CE AM MĂSURAT ÎNAINTE SĂ SCRIU ASTA, fiindcă schimbă tot: `west` este hflip-ul EXACT,
# pixel cu pixel, al lui `east`, iar `south_west` hflip-ul exact al lui `south_east` (verificat
# pe toate cele 8 cadre, md5 pe RGBA). Deci generatorul lui Răzvan a desenat de mână doar
# jumătatea de est și a oglindit-o pe cealaltă — exact ce facem și noi aici, cu aceeași metodă.
# `_autoverificare()` reface acea pereche la fiecare rulare: dacă vreodată nu mai iese identică,
# arta s-a schimbat sub noi și metoda trebuie regândită.
#
# ⚠️ OGLINDIRE CURATĂ, FĂRĂ RECENTRARE — invers decât la `tool_mirror_grasu.gd`. Acolo arta nu
# stătea în mijlocul pânzei, deci `flip_x()` muta personajul cu dublul decalajului și în joc
# sărea lateral; unealta îl punea la loc pe coloanele originalului. AICI arta E centrată
# (pânză 88, mijloc 43,5; `east` iese pe coloanele 32..55, adică fix centrul) — iar diagonalele
# se SPRIJINĂ intenționat într-o parte (`south_east` 30..61, `south_west` 26..57, adică ±2 față
# de mijloc). O recentrare ar trage acel sprijin înapoi în mijloc, adică ar STRICA înclinarea
# desenatorului și ar rupe egalitatea cu `south_west`-ul livrat. Deci: `flip_x()` și atât.
#
# ⚠️ RE-RULABILĂ, dar NU idempotentă pe direcțiile pe care le SCRIE: `north_east` și
# `north_west` se refac de fiecare dată din surse (`north`, respectiv `north_east`), deci
# ordinea din cod contează — supliniera întâi, oglindirea după.

const DIR := "res://harta/castle/castle enemies/frames/"
const PREFIX := "run"
const CADRE := 8

# --- 1. SUPLINIREA (temporară) ---
# `north_east` nu există deloc: nu e o direcție pe care s-o pot oglindi din ceva, fiindcă
# `north_west` lipsește și el. Până când Răzvan randează GIF-ul lipsă, ținem locul cu spatele
# curat (`north`) — dintre cele șase desenate, el e cel mai aproape: în foaia de rotații
# (`Idle_rotations_8dir.gif`) pozele de trei-sferturi-spate seamănă cu spatele, nu cu profilul,
# iar un profil pus pe o mișcare în sus-dreapta ar aluneca vizibil lateral.
#
# ⚠️ ȘTERGE LINIA ASTA în ziua în care apare `Idle_v3_walking_north-east.gif`: retai GIF-urile,
# golește `SUPLINIRI` și rulează unealta din nou — `PERECHI` face singur `north_west`-ul.
const SUPLINIRI := {
	"north_east": "north",
}

# --- 2. OGLINDIREA (permanentă) ---
# destinație <- sursă. Vestul se face din est, ca la tot restul foii.
const PERECHI := {
	"north_west": "north_east",
}

# Perechea deja livrată de generator, pe care ne verificăm metoda (vezi comentariul de sus).
const CONTROL := {"west": "east", "south_west": "south_east"}


func _ready() -> void:
	if not _autoverificare():
		get_tree().quit(1)
		return
	print("--- suplinesc (temporar) ---")
	for dest in SUPLINIRI:
		for i in CADRE:
			_copiaza(SUPLINIRI[dest], dest, i)
		push_warning("Cavaler: `%s` e SUPLINIT din `%s` — arta adevărată încă lipsește" % [dest, SUPLINIRI[dest]])
	print("--- oglindesc ---")
	for dest in PERECHI:
		for i in CADRE:
			_oglindeste(PERECHI[dest], dest, i)
	print("gata")
	get_tree().quit()


# Refacem cu metoda noastră o direcție pe care generatorul a livrat-o deja și cerem egalitate
# PIXEL CU PIXEL. E singura dovadă că „oglindim ca desenatorul" — dacă pică, nu scriem nimic.
func _autoverificare() -> bool:
	print("--- autoverificare (metoda noastră vs. arta livrată) ---")
	var bun := true
	for dest in CONTROL:
		var sursa: String = CONTROL[dest]
		for i in CADRE:
			var a := _incarca(sursa, i)
			var b := _incarca(dest, i)
			if a == null or b == null:
				push_error("Cavaler: lipsesc cadre pentru autoverificare (%s/%s _%d)" % [sursa, dest, i])
				return false
			a.flip_x()
			if a.get_data() != b.get_data():
				push_error("Cavaler: `%s_%d` NU e hflip-ul lui `%s_%d` — arta s-a schimbat, regândește metoda" % [dest, i, sursa, i])
				bun = false
		if bun:
			print("  %-11s == flip(%s)  pe toate cele %d cadre" % [dest, sursa, CADRE])
	return bun


func _incarca(d: String, i: int) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("%s%s_%s_%d.png" % [DIR, PREFIX, d, i]))


func _copiaza(sursa: String, dest: String, i: int) -> void:
	var img := _incarca(sursa, i)
	if img == null:
		push_error("LIPSA: %s%s_%s_%d.png" % [DIR, PREFIX, sursa, i])
		return
	var err := img.save_png(ProjectSettings.globalize_path("%s%s_%s_%d.png" % [DIR, PREFIX, dest, i]))
	print("  %s_%d <- %s_%d   contur %s  err=%d" % [dest, i, sursa, i, str(img.get_used_rect()), err])


func _oglindeste(sursa: String, dest: String, i: int) -> void:
	var img := _incarca(sursa, i)
	if img == null:
		push_error("LIPSA: %s%s_%s_%d.png" % [DIR, PREFIX, sursa, i])
		return
	var inainte := img.get_used_rect()
	img.flip_x()
	var err := img.save_png(ProjectSettings.globalize_path("%s%s_%s_%d.png" % [DIR, PREFIX, dest, i]))
	print("  %s_%d <- flip(%s_%d)   contur %s -> %s  err=%d"
		% [dest, i, sursa, i, str(inainte), str(img.get_used_rect()), err])
