extends CanvasLayer

# INTRAREA ÎN RUNDĂ — cinematica de moarte, rulată pe dos (cerută de Răzvan pe 2026-08-31:
# „când dai Start la joc să fie o animație ca aia de la moarte doar că pe invers").
#
# La moarte, o diafragmă se ÎNCHIDE peste tine: ultimul lucru pe care îl vezi ești tu, în mijloc,
# cu tot ce te-a omorât în jur. Aici se DESCHIDE de pe tine: primul lucru pe care îl vezi ești tot
# tu, singur, iar lumea năvălește după. Aceeași diafragmă (`iris.gd`), aceleași secunde, în ordine
# inversă.
#
# COREGRAFIA, oglindită faza cu faza. Cifrele NU sunt scrise aici: se citesc din `gameover.gd`
# (vezi `MOARTE` mai jos), deci dacă Răzvan reglează moartea, intrarea se mută singură după ea și
# cele două rămân oglinda una alteia. Asta e tot rostul: două cinematici care nu se văd niciodată
# una lângă alta (una e la început, cealaltă la sfârșit) s-ar despărți în tăcere la prima reglare.
#
#   t=0.00  tăcerea    — ecran NEGRU și nimic. La moarte e ultima bucată, aici e prima.
#                        (`T_TACERE`) Ține și de treabă, nu doar de dramă: negrul acoperă și
#                        cadrele în care lumea se așază pe player (vezi `CADRE_DE_ASEZARE`), deci
#                        hopul de la primele cadre nu se vede.
#   t=0.45  deschiderea— cercul se smucește de la zero (`T_INCHIDERE`, CUBIC/EASE_OUT — exact
#                        prăbușirea morții, întoarsă). Aici se vede numai capul player-ului.
#   t=0.54  respirația — se lărgește încet în jurul tău (`T_STRANGERE`, SINE). Vezi unde ai căzut,
#                        dar încă nu poți face nimic.
#   t=1.04  năvala     — lumea intră toată deodată (`T_INGHITIRE`, CUBIC/EASE_IN: pornește lin,
#                        accelerează) — oglinda înghițirii, care pornea tare și frâna.
#   t=1.84  ultima clipă— ecranul e întreg, dar lumea încă stă (`T_LOVITURA`). O bătaie de inimă
#                        între „văd tot" și „pot să mă mișc".
#   t=2.00  gata       — lumea pornește.
#
# Culoarea se întoarce în imagine pe măsură ce cercul se deschide, iar inelul de pe margine arde
# CYAN, nu roșu — același cyan ca bara de încărcare (`loading.gd`). Nu sunt animate separat: se
# calculează DIN rază, în `iris.gd`, deci n-au cum să iasă din sincron.
#
# ⚠️ Muzica face același drum: pornește ÎNFUNDATĂ (ușa închisă) și se deschide exact pe durata
# cercului — `Audio.intro_inchide()` / `intro_deschide()`, oglinda lui `death_muffle`. Jingle-ul
# de început (`game_start`) și muzica sunt pornite deja de `spawner.gd`; noi doar ținem ușa.
#
# ⚠️ Cinematica asta rulează la ORICE intrare în rundă: START din meniu, dar și PLAY AGAIN de pe
# ecranul de Game Over (`reload_current_scene`). E o proprietate a rundei, nu a butonului.

const IRIS := preload("res://iris.gd")
const MOARTE := preload("res://gameover.gd")   # de aici vin TOȚI timpii și TOATE razele

# Inelul de pe marginea cercului. Moartea îl arde roșu, ca „YOU DIED"; intrarea îl arde în cyanul
# barei de încărcare (`loading.gd::CYAN`), adică exact culoarea ecranului de dinaintea rundei.
const CULOARE_INEL := Color(0.20, 0.90, 1.00)

# Câte cadre lasă cinematica lumea să meargă înainte s-o înghețe. Rostul lor (și de ce fără ele
# runda începe cu două secunde de gri gol) e scris pe larg deasupra lui `_cinematica`.
const CADRE_DE_ASEZARE := 2

var _iris: ColorRect
var _pornit := false   # ca un `_ready` chemat de două ori să nu pornească două cinematici

func _ready() -> void:
	add_to_group("intro_screen")   # ca `pause.gd` să nu deschidă meniul peste noi
	process_mode = Node.PROCESS_MODE_ALWAYS   # lumea e pe pauză; noi trebuie să mergem
	layer = 19   # peste tot (inclusiv HUD), dar SUB ecranul de Game Over, care e 20

	_iris = IRIS.new()
	_iris.culoare_inel = CULOARE_INEL
	add_child(_iris)
	_porneste()

func _porneste() -> void:
	if _pornit:
		return
	# ⚠️ Negru din PRIMUL cadru, înainte de orice altceva: dacă am aștepta măcar un cadru ca să
	# aflăm unde e player-ul, s-ar vedea o clipire cu lumea întreagă exact înainte s-o acoperim.
	# Cât e raza 0, centrul nu contează — ecranul e negru oricum —, deci așezarea cercului se poate
	# face liniștit la pasul următor.
	#
	# Tot de-aici se ține și că lumea mai merge câteva cadre înainte să fie oprită (vezi
	# `_cinematica`): ele se petrec sub negrul ăsta, deci nimeni nu le vede.
	_iris.seteaza_raza(0.0)
	visible = true
	_cinematica.call_deferred()

