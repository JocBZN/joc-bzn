shader_type canvas_item;

// Podea cu 2 biome: iarbă în stânga, deșert în dreapta, cu o trecere lină între ele.
// Alege textura după poziția X REALĂ din lume (world_pos.x), nu după ecran.

uniform sampler2D grass_tex : filter_nearest, repeat_enable;
uniform sampler2D desert_tex : filter_nearest, repeat_enable;
uniform float tile_size = 64.0;         // mărimea unui tile în px
uniform float boundary_x = 2500.0;      // de la ce X spre dreapta e deșert
uniform float transition_width = 600.0; // cât de lată e trecerea (px)

varying vec2 world_pos;

void vertex() {
	// poziția reală în lume a fiecărui punct al podelei
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = world_pos / tile_size;                 // coordonate de tiling (repetă la fiecare tile_size)
	vec4 grass = texture(grass_tex, uv);
	vec4 desert = texture(desert_tex, uv);
	// 0 = iarbă (stânga boundary), 1 = deșert (dreapta); între ele, amestec lin
	float t = smoothstep(boundary_x - transition_width * 0.5, boundary_x + transition_width * 0.5, world_pos.x);
	COLOR = mix(grass, desert, t);
}
