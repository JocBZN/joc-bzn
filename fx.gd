extends Node

# "Atelierul de efecte" global. Autoload "Fx". Îl chemi de oriunde:
#   Fx.muzzle(pozitie)             -> fulger la gura armei
#   Fx.impact(pozitie, culoare)    -> scântei + flash la lovitură
#   Fx.damage_number(poz, 25, true)-> număr de damage care sare (crit = mare & galben)
#
# Tot ce apare e adăugat în scena curentă (lumea jocului), în coordonate de LUME,
# și se auto-distruge după animație. Nu trebuie să atingi nimic în editor.

var _glow_tex: GradientTexture2D    # un cerc moale alb→transparent, refolosit pentru glow
var _add_mat: CanvasItemMaterial    # material "additive" = luminile se adună → efect de strălucire

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# construim o textură radială (cerc moale) o singură dată
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = grad
	_glow_tex.width = 64
	_glow_tex.height = 64
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	# material additiv pentru glow
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

# unde adăugăm efectele: scena curentă (lumea). Dacă nu există, ieșim în siguranță.
func _world() -> Node:
	return get_tree().current_scene

# --- fulger de glow care se umflă și se stinge (pentru muzzle/impact) ---
func _flash(pos: Vector2, color: Color, size: float, dur: float) -> void:
	var w := _world()
	if w == null:
		return
	var s := Sprite2D.new()
	s.texture = _glow_tex
	s.material = _add_mat
	s.modulate = color
	s.z_index = 60
	w.add_child(s)
	s.global_position = pos
	s.scale = Vector2.ONE * size * 0.25
	var t := s.create_tween()
	t.tween_property(s, "scale", Vector2.ONE * size, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "modulate:a", 0.0, dur)
	t.tween_callback(s.queue_free)

# fulger cald la gura armei când tragi
func muzzle(pos: Vector2) -> void:
	_flash(pos, Color(1.0, 0.9, 0.5), 0.9, 0.10)

# flash + scântei la lovitură
func impact(pos: Vector2, color: Color = Color(0.6, 1.0, 1.0)) -> void:
	_flash(pos, color, 0.7, 0.14)
	var w := _world()
	if w == null:
		return
	var p := CPUParticles2D.new()
	p.z_index = 60
	w.add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0        # toate scânteile pornesc odată
	p.amount = 10
	p.lifetime = 0.35
	p.spread = 180.0             # în toate direcțiile
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = color
	p.emitting = true
	# îl ștergem după ce s-a stins
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

# --- număr de damage care sare în sus și se stinge ---
func damage_number(pos: Vector2, amount: int, crit: bool = false) -> void:
	var w := _world()
	if w == null:
		return
	var holder := Node2D.new()
	holder.z_index = 100
	w.add_child(holder)
	holder.global_position = pos + Vector2(randf_range(-8, 8), -20)

	var lbl := Label.new()
	lbl.text = str(amount)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-40, -20)
	lbl.custom_minimum_size = Vector2(80, 0)
	var marime := 30 if crit else 20
	lbl.add_theme_font_size_override("font_size", marime)
	# crit = galben mare; normal = alb
	var culoare := Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1)
	lbl.add_theme_color_override("font_color", culoare)
	# contur negru ca să se citească pe orice fundal
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 5)
	holder.add_child(lbl)

	# sare în sus + se stinge, apoi dispare
	var t := holder.create_tween()
	t.tween_property(holder, "position:y", holder.position.y - 45, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	t.tween_callback(holder.queue_free)
