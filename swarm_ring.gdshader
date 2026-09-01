shader_type canvas_item;
render_mode blend_mix;

// SIGILIUL HOARDEI — cercul desenat pe jos în jurul monumentului, cât curge swarm-ul.
// Îl pune `swarm_ring.gd` pe un Sprite2D pătrat; textura nu se citește niciodată, tot ce vezi
// se calculează aici din UV. De aia se poate scala oricât fără să se pixeleze: la fel de curat
// la rază de 200 ca la 900.
//
// Sistemul de coordonate: `p` merge de la -1 la +1 pe fiecare axă, deci `d` (distanța de la
// centru) e 1.0 fix pe marginea sprite-ului. Inelul stă la `raza` (0.70), iar restul de 0.30
// e loc pentru halou și pentru dinții din afară — dacă urci `raza` peste ~0.82, marginea de
// sus a haloului se taie drept în muchia sprite-ului și se vede pătratul.
//
// GROSIMILE SUNT ÎN FRACȚIUNI, NU ÎN PIXELI, și asta e intenționat: `swarm_ring.gd` scalează
// nodul ca să iasă raza cerută în pixeli de lume, deci un inel de 900 px are linia proporțional
// mai groasă decât unul de 300 px. Ce ține linia CITIBILĂ la orice mărime e `fwidth(d)` de mai
// jos: e cât un pixel de ecran în unități de `d`, deci antialiasing-ul e mereu de exact un pixel,
// oricât ar fi zoom-ul camerei.
//
// ⚠️ NU e `blend_add`. Lumina aditivă se comportă altfel pe fiecare sol — vezi lecția din
// `poarta_castel.gd`: pe nisipul deșertului canalele sunt deja aproape pline, așa că orice adaos
// iese ALB, iar pe iarba închisă aceeași cifră abia se vede. Monumentul apare în AMBELE biomuri.
// Soluția e cea de la barele de viață: sub linia luminoasă punem o bandă ÎNCHISĂ, iar linia se
// amestecă normal (`blend_mix`) peste ea. Așa contrastul îl aduce inelul cu el, nu solul.

const float TAU_ = 6.28318530718;

uniform vec4 culoare : source_color = vec4(1.0, 0.15, 0.09, 1.0);        // roșul hoardei (ca `hud.gd::TIMER_SWARM`)
uniform vec4 culoare_miez : source_color = vec4(1.0, 0.92, 0.78, 1.0);   // miezul liniei, alb-auriu (metal încins)
uniform vec4 culoare_umbra : source_color = vec4(0.07, 0.008, 0.015, 1.0);// banda închisă de dedesubt
uniform float raza : hint_range(0.1, 0.85) = 0.70;      // unde stă inelul, fracție din jumătatea sprite-ului
uniform float grosime : hint_range(0.001, 0.05) = 0.008;// jumătatea grosimii liniei
uniform float halou : hint_range(0.01, 0.3) = 0.052;    // cât de departe se stinge strălucirea
uniform float progres : hint_range(0.0, 1.0) = 1.0;     // ceasul hoardei: 1 = abia a început, 0 = gata
uniform float intensitate : hint_range(0.0, 2.0) = 1.0; // aprindere / stingere (o mișcă tween-ul)
uniform float timp = 0.0;                               // ceasul JOCULUI, nu TIME — vezi `swarm_ring.gd`
uniform float dinti = 54.0;                             // câți dinți are inelul din afară
uniform float dinti_mici = 30.0;                        // și cel dinăuntru, care se învârte invers
uniform float umplere : hint_range(0.0, 0.5) = 0.09;     // cât de mult se închide solul în interior

