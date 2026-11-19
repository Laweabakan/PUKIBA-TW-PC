// Hielo agrietado: superficie helada con grietas y destellos que recorren el hielo.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/scenery_noise.gdshaderinc"

uniform vec4 ice_color : source_color = vec4(0.62, 0.82, 0.95, 1.0);
uniform vec4 deep_color : source_color = vec4(0.25, 0.5, 0.75, 1.0);
uniform vec4 crack_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = sc_fbm(p * 0.8);
	vec3 col = mix(deep_color.rgb, ice_color.rgb, clamp(n * 1.2 + COLOR.r * 0.5, 0.0, 1.0));
	float c1 = 1.0 - smoothstep(0.0, 0.05, sc_cells(p * 1.2));
	float c2 = 1.0 - smoothstep(0.0, 0.035, sc_cells(p * 3.1 + 5.0));
	col = mix(col, crack_color.rgb, max(c1, c2 * 0.6));
	// Escarcha en la orilla
	col = mix(col, vec3(0.95, 0.98, 1.0), smoothstep(0.55, 0.9, COLOR.r + (n - 0.5) * 0.4));
	// Destello que barre el hielo
	float sweep = smoothstep(0.96, 1.0, sin((p.x + p.y) * 0.8 - TIME * 1.2) * 0.5 + 0.5);
	ALBEDO = col;
	EMISSION = vec3(0.6, 0.85, 1.0) * sweep * 0.35;
	ROUGHNESS = 0.18;
	SPECULAR = 0.8;
}
