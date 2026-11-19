// Agua que fluye con espuma en las orillas (también oasis y pantano según los uniforms).
// COLOR.r = cercanía a la orilla (1 en el borde).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/scenery_noise.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.12, 0.32, 0.55, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.25, 0.58, 0.72, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform vec2 flow = vec2(0.35, 0.0);
uniform float foam_amount = 1.0;
uniform float sparkle = 1.0;
uniform float wave_height = 0.015;
uniform float weed_amount = 0.0; // lentejas de agua (pantano)
uniform vec4 weed_color : source_color = vec4(0.35, 0.5, 0.15, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.7 + wpos.x * 2.1 + wpos.z * 1.3) * wave_height;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	float shore = COLOR.r;
	float n1 = sc_fbm(p * 1.3 - flow * t);
	float n2 = sc_noise(p * 3.1 - flow * t * 1.6 + vec2(4.0, 1.0));
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(shore * 0.9 + n1 * 0.45, 0.0, 1.0));
	// Ondas brillantes que viajan con la corriente
	float ripple = smoothstep(0.6, 0.7, sc_noise(p * vec2(2.2, 4.0) - flow * t * 2.0) * 0.6 + n2 * 0.4);
	col = mix(col, foam_color.rgb, ripple * 0.3 * sparkle);
	// Espuma en las orillas (franja que late)
	float edge = shore + (n2 - 0.5) * 0.35 + sin(t * 2.0 + n1 * 6.0) * 0.06;
	float foam = smoothstep(0.62, 0.78, edge) * foam_amount;
	col = mix(col, foam_color.rgb, foam);
	// Lentejas de agua del pantano: manchas que derivan despacio
	float weed = smoothstep(0.56, 0.62, sc_fbm(p * 0.9 + vec2(t * 0.02, t * 0.015))) * weed_amount;
	col = mix(col, weed_color.rgb * (0.8 + n2 * 0.4), weed);
	ALBEDO = col;
	ROUGHNESS = mix(0.12, 0.8, max(foam, weed));
	SPECULAR = 0.6;
}
