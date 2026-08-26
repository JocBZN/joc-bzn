shader_type canvas_item;

// VÂLTOAREA din portalul Nether — pânza aia mov care fierbe în gura arcadei, ca la portalul
// de Nether din Minecraft, doar că a noastră e aprinsă mereu (nu se aprinde cu amnarul).
//
// Stă pe nodul `Vartej` din `portal.tscn`, un Sprite2D pus EXACT peste `Sprite2D`-ul cu piatra:
// aceeași scară 2.4, același `offset`, și o textură tot de 128×128 — anume MASCA. Textura
// nodului nu se vede niciodată (shaderul scrie `COLOR` peste tot), ea e acolo ca să dea nodului
// mărimea și sistemul de coordonate al artei portalului. De-aia toată socoteala de mai jos se
// face în UV (0..1 pe lățimea/înălțimea arcadei): un punct din shader cade fix pe același punct
// din desenul arcadei, fără nicio cifră potrivită cu mâna.
//
// Trei lucruri se întâmplă aici:
//
//   1. MASCA (`portal_masca.png`, textura nodului) ține animația înăuntru. E albă exact peste
//      golul arcadei și transparentă în rest — o face `tool_portal_nether.gd`, umplând
//      „afarăul" din `harta/Portal 1.png`. Tot ce desenăm se înmulțește cu alfa ei, deci pe
//      lângă piatră nu poate ieși nimic, nici măcar un pixel. ⚠️ Dacă se schimbă desenul
//      portalului, masca trebuie refăcută cu unealta, altfel vâltoarea rămâne pe forma veche.
//
//   2. CADRELE curg dintr-o singură foaie. `portal_vartej.png` are cele 10 desene ale lui Răzvan
//      lipite pe orizontală (1280×128). Un AnimatedSprite2D ar fi schimbat textura la fiecare
//      cadru, dar atunci shaderul n-ar fi putut vedea DOUĂ cadre deodată — iar noi vrem să le
//      putem topi unul în altul (`topire`).
//
//   3. CULOAREA. Desenul e alb-albăstrui; aici îl repictăm în mov, pe trei trepte de lumină:
//      pixelii închiși → `culoare_umbra`, pânza propriu-zisă → `culoare_linii`, vârfurile albe
//      → `culoare_scantei`. Golurile dintre fire (transparente în desen) se umplu cu
//      `culoare_fundal`, ca portalul să fie un perete de energie, nu o plasă găurită.

// --- ce desenăm ---------------------------------------------------------------------------
uniform sampler2D foaie : filter_nearest, repeat_disable;   // cele N desene, cap la cap
uniform float cadre = 10.0;                       // câte desene sunt în foaie (le zice unealta)

// --- mișcarea -----------------------------------------------------------------------------
uniform float viteza = 8.0;                       // cadre pe secundă
uniform float topire : hint_range(0.0, 1.0) = 0.0; // 0 = salt sec între cadre (pixel art curat),
                                                   // 1 = se topesc unul în altul (mai lin, dar
                                                   //     apar fantome pe muchii)
// Cât de măruntă e pânza: 1 = desenul la mărimea lui, 2 = ochiuri de două ori mai mici (încap
// mai multe în gaura arcadei).
//
// ⚠️ **NU trece de 2.0.** Peste atât, colțul de sus al arcadei ar cere pixeli din AFARA
// desenului, iar desenele lui Răzvan **nu se îmbină cap la cap** — măsurat pe cadrul 1: din
// firele care ating marginea de jos, doar 9 din 21 continuă sus, iar pe verticală 8 din 30.
// Adică o repetare (`fract`) taie pânza pe o linie dreaptă prin mijlocul portalului: exact
// cusătura pe care a văzut-o Răzvan pe 2026-08-26. De-aia mai jos se folosește `clamp`, nu
// `fract`, și de-aia am scos deriva (pânza care urca încet): ea plimba fereastra de citire
// peste marginea desenului, deci cusătura apărea de la sine după vreo 25 de secunde de joc.
// La 1.9 fereastra stă între 0.025 și 0.886 pe verticală și 0.188 … 0.796 pe orizontală —
// bine înăuntru, cu marjă. Mișcarea o dau cele 10 cadre, n-avem nevoie de alunecare.
uniform float zoom : hint_range(0.5, 2.0) = 1.9;

// --- culorile ------------------------------------------------------------------------------
uniform vec4 culoare_fundal : source_color = vec4(0.118, 0.027, 0.2, 1.0);
uniform vec4 culoare_umbra : source_color = vec4(0.42, 0.129, 0.659, 1.0);
uniform vec4 culoare_linii : source_color = vec4(0.71, 0.42, 1.0, 1.0);
uniform vec4 culoare_scantei : source_color = vec4(0.941, 0.878, 1.0, 1.0);

// Respirația: portalul se luminează și se stinge încet, ca să nu pară o poză care clipește.
uniform float puls : hint_range(0.0, 0.5) = 0.07;
uniform float viteza_puls = 0.5;                   // rotații pe secundă (0.5 = o respirație la 2s)

// Stingerea de la scufundare. ⚠️ Ca la fântâna Ender: shaderul își scrie SINGUR `COLOR`, deci
// `modulate` pe nod n-are niciun efect. Cine vrea s-o stingă, animă `shader_parameter/fade`
// (o face `portal.gd::intra_in_pamant()`).
uniform float fade : hint_range(0.0, 1.0) = 1.0;


// Scoate cadrul `idx` din foaie. Foaia e o bandă de `cadre` desene puse cap la cap, deci
// cadrul i ocupă felia [i/cadre, (i+1)/cadre] pe orizontală.
vec4 cadru(vec2 uv, float idx) {
	float i = mod(idx, cadre);
	return texture(foaie, vec2((i + uv.x) / cadre, uv.y));
}

void fragment() {
	float m = texture(TEXTURE, UV).a;    // 1 în gaura arcadei, 0 în rest
	if (m < 0.5) {
		COLOR = vec4(0.0);               // nimic nu iese pe lângă piatră
	} else {
		// Punctul din pânză. `clamp`, NU `fract`: desenele nu se îmbină cap la cap, deci o
		// repetare ar tăia pânza pe o linie dreaptă prin portal (vezi nota de la `zoom`).
		// Cu `zoom` sub 2.0 nu se atinge nimic de `clamp` — el e doar plasa de siguranță.
		// (Marginea de sus e 0.999, nu 1.0: la fix 1.0 citirea ar cădea pe primul pixel al
		//  cadrului URMĂTOR din foaie, fiindcă acolo se termină felia lui.)
		vec2 uv = clamp((UV - 0.5) * zoom + 0.5, 0.0, 0.999);

		// Cadrul curent și următorul, amestecate după `topire`.
		float t = TIME * viteza;
		vec4 src = mix(cadru(uv, floor(t)), cadru(uv, floor(t) + 1.0), fract(t) * topire);

		// Repictarea în mov, după cât de deschis e pixelul desenat.
		float lum = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 linie = mix(culoare_umbra.rgb, culoare_linii.rgb, smoothstep(0.45, 0.88, lum));
		linie = mix(linie, culoare_scantei.rgb, smoothstep(0.92, 1.0, lum));

		// `src.a` = unde e desenat fir; restul e gol și se umple cu fundalul.
		vec3 rgb = mix(culoare_fundal.rgb, linie, src.a);
		float alfa = mix(culoare_fundal.a, 1.0, src.a);

		rgb *= 1.0 + puls * sin(TIME * viteza_puls * TAU);
		COLOR = vec4(rgb, alfa * m * fade);
	}
}
