extends Node

# Construiește resursa de animații a inamicului din Nether (`enemy_nether_frames.tres`) din
# cadrele tăiate din GIF-urile lui Răzvan (`homeless directii/Nether Enemies/frames/`).
#
# Rulare:  godot --headless --path <proj> res://tool_frames_nether.tscn
#
# De ce o unealtă și nu un `.tres` scris de mână: fișierul are 8 animații × 4 cadre = 32 de
# referințe cu UID, iar un UID greșit scris manual dă „resource not found" abia la rulare.
# Aici cadrele se încarcă cu `load()`, deci dacă un fișier lipsește, se vede pe loc.

const DIR := "res://homeless directii/Nether Enemies/frames/"
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const CADRE := 4
const VITEZA := 12.0     # fps-ul animației (ca la polițist)
const IESIRE := "res://enemy_nether_frames.tres"

func _ready() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var lipsa := 0
	for d in DIRECTII:
		sf.add_animation(d)
		sf.set_animation_speed(d, VITEZA)
		sf.set_animation_loop(d, true)
		for i in CADRE:
			var cale := "%srun_%s_%d.png" % [DIR, d, i]
			if not ResourceLoader.exists(cale):
				print("!!! lipsește ", cale)
				lipsa += 1
				continue
			var tex: Texture2D = load(cale)
			sf.add_frame(d, tex)
			if d == "east" and i == 0:
				print("   mărimea unui cadru: ", tex.get_size())
	if lipsa > 0:
		print("!!! ", lipsa, " cadre lipsă — nu salvez")
		get_tree().quit()
		return
	var err := ResourceSaver.save(sf, IESIRE)
	print("gata: ", IESIRE, " (", DIRECTII.size(), " direcții × ", CADRE, " cadre) err=", err)
	# comparație cu polițistul, ca să știm dacă trebuie altă scară în scenă
	var politist: Texture2D = load("res://homeless directii/frames/walk_east_0.png")
	if politist != null:
		print("   pentru comparație, cadrul polițistului: ", politist.get_size())
	get_tree().quit()
