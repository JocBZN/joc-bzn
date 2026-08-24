shader_type canvas_item;

// Albește sprite-ul după `flash` (0 = normal, 1 = complet alb), păstrând transparența.
// Folosit de player la Mike's Hedgehog (pe block, flash sare la 1 și se stinge spre 0), la
// „dash-ul e iar gata" (o albire scurtă), și de fantomele albe din `dashtrail.gd`, care stau
// fix pe flash = 1.
//
// ⚠️ Lucrăm pe COLOR, nu pe `texture(TEXTURE, UV)`. Godot îl umple ÎNAINTE de `fragment()` cu
// textura ÎNMULȚITĂ cu `modulate`, deci așa transparența dată din cod (stingerea fantomei) chiar
// ajunge pe ecran. Varianta veche citea direct textura și SCRIA peste alfa: `modulate:a` nu mai
// avea niciun efect — fantomele de dash rămâneau albe pline până dispăreau brusc.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
