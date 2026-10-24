// Ekran kenarı efektleri: hasar ve düşük can (kırmızı), mide bulantısı (yeşil),
// soğuk (buz mavisi) ve su altı renk tonu.
shader_type canvas_item;

uniform float damage = 0.0;
uniform float low_health = 0.0;
uniform float nausea = 0.0;
uniform float cold = 0.0;
uniform float underwater = 0.0;

vec4 over(vec4 top, vec4 base) {
	float a = top.a + base.a * (1.0 - top.a);
	vec3 rgb = (top.rgb * top.a + base.rgb * base.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(rgb, a);
}

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.5, 1.0));
	float edge = smoothstep(0.32, 0.95, d);
	float pulse = 0.65 + 0.35 * sin(TIME * 4.0);

	vec4 c = vec4(0.04, 0.22, 0.32, 0.42 * underwater);
	c = over(vec4(0.75, 0.88, 1.0, edge * cold * 0.6), c);
	c = over(vec4(0.25, 0.45, 0.08, edge * nausea * 0.45), c);
	c = over(vec4(0.55, 0.0, 0.0, edge * clamp(damage + low_health * pulse * 0.7, 0.0, 0.9)), c);
	COLOR = c;
}
