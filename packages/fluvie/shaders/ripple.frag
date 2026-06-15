#version 460 core
#include <flutter/runtime_effect.glsl>

// A small, dependency-free ripple/displacement shader (decision D13).
//
// It samples nothing external: the colour is a pure function of the fragment
// position, the resolution, and an animation progress. Concentric rings ripple
// out from the centre as `uProgress` advances, so the same progress always
// produces the same image (the determinism contract). Slot order is fixed and
// mirrored by `ShaderEffect`: resolution.x, resolution.y, then progress.

precision highp float;

// Slot 0,1 — the paint size in physical pixels (set by the painter).
uniform vec2 uResolution;
// Slot 2 — the animation progress in [0, 1] (frame-driven, never a clock).
uniform float uProgress;

out vec4 fragColor;

void main() {
  // Normalised coordinates in [0, 1], centred so the ripple radiates outward.
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec2 centred = uv - vec2(0.5);
  float dist = length(centred);

  // A travelling cosine ring: the phase advances with progress so the rings
  // move outward deterministically. Amplitude eases out toward the edges.
  float wave = cos((dist * 28.0) - (uProgress * 6.2831853));
  float ring = 0.5 + (0.5 * wave) * (1.0 - dist);

  // Tint the rings blue/cyan with a warm centre so the displacement reads
  // clearly against any child. Alpha tracks the ring so flat areas stay clear.
  float alpha = clamp(ring * 0.65, 0.0, 1.0);
  vec3 colour = mix(vec3(0.05, 0.35, 0.85), vec3(0.95, 0.85, 0.45), ring);
  fragColor = vec4(colour * alpha, alpha);
}
