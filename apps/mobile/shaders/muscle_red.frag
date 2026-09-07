#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec3 uSourceRed;
uniform sampler2D uImage;
out vec4 fragColor;

void main() {
  vec4 sampleColor = texture(uImage, FlutterFragCoord().xy / uSize);
  // Texture samples are premultiplied. Classify the actual RGB, including
  // partially transparent edges, then restore the ORIGINAL alpha unchanged.
  vec3 rgb = sampleColor.rgb / max(sampleColor.a, 0.00001);
  float redDominance = (rgb.r - max(rgb.g, rgb.b)) / max(rgb.r, 0.00001);
  float mask = smoothstep(0.15, 0.35, redDominance);
  vec3 targetRed = vec3(234.0, 78.0, 69.0) / 255.0;
  // Match the existing glutes red without flattening texture and shadows.
  // Per-channel gains retain the source variations; glutes gains are 1.
  vec3 corrected = clamp(rgb * targetRed / uSourceRed, 0.0, 1.0);
  fragColor = vec4(mix(rgb, corrected, mask) * sampleColor.a, sampleColor.a);
}
