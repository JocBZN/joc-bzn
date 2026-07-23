shader_type canvas_item;

// Estompează spre iarbă DOAR laturile expuse ale unui tile de potecă (cele fără vecin-potecă).
// Care laturi se estompează vine prin `self_modulate` (culoarea vertexului) — NU prin instance
// uniforms, ca să nu lovim limita „Too many instances using shader instance variables" când sunt
// multe tile-uri pe ecran. Codificare: R=stânga, G=sus, B=dreapta, A=jos (1 = estompează).
// La colț (două laturi active) `min` dă o estompare ROTUNJITĂ frumos — fără tile de colț.
uniform float fade_w : hint_range(0.05, 0.5) = 0.4;  // cât de lat e fade-ul, ca fracție din tile

void fragment() {
	vec4 mask = COLOR;  // COLOR de intrare = self_modulate (măștile de latură)
	vec4 c = texture(TEXTURE, UV);
	float a = 1.0;
	if (mask.r > 0.5) { a = min(a, smoothstep(0.0, fade_w, UV.x)); }
	if (mask.g > 0.5) { a = min(a, smoothstep(0.0, fade_w, UV.y)); }
	if (mask.b > 0.5) { a = min(a, smoothstep(0.0, fade_w, 1.0 - UV.x)); }
	if (mask.a > 0.5) { a = min(a, smoothstep(0.0, fade_w, 1.0 - UV.y)); }
	// Pixelii negri de pe margine sunt scoși din textură la încărcare (pathways.gd `_clean_texture`),
	// deci aici doar estompăm curat.
	c.a *= a;
	COLOR = c;
}
