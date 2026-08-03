shader_type canvas_item;
render_mode blend_mix, unshaded;

// ATMOSFERA ENDER-ULUI — „cosmic". Fratele lui `nether_hell.gdshader`, construit la fel
// (același truc de compunere la final, aceleași reguli: nu citește ecranul, deci nu strică
// HUD-ul de dedesubt), dar cu alt conținut: stele care clipesc, o nebuloasă care se rotește
// încet, o panglică de auroră și o vinietă indigo, ca o gaură de întuneric în jurul tău.
//
// Culoarea generală a lumii vine din `CanvasModulate` (vezi `atmosphere.gd`), nu de aici.
// `amount` = 0 stins, 1 aprins complet.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 star_color : source_color = vec3(0.85, 0.94, 1.0);
uniform vec3 nebula_a : source_color = vec3(0.42, 0.16, 0.75);    // violet
uniform vec3 nebula_b : source_color = vec3(0.05, 0.55, 0.72);    // turcoaz
uniform vec3 vignette_color : source_color = vec3(0.01, 0.0, 0.05);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.58;
uniform float star_density : hint_range(0.0, 2.0) = 1.0;
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.30;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

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

// Un strat de stele. Aceeași grilă ca la scânteile Nether-ului, dar punctele stau pe loc
// (doar întregul câmp plutește foarte încet) și clipesc fiecare în ritmul lui.
// `drift` = încotro plutește stratul; straturile cu stele mici merg mai repede → parallax.
float stars(vec2 uv, float cells, vec2 drift, float size, float seed) {
	vec2 p = uv * cells + drift * TIME + vec2(seed, seed * 0.7);
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float r = hash21(id + seed);
	if (r < 0.80) {
		return 0.0;
	}
	vec2 off = (vec2(hash21(id + 5.1), hash21(id + 19.4)) - 0.5) * 0.7;
	float d = length(f - off);
	float g = smoothstep(size, 0.0, d);
	// clipit: nu se stinge complet niciodată (0.45 minim), ca să nu pară că se aprind becuri
	float twinkle = 0.45 + 0.55 * sin(TIME * (0.7 + r * 2.2) + r * 40.0);
	return g * twinkle * (0.3 + 0.7 * r);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV;
	vec2 auv = vec2(uv.x * aspect, uv.y);

	// Nebuloasa se rotește în jurul centrului ecranului, foarte încet (~un tur în 10 minute).
	// De aia se simte „spațiu", nu „filtru pus peste joc".
	float ang = TIME * 0.01;
	vec2 c = auv - vec2(aspect * 0.5, 0.5);
	vec2 rot = vec2(c.x * cos(ang) - c.y * sin(ang), c.x * sin(ang) + c.y * cos(ang));

	float t = TIME * 0.03;
	float n1 = noise(rot * 2.6 + vec2(t, -t * 0.6));
	float n2 = noise(rot * 5.3 - vec2(t * 1.4, t * 0.9));
	float neb = smoothstep(0.30, 0.92, n1 * 0.7 + n2 * 0.3);
	// a doua hartă de zgomot alege CULOAREA norului, ca să nu iasă totul de-o violetă
	vec3 neb_col = mix(nebula_a, nebula_b, smoothstep(0.35, 0.75, noise(rot * 1.7 + vec2(t * 0.5, 0.0))));

	// Panglică de auroră: o bandă care șerpuiește pe lățimea ecranului și respiră.
	float band = sin(auv.x * 3.1 + TIME * 0.23) * 0.10 + 0.42;
	float aurora = smoothstep(0.16, 0.0, abs(uv.y - band)) * (0.55 + 0.45 * sin(TIME * 0.6));

	float twinkling = (stars(auv, 11.0, vec2(0.004, -0.002), 0.030, 0.0)
	                + stars(auv, 21.0, vec2(0.010, -0.006), 0.020, 13.7) * 0.75) * star_density;

	float rad = length((uv - 0.5) * vec2(1.25, 1.0));
	float dark = smoothstep(0.30, 0.98, rad) * vignette_strength;

	vec3 lit = star_color * twinkling
	         + neb_col * neb * nebula_strength
	         + nebula_b * aurora * 0.07;

	// vezi `nether_hell.gdshader` pentru explicația compunerii
	float lum = max(max(lit.r, lit.g), lit.b);
	float a = clamp(dark + lum, 0.0, 1.0);
	vec3 col = (vignette_color * dark + lit) / max(a, 0.0001);
	COLOR = vec4(col, a * amount);
}
