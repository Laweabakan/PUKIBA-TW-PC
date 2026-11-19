// Follaje que se mece con el viento (compartido por árboles, cañas y hierbas).
// Las mallas tienen la base en y = 0: cuanto más alto el vértice, más se mueve.
// Estilo low-poly de papel: caras planas (la normal sale de la propia cara) y un tono
// propio por planta en vez de manchas.
shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 albedo : source_color = vec4(0.25, 0.5, 0.2, 1.0);
uniform float sway = 0.035;
uniform float speed = 1.6;
uniform float emission = 0.0;

varying float tone;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float s = sin(TIME * speed + origin.x * 0.9 + origin.z * 0.7) + 0.35 * sin(TIME * speed * 2.3 + origin.z * 2.1 + VERTEX.y * 3.0);
	VERTEX.x += s * sway * h;
	VERTEX.z += s * sway * 0.5 * h;
	tone = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Normal de la cara (plana) a partir de la posición: facetas nítidas aunque la planta se mezca
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 col = albedo.rgb * (0.9 + 0.2 * tone);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
	EMISSION = col * emission;
}
