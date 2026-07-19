shader_type canvas_item;

// Blur gaussian 5x5 pentru fundalul video din meniul principal.
// blur_amount = cât de departe se duc probele, în pixeli. 0 = imagine curată (fără blur).
// La intrarea în meniu pornește de la 0 și urcă la MENU_BLUR (vezi menu.gd).
uniform float blur_amount : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	if (blur_amount <= 0.001) {
		// scurtătură: cât timp nu e blur, luăm pixelul direct (nu irosim 25 de probe)
		COLOR = texture(TEXTURE, UV);
	} else {
		float w[5] = {1.0, 4.0, 6.0, 4.0, 1.0};   // kernel gaussian 1D, aplicat pe X și pe Y
		vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_amount;
		vec4 sum = vec4(0.0);
		float total = 0.0;
		for (int y = 0; y < 5; y++) {
			for (int x = 0; x < 5; x++) {
				float weight = w[x] * w[y];
				vec2 off = vec2(float(x - 2), float(y - 2)) * step_uv;
				sum += texture(TEXTURE, UV + off) * weight;
				total += weight;
			}
		}
		COLOR = sum / total;
	}
}
