shader_type canvas_item;
render_mode blend_mix, unshaded;

// ATMOSFERA NETHER-ULUI — „iad". Se pune peste tot ecranul, într-un CanvasLayer propriu
// (`atmosphere.gd::_setup_dimension`), și desenează DOAR efect: scântei care urcă, fum,
// lumina cuptorului de jos și o vinietă caldă. Culoarea generală a lumii NU se face de aici,
// ci dintr-un `CanvasModulate` — vezi `atmosphere.gd`, secțiunea „atmosfera dimensiunilor".
//
// ⚠️ NU citește ecranul (`hint_screen_texture`), spre deosebire de `limbo_bw.gdshader`. De
// aia nu deformează și nu decolorează HUD-ul de dedesubt: pune doar lumină peste el.
//
// `amount` = 0 stins, 1 aprins complet. Se animă la intrare/ieșire, tot din `atmosphere.gd`.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ember_color : source_color = vec3(1.0, 0.52, 0.16);   // scânteile
uniform vec3 smoke_color : source_color = vec3(0.62, 0.09, 0.02);  // fumul + jarul de dedesubt
uniform vec3 vignette_color : source_color = vec3(0.07, 0.0, 0.0); // marginile (roșu aproape negru)
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.50;
uniform float ember_density : hint_range(0.0, 2.0) = 1.3;          // cât de multe scântei
uniform float furnace_strength : hint_range(0.0, 1.0) = 0.30;      // lumina care bate de jos

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// zgomot cu interpolare lină, pentru fum
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Un strat de scântei. Ecranul se taie într-o grilă de `cells`; în puține celule (restul se
// resping mai jos, la `if (r < 0.74)`) stă câte un punct, deplasat aleator în celula lui.
// Grila urcă în timp — deci scânteile urcă — și fiecare punct se leagănă lateral și pâlpâie.
float embers(vec2 uv, float cells, float speed, float size, float seed) {
	vec2 p = uv * cells + vec2(seed, 0.0);
	p.y += TIME * speed;          // grila curge în sus pe conținut → scânteile urcă pe ecran
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float r = hash21(id + seed);
	if (r < 0.70) {
		return 0.0;               // celulă goală — altfel ecranul ar fi o perdea de puncte
	}
	vec2 off = vec2(hash21(id + 11.3), hash21(id + 27.7)) - 0.5;
	off.x += 0.22 * sin(TIME * (0.8 + r * 1.6) + r * 30.0);   // legănat lateral
	float d = length(f - off * 0.7);
	float g = smoothstep(size, 0.0, d);
	float blink = 0.55 + 0.45 * sin(TIME * (2.0 + r * 4.0) + r * 12.0);
	return g * blink * (0.35 + 0.65 * r);
}

void fragment() {
	// celulele trebuie să fie pătrate, altfel scânteile ies ovale pe ecran lat
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV;
	vec2 auv = vec2(uv.x * aspect, uv.y);

	// pâlpâitul de cuptor: două sinusuri care nu se repetă la fel, ca să nu se simtă ritmul
	float flicker = 0.86 + 0.14 * sin(TIME * 3.7) * sin(TIME * 8.3 + 1.7);

	// fum care urcă — două octave, a doua mai iute și mai mică
	float t = TIME * 0.06;
	float smoke = noise(auv * 3.0 + vec2(t * 0.6, -t * 3.0)) * 0.65
	            + noise(auv * 7.0 + vec2(-t * 1.1, -t * 5.0)) * 0.35;
	smoke = smoothstep(0.35, 0.95, smoke);

	// jarul de dedesubt: lumina bate de jos în sus (uv.y = 1 e marginea de jos a ecranului)
	float furnace = pow(uv.y, 2.6) * furnace_strength;

	float sparks = (embers(auv, 9.0, 0.14, 0.055, 0.0)
	             + embers(auv, 17.0, 0.26, 0.035, 7.3) * 0.7) * ember_density;

	// vinietă ovală (ecranul e mai lat decât înalt, deci strângem pe x)
	float rad = length((uv - 0.5) * vec2(1.25, 1.0));
	float dark = smoothstep(0.34, 0.95, rad) * vignette_strength;

	vec3 lit = ember_color * sparks * flicker
	         + smoke_color * (smoke * 0.16 + furnace) * flicker;

	// Compunere într-o singură trecere, cu amestec normal (`blend_mix`): `a` e cât acoperim din
	// ce e dedesubt, iar culoarea se împarte la `a` ca înmulțirea de la amestecare s-o aducă
	// înapoi la valoarea vrută. Lumina tare acoperă fundalul (scânteile sunt mici și fierbinți,
	// exact ce vrem); ceața largă are `a` mic, deci abia se simte.
	float lum = max(max(lit.r, lit.g), lit.b);
	float a = clamp(dark + lum, 0.0, 1.0);
	vec3 col = (vignette_color * dark + lit) / max(a, 0.0001);
	COLOR = vec4(col, a * amount);
}
