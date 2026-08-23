shader_type canvas_item;

// CERCUL DE MOARTE — diafragma care se închide peste player (`gameover.gd`).
//
// Citește ecranul deja desenat (`hint_screen_texture`, ca `limbo_bw.gdshader`) și îl redă înapoi
// cu trei lucruri peste:
//   • în AFARA cercului: negru complet — acolo lumea nu mai există;
//   • în interior: culoarea și lumina se scurg treptat (`stins`), ca la un om care leșină;
//   • pe marginea dinăuntru: o pâlpâire roșie slabă (`rama`), aceeași culoare cu „YOU DIED".
//
// Raza se măsoară în JUMĂTĂȚI DE ÎNĂLȚIME de ecran, nu în pixeli: cu `raport` = (lățime/înălțime, 1)
// cercul rămâne rotund pe orice ecran, iar `gameover.gd` nu trebuie să știe rezoluția.
uniform sampler2D ecran : hint_screen_texture, filter_linear;
uniform vec2 centru = vec2(0.5, 0.5);          // unde e player-ul pe ecran (0..1)
uniform vec2 raport = vec2(1.0, 1.0);          // corecția de aspect
uniform float raza = 3.0;                      // 3 = mult peste colțuri, adică nimic negru
uniform float moliciune = 0.010;               // cât de moale e trecerea spre negru
uniform float stins : hint_range(0.0, 1.0) = 0.0;   // 0 = lumea normală, 1 = gri și întunecat
uniform float rama : hint_range(0.0, 1.0) = 0.0;    // cât de tare arde inelul de la margine
uniform vec4 culoare_rama : source_color = vec4(0.60, 0.05, 0.07, 1.0);

void fragment() {
	float d = length((SCREEN_UV - centru) * raport);
	// 0 = înăuntru, 1 = afară. `moliciune` ține marginea moale, altfel se văd trepte pe cerc.
	float negru = smoothstep(raza - moliciune, raza + moliciune, d);

	vec3 c = texture(ecran, SCREEN_UV).rgb;
	// aceeași formulă de luminozitate percepută ca la Limbo (ochiul vede verdele cel mai tare)
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), stins) * (1.0 - 0.55 * stins);

	// Inelul: o dungă subțire chiar pe margine (ultimele 12% din rază), și numai pe dinăuntru.
	// Fără `(1.0 - negru)` ar lumina și negrul din afară și s-ar vedea un halou în gol. `0.45`:
	// prima variantă mergea de la 62% din rază, la putere întreagă, și ieșea o pată roșie cât
	// jumătate de cerc — arăta a filtru de Instagram, nu a margine care arde.
	float inel = smoothstep(raza * 0.88, raza, d) * (1.0 - negru);
	c += culoare_rama.rgb * inel * rama * 0.45;

	COLOR = vec4(mix(c, vec3(0.0), negru), 1.0);
}
