shader_type canvas_item;
// ADUNARE, nu suprapunere. Verificat pe captură: amestecul obișnuit dădea o siluetă cenușiu-albastră,
// mată, care arăta ca o pată de vopsea uitată pe nebuloasă. Adunată peste fundal, aceeași siluetă e
// LUMINĂ — se citește ca energia rămasă în urmă, se stinge frumos și nu are nevoie de contur ca să
// nu fie o gaură în ecran (problema de căpătâi a lui Celesto, vezi `contur_1px.gdshader`).
render_mode blend_add;

// UMBRA rămasă în urmă când Celesto se teleportează — silueta lui, plată, într-un albastru aprins,
// care se umflă puțin și se stinge în ~0,3 secunde. Fără ea, o teleportare e doar „era acolo, acum
// e dincolo": ochiul n-are ce urmări și mișcarea nu se citește. Cu ea, rămâne o urmă exact în locul
// din care a plecat, deci vezi DRUMUL, nu doar cele două capete.
//
// De ce un shader și nu pur și simplu o copie a sprite-ului cu `modulate` albastru: desenul lui e
// o siluetă NEAGRĂ (de-aia are nevoie și de `contur_1px` ca să nu fie o gaură în ecran), iar
// `modulate` ÎNMULȚEȘTE culoarea — negru înmulțit cu orice rămâne negru. Aici aruncăm culoarea din
// textură și păstrăm doar FORMA ei (alfa), pe care o umplem cu culoarea cerută.
//
// Folosit de `celesto.gd::umbra()`: în cinematica de intrare (`ender.gd`) și la teleportările din
// fazele 2 și 3.

// Mai aprins decât albastrul lui de contur (0.15, 0.27, 0.78): adunarea peste o nebuloasă
// aproape neagră mănâncă din intensitate, iar o urmă ștearsă nu se citește ca energie.
uniform vec4 culoare : source_color = vec4(0.50, 0.78, 1.15, 1.0);

void fragment() {
	// `COLOR` intră în `fragment()` DEJA înmulțit cu textura ȘI cu `modulate`-ul nodului (același
	// lucru e explicat pe larg în `contur_1px.gdshader`). Deci `COLOR.a` e exact „cât din pixelul
	// ăsta e desen" × „cât de vie mai e umbra" — adică stingerea se poate face din afară, cu un
	// tween obișnuit pe `modulate:a`, fără să umblăm la uniforme.
	COLOR = vec4(culoare.rgb, COLOR.a * culoare.a);
}
