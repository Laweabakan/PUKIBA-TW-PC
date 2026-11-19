// Vacío: remolino violeta con estrellas que titilan y un brillo ondulante en el borde.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/scenery_noise.gdshaderinc"

uniform vec4 dark_color : source_color = vec4(0.04, 0.0, 0.08, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.2, 0.95, 1.0);
uniform vec4 star_color : source_color = vec4(0.9, 0.8, 1.0, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME * 0.25;
	vec2 q = vec2(sc_fbm(p * 0.6 + t), sc_fbm(p * 0.6 - t + 3.0));
	float swirl = sc_fbm(p * 0.9 + q * 2.5 + vec2(t * 0.7, -t * 0.4));
	vec3 col = mix(dark_color.rgb, glow_color.rgb, smoothstep(0.35, 0.85, swirl) * 0.8);
	// Estrellas
	vec2 sp = p * 6.0;
	float sh = sc_hash(floor(sp));
	float star = step(0.93, sh) * smoothstep(0.25, 0.0, length(fract(sp) - 0.5));
	star *= 0.5 + 0.5 * sin(TIME * 3.0 + sh * 40.0);
	col += star_color.rgb * star;
	// Borde brillante
	col += glow_color.rgb * smoothstep(0.55, 1.0, COLOR.r) * (0.6 + 0.4 * sin(TIME * 2.0 + p.x));
	ALBEDO = col;
}
