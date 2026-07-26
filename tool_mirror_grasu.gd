extends Node

# UNEALTĂ (se rulează ca scenă, o dată):
#
#   godot --headless --path <proiect> res://tool_mirror_grasu.tscn
#
# Face animațiile de alergare care lipsesc pentru Grasu, oglindind pe orizontală direcția
# opusă. Răzvan a șters GIF-urile de `west`, `north-west` și `south-east`, iar celelalte cinci
# (east, north, north-east, south, south-west) sunt suficiente: stânga e dreapta întoarsă.
#
# ⚠️ De ce contează CENTRAREA: oglindirea întoarce toată pânza, deci dacă personajul nu stă
# fix în mijlocul ei, se mută cu dublul decalajului — iar în joc ai vedea player-ul „sărind"
# lateral când schimbi direcția. De aia unealta măsoară conturul opac înainte și după și
# **recentreză** rezultatul pe aceeași coloană pe care stătea originalul.

const DIR := "res://grasu directii/running/frames/"
const CADRE := 4

# destinație <- sursă (cea care a rămas)
const PERECHI := {
	"west": "east",
	"north_west": "north_east",
	"south_east": "south_west",
}

func _ready() -> void:
	# întâi raportul: unde stă personajul ACUM în fiecare direcție (inclusiv în cadrele vechi
	# pe care le înlocuim) — ca să văd dacă arta e centrată și cât ar trebui mutată
	print("--- contur opac ÎNAINTE ---")
	for d in ["east", "west", "north_east", "north_west", "south_west", "south_east"]:
		for i in CADRE:
			var img := Image.load_from_file(ProjectSettings.globalize_path("%s%s_%d.png" % [DIR, d, i]))
			if img != null:
				print("  %-11s %d  %dx%d  contur %s" % [d, i, img.get_width(), img.get_height(), str(img.get_used_rect())])
	print("--- oglindesc ---")
	for dest in PERECHI:
		var sursa: String = PERECHI[dest]
		for i in CADRE:
			_oglindeste(sursa, dest, i)
	print("gata")
	get_tree().quit()

func _oglindeste(sursa: String, dest: String, i: int) -> void:
	var cale_src := ProjectSettings.globalize_path("%s%s_%d.png" % [DIR, sursa, i])
	var cale_dst := ProjectSettings.globalize_path("%s%s_%d.png" % [DIR, dest, i])
	var img := Image.load_from_file(cale_src)
	if img == null:
		print("LIPSA: ", cale_src)
		return
	var inainte := img.get_used_rect()
	img.flip_x()
	# după flip, conturul ajunge oglindit față de mijlocul pânzei; îl mut la loc, ca personajul
	# să ocupe exact aceleași coloane ca în direcția-sursă
	var dupa := img.get_used_rect()
	var dx := inainte.position.x - dupa.position.x
	if dx != 0:
		var mutat := Image.create(img.get_width(), img.get_height(), false, img.get_format())
		mutat.fill(Color(0, 0, 0, 0))
		mutat.blit_rect(img, dupa, dupa.position + Vector2i(dx, 0))
		img = mutat
	var err := img.save_png(cale_dst)
	print("%s_%d <- %s_%d   contur %s -> %s  (mutat %d px)  err=%d"
		% [dest, i, sursa, i, str(inainte), str(img.get_used_rect()), dx, err])