# Partea întâi: tăcerea pe negru. Atât — plus singura treabă adevărată a cinematicii.
#
# 🔑 DE CE NU ÎNGHEȚĂM LUMEA DIN PRIMA (prins pe 2026-09-02, raportat ca „se vede o secundă
# gri"): jumătate din lume se AȘAZĂ în `_process`, nu în `_ready`. Podeaua (`ground.gd`) e o
# pânză care se mută pe player abia la primul cadru; copacii, pietrele, tufele, potecile,
# lăzile, monumentele — toate își construiesc pătratele din jurul player-ului tot atunci
# (`props.gd`, `rocks.gd`, `bushes.gd`, `pathways.gd`, ...); până și HUD-ul își scrie cifrele
# în `_process`. Iar player-ul tocmai a fost aruncat la zeci de mii de pixeli de origine
# (`spawner.gd::_muta_player_aleator`), deci NIMIC din toate astea nu e încă acolo unde se uită
# camera.
#
# Puneam pauza în `_ready`, adică înainte de primul cadru: pătratele nu se mai construiau
# niciodată cât ținea cinematica. Diafragma se deschidea corect, pe player, dar în jurul lui nu
# era iarbă, ci fundalul gol al ferestrei — două secunde de gri mort, cu omul plutind în el, iar
# la `_gata()` năvălea pădurea toată deodată. Exact aceeași rădăcină ca bug-ul camerei de mai
# devreme (vezi `spawner.gd`): tot ce se pune la punct ÎN `_process` rămâne pe loc dacă pauza
# vine înaintea primului cadru.
#
# Deci lăsăm lumea să meargă `CADRE_DE_ASEZARE` cadre și abia apoi o oprim. Nu se vede nimic din
# ele — ecranul e negru din `_ready` —, iar în timpul lor lumea nu apucă să facă nimic: la 60 fps
# sunt vreo 33 ms, adică sub o zecime din tăcerea de 0,45 s care urmează. E cel mai ieftin preț:
# alternativa era ca cinematica să cunoască pe nume paisprezece noduri și să le ceară ea, unul
# câte unul, să-și construiască pătratele — iar al cincisprezecelea, adăugat peste o lună, ar fi
# lipsit din nou din poză, în tăcere.
#
# ⚠️ De ce DOUĂ cadre și nu unul: în primul, generatoarele își fac nodurile (`add_child`); al
# doilea le prinde așezate și lasă și restul (HUD, atmosferă) să-și ia poziția. Unul singur mergea
# și el în probe, dar n-are cine să ne apere dacă un generator ajunge vreodată să aibă nevoie de
# două treceri — iar cadrele astea nu costă nimic.
#
# ⚠️ Amânată cu `call_deferred` fiindcă abia atunci s-au trezit TOATE nodurile scenei — inclusiv
# spawner-ul, al cărui `_ready` cheamă `Audio.play_music()`, iar ăla deschide filtrul instant
# (`_uita_meniurile`). Dacă am fi închis ușa muzicii direct în `_ready`-ul nostru, ar fi contat
# unde stă nodul `Intro` în arbore, iar mutarea lui mai sus ar fi stricat sunetul în tăcere.
func _cinematica() -> void:
	Audio.intro_inchide()
	_iris.seteaza_raza(0.0)
	for i in CADRE_DE_ASEZARE:
		await get_tree().process_frame
	get_tree().paused = true
	var tw := create_tween()
	tw.tween_interval(MOARTE.T_TACERE)
	tw.tween_callback(_deschide)

# Partea a doua: cercul. Un SINGUR lanț de tween-uri, ca la moarte — așa fazele nu pot aluneca
# una față de alta, oricât ar încetini jocul.
#
# 🔑 De ce cercul se AȘAZĂ abia aici, și nu odată cu restul: în primele cadre ale scenei camera
# nu și-a luat încă locul, deci `get_global_transform_with_canvas()` întoarce o poziție care nu
# înseamnă nimic. Așezat atunci, cercul se deschidea din COLȚUL ecranului, nu de pe tine — prins
# de `tool_intro.gd`, care a văzut o rază de pornire de 2.57 în loc de 1.04 (adică un centru
# împins tocmai în afara ecranului). Aici, după cele 0,45 s de negru, camera e de mult la locul
# ei. Și nu se pierde nimic amânând: cât raza e 0, ecranul e negru, deci unde e centrul nu se
# vede oricum.
func _deschide() -> void:
	_iris.aseaza_pe_player()
	_iris.seteaza_raza(0.0)
	# Ușa muzicii se deschide odată cu cercul, pe exact atâtea secunde cât face el drumul — la fel
	# cum la moarte se închidea pe exact cât făcea drumul invers (`T_CERC`).
	Audio.intro_deschide(MOARTE.T_CERC)

	var tw := create_tween()
	tw.tween_method(_iris.seteaza_raza, 0.0, MOARTE.RAZA_STRANSA, MOARTE.T_INCHIDERE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_iris.seteaza_raza, MOARTE.RAZA_STRANSA, MOARTE.RAZA_MICA, MOARTE.T_STRANGERE) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_method(_iris.seteaza_raza, MOARTE.RAZA_MICA, _iris.raza_start, MOARTE.T_INGHITIRE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_interval(MOARTE.T_LOVITURA)
	tw.tween_callback(_gata)

func _gata() -> void:
	get_tree().paused = false
	visible = false   # nodul rămâne, dar nu mai desenează nimic până la runda următoare
