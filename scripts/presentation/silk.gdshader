shader_type spatial;
// The safety line's ribbon (A-017, chunk 6A): a camera-facing strip, UV.x running -1 to 1 across it, UV2.x the share of
// the half width that is core and UV2.y the share where the rim ends. Both edges are smoothed over one pixel, centred on
// the edge. A dark core inside a thin light rim reads on pale and on dark backgrounds;
// an old line uses the same colour for both and is thin and pale. Unshaded, alpha blended, depth tested and never
// writing depth, so the world hides it as it hides anything else (no X-ray).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 core_color : source_color = vec4(0.06, 0.07, 0.10, 1.0);
uniform vec4 rim_color : source_color = vec4(0.97, 0.96, 0.92, 1.0);
uniform float opacity = 1.0;

void fragment() {
	float d = abs(UV.x);
	float w = max(fwidth(d), 1e-4);   // one pixel across the strip
	float core = 1.0 - smoothstep(UV2.x - 0.5 * w, UV2.x + 0.5 * w, d);
	float body = 1.0 - smoothstep(UV2.y - 0.5 * w, UV2.y + 0.5 * w, d);
	ALBEDO = mix(rim_color.rgb, core_color.rgb, core);
	ALPHA = body * opacity;
}
