// Mar de nubes visto desde arriba (islas flotantes): nubes esponjosas que derivan.
shader_type spatial;
render_mode diffuse_lambert;

#include "res://shaders/scenery_noise.gdshaderinc"

uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.68, 0.78, 0.92, 1.0);
uniform vec4 gap_color : source_color = vec4(0.42, 0.62, 0.9, 1.0);
uniform vec2 drift = vec2(0.18, 0.05);
uniform float scale = 0.35;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = sc_noise(wpos.xz * scale * 1.5 - drift * TIME * 0.5);
	VERTEX.y += n * 0.25;
}

void fragment() {
	vec2 p = wpos.xz * scale - drift * TIME * 0.12;
	float c = sc_fbm(p) * 0.75 + sc_noise(p * 3.0 + TIME * 0.03) * 0.25;
	float cover = smoothstep(0.32, 0.55, c + COLOR.r * 0.2);
	float puff = smoothstep(0.45, 0.8, c);
	vec3 col = mix(gap_color.rgb, mix(shade_color.rgb, cloud_color.rgb, puff), cover);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = col * 0.15;
}
