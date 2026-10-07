#version 460 core
#include <flutter/runtime_effect.glsl>

// A 3D LUT over the rendered child (phase V6.2).
//
// uLut is the cube flattened to 2D: uSize slices of uSize x uSize tiled
// horizontally, blue selecting the tile, red across, green down — exactly
// CubeLut.toRgbaBytes. The sampler is not guaranteed to filter, so the
// trilinear read is spelled out: four exact-center taps per slice, mixed by
// the red and green fractions, two slices mixed by the blue fraction. The
// colour-space contract: both samplers hold non-linear sRGB, the LUT
// indexes on encoded values and answers encoded values. uIntensity mixes
// toward the untouched child, so zero is exactly the input frame.

precision highp float;

// Slot 0,1 — the child size in physical pixels.
uniform vec2 uResolution;
// Slot 2 — how far toward the graded frame to move, in [0, 1].
uniform float uIntensity;
// Slot 3 — points per axis (the .cube LUT_3D_SIZE).
uniform float uSize;

uniform sampler2D uChild;
uniform sampler2D uLut;

out vec4 fragColor;

vec3 tap(float r, float g, float slice) {
  float u = (slice * uSize + r + 0.5) / (uSize * uSize);
  float v = (g + 0.5) / uSize;
  return texture(uLut, vec2(u, v)).rgb;
}

vec3 sliceRead(vec3 rgb, float slice) {
  float rs = rgb.r * (uSize - 1.0);
  float gs = rgb.g * (uSize - 1.0);
  float r0 = floor(rs);
  float g0 = floor(gs);
  float r1 = min(r0 + 1.0, uSize - 1.0);
  float g1 = min(g0 + 1.0, uSize - 1.0);
  vec3 top = mix(tap(r0, g0, slice), tap(r1, g0, slice), fract(rs));
  vec3 bottom = mix(tap(r0, g1, slice), tap(r1, g1, slice), fract(rs));
  return mix(top, bottom, fract(gs));
}

vec3 graded(vec3 rgb) {
  float scaled = rgb.b * (uSize - 1.0);
  float lower = floor(scaled);
  float upper = min(lower + 1.0, uSize - 1.0);
  return mix(sliceRead(rgb, lower), sliceRead(rgb, upper), fract(scaled));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 source = texture(uChild, uv);
  if (source.a <= 0.0) {
    fragColor = source;
    return;
  }
  vec3 straight = clamp(source.rgb / source.a, 0.0, 1.0);
  fragColor = vec4(mix(straight, graded(straight), uIntensity) * source.a, source.a);
}
