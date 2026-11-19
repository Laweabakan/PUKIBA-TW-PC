// Pájaros / murciélagos: las alas (|x| grande) aletean en el shader.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 albedo : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform float flap_speed = 9.0;
uniform float flap = 0.9;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 3.1 + o.z * 1.7;
	VERTEX.y += abs(VERTEX.x) * sin(TIME * flap_speed + ph) * flap;
}

void fragment() {
	ALBEDO = albedo.rgb;
}
