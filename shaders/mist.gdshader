// Bruma / niebla que deriva a ras de suelo (plano transparente).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/scenery_noise.gdshaderinc"

uniform vec4 mist_color : source_color = vec4(0.7, 0.85, 0.7, 1.0);
uniform float density = 0.5;
uniform vec2 drift = vec2(0.12, 0.04);
uniform float scale = 0.25;
uniform vec2 board_half = vec2(6.0, 10.0); // medio tablero: allí la bruma casi desaparece
uniform float board_alpha = 0.15;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale - drift * TIME;
	float n = sc_fbm(p) * 0.7 + sc_noise(p * 2.7 + TIME * 0.05) * 0.3;
	float a = smoothstep(0.4, 0.75, n) * density;
	// Se desvanece hacia el borde del plano (UV 0..1)
	vec2 e = min(UV, 1.0 - UV);
	a *= smoothstep(0.0, 0.15, min(e.x, e.y));
	float out_d = max(abs(wpos.x) - board_half.x, abs(wpos.z) - board_half.y);
	a *= mix(board_alpha, 1.0, smoothstep(-0.5, 1.5, out_d));
	ALBEDO = mist_color.rgb;
	ALPHA = a;
}
