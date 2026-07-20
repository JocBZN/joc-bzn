shader_type canvas_item;

// Alb-negru peste tot ce s-a desenat până aici (lumea + HUD-ul), pentru Limbo.
// Citește ecranul deja desenat (`hint_screen_texture`) și îi scoate culoarea.
// `amount` = 0 → imagine normală, 1 → complet alb-negru. Se animă la intrare/ieșire.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float darken : hint_range(0.0, 1.0) = 0.25;   // cât de mult întunecă, ca să pară „alt loc"

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	// luminozitatea percepută (ochiul vede verdele mult mai tare decât albastrul)
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 bw = mix(c, vec3(g), amount);
	COLOR = vec4(bw * (1.0 - darken * amount), 1.0);
}
