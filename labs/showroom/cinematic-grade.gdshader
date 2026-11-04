shader_type canvas_item;
render_mode unshaded;
uniform sampler2D rendered_scene : hint_screen_texture, filter_linear;
void fragment() {
    vec3 c = texture(rendered_scene, SCREEN_UV).rgb;
    float luminance = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(luminance), c, 0.94);
    float highlight = smoothstep(0.25, 0.85, luminance);
    c *= mix(vec3(0.985, 1.0, 1.015), vec3(1.035, 1.005, 0.955), highlight);
    vec2 p = (SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.82);
    float vignette = smoothstep(0.16, 0.61, length(p));
    c *= 1.0 - 0.24 * vignette;
    COLOR = vec4(c, 1.0);
}
