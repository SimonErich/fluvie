#version 460 core
#include <flutter/runtime_effect.glsl>

// Per-channel tone curves over the rendered child (phase V6.2).
//
// The child is rasterized and handed in as uChild; uLookup is a 256x1 strip
// whose R, G and B channels each hold that channel's baked curve (master
// composed in at bake time by ToneCurve on the CPU). The colour-space
// contract: both samplers hold non-linear sRGB, the curves index on the
// encoded values and answer encoded values, no transfer function on either
// side. uIntensity mixes toward the untouched child, so zero is exactly the
// input frame.

precision highp float;

// Slot 0,1 — the child size in physical pixels.
uniform vec2 uResolution;
// Slot 2 — how far toward the curved frame to move, in [0, 1].
uniform float uIntensity;

uniform sampler2D uChild;
uniform sampler2D uLookup;

out vec4 fragColor;

vec3 curved(vec3 rgb) {
  // Sample the strip at each channel's own value; half-texel insets keep the
  // read inside the 256 baked samples.
  float r = texture(uLookup, vec2(mix(0.5 / 256.0, 255.5 / 256.0, rgb.r), 0.5)).r;
  float g = texture(uLookup, vec2(mix(0.5 / 256.0, 255.5 / 256.0, rgb.g), 0.5)).g;
  float b = texture(uLookup, vec2(mix(0.5 / 256.0, 255.5 / 256.0, rgb.b), 0.5)).b;
  return vec3(r, g, b);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 source = texture(uChild, uv);
  if (source.a <= 0.0) {
    fragColor = source;
    return;
  }
  // Un-premultiply, curve the straight colour, re-premultiply: the curves
  // are authored over colour, not over coverage.
  vec3 straight = source.rgb / source.a;
  vec3 graded = curved(clamp(straight, 0.0, 1.0));
  fragColor = vec4(mix(straight, graded, uIntensity) * source.a, source.a);
}
