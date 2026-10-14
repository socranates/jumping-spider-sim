// VISUAL-01: Phidippus audax chelicerae, metallic green that turns teal-blue toward grazing angles. Compatibility-safe.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 face_color : source_color = vec4(0.07, 0.62, 0.42, 1.0);
uniform vec4 edge_color : source_color = vec4(0.10, 0.26, 0.72, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.10, 0.08, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.85;
uniform float roughness : hint_range(0.0, 1.0) = 0.24;

void fragment() {
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 sheen = mix(edge_color.rgb, face_color.rgb, pow(ndotv, 0.8));
	ALBEDO = mix(deep_color.rgb, sheen, 0.35 + 0.65 * ndotv);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = sheen * pow(1.0 - ndotv, 3.0) * 0.12;
}
