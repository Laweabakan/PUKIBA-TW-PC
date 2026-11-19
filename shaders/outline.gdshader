shader_type spatial;
// Contorno estilo dibujo animado ("casco invertido"): se dibuja como pasada extra de los
// materiales, agrandando la malla unos píxeles en pantalla y pintando solo las caras traseras.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.16, 0.11, 0.08, 1.0);
uniform float width_px = 1.8; // grosor a 1280 px de alto (se escala con la resolución)

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 nv = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 dir = (PROJECTION_MATRIX * vec4(nv, 0.0)).xy;
	float len = length(dir);
	if (len > 0.0001) {
		dir /= len;
	}
	float px = width_px * VIEWPORT_SIZE.y / 1280.0;
	clip.xy += dir * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
