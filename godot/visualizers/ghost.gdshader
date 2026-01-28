shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform vec4 albedo : source_color = vec4(0.0, 1.0, 0.0, 0.35);
uniform float fresnel_power = 2.5;
uniform float edge_intensity = 1.5;
uniform float fill_amount = 0.05;

void fragment() {
    ALBEDO = albedo.rgb;
    
    // Fresnel effect
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
    
    // Combine fill and edge
    float alpha = clamp((fresnel * edge_intensity) + fill_amount, 0.0, 1.0);
    
    // Apply albedo alpha as well
    ALPHA = alpha * albedo.a;
}
