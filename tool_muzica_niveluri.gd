extends Node

# Măsoară CÂT SE AUDE fiecare melodie de fundal, ca să stea toate la același nivel.
#
# De ce RMS și nu vârful: vârful spune cât de ascuțită e o tobă, nu cât de tare ți se pare
# melodia. Două melodii pot avea același vârf și una să pară de două ori mai tare. Deci melodia
# intră pe o magistrală curată cu un `AudioEffectCapture`, i se citesc PROBELE care ies din ea
# și li se calculează RMS-ul în cinci locuri din melodie, câte 4 secunde. Media celor cinci =
# „cât de tare e".
#
# Rulare (FEREASTRĂ, nu headless — driverul dummy nu mixează, deci n-ar ieși nicio probă;
# `Master` e oricum pus pe mut, nu urlă în casă). Ține ~2 minute:
#   godot --path <proj> res://tool_muzica_niveluri.tscn
#
# Coloana „efectiv" e cea care contează: trebuie să iasă TOATE egale (vezi tabelul de volume din
# `audio.gd`). Când adaugi o melodie: pune-o mai jos cu volum 0, citește RMS-ul și scrie în joc
# `TINTA - RMS`.

# nume, fișier, volumul cu care o pornește jocul (din `audio.gd`)
const PISTE := [
	["Overworld Theme", "res://audio/First 5 Minutes - Main World/Overworld Theme.mp3", -19.1],
	["main menu theme", "res://audio/main menu theme.ogg", -13.9],
	["Nether Song", "res://audio/Nether Audio/Nether Song.mp3", -15.1],
	["sky-lines", "res://audio/Nether Audio/sky-lines.ogg", -11.5],
	["Ender Theme", "res://audio/Ender Audio/Ender Theme.ogg", -16.7],
	["Saratalin Theme", "res://audio/Nether Audio/Saratalin Theme.mp3", -18.1],
]

const FERESTRE := [0.02, 0.2, 0.4, 0.6, 0.8]   # unde în melodie măsurăm (procent din lungime)
const DURATA := 4.0                            # cât ține o fereastră, în secunde
const TINTA := -28.8                           # nivelul la care vrem să stea toate

var _cap: AudioEffectCapture

func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Masura")
	AudioServer.set_bus_send(idx, "Master")
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 1.0
	AudioServer.add_bus_effect(idx, _cap)
	var p := AudioStreamPlayer.new()
	p.bus = "Masura"
	add_child(p)
	print("melodie                 RMS pe ferestre, cu volumul din joc (dBFS)  | efectiv | volum")
	for piesa in PISTE:
		var s: AudioStream = load(piesa[1])
		if s == null:
			print(piesa[0], ": lipseste")
			continue
		p.stream = s
		p.volume_db = piesa[2]
		var lung := s.get_length()
		var valori: Array = []
		for f in FERESTRE:
			valori.append(await _masoara(p, lung * f))
		var suma := 0.0
		for v in valori:
			suma += v
		var linie := "%-22s " % piesa[0]
		for v in valori:
			linie += "%8.1f" % v
		linie += "  | %7.2f | %6.1f" % [suma / valori.size(), piesa[2]]
		print(linie)
	print("(tinta: %.1f dBFS — coloana `efectiv` trebuie sa fie aceeasi peste tot)" % TINTA)
	get_tree().quit()

# Pornește melodia de la secunda `poz`, adună pătratele probelor `DURATA` secunde și întoarce RMS-ul.
func _masoara(p: AudioStreamPlayer, poz: float) -> float:
	p.play(poz)
	await get_tree().create_timer(0.3).timeout   # lăsăm mixerul să se umple
	_cap.clear_buffer()
	var suma_patrate := 0.0
	var nr := 0
	var t := 0.0
	while t < DURATA:
		await get_tree().process_frame
		t += get_process_delta_time()
		var n := _cap.get_frames_available()
		if n > 0:
			for v in _cap.get_buffer(n):
				suma_patrate += v.x * v.x + v.y * v.y
				nr += 2
	p.stop()
	if nr == 0 or suma_patrate <= 0.0:
		return -200.0
	return 20.0 * (log(sqrt(suma_patrate / nr)) / log(10.0))