// Suprapune un strat NOU (c, ca) peste ce s-a desenat până acum (col, a) — exact ce face motorul
// când desenează două sprite-uri transparente unul peste altul, doar că aici o facem într-un
// singur pixel, ca inelul să iasă dintr-o singură trecere.
void amesteca(inout vec3 col, inout float a, vec3 c, float ca) {
	float na = ca + a * (1.0 - ca);
	col = (c * ca + col * a * (1.0 - ca)) / max(na, 0.0001);
	a = na;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float px = max(fwidth(d), 0.0008) * 1.2;   // un pixel de ecran, în unitățile lui `d`
	float dist = abs(d - raza);

	// Unghiul, ca fracție 0..1 pornind de la VÂRF și mergând în sensul acelor de ceasornic.
	// `atan(p.x, -p.y)` (nu `atan(p.y, p.x)`) e chiar rotația asta: în sus dă 0, la dreapta dă un
	// sfert. Așa ceasul de pe inel se golește la fel ca orice cronometru rotund pe care l-ai văzut.
	float t = fract(atan(p.x, -p.y) / TAU_ + 1.0);

	// Ce parte din inel a mai rămas. Partea consumată nu dispare (ai pierde cercul), ci se stinge
	// la o cincime — inelul rămâne întreg, dar se vede din el cât mai ai de tras.
	float ramas = 1.0 - smoothstep(progres - 0.003, progres + 0.003, t);
	// Pragul de jos e 0.30, nu 0: partea consumată trebuie să rămână un CERC. Ceasul e informație
	// în plus, dar treaba de căpătâi a inelului e „ești înăuntru", și aia nu se stinge la secunda 9.
	float viu = mix(0.30, 1.0, ramas);
	float puls = 0.92 + 0.08 * sin(timp * 2.3);

	vec3 col = vec3(0.0);
	float a = 0.0;

	// 1. INTERIORUL — solul se închide ușor, tot mai mult spre margine. Ăsta e stratul care
	//    face „ești ÎNĂUNTRU": la 10% nu întunecă lupta, dar ochiul prinde imediat unde se termină.
	float inner = pow(smoothstep(0.0, raza, d), 2.0) * (1.0 - smoothstep(raza, raza + px * 2.0, d));
	amesteca(col, a, culoare_umbra.rgb, inner * umplere);

	// 2. BANDA ÎNCHISĂ de sub linie — contrastul pe care nu-l putem cere solului (vezi nota de sus).
	float sub = 1.0 - smoothstep(grosime * 2.0, grosime * 2.0 + halou * 0.9, dist);
	amesteca(col, a, culoare_umbra.rgb, sub * 0.38);

	// 3. HALOUL roșu, cu o unduire fină pe unghi ca să nu arate ca un cerc desenat în Paint.
	float g0 = 1.0 - smoothstep(0.0, halou, dist);
	float glow = pow(g0, 2.0);
	float grain = 0.88 + 0.12 * sin(t * TAU_ * 9.0 + timp * 1.2);
	// ⚠️ haloul rămâne ROȘU aproape peste tot: dacă albește prea devreme, tot inelul iese bej și
	// citește ca o funie sau ca o potecă de pământ (prima variantă, 2026-09-01, arăta exact așa).
	// Doar ultima fâșie de lângă linie se aprinde spre alb — `pow(g0, 6.0)` e cât „ultima fâșie".
	vec3 cald = mix(culoare.rgb, culoare_miez.rgb, pow(g0, 6.0) * 0.55);
	amesteca(col, a, cald, glow * 0.92 * viu * puls * grain);

	// 4. DOUĂ INELE DE DINȚI care se rotesc în sensuri OPUSE. Ăsta e tot trucul „arată profesionist":
	//    un cerc care stă nemișcat citește ca o decalcomanie, două care se contrează citesc ca un
	//    mecanism care merge. Se învârt încet (0.045 și 0.03) — cât să se vadă, nu cât să distragă.
	float f1 = fract(t * dinti - timp * 0.045);
	float d1 = smoothstep(0.0, 0.08, f1) * (1.0 - smoothstep(0.40, 0.48, f1));
	float b1 = 1.0 - smoothstep(grosime * 0.9, grosime * 0.9 + px, abs(d - (raza + halou * 1.15)));
	amesteca(col, a, culoare.rgb, b1 * d1 * 0.9 * viu);

	float f2 = fract(t * dinti_mici + timp * 0.03);
	float d2 = smoothstep(0.0, 0.10, f2) * (1.0 - smoothstep(0.30, 0.40, f2));
	float b2 = 1.0 - smoothstep(grosime * 0.7, grosime * 0.7 + px, abs(d - (raza - halou * 1.6)));
	amesteca(col, a, culoare.rgb, b2 * d2 * 0.7 * viu);

	// 5. LINIA propriu-zisă: subțire, aproape albă la mijloc.
	float core = 1.0 - smoothstep(grosime, grosime + px, dist);
	amesteca(col, a, mix(culoare.rgb, culoare_miez.rgb, 0.85), core * viu);

	// 6. CAPUL ceasului — bulgărele alb care mănâncă inelul. Se stinge la capete (`step`-urile),
	//    altfel la progres 0 sau 1 ar rămâne o pată lipită în vârf.
	float dt = abs(t - progres);
	dt = min(dt, 1.0 - dt);
	float cap = exp(-dt * dt / 0.00008) * step(0.004, progres) * step(progres, 0.998);
	float capb = 1.0 - smoothstep(halou * 0.5, halou * 0.5 + px, dist);
	amesteca(col, a, culoare_miez.rgb, clamp(cap, 0.0, 1.0) * capb);

	COLOR = vec4(col, clamp(a, 0.0, 1.0) * intensitate);
}
