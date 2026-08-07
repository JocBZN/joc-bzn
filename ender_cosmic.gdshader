shader_type canvas_item;
render_mode blend_mix, unshaded;

// ATMOSFERA ENDER-ULUI — „cosmic". Fratele lui `nether_hell.gdshader`, construit la fel
// (același truc de compunere la final, aceleași reguli: nu citește ecranul, deci nu strică
// HUD-ul de dedesubt), dar cu alt conținut: un cer adânc, cu stele pe trei straturi de
// adâncime, o nebuloasă cu filamente, o auroră care curge și, rar, o stea căzătoare.
//
// Culoarea generală a lumii vine din `CanvasModulate` (vezi `atmosphere.gd`), nu de aici.
// `amount` = 0 stins, 1 aprins complet.
//
// ⚠️ DE CE E REFĂCUT (2026-08-07): versiunea veche desena MUCHII DREPTE peste tot ecranul —
// linii lungi, albăstrui, care se roteau încet. Vinovat era hash-ul:
//
//     float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32);
//                            return fract(p.x * p.y); }
//
// Zgomotul cu interpolare e continuu DOAR dacă cele două celule vecine citesc EXACT aceeași
// valoare în colțul comun. Hash-ul ăsta trece prin `fract()` de două ori, iar la final
// înmulțește două numere de ordinul lui ~90 (produs ~8600): acolo un `float` are pași de
// ~0.001, iar colțul comun ieșea cu valori ușor diferite din cele două celule → treaptă în
// valoare → o linie DREAPTĂ fix pe granița celulei. Verificat pe 2026-08-07: același zgomot
// cu hash pe biți întregi (mai jos) e complet curat, fără nicio linie.
// MORALA: pentru zgomot pe ecran mare, hash pe ÎNTREGI, nu `fract()` peste `fract()`.
// (`nether_hell.gdshader` are încă hash-ul vechi — fumul lui suferă de aceeași boală.)

uniform float amount : hint_range(0.0, 1.0) = 0.0;

// Poziția lumii pe ecran, în pixeli (o scrie `atmosphere.gd` în fiecare cadru). Cerul se mișcă
// cu ea, mult mai încet decât lumea → PARALAXĂ. Fără asta, cerul stă lipit de ecran și se simte
// „filtru pus peste joc"; cu ea, se simte că ești ÎNTR-un loc.
uniform vec2 world_offset = vec2(0.0);
uniform float parallax : hint_range(0.0, 3.0) = 1.0;   // 0 = cer lipit de ecran (ca înainte)

uniform vec3 star_cool : source_color = vec3(0.82, 0.90, 1.0);    // majoritatea stelelor
uniform vec3 star_warm : source_color = vec3(1.0, 0.83, 0.62);    // câteva chihlimbarii, pentru contrast
uniform vec3 nebula_a : source_color = vec3(0.42, 0.16, 0.75);    // violet
uniform vec3 nebula_b : source_color = vec3(0.05, 0.55, 0.72);    // turcoaz
uniform vec3 nebula_c : source_color = vec3(0.78, 0.24, 0.55);    // roz, doar în miezurile groase
uniform vec3 vignette_color : source_color = vec3(0.01, 0.0, 0.05);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float star_density : hint_range(0.0, 2.0) = 1.0;
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.30;
uniform float aurora_strength : hint_range(0.0, 1.0) = 0.10;
uniform float meteor_period = 19.0;   // la câte secunde trece o stea căzătoare (0 = niciodată)

// ---------------------------------------------------------------- zgomot

