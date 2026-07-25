shader_type canvas_item;

// Albește sprite-ul după `flash` (0 = normal, 1 = complet alb), păstrând transparența.
// Folosit de player la Mike's Hedgehog: pe block, flash sare la 1 și se stinge spre 0.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
