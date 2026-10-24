// Low-poly görünüm: her üçgen ekran türevlerinden hesaplanan düz normalle aydınlanır.
// Arazi, ağaçlar, kayalar ve yer tutucu modeller bu shader'ı kullanır.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
// Rüzgarda sallanma miktarı (yapraklar için). 0 ise sabit.
uniform float sway = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

void vertex() {
	if (sway > 0.0) {
		vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float t = TIME * 1.3 + origin.x * 0.21 + origin.z * 0.17;
		float k = max(VERTEX.y - 1.0, 0.0) * sway;
		VERTEX.x += sin(t) * k * 0.04;
		VERTEX.z += cos(t * 0.8) * k * 0.03;
	}
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	// Köşe renkleri sRGB yazılır; ışık hesabı için doğrusal uzaya çevrilir.
	vec3 c = COLOR.rgb;
	c = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThan(c, vec3(0.04045))));
	ALBEDO = albedo.rgb * c;
	ROUGHNESS = roughness;
	EMISSION = emission.rgb * emission_energy;
}
