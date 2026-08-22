shader_type canvas_item;
render_mode blend_mix, unshaded;

// VALUL DE CĂLDURĂ AL DEȘERTULUI — aerul fierbinte care tremură deasupra nisipului.
// Se pune peste tot ecranul, într-un CanvasLayer propriu (`atmosphere.gd::_setup_heat`), și
// CITEȘTE ecranul deja desenat (`hint_screen_texture`, ca `limbo_bw.gdshader`): nu desenează
// nimic nou, ci re-așază ce e dedesubt cu o fracțiune de pixel. Asta e diferența dintre un
// „efect de căldură" adevărat și o perdea portocalie pusă peste imagine — căldura nu are
// culoare, se vede doar prin ce STRÂMBĂ.
//
// ⚠️ Fiindcă citește ecranul, stratul lui trebuie să stea SUB HUD (vezi `atmosphere.gd`):
// altfel ar fi unduit și viața, și XP-ul, și cronometrul — iar un HUD care tremură nu se citește
// ca atmosferă, ci ca un bug.
//
// `amount` = 0 stins, 1 deșert plin. Îl mișcă `atmosphere.gd` după cât de deșert e solul de sub
// player, deci efectul crește pe măsură ce iarba se face nisip și nu „se aprinde" la o graniță.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

// Cât s-a dus lumea sub cameră, în pixeli de ecran (`-canvas_transform.origin`, scris tot din
// `atmosphere.gd` — aceeași uniformă ca la stelele din Ender). Fără ea, unduirea ar sta lipită
// de ecran și ar călători cu tine ca o pată pe obiectiv; cu ea, fiecare val de aer rămâne
// deasupra peticului lui de nisip și îi treci pe lângă.
uniform vec2 world_offset = vec2(0.0);

// Câți pixeli de ecran face un pixel de LUME (zoom-ul camerei × întinderea ferestrei). Tot din
// `atmosphere.gd`. Toate cifrele de mai jos sunt astfel în pixeli de LUME, adică în pixeli de
// desen: pe un ecran 4K unduirea rămâne la fel de mare FAȚĂ DE JOC, nu se face de patru ori mai
// mică. Un efect măsurat în pixeli de ecran e un efect care arată altfel la fiecare jucător.
uniform float px_scale = 1.0;

// Cât de mult se mișcă imaginea, la vârful valului (pixeli de lume). 1,3 înseamnă că un perete de
// piatră se leagănă cu mai puțin de un pixel și jumătate de artă — se simte, nu se vede.
uniform float wobble_px : hint_range(0.0, 8.0) = 1.3;
uniform float cell_px = 84.0;                            // cât de mari sunt valurile de aer
uniform float rise_px = 30.0;                            // cât de repede urcă aerul cald (px/s)
// Cât de tare unduie JOSUL ecranului față de sus. Sus e „mai departe" într-un joc văzut de sus,
// iar căldura se adună cu distanța — la fel cum, pe șosea, asfaltul de sub tine e limpede și
// zarea fierbe. 1.0 aici = ramp scos, unduire egală peste tot.
uniform float depth_min : hint_range(0.0, 1.0) = 0.55;
uniform vec3 heat_color : source_color = vec3(1.0, 0.87, 0.66);  // suflul cald de deasupra nisipului
uniform float tint : hint_range(0.0, 0.25) = 0.045;      // cât de mult din el se vede (foarte puțin)

// ⚠️ DE CE SINUSURI ȘI NU ZGOMOT (value noise), ca în `nether_hell.gdshader`:
// prima versiune folosea trei straturi de zgomot, ca scânteile din Nether. Arăta bine, dar
// MĂSURAT pe RTX 3050 Ti, la 1920×1080: 6,40 ms/cadru fără efect, 6,96 ms cu shaderul gol (adică
// atât costă copierea ecranului) și 8,03 ms cu zgomotul — două treimi din preț se duceau pe
// hash-uri, pentru un tremur de doi pixeli pe care nimeni nu-l vede în detaliu. Jocul e pe
// renderer-ul „Mobile", unde 1 ms de laptop e mult mai mult pe telefon.
// Trei sinusuri cu frecvențe care nu se împart una la alta (6,1 / 11,3 / 4,7), unul mergând în
// contra celorlalte și unul îndoit de primul (domain warp), dau exact același tremur — la a zecea
// parte din cost și fără nicio muchie de celulă. Regularitatea sinusurilor s-ar vedea doar la
// amplitudini mari; la doi pixeli, nu.
void fragment() {
	// punctul ANCORAT DE SOL: pixelul de ecran, mutat cu cât s-a dus lumea sub cameră
	vec2 sp = SCREEN_UV / SCREEN_PIXEL_SIZE + world_offset;
	// `sp / px_scale` = poziția în pixeli de LUME, deci și valurile, și viteza lor sunt măsurate
	// în ce vezi desenat, nu în puncte de ecran.
	vec2 p = sp / (cell_px * px_scale);
	// Tiparul curge în SUS pe conținut → valurile de aer urcă. (Coordonata crește, deci trăsătura
	// pe care o vezi acum era, o clipă mai devreme, mai jos.)
	p.y += TIME * rise_px / cell_px;
	p.x += sin(TIME * 0.21) * 0.18;   // o adiere leneșă, ca să nu curgă totul pe o singură axă

	float t = TIME;
	float w1 = sin(p.y * 6.1 + p.x * 1.7 + t * 0.9);    // valul lung, care duce tot
	float w2 = sin(p.y * 11.3 - p.x * 3.1 - t * 1.6);   // unul scurt, în contra: de aici vine clocotul
	float sx = sin(p.x * 4.7 + w1 * 0.8 + t * 0.6);     // legănatul lateral, îndoit de valul lung

	// Verticala primește toată amplitudinea, orizontala cam jumătate: aerul urcă, deci imaginea
	// se ridică și coboară mai mult decât se clatină în lături.
	vec2 off = vec2(sx * 0.5, w1 * 0.62 + w2 * 0.38);

	float depth = mix(depth_min, 1.0, 1.0 - SCREEN_UV.y);
	float k = amount * depth;

	// ⚠️ deplasarea se face în PIXELI (`* SCREEN_PIXEL_SIZE`), nu în UV: altfel același reglaj ar
	// însemna alt tremur la altă rezoluție, iar pe un ecran lat ar unduia mai mult pe x decât pe y.
	vec2 uv = SCREEN_UV + off * (wobble_px * px_scale) * k * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;

	// suflul cald: aceleași valuri, dar ca lumină — doar cât să simți aerul, nu cât să se vadă
	float shimmer = clamp(0.5 + w1 * 0.35 + w2 * 0.15, 0.0, 1.0);
	c += heat_color * (tint * k * shimmer);

	COLOR = vec4(c, 1.0);
}
