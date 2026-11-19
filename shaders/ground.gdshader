shader_type spatial;
render_mode diffuse_lambert;
// Suelo del tablero, estilo LOW-POLY DE PAPEL: el color de cada casilla (instancia) sin
// textura, partido en triángulos. Cada triángulo tiene un tono y una inclinación propios,
// así la luz lo pinta en facetas como un terreno de papel plegado. Las facetas siguen el
// mundo (no la casilla), de modo que el suelo se ve continuo entre casillas.

uniform float facet_scale = 1.35; // triángulos por unidad (más = facetas más pequeñas)
uniform float jitter = 0.06;      // variación de tono entre caras
uniform float tilt = 0.45;        // inclinación de cada cara (cuánto cambia su luz)
uniform float detail = 1.0;       // (compatibilidad: ya no se usa)

varying vec3 world_pos;
varying vec3 world_nrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz * facet_scale;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	// Cada cuadro se parte en dos triángulos; la diagonal cambia al azar de un cuadro a otro
	float diag = step(0.5, hash(cell));
	float tri = diag > 0.5 ? step(f.x, f.y) : step(f.x, 1.0 - f.y);
	vec2 id = cell * 2.0 + vec2(tri, diag * 0.37);
	float h1 = hash(id);
	float h2 = hash(id + 17.31);
	float h3 = hash(id + 5.17);
	// Forward+: el color de la instancia viene en sRGB; se pasa a lineal
	vec3 base = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb));
	ALBEDO = base * (1.0 + (h1 - 0.5) * 2.0 * jitter);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	if (world_nrm.y > 0.7) {
		// Cara de arriba: normal inclinada por triángulo (facetas)
		vec3 wn = normalize(vec3((h2 - 0.5) * tilt, 1.0, (h3 - 0.5) * tilt));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}
