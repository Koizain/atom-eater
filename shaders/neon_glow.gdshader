shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.3, 0.5, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float glow_radius : hint_range(0.0, 0.5) = 0.15;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);

	// Distance from center for glow falloff
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);

	// Glow contribution
	float glow = smoothstep(0.5, 0.5 - glow_radius, dist) * glow_intensity * pulse;

	// Combine original with glow
	vec3 final_color = tex_color.rgb + glow_color.rgb * glow * tex_color.a;
	COLOR = vec4(final_color, tex_color.a);
}