// Hash pe biți întregi — ACELAȘI ca `hashu()` din `biome.gdshader`. Nu trece prin `float`
// intermediar, deci colțul comun a două celule iese bit-identic din amândouă → zero muchii.
uint uhash(ivec2 c) {
	uint h = uint(c.x) * 374761393u + uint(c.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return h ^ (h >> 16u);
}

float hash21(vec2 c) {
	return float(uhash(ivec2(c)) >> 8u) * (1.0 / 16777216.0);
}

// Două valori necorelate dintr-un singur hash (offset/culoare/fază de stea).
vec2 hash22(vec2 c) {
	uint h = uhash(ivec2(c));
	return vec2(float(h & 0xFFFFu), float((h >> 16u) & 0xFFFFu)) * (1.0 / 65535.0);
}

// Zgomot cu interpolare QUINTICĂ (aceeași „smootherstep" ca în `biome.gdshader`). Cubica
// obișnuită lasă o cută vizibilă pe granița celulei când contrastul e împins cu `smoothstep`;
// quintica are și derivata a doua zero acolo, deci granița dispare de tot.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Între octave rotim ȘI sărim cu un pas ne-întreg (2.03, nu 2.0). Amândouă rup alinierea pe
// axe: altfel octavele își pun granițele una peste alta și reapare grila, doar mai fină.
const mat2 OCT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

float fbm2(vec2 p) {
	float s = vnoise(p) * 0.5;
	p = OCT * p * 2.03;
	s += vnoise(p) * 0.25;
	return s * (1.0 / 0.75);   // adus înapoi în 0..1
}

float fbm3(vec2 p) {
	float s = vnoise(p) * 0.5;
	p = OCT * p * 2.03;
	s += vnoise(p) * 0.25;
	p = OCT * p * 2.03;
	s += vnoise(p) * 0.125;
	return s * (1.0 / 0.875);
}

// ---------------------------------------------------------------- stele

// Un strat de stele. Ecranul se taie într-o grilă de `cells` celule pe înălțime; în celulele
// cu hash-ul peste `thresh` stă câte o stea, împinsă aleator în celula ei.
//
// ⚠️ Steaua NU are voie să atingă marginea celulei: acolo desenul se taie brusc și iese exact
// muchia dreaptă pe care o reparăm. De aia offset-ul e ±0.25 și haloul se stinge până la 0.25 —
// împreună rămân sub 0.5, adică sub jumătatea celulei.
vec3 star_layer(vec2 p, float thresh, float size, float halo, float spike_amt, float seed) {
	vec2 id = floor(p);
	vec2 cell = id + vec2(seed, seed * 3.0);
	float r = hash21(cell);
	if (r < thresh) {
		return vec3(0.0);   // celulă goală — altfel cerul ar fi o perdea uniformă de puncte
	}
	vec2 h = hash22(cell + vec2(101.0, 233.0));
	vec2 d = p - id - 0.5 - (h - 0.5) * 0.5;
	float dist = length(d);

	// Luminozitatea nu e uniformă, ci strâmbată cu o putere: puține stele tari, multe abia
	// vizibile. Așa arată un cer adevărat — și tot așa se vede diferența față de „puncte albe".
	float br = pow((r - thresh) / (1.0 - thresh), 2.4);
	float core = smoothstep(size, 0.0, dist);
	float glow = smoothstep(halo, 0.0, dist);
	glow *= glow;                                  // cade repede → halo moale, nu ceață

	// clipit: fiecare stea în ritmul ei și niciodată complet stinsă (0.74 minim), ca să nu
	// pară că se aprind becuri
	float tw = 0.74 + 0.26 * sin(TIME * (0.45 + h.x * 1.7) + h.y * 62.8);

	float light = core + glow * 0.32;
	if (spike_amt > 0.001) {
		// Cele mai tari stele primesc o cruce subțire de lumină, ca la un obiectiv de aparat
		// foto. `br * br` = doar vârful distribuției o prinde, deci rămâne un accent, nu un efect.
		float sx = exp(-abs(d.x) * 24.0 - d.y * d.y * 900.0);
		float sy = exp(-abs(d.y) * 24.0 - d.x * d.x * 900.0);
		light += (sx + sy) * spike_amt * br * br;
	}
	return mix(star_cool, star_warm, h.y * h.y) * light * br * tw;
}

// Stea căzătoare: o dată la `meteor_period` secunde, pe o diagonală aleasă aleator, aprinsă
// mai puțin de o secundă. E rară intenționat — dacă o vezi des, devine zgomot de fundal.
vec3 meteor(vec2 auv, float aspect) {
	if (meteor_period < 1.0) {
		return vec3(0.0);
	}
	float idx = floor(TIME / meteor_period);
	float k = fract(TIME / meteor_period) / 0.055;   // 0..1 pe durata trecerii
	if (k > 1.0) {
		return vec3(0.0);
	}
	vec2 rr = hash22(vec2(idx, 7.0));
	vec2 dir = normalize(vec2(-0.88, 0.47 + rr.x * 0.3));
	vec2 start = vec2(aspect * (0.55 + rr.y * 0.75), -0.25 + rr.x * 0.35);
	vec2 d = auv - (start + dir * (k * 1.9));
	float along = clamp(dot(d, -dir), 0.0, 0.30);    // cât de departe pe coadă, în urma capului
	float perp = length(d + dir * along);
	float trail = smoothstep(0.0055, 0.0, perp) * (1.0 - along / 0.30);
	// intră și iese lin, ca să nu apară/dispară dintr-o bucată
	return star_cool * trail * smoothstep(0.0, 0.10, k) * smoothstep(1.0, 0.72, k);
}

// ---------------------------------------------------------------- desenul

void fragment() {
	// celulele trebuie să fie pătrate, altfel stelele ies ovale pe ecran lat
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV;
	vec2 auv = vec2(uv.x * aspect, uv.y);
	// deplasarea lumii, adusă în aceleași unități ca `auv` (1 = înălțimea ecranului)
	vec2 par = world_offset * SCREEN_PIXEL_SIZE.y * parallax;
	vec2 cen = auv - vec2(aspect * 0.5, 0.5);

	// --- nebuloasa ---
	// Zgomot împins cu alt zgomot („domain warp"): din pete rotunde ies volute și filamente.
	// Ăsta e singurul lucru care face un nor procedural să nu arate procedural.
	float t = TIME * 0.012;
	vec2 np = cen * 1.35 + par * 0.30;
	vec2 q = vec2(fbm2(np + vec2(0.0, t)), fbm2(np + vec2(4.3, -t)));
	float n = fbm3(np + q * 1.15 + vec2(-t * 0.6, t * 0.35));
	float neb = smoothstep(0.52, 0.95, n);
	// „dust lanes": al doilea câmp taie fâșii din nor → structură, nu ceață uniformă
	neb *= 1.0 - 0.55 * smoothstep(0.45, 0.95, q.x);
	vec3 neb_col = mix(nebula_a, nebula_b, clamp(q.y * 1.5 - 0.25, 0.0, 1.0));
	neb_col = mix(neb_col, nebula_c, smoothstep(0.72, 1.0, n) * 0.55);

	// --- aurora ---
	// O panglică ce șerpuiește pe lățimea ecranului. Îndoitura vine din zgomot, nu dintr-un
	// singur sinus: un sinus curat se citește ca „val de manual", zgomotul se citește ca fenomen.
	float band = 0.42 + (fbm2(vec2(auv.x * 1.1 + par.x * 0.08, TIME * 0.035)) - 0.5) * 0.34;
	float aurora = smoothstep(0.15, 0.0, abs(uv.y - band));
	aurora *= aurora * (0.55 + 0.45 * sin(TIME * 0.37));

	// --- stele: trei straturi, cu paralaxă crescătoare → adâncime ---
	vec3 sky = star_layer(auv * 27.0 + par * (27.0 * 0.020), 0.86, 0.016, 0.05, 0.0, 0.0)
	         + star_layer(auv * 15.0 + par * (15.0 * 0.055), 0.83, 0.022, 0.09, 0.0, 37.0) * 0.85
	         + star_layer(auv *  8.0 + par * ( 8.0 * 0.115), 0.80, 0.030, 0.16, 0.5, 91.0) * 0.70;
	sky *= star_density;
	// stelele din spatele norului se sting — norul e ÎN FAȚA lor
	sky *= 1.0 - 0.55 * neb;

	// --- vinieta ---
	float rad = length((uv - 0.5) * vec2(1.18, 1.0)) * 1.42;
	float dark = smoothstep(0.32, 1.0, rad);
	dark = dark * dark * (3.0 - 2.0 * dark) * vignette_strength;

	vec3 lit = sky
	         + neb_col * neb * nebula_strength
	         + nebula_b * aurora * aurora_strength
	         + meteor(auv, aspect);

	// Dither: o miime de zgomot fix pe pixel, adăugat înainte de afișare. Gradientele foarte
	// întunecate (nebuloasa, vinieta) ies altfel în INELE pe 8 biți — banding-ul e cel mai
	// ieftin mod de a arăta amatorism, și se repară cu o singură linie.
	float dth = (hash21(FRAGCOORD.xy) - 0.5) * (1.0 / 255.0);
	lit += vec3(dth);
	dark = max(dark + dth, 0.0);

	// vezi `nether_hell.gdshader` pentru explicația compunerii
	float lum = max(max(lit.r, lit.g), lit.b);
	float a = clamp(dark + lum, 0.0, 1.0);
	vec3 col = (vignette_color * dark + lit) / max(a, 0.0001);
	COLOR = vec4(col, a * amount);
}
