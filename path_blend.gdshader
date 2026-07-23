shader_type canvas_item;

// Estompează spre iarbă DOAR laturile expuse ale unui tile de potecă (cele fără vecin-potecă).
// `fade` = ce laturi se estompează: x=stânga, y=sus, z=dreapta, w=jos (1 = estompează).
// E un uniform NORMAL (nu instance, nu self_modulate): pathways.gd ține câte un material partajat
// pentru fiecare combinație de laturi (~9 în total). De ce nu self_modulate: Godot nu livrează
// corect canalele G/B ale culorii vertexului la shaderul 2D → doar sud/vest se estompau.
// La colț (două laturi) `min` dă o estompare ROTUNJITĂ frumos — fără tile de colț.
uniform vec4 fade = vec4(0.0);
uniform float fade_w : hint_range(0.05, 0.5) = 0.4;  // cât de lat e fade-ul, ca fracție din tile

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 1.0;
	if (fade.x > 0.5) { a = min(a, smoothstep(0.0, fade_w, UV.x)); }
	if (fade.y > 0.5) { a = min(a, smoothstep(0.0, fade_w, UV.y)); }
	if (fade.z > 0.5) { a = min(a, smoothstep(0.0, fade_w, 1.0 - UV.x)); }
	if (fade.w > 0.5) { a = min(a, smoothstep(0.0, fade_w, 1.0 - UV.y)); }
	// Pixelii negri de pe margine sunt scoși din textură la încărcare (pathways.gd `_clean_texture`).
	c.a *= a;
	COLOR = c;
}
