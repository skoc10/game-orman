// Gökyüzü: gün içi renk geçişi, güneş, ay ve gece yıldızları.
// Tüm değerler DayNight tarafından her karede güncellenir.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.25, 0.48, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.80, 0.92);
uniform vec3 ground_color : source_color = vec3(0.20, 0.22, 0.20);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float sun_amount = 1.0;
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float moon_amount = 0.0;
uniform float star_amount = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(pow(-h, 0.35), 0.0, 1.0));
	}

	if (AT_CUBEMAP_PASS == false) {
		float sd = dot(dir, normalize(sun_dir));
		col += sun_color * smoothstep(0.9993, 0.9996, sd) * sun_amount * 4.0;
		col += sun_color * pow(max(sd, 0.0), 12.0) * 0.25 * sun_amount;

		float md = dot(dir, normalize(moon_dir));
		col += vec3(0.85, 0.88, 0.95) * smoothstep(0.9990, 0.9993, md) * moon_amount * 1.5;
		col += vec3(0.3, 0.35, 0.5) * pow(max(md, 0.0), 30.0) * 0.15 * moon_amount;

		if (star_amount > 0.0 && h > 0.0) {
			vec3 cell = floor(dir * 220.0);
			float s = hash(cell);
			float star = step(0.9975, s) * (0.5 + 0.5 * sin(TIME * 2.0 + s * 100.0));
			col += vec3(star) * star_amount * smoothstep(0.0, 0.25, h);
		}
	}
	COLOR = col;
}
