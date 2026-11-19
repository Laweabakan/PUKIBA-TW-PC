// Telón de cielo detrás de la cordillera: degradado con vetas de nubes que se desplazan.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://shaders/scenery_noise.gdshaderinc"

uniform vec4 horizon_color : source_color = vec4(0.85, 0.9, 0.95, 1.0);
uniform vec4 top_color : source_color = vec4(0.45, 0.65, 0.9, 1.0);
uniform vec4 streak_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float streaks = 0.5;

void fragment() {
	float h = 1.0 - UV.y; // 0 abajo, 1 arriba
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.05, 0.8, h));
	vec2 p = vec2(UV.x * 9.0 - TIME * 0.01, h * 5.0);
	float n = sc_fbm(p * vec2(1.0, 2.5));
	float band = smoothstep(0.55, 0.75, n) * smoothstep(0.85, 0.3, h) * streaks;
	col = mix(col, streak_color.rgb, band * 0.6);
	ALBEDO = col;
}
