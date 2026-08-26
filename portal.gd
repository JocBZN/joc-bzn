extends StaticBody2D

# Portal fix în lume — sora mai rară a statuii (vezi `statue.gd` și `portals.gd`).
#
# Când player-ul se apropie apare deasupra lui textul „Press E to interact", exact ca la
# statuie (îl afișează `interact_ui.gd`). Apăsând E te duce în NETHER — a doua dimensiune
# (vezi `nether.gd`).
#
# ACELAȘI script joacă ambele roluri, după steagul `retur`:
#   • `retur = false` (portalurile din lume, puse de `portals.gd`) → INTRI în Nether;
#   • `retur = true`  (portalul pe care îl pune `nether.gd` unde ai aterizat) → IEȘI.
#
# Poziția nodului Portal = BAZA portalului (talpa) → și linia de la care te
# acoperă (Y-sort), la fel ca la statuie.
#
# ---------------------------------------------------------------------------
# HITBOX-UL SE REGLEAZĂ CU MÂNA, ÎN EDITOR — exact ca la statuia Gărzii.
# ---------------------------------------------------------------------------
# Scriptul NU-l atinge niciodată la rulare. Ce vezi în `portal.tscn` = ce iese în joc.
#
#   1. deschide `portal.tscn` (dublu-click în FileSystem, stânga-jos);
#   2. click pe nodul `CollisionShape2D`;
#   3. trage de pătrățelele portocalii din fereastra de editare, sau scrie cifrele în
#      Inspector la `Shape → Size` (lățime × înălțime) și `Transform → Position`;
#   4. Ctrl+S.
#
# Ca să vezi hitbox-urile ÎN TIMP CE JOCI: în Godot, meniul **Debug → Visible Collision
# Shapes**, apoi rulezi. Le arată pe toate, nu doar pe ale portalului.
#
# ⚠️ Dacă muți `Sprite2D` pe verticală, mută `CollisionShape2D` cu ACEEAȘI valoare, altfel
# hitbox-ul rămâne în urmă și te lovești de aer.
#
# Iar `Sprite2D.offset.y = -25.17` e calculat ca baza artei să cadă 74px SUB originea
# nodului. Cifra 74 nu e la întâmplare: sprite-ul player-ului e CENTRAT pe punctul lui de
# sortare, deci se întinde ~64px sub el. Dacă arta urcă prea sus, când player-ul trece prin
# spate îi rămân picioarele afară, sub portal. Copacii și statuia folosesc tot 74. Deci:
# poți să cobori arta, dar nu s-o urci sub ~64.

# ---------------------------------------------------------------------------
# VÂLTOAREA MOV DIN GURA ARCADEI
# ---------------------------------------------------------------------------
# Nodul `Vartej` (pus ÎNAINTEA lui `Sprite2D` în scenă, deci se desenează SUB piatră) e cel
# care ține pânza aia care fierbe, ca la portalul de Nether din Minecraft — doar că a noastră
# arde tot timpul, portalul nostru nu se aprinde cu nimic. Nu iese niciun pixel pe lângă
# arcadă: `portal_nether.gdshader` taie totul cu o mască pe forma exactă a golului.
#
# Cifrele de reglat (viteză, culori, cât de mărunte-s ochiurile) stau în Inspector, pe
# `Vartej → Material → Shader Parameters`, și se văd pe loc în editor. Explicațiile lor —
# în capul shaderului. Dacă schimbi arta portalului sau adaugi cadre, rulează din nou
# `tool_portal_nether.tscn` (vezi comentariul de acolo).
#
# ⚠️ `Vartej` trebuie să rămână cu ACELAȘI `offset` și aceeași `scale` ca `Sprite2D` — dacă
# unul se mișcă și celălalt nu, masca nu mai cade peste gaură și vâltoarea iese pe piatră.

@export var interact_range: float = 200.0   # cât de aproape trebuie să fii ca să apară textul
@export var retur: bool = false             # true doar pe portalul de întoarcere din Nether

# --- Închiderea definitivă (după ce l-ai bătut pe Saratalin) ---
@export var sink_duration: float = 1.0   # cât durează scufundarea
@export var sink_depth: float = 90.0     # cât de adânc coboară (se stinge oricum în paralel)

func _ready() -> void:
	# „interactable" = tot ce poate afișa textul „Press E to interact" (vezi `interact_ui.gd`).
	# Statuia e în același grup.
	add_to_group("interactable")

# Mai poate fi folosit? `interact_ui.gd` întreabă asta înainte să arate textul.
# Portalul nu se consumă — intri și ieși de câte ori vrei.
func poate_invoca() -> bool:
	return true

# Apăsarea tastei de interacțiune ajunge aici: te duce în Nether sau te aduce înapoi.
func invoca() -> void:
	var nether := get_tree().get_first_node_in_group("nether")
	if nether == null:
		return
	if retur:
		nether.exit_nether()
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		# îi dăm și locul nostru: portalul de întoarcere din Nether se pune exact aici
		nether.enter(player, global_position)

# Portalul intră în pământ și dispare, ca statuia după invocare. Chemat din `nether.gd`
# când te întorci învingător: din clipa aia nu mai există portaluri în runda asta.
func intra_in_pamant() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)   # nu mai e zid cât coboară
	remove_from_group("interactable")        # și nu mai poți apăsa E pe el
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		queue_free()
		return
	var t := sprite.create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "position:y", sprite.position.y + sink_depth, sink_duration)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	# Vâltoarea coboară odată cu piatra și se stinge la fel. ⚠️ Stinsul ei merge pe
	# `shader_parameter/fade`, NU pe `modulate:a`: `portal_nether.gdshader` își scrie singur
	# `COLOR`, deci `modulate` n-are niciun efect pe el — ar fi coborât mov-aprins până
	# la `queue_free` și ar fi pierit dintr-o bucată (aceeași capcană ca la fântâna Ender).
	var vartej := get_node_or_null("Vartej") as Sprite2D
	if vartej != null:
		t.parallel().tween_property(vartej, "position:y", vartej.position.y + sink_depth, sink_duration)
		var mat := vartej.material as ShaderMaterial
		if mat != null:
			t.parallel().tween_property(mat, "shader_parameter/fade", 0.0, sink_duration)
		else:
			t.parallel().tween_property(vartej, "modulate:a", 0.0, sink_duration)
	t.tween_callback(queue_free)
