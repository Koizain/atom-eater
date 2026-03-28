shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.3, 0.5, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.3;
uniform float entity_phase : hint_range(0.0, 100.0) = 0.0;
uniform float speed_factor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center) * 2.0; // 0 at center, 1 at edge

	// Animated pulse with per-entity phase offset
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed + entity_phase);

	// Speed boost: faster entities glow brighter
	float speed_boost = 1.0 + speed_factor * 1.5;

	// === PASS 1: Tight inner glow (sharp neon core) ===
	float tight_glow = smoothstep(1.0, 0.3, dist) * 2.0;

	// === PASS 2: Medium glow (main neon body) ===
	float med_glow = smoothstep(1.2, 0.0, dist) * 0.8;

	// === PASS 3: Wide bloom (soft outer halo) ===
	float wide_bloom = smoothstep(1.8, 0.0, dist) * 0.3;

	// Combine glow layers
	float total_glow = (tight_glow + med_glow + wide_bloom) * glow_intensity * pulse * speed_boost;

	// === Chromatic aberration on glow edges ===
	// Shift RGB channels outward from center at the glow boundary
	float aberration_strength = 0.012 * smoothstep(0.2, 0.8, dist) * speed_boost;
	vec2 dir_from_center = normalize(UV - center);

	// Red shifts outward, blue shifts inward
	vec2 uv_r = UV + dir_from_center * aberration_strength;
	vec2 uv_b = UV - dir_from_center * aberration_strength;

	float r_sample = texture(TEXTURE, uv_r).r;
	float g_sample = tex_color.g;
	float b_sample = texture(TEXTURE, uv_b).b;

	vec3 aberrated_tex = vec3(r_sample, g_sample, b_sample);

	// Edge color shift: warm tint at outer edges of glow
	vec3 edge_tint = mix(glow_color.rgb, vec3(glow_color.r + 0.2, glow_color.g * 0.7, glow_color.b + 0.3), smoothstep(0.4, 1.0, dist));

	// Final compositing
	vec3 glow_contribution = edge_tint * total_glow;
	vec3 final_color = aberrated_tex + glow_contribution * tex_color.a;

	// Hot white core
	float core_boost = smoothstep(0.5, 0.0, dist) * 0.4 * pulse;
	final_color += vec3(core_boost);

	COLOR = vec4(final_color, tex_color.a + wide_bloom * 0.15 * tex_color.a);
}
