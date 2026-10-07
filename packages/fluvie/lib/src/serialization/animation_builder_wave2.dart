part of 'animation_builder.dart';

/// The wave-2 tranche of the preset dispatch: color data, the pixel
/// post-effects, the reactive presets, and the path-following `along` form.
/// Reactive `track` ids resolve through the document's shared [AnchorTable]
/// so anchor identity survives serialization (mirroring `Bars`).
Animation _wave2Animation(AnimationSpec spec, AnchorTable anchors) {
  final at = spec.at ?? Trigger.auto;
  final delay = spec.delay ?? Time.zero;
  final args = spec.args;
  switch (spec.kind) {
    case 'color':
      return Animation.color(
        to: decodeColor(args['to'], path: const ['to']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'gradientShift':
      return Animation.gradientShift(
        to: _colorList(args['to']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'scanlines':
      return Animation.scanlines(
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'chromatic':
      return Animation.chromatic(
        _double(args['px']) ?? 0,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'bloom':
      return Animation.bloom(
        _double(args['amount']) ?? 0,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'parallax':
      return Animation.parallax(
        depth: _double(args['depth']) ?? 0.2,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'particles':
      return Animation.particles(
        decodeParticles(args['spec'], path: const ['spec']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'shader':
      return Animation.shader(
        _shaderAsset(args['asset']),
        uniforms: _uniforms(args['uniforms']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'scaleY':
      return Animation.scaleY(
        on: decodeEnum(AudioBand.values, args['on'], 'band', path: const ['on']),
        gain: _double(args['gain']) ?? 1.0,
        track: _trackAnchor(args['track'], anchors),
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'along':
      return Animation.along(
        _svgPath(args['path']),
        orient: args['orient'] != false,
        phase: args['phase'] == null
            ? null
            : decodeEnum(AnimationPhase.values, args['phase'], 'phase', path: const ['phase']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
  }
  // coverage:ignore-line unreachable AnimationSpec fromJson validates the kind before this dispatch
  throw FluvieSpecError('Unknown animation kind "${spec.kind}"');
}
