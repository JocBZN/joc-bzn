extends Node

# Unealta de masurat efectul de "infundat" din meniuri (`audio.gd`, sectiunea "Muzica in meniuri").
# Masoara acelasi fragment din melodie de doua ori — o data curat, o data prin meniu — si scoate
# cate dB se pierd pe fiecare banda de octava; apoi verifica si purtarea (ESC, meniuri suprapuse,
# revenirea). Cifrele din tabelul din `audio.gd` de aici vin; daca schimbi constantele, ruleaza
# din nou si treci noile numere acolo.
#
# ⚠️ Ruleaza FERESTRUIT — headless inseamna driver audio fals, deci masori numai zerouri:
#   godot --path <proj> res://tool_infundat.tscn

const POZ := 30.0
const CADRE := 26
const BENZI := [[88.0, 177.0], [177.0, 354.0], [354.0, 707.0], [707.0, 1414.0],
	[1414.0, 2828.0], [2828.0, 5657.0], [5657.0, 11314.0]]
const NUME := ["125Hz", "250Hz", "500Hz", " 1kHz", " 2kHz", " 4kHz", " 8kHz"]

var _inst: AudioEffectSpectrumAnalyzerInstance
var _erori := 0

func _ready() -> void:
	var an := AudioEffectSpectrumAnalyzer.new()
	an.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
	AudioServer.add_bus_effect(0, an, 0)
	_inst = AudioServer.get_bus_effect_instance(0, 0) as AudioEffectSpectrumAnalyzerInstance
	await get_tree().process_frame

	# 1. magistrale
	var idx := AudioServer.get_bus_index("Music")
	_cer(idx > 0, "magistrala Music exista (index %d)" % idx)
	_cer(AudioServer.get_bus_send(idx) == "Master", "Music trimite in Master")
	_cer(AudioServer.get_bus_effect_count(idx) == 1, "Music are exact un efect (filtrul)")
	_cer(not AudioServer.is_bus_effect_enabled(idx, 0), "in afara meniurilor filtrul e OPRIT")

	Audio.play_music()
	await get_tree().create_timer(3.6).timeout
	_cer(Audio._music.bus == "Music", "muzica intra pe magistrala Music")
	_cer(Audio._players[0].bus == "Master", "efectele raman pe Master (nefiltrate)")

	# 2. cat de infundat se aude, prin API-ul real (filtru + coborarea de volum)
	var ref := await _masoara()
	Audio.enter_menu_muffle("test")
	var curba := PackedStringArray()
	for i in 16:
		curba.append("%.0f" % Audio._filtru.cutoff_hz)
		await get_tree().create_timer(0.016).timeout
	print("cutoff, cadru cu cadru (Hz): ", ", ".join(curba))
	await get_tree().create_timer(0.3).timeout
	var muf := await _masoara()
	print("\n=== cat se pierde in meniu (dB) ===")
	var linie := PackedStringArray()
	for i in BENZI.size():
		linie.append("%6.1f" % (muf[i] - ref[i]))
	print("          ", " ".join(NUME))
	print("pierdere: ", " ".join(linie))
	_cer(muf[6] - ref[6] < -30.0, "8 kHz scade cu peste 30 dB (inaltele dispar)")
	_cer(muf[3] - ref[3] < -4.0, "1 kHz scade (melodia se retrage)")
	_cer(muf[0] - ref[0] > -12.0, "125 Hz ramane (basul trece prin perete)")
	_cer(is_equal_approx(AudioServer.get_bus_volume_db(Audio._bus_muzica), -6.0), "bus la -6 dB")

	# 3. ESC peste meniu: muzica CURGE mai departe, lumea ingheata
	Audio.play("button")
	await get_tree().process_frame
	var poz1 := Audio._music.get_playback_position()
	Audio.pause_all()
	await get_tree().create_timer(0.7).timeout
	var avans := Audio._music.get_playback_position() - poz1
	_cer(avans > 0.5, "la ESC muzica merge inainte (%.2fs in 0,7s)" % avans)
	_cer(Audio._music.playing, "boxa muzicii ramane pornita la ESC")
	# ⚠ Godot NU retine stream_paused pe o boxa care nu canta ("does not have perfect recall"
	# in sursa lor) — deci se numara doar boxele care chiar aveau ce ingheta.
	var inghetate := 0
	var porniti := 0
	for p in Audio._players:
		if not p.playing and not p.stream_paused:
			continue
		porniti += 1
		if p.stream_paused:
			inghetate += 1
	_cer(porniti > 0 and inghetate == porniti, "efectele care sunau ingheata la ESC (%d/%d)" % [inghetate, porniti])
	Audio.resume_all()

	# 4. meniuri suprapuse: filtrul se deschide abia la ultimul
	Audio.enter_menu_muffle("peste")
	Audio.exit_menu_muffle("test")
	await get_tree().create_timer(0.4).timeout
	_cer(AudioServer.is_bus_effect_enabled(Audio._bus_muzica, 0), "cu un meniu inca deschis, ramane infundat")
	Audio.exit_menu_muffle("peste")
	await get_tree().create_timer(0.5).timeout
	_cer(not AudioServer.is_bus_effect_enabled(Audio._bus_muzica, 0), "la ultimul meniu inchis, filtrul se opreste")
	_cer(is_equal_approx(AudioServer.get_bus_volume_db(Audio._bus_muzica), 0.0), "bus inapoi la 0 dB")
	var inapoi := await _masoara()
	print("dupa iesire, fata de referinta: %.1f dB la 8 kHz (trebuie ~0)" % (inapoi[6] - ref[6]))
	_cer(absf(inapoi[6] - ref[6]) < 4.0, "sunetul revine exact cum era")   # +-3 dB e zgomotul masuratorii

	# 5. schimbare de scena cu meniu deschis (Quit din pauza) -> filtrul nu ramane agatat
	Audio.enter_menu_muffle("ramas_deschis")
	await get_tree().create_timer(0.25).timeout
	Audio.play_menu_music()   # ce face intoarcerea in meniul principal
	_cer(not AudioServer.is_bus_effect_enabled(Audio._bus_muzica, 0), "scena noua curata filtrul pe loc")

	print("\n=== %s ===" % ("TOATE VERIFICARILE AU TRECUT" if _erori == 0 else "%d VERIFICARI PICATE" % _erori))
	get_tree().quit()

func _cer(conditie: bool, ce: String) -> void:
	if not conditie:
		_erori += 1
	print("  %s %s" % ["OK  " if conditie else "PICAT", ce])

func _masoara() -> Array:
	Audio._music.seek(POZ)
	await get_tree().create_timer(0.30).timeout
	var sume := []
	sume.resize(BENZI.size())
	sume.fill(0.0)
	for i in CADRE:
		for b in BENZI.size():
			sume[b] += _inst.get_magnitude_for_frequency_range(
				BENZI[b][0], BENZI[b][1],
				AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE).length()
		await get_tree().process_frame
	var out := []
	for b in BENZI.size():
		out.append(linear_to_db(maxf(sume[b] / CADRE, 1e-9)))
	return out
