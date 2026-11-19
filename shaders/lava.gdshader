// Lava que burbujea: costra oscura con grietas incandescentes que laten.
shader_type spatial;
render_mode diffuse_lambert;

#include "res://shaders/scenery_noise.gdshaderinc"

uniform vec4 crust_color : source_color = vec4(0.16, 0.07, 0.05, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.42, 0.06, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec2 flow = vec2(0.12, 0.0);
uniform float glow = 2.2;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 0.9 + wpos.x * 1.5 + wpos.z * 2.0) * 0.012;
}

void fragment() {
	vec2 p = wpos.xz - flow * TIME;
	float cracks = sc_cells(p * 1.6 + vec2(sc_noise(p * 2.0 + TIME * 0.1)) * 0.4);
	float heat = 1.0 - smoothstep(0.02, 0.22, cracks);
	float pulse = 0.65 + 0.35 * sin(TIME * 2.3 + sc_noise(p * 0.7) * 6.28);
	// Burbujas que aparecen y estallan
	vec2 bp = wpos.xz * 2.5;
	vec2 bi = floor(bp);
	float bh = sc_hash(bi);
	float bt = fract(TIME * (0.3 + bh * 0.4) + bh * 7.0);
	float bubble = smoothstep(0.3 * bt + 0.02, 0.0, length(fract(bp) - 0.5)) * step(0.7, bh) * (1.0 - bt);
	float shore = COLOR.r;
	float hot = clamp(heat * pulse + bubble + (1.0 - shore) * 0.25 * sc_noise(p * 3.0), 0.0, 1.0);
	vec3 col = mix(crust_color.rgb, hot_color.rgb, hot);
	col = mix(col, core_color.rgb, smoothstep(0.75, 1.0, hot));
	ALBEDO = col * 0.6;
	EMISSION = mix(hot_color.rgb * 0.15, col, hot) * glow;
	ROUGHNESS = 0.9;
}
