shader_type canvas_item;

// TENTĂ DE CULOARE peste un proiectil, păstrându-i desenul.
//
// De ce nu `modulate`: `modulate` ÎNMULȚEȘTE, iar glonțul de bază e ALĂMIU (roșu/verde mult,
// albastru aproape deloc). Un `modulate` albastru l-ar face aproape NEGRU, nu albastru. La fel
// pățește cuțitul (metal cenușiu) și izbucnirea galbenă a mage-ului.
//
// Aici luăm LUMINANȚA pixelului (cât de deschis e) și o recolorăm cu `tenta`, apoi amestecăm
// înapoi peste original cu `putere`. Așa umbrele rămân umbre și lucirile rămâne luciri — doar
// culoarea se schimbă. Merge pe orice artă, oricât de închisă.
//
// ⚠️ Lucrăm pe COLOR, nu pe `texture(TEXTURE, UV)`: Godot îl umple înainte de `fragment()` cu
// textura înmulțită cu `modulate`, deci transparența dată din cod rămâne bună (aceeași notă ca
// la `white_flash.gdshader`).
uniform vec3 tenta : source_color = vec3(1.0);
uniform float putere : hint_range(0.0, 1.0) = 0.88;

// Cât de mult se ridică pixelii închiși înainte de colorare. Fără el, un metal închis ar ieși
// „negru colorat", adică tot negru: culoarea n-ar mai fi vizibilă de la distanța de joc.
const float PODEA = 0.30;

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 colorat = tenta * (PODEA + (1.0 - PODEA) * lum);
	COLOR.rgb = mix(COLOR.rgb, colorat, putere);
}
