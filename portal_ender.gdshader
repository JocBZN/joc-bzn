shader_type canvas_item;

// Rotește LICHIDUL din gura fântânii (portalul Ender), fără să atingă piatra din jur.
//
// Cum funcționează: gura fântânii e o ELIPSĂ (o rotunjime văzută din unghi). Aducem
// pixelul în „spațiul cercului" (împărțim la raze), îl rotim acolo, apoi îl întindem
// înapoi în elipsă. Așa lichidul se învârte pe loc, iar conturul elipsei stă pe loc —
// dacă am fi rotit direct sprite-ul, s-ar fi rotit și forma, ca o roată de mașină.
//
// Cifrele implicite sunt măsurate pe „harta/Portal Ender/portal ender.png" (128×128):
// lichidul ocupă x 38..89, y 52..79 → centru (63.5, 65.5), raze (25.6, 13.4) în pixeli.
// Dacă se schimbă desenul, se re-reglează din Inspector (se văd pe loc, în editor).

// Centrul lichidului, în UV (0..1 pe lățimea/înălțimea texturii).
uniform vec2 liquid_center = vec2(0.496, 0.512);
// Razele elipsei (orizontală, verticală), tot în UV.
uniform vec2 liquid_radius = vec2(0.2, 0.105);

// Cât de repede se învârte, în rotații pe secundă. 0.05 = o tură la 20 de secunde.
uniform float spin_speed = 0.05;

// Legănarea: brațele spiralei se strâng și se lasă puțin, ca să nu pară o poză rotită
// mecanic. `wobble` = cât de mult (în rotații), `wobble_speed` = cât de des.
uniform float wobble : hint_range(0.0, 0.1) = 0.012;
uniform float wobble_speed = 0.9;

// De la ce rază (0 = centru, 1 = marginea elipsei) începe să se estompeze rotația.
// Banda dinspre margine rămâne pe loc, ca să nu apară o cusătură la buza de piatră.
uniform float edge_fade : hint_range(0.5, 1.0) = 0.88;

void fragment() {
	vec4 c = texture(TEXTURE, UV);

	vec2 p = (UV - liquid_center) / liquid_radius;   // în spațiul cercului
	float r = length(p);
	if (r < 1.0) {
		float a = (TIME * spin_speed + wobble * sin(r * TAU - TIME * wobble_speed)) * TAU;
		float sa = sin(a);
		float ca = cos(a);
		vec2 rot = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
		vec4 liquid = texture(TEXTURE, liquid_center + rot * liquid_radius);
		float mask = 1.0 - smoothstep(edge_fade, 1.0, r);
		c = mix(c, liquid, mask * liquid.a);
	}

	COLOR = c;
}
