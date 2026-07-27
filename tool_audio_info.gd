extends Node

# Unealtă de măsurat sunete: citește fișierul WAV DE PE DISC (nu resursa importată — Godot
# importă WAV-urile ca QOA comprimat, din care nu poți citi probele) și spune, pentru fiecare:
# durata, vârful în dBFS, media (rms) și profilul pe sferturi de secundă — util ca să vezi
# unde e de fapt sunetul și cât e coadă/liniște.
#
# Rulare:  godot --headless --path <proj> res://tool_audio_info.tscn

const FISIERE := [
	"res://audio/Earthquake.wav",
	"res://audio/Mage Staff Audio.wav",
	"res://audio/Cursed Sword.wav",              # referințe: sunete deja reglate în joc
	"res://audio/Garda Attack.wav",
	"res://audio/When enemy hits player.wav",
	"res://audio/Nether Audio/Saratalin Flashing Purple.wav",
]

func _ready() -> void:
	for f in FISIERE:
		_masoara(f)
	get_tree().quit()

func _masoara(cale: String) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(cale), FileAccess.READ)
	if f == null:
		print(cale.get_file(), ": nu pot deschide")
		return
	var tot := f.get_buffer(f.get_length())
	f.close()
	if tot.size() < 44 or tot.slice(0, 4).get_string_from_ascii() != "RIFF":
		print(cale.get_file(), ": nu e RIFF/WAV")
		return
	# parcurgem bucățile RIFF până găsim `fmt ` și `data`
	var poz := 12
	var cod := 0
	var canale := 0
	var rata := 0
	var biti := 0
	var d_start := -1
	var d_len := 0
	while poz + 8 <= tot.size():
		var nume := tot.slice(poz, poz + 4).get_string_from_ascii()
		var lung := tot.decode_u32(poz + 4)
		var corp := poz + 8
		if nume == "fmt ":
			cod = tot.decode_u16(corp)
			canale = tot.decode_u16(corp + 2)
			rata = int(tot.decode_u32(corp + 4))
			biti = tot.decode_u16(corp + 14)
		elif nume == "data":
			d_start = corp
			d_len = int(lung)
			break
		poz = corp + int(lung) + (int(lung) & 1)
	if d_start < 0 or canale == 0 or biti == 0:
		print(cale.get_file(), ": header neînțeles")
		return
	var octeti := biti / 8
	var probe := d_len / octeti
	var cadre := probe / canale
	var durata := float(cadre) / float(rata)
	var varf := 0.0
	var suma := 0.0
	var pe_sfert := {}      # sfert de secundă -> vârful din el
	for i in probe:
		var o := d_start + i * octeti
		if o + octeti > tot.size():
			break
		var v := 0.0
		if cod == 3 and biti == 32:
			v = absf(tot.decode_float(o))
		elif biti == 16:
			v = absf(float(tot.decode_s16(o))) / 32768.0
		elif biti == 24:
			var brut := tot[o] | (tot[o + 1] << 8) | (tot[o + 2] << 16)
			if brut >= 0x800000:
				brut -= 0x1000000
			v = absf(float(brut)) / 8388608.0
		elif biti == 32:
			v = absf(float(tot.decode_s32(o))) / 2147483648.0
		varf = maxf(varf, v)
		suma += v * v
		var sf := int(floor(float(i / canale) / float(rata) * 4.0))
		pe_sfert[sf] = maxf(float(pe_sfert.get(sf, 0.0)), v)
	var rms := sqrt(suma / maxf(1.0, float(probe)))
	print("%s: %.2fs · %dHz · %d canale · %d biți (cod %d) · vârf %.1f dBFS · rms %.1f dBFS" % [
		cale.get_file(), durata, rata, canale, biti, cod,
		linear_to_db(maxf(varf, 0.00001)), linear_to_db(maxf(rms, 0.00001))])
	# profilul pe sferturi de secundă, ca să se vadă atacul și coada
	var linie := "   profil (vârf pe fiecare 0.25s, dBFS): "
	var chei := pe_sfert.keys()
	chei.sort()
	for k in chei:
		linie += "%.0f " % linear_to_db(maxf(float(pe_sfert[k]), 0.00001))
	print(linie)
