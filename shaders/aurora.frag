#version 460 core
#include <flutter/runtime_effect.glsl>

// Aurora / energy-field background.
// A GPU fragment shader (GLSL) that produces a smooth, animated, layered
// gradient with flowing value-noise. Runs per-pixel on Impeller (mobile) and
// CanvasKit (web). Driven from Dart via FragmentShader uniforms.

precision highp float;

uniform vec2 uSize;     // canvas size in pixels        (floats 0,1)
uniform float uTime;    // seconds since start          (float  2)
uniform vec3 uColor1;   // bottom / base colour         (floats 3,4,5)
uniform vec3 uColor2;   // mid colour                   (floats 6,7,8)
uniform vec3 uColor3;   // highlight / glow colour      (floats 9,10,11)

out vec4 fragColor;

// --- cheap value noise -------------------------------------------------------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// fractal brownian motion (a few octaves of noise)
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    float t = uTime * 0.12;

    // flowing distortion field
    vec2 q = vec2(
        fbm(uv * 3.0 + vec2(t, t * 0.6)),
        fbm(uv * 3.0 + vec2(-t * 0.8, t * 1.1) + 5.2)
    );
    float n = fbm(uv * 3.0 + q * 1.5 + vec2(t * 0.5, -t * 0.4));

    // vertical base gradient blended with the noise field
    float g = clamp(uv.y + (n - 0.5) * 0.7, 0.0, 1.0);
    vec3 col = mix(uColor1, uColor2, smoothstep(0.0, 1.0, g));

    // soft glowing ribbons of the highlight colour
    float glow = smoothstep(0.55, 0.95, n);
    col = mix(col, uColor3, glow * 0.65);

    // gentle diagonal light sweep
    float sweep = 0.5 + 0.5 * sin((uv.x + uv.y) * 3.1415 - uTime * 0.8);
    col += uColor3 * sweep * 0.06;

    // vignette for depth
    float vig = smoothstep(1.25, 0.35, length(uv - 0.5));
    col *= 0.70 + 0.30 * vig;

    fragColor = vec4(col, 1.0);
}
