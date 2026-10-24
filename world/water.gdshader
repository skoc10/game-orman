// Low-poly su: hafif dalga, derinliğe göre renk ve kıyıda köpük.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.22, 0.55, 0.58, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.18, 0.30, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.92, 0.95, 1.0);
uniform float depth_fade = 3.5;
uniform float foam_width = 0.35;
// Gece suyu karartmak için DayNight tarafından ayarlanır.
uniform float brightness = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.35 + TIME * 1.1) * 0.06 + cos(world_pos.z * 0.29 + TIME * 0.8) * 0.06;
	VERTEX.y += w;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = max(VERTEX.z - behind.z, 0.0);

	float t = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, t);
	float foam = 1.0 - smoothstep(0.0, foam_width, water_depth);
	col = mix(col, foam_color.rgb, foam * 0.7);

	ALBEDO = col * brightness;
	ALPHA = clamp(mix(0.55, 0.93, t) + foam * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
