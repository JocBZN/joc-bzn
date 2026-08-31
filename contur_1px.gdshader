shader_type canvas_item;

// CONTUR de 1 PIXEL DE ECRAN, desenat la rulare — nu copt în poză.
//
// De ce nu-l coacem în PNG (cum făcea `tool_contur_foaie.gd` pentru Saratalin, până pe
// 2026-08-31, când a trecut și el pe shaderul ăsta): cel mai subțire
// contur care se poate desena într-o poză e de 1 pixel DIN POZĂ. Celesto se afișează la scale
// 3.2, deci acel „1px" ajunge un chenar de 3 pixeli pe ecran, iar coasa uriașă din faza 3 (×3)
// ar avea conturul de trei ori mai gros decât cele mici. Aici grosimea se măsoară pe ECRAN, deci
// rămâne 1px oricât ar fi mărit sprite-ul și oricât ar zoom-a camera.
//
// Trucul e derivata lui UV: cât se schimbă UV când te muți un pixel pe ecran, exact în punctul
// ăsta. O calculăm o singură dată, ÎNAINTE de orice `if` — derivatele sunt nedefinite dacă se cer
// pe ramuri. Nu `fwidth`, ci lungimea gradientului: coasa se ÎNVÂRTE în zbor, iar `fwidth` (care
// adună cele două derivate) ar îngroșa conturul cu până la 40% când sprite-ul e pe diagonală.
//
// Folosit de `celesto.tscn` (albastru, ca la boss-ul dinainte), de `scythe.tscn`, de
// `final_boss.tscn` și, de pe 2026-08-31, de `saratalin.tscn` (mov `(0.72, 0.28, 1.0)`, cerut de
// Răzvan — la el conturul era înainte COPT în foaia veche cu `tool_contur_foaie.gd`).
// Silueta trebuie să aibă margine transparentă în poză, altfel conturul iese tăiat la marginea
// cadrului — cadrele lui Celesto (128×128), ale lui Saratalin (96×96, desen pe 24..70 × 17..79)
// și coasa au loc destul.

// `modulare` = culoarea nodului (flash-ul la lovitură, fade-ul de la moarte). În `fragment()`,
// `COLOR` vine deja înmulțit cu textura, deci n-ai de unde s-o scoți curată; în `vertex()` e
// exact ea. (`MODULATE` nu există în 4.7 — dă „Unknown identifier".)
varying vec4 modulare;

uniform vec4 culoare : source_color = vec4(0.15, 0.27, 0.78, 1.0);
uniform float grosime : hint_range(0.0, 4.0) = 1.0;   // în pixeli de ECRAN
uniform float prag : hint_range(0.0, 1.0) = 0.35;     // de la ce alfa în sus e desen

void vertex() {
	modulare = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 du = dFdx(UV);
	vec2 dv = dFdy(UV);
	vec2 pas = vec2(length(vec2(du.x, dv.x)), length(vec2(du.y, dv.y))) * grosime;
	// cei 8 vecini (și diagonalele, altfel colțurile rămân roase)
	float vecin = 0.0;
	vecin = max(vecin, texture(TEXTURE, UV + vec2(pas.x, 0.0)).a);
	vecin = max(vecin, texture(TEXTURE, UV - vec2(pas.x, 0.0)).a);
	vecin = max(vecin, texture(TEXTURE, UV + vec2(0.0, pas.y)).a);
	vecin = max(vecin, texture(TEXTURE, UV - vec2(0.0, pas.y)).a);
	vecin = max(vecin, texture(TEXTURE, UV + pas).a);
	vecin = max(vecin, texture(TEXTURE, UV - pas).a);
	vecin = max(vecin, texture(TEXTURE, UV + vec2(pas.x, -pas.y)).a);
	vecin = max(vecin, texture(TEXTURE, UV + vec2(-pas.x, pas.y)).a);
	// Modularea se înmulțește ȘI peste contur, ca să nu rămână un chenar aprins pe un boss care
	// tocmai s-a stins.
	if (c.a < prag && vecin >= prag) {
		COLOR = culoare * modulare;
	} else {
		COLOR = c * modulare;
	}
}
