shader_type canvas_item;

// Podea cu 2 biome: iarbă + deșert. Deșertul apare în PETICE PĂTRATE random (vezi biome_map.gd),
// cu latura între min_size și max_size chunk-uri, plasate aleator prin lume. Margini soft (smootherstep).
// IMPORTANT: matematica biomului de aici trebuie să fie IDENTICĂ cu cea din biome_map.gd.
// Parametrii macro/min_size/max_size/desert_percent vin din biome_map.gd (setați de ground.gd) →
// un SINGUR loc de reglat, ca vizualul să coincidă mereu cu blocarea copacilor/pietrelor.

uniform sampler2D grass_tex : filter_nearest, repeat_enable;
uniform sampler2D desert_tex : filter_nearest, repeat_enable;
uniform float tile_size = 64.0;      // mărimea unui tile de textură (px)
uniform float chunk_size = 512.0;    // mărimea unui chunk (px) — TREBUIE să fie ca în props.gd/rocks.gd
uniform float blend_chunks = 1.5;    // cât de soft e marginea deșertului (în chunk-uri)
uniform int macro = 20;              // = MACRO din biome_map.gd
uniform int min_size = 6;            // = MIN_SIZE din biome_map.gd
uniform int max_size = 20;           // = MAX_SIZE din biome_map.gd
uniform int desert_percent = 40;     // = DESERT_PERCENT din biome_map.gd
uniform int edge_snap = 2;           // = EDGE_SNAP din biome_map.gd

varying vec2 world_pos;

void vertex() {
	// poziția reală în lume a fiecărui punct al podelei
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Hash întreg pe 32 de biți. IDENTIC cu _hash() din biome_map.gd.
uint hashu(int cx, int cy) {
	uint x = uint(cx);
	uint y = uint(cy);
	uint h = x * 374761393u + y * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return h;
}

// Marginile peticului pe o axă, în coordonate LOCALE de celulă, după LIPIRE.
// IDENTIC cu _snap_axis() din biome_map.gd — vezi acolo de ce (culoare subțiri de iarbă
// rămâneau între două deșerturi vecine).
vec2 snap_axis(float lo, float size) {
	float hi = lo + size;
	if (lo <= float(edge_snap)) { lo = 0.0; }
	if (hi >= float(macro) - float(edge_snap)) { hi = float(macro); }
	return vec2(lo, hi);
}

// smootherstep (quintic) — trecere lină, fără muchie.
float ss(float e0, float e1, float x) {
	float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

void fragment() {
	vec2 uv = world_pos / tile_size;
	vec4 grass = texture(grass_tex, uv);
	vec4 desert = texture(desert_tex, uv);

	uint pct = uint(desert_percent);
	uint span = uint(max_size - min_size + 1);
	vec2 chunkf = world_pos / chunk_size;                     // coordonată de chunk (continuă)
	ivec2 base_macro = ivec2(floor(chunkf / float(macro)));
	float d = 0.0;                                            // „deșert-ime": 0 = iarbă, 1 = deșert
	// Ne uităm la macro-celula curentă + cele 8 vecine, ca marginile soft să se lege corect peste granițe.
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 m = base_macro + ivec2(dx, dy);
			uint h = hashu(m.x, m.y);
			if ((h % 100u) < pct) {
				uint f = uint(min_size) + (h / 100u) % span;  // latura peticului: min..max
				uint room = uint(macro) - f + 1u;             // câte poziții încap pe o axă
				uint ox = (h / 10000u) % room;
				uint oy = (h / 1000000u) % room;
				// dreptunghiul de deșert, în coordonate de chunk (globale), cu marginile lipite
				vec2 sx = snap_axis(float(ox), float(f));
				vec2 sy = snap_axis(float(oy), float(f));
				vec2 lo = vec2(m) * float(macro) + vec2(sx.x, sy.x);
				vec2 hi = vec2(m) * float(macro) + vec2(sx.y, sy.y);
				vec2 q = max(max(lo - chunkf, chunkf - hi), vec2(0.0));  // 0 în interiorul peticului
				float dist = length(q);
				d = max(d, 1.0 - ss(0.0, blend_chunks, dist));           // soft spre exterior
			}
		}
	}
	COLOR = mix(grass, desert, d);
}
