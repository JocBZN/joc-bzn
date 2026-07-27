extends Node2D

# Efectul de la deschiderea unui cufăr (vezi `chest.gd`). Instanțiat din cod, se joacă singur
# și se șterge la final — ca `firetrail.gd`, n-are scenă în editor.
#
#   1) o EXPLOZIE de raze deasupra cufărului, cu culoarea SCHIMBATĂ la fiecare cadru;
#   2) apoi iconița upgrade-ului primit, care stă `PAUZA` secunde și se stinge urcând.
#
# 🔑 De ce nod separat, agățat de LUME, și nu `await`-uri în `chest.gd`:
# cufărul stă într-un container de chunk care se ȘTERGE când te îndepărtezi. Dacă efectul ar
# fi copilul lui, ar dispărea la jumătate de animație și `await`-urile ar rămâne agățate de un
# nod mort. Așa trăiește singur, indiferent ce se întâmplă cu cufărul.
#
# 🔑 Cadrele NU sunt fișiere separate. `harta/Chest/Chest Animation 2/652.png` e o foaie de
# 1024×576 = 16 coloane (cadrele animației) × 9 rânduri (aceeași animație, în 9 culori).
# Le decupăm cu `AtlasTexture` — 144 de PNG-uri tăiate ar fi fost aceeași imagine de 144 de ori.

const FOAIE := "res://harta/Chest/Chest Animation 2/652.png"
const CADRU := 64    # latura unei celule din foaie (px)
const CADRE := 16    # câte cadre are animația = coloanele foii
const CULORI := 9    # câte variante de culoare = rândurile foii

const BURST_FPS := 6.67     # 16 cadre ≈ 2.4s (de 3× mai încet decât primele 20 fps)
const BURST_SCALE := 1.0    # 64px pe ecran (de 2× mai mică decât primul 2.0)
const ICON_SCALE := 0.72    # iconițele sunt 128×128 → ~92px
const PAUZA := 1.0          # cât stă iconița NEATINSĂ înainte să înceapă stingerea
                            # (pe ecran o vezi PAUZA + FADE, adică 1.6s în total)
const FADE := 0.6           # cât durează stingerea
const URCARE := 30.0        # cât urcă iconița cât se stinge

var _cale_icon := ""

# Pornește tot lanțul. `la_pozitie` = unde, în lume (deja deasupra cufărului);
# `cale_icon` = iconița upgrade-ului primit ("" dacă n-a picat niciunul).
func porneste(la_pozitie: Vector2, cale_icon: String) -> void:
	global_position = la_pozitie
	_cale_icon = cale_icon
	z_index = 100
	z_as_relative = false   # z absolut → mereu peste copaci și peste cufăr, oriunde ar cădea
	_explozie()

# Animația de raze. Fiecare cadru își trage ALTĂ culoare, deci explozia pâlpâie și nu arată
# niciodată la fel de două ori — asta a cerut Răzvan.
func _explozie() -> void:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _cadre_amestecate()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(BURST_SCALE, BURST_SCALE)
	add_child(s)
	s.animation_finished.connect(_dupa_explozie.bind(s))
	s.play("boom")

func _cadre_amestecate() -> SpriteFrames:
	var foaie := load(FOAIE) as Texture2D
	var f := SpriteFrames.new()
	f.add_animation("boom")   # un SpriteFrames nou vine doar cu „default"; fără asta, tot ce urmează dă eroare
	f.set_animation_speed("boom", BURST_FPS)
	f.set_animation_loop("boom", false)   # o singură dată, apoi vine iconița
	var precedenta := -1
	for i in CADRE:
		# aceeași culoare de două ori la rând nu s-ar vedea ca pâlpâire, ci ca o sacadare
		var culoare := randi() % CULORI
		while culoare == precedenta:
			culoare = randi() % CULORI
		precedenta = culoare
		var at := AtlasTexture.new()
		at.atlas = foaie
		at.region = Rect2(i * CADRU, culoare * CADRU, CADRU, CADRU)   # coloana = cadrul, rândul = culoarea
		f.add_frame("boom", at)
	return f

func _dupa_explozie(s: AnimatedSprite2D) -> void:
	s.queue_free()
	_iconita()

# Iconița upgrade-ului: apare, stă `PAUZA` secunde, apoi se stinge urcând.
func _iconita() -> void:
	if _cale_icon == "" or not ResourceLoader.exists(_cale_icon):
		queue_free()   # n-a picat niciun upgrade (sau lipsește iconița) → gata efectul
		return
	var ic := Sprite2D.new()
	ic.texture = load(_cale_icon)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.scale = Vector2(ICON_SCALE, ICON_SCALE)
	add_child(ic)
	var tw := create_tween()
	tw.tween_interval(PAUZA)
	tw.tween_property(ic, "modulate:a", 0.0, FADE)
	tw.parallel().tween_property(ic, "position:y", ic.position.y - URCARE, FADE)
	tw.tween_callback(queue_free)
