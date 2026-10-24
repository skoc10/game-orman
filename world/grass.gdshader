// Çimen öbekleri: dipten uca renk geçişi ve rüzgarda sallanma.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.18, 0.32, 0.12, 1.0);
uniform vec4 tip_color : source_color = vec4(0.48, 0.62, 0.25, 1.0);
uniform float height = 0.6;

varying float tip;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	tip = clamp(VERTEX.y / height, 0.0, 1.0);
	float t = TIME * 1.8 + origin.x * 0.3 + origin.z * 0.25;
	VERTEX.x += sin(t) * tip * 0.08;
	VERTEX.z += cos(t * 0.7) * tip * 0.06;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(base_color.rgb, tip_color.rgb, tip) * COLOR.rgb;
	ROUGHNESS = 1.0;
}
