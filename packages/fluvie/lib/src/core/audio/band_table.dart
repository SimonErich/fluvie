import 'dart:convert';
import 'dart:typed_data';

import 'package:fluvie/src/core/audio_band.dart';
import 'package:meta/meta.dart';

/// One energy value per video frame per frequency band — the
/// precomputed input every reactive animation reads.
///
/// The frequency analyzer decodes a track once before frame 0, runs the
/// in-house DSP, and resamples the per-hop band sums onto one value per video
/// frame; the result is this immutable table. During the frame loop a reactive
/// effect calls [energyAt] (a pure clamped lookup, never live audio), so the
/// frame stays the only clock and the render stays deterministic.
///
/// The table is value-equal by contents and round-trips through [toJson] /
/// [BandTable.fromJson] byte-stably (bands always serialize in `AudioBand`
/// order), so
/// it can be content-hash cached as JSON and reloaded without recomputing the
/// DSP. It lives in `core` because it carries only `dart:typed_data` and the
/// `AudioBand` enum.
@immutable
final class BandTable {
  /// Creates a table over per-band energy lists; every band present must share
  /// one length (the [totalFrames]). An absent band reads as zero.
  BandTable(Map<AudioBand, Float64List> energies)
    : _energies = {
        for (final entry in energies.entries) entry.key: Float64List.fromList(entry.value),
      };

  /// Rebuilds a table from the JSON produced by [toJson].
  factory BandTable.fromJson(Map<String, Object?> json) => BandTable({
    for (final band in AudioBand.values)
      if (json[band.name] case final List<Object?> values)
        band: Float64List.fromList([for (final v in values) (v! as num).toDouble()]),
  });

  /// Resamples per-hop band sums onto one value per video frame.
  ///
  /// Each hop `h` sits at sample `h · hopSize`, i.e. `h · hopSize / sampleRate ·
  /// fps` video frames; every video frame takes the energy of the nearest hop,
  /// so a 1024/512 analysis (≈86 hops/s) maps cleanly onto 30 or 60 fps. The
  /// table is normalized into `[0, 1]` per band (the loudest hop becomes `1`) so
  /// `gain` is a recognisable multiplier regardless of the track's level. Pure:
  /// identical hops always produce an identical table.
  factory BandTable.fromHops(
    Map<AudioBand, Float64List> hopEnergies, {
    required int hopSize,
    required int sampleRate,
    required int fps,
    required int totalFrames,
  }) => BandTable({
    for (final band in AudioBand.values)
      if (hopEnergies[band] case final Float64List hops)
        band: _resampleHops(
          hops,
          hopSize: hopSize,
          sampleRate: sampleRate,
          fps: fps,
          totalFrames: totalFrames,
        ),
  });

  final Map<AudioBand, Float64List> _energies;

  /// The number of video frames this table covers (the per-band length, or `0`
  /// when the table is empty).
  int get totalFrames => _energies.isEmpty ? 0 : _energies.values.first.length;

  /// The per-frame energies for [band], or an empty list when the band is
  /// absent.
  Float64List energiesFor(AudioBand band) => _energies[band] ?? Float64List(0);

  /// The energy of [band] at [frame], clamped to the table's bounds.
  ///
  /// A frame before `0` reads the first sample and a frame past the end reads
  /// the last, so a reactive effect never indexes out of range. An absent or
  /// empty band reads `0`.
  double energyAt(int frame, AudioBand band) {
    final energies = _energies[band];
    if (energies == null || energies.isEmpty) return 0;
    final index = frame.clamp(0, energies.length - 1);
    return energies[index];
  }

  /// The JSON form: each present band's name mapped to its energy list, always
  /// emitted in `AudioBand` order so two encodes are byte-identical.
  Map<String, Object?> toJson() => {
    for (final band in AudioBand.values)
      if (_energies[band] case final Float64List energies) band.name: energies.toList(),
  };

  /// The encoded JSON string — the byte-stable content-hash cache payload.
  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) {
    if (other is! BandTable) return false;
    if (other._energies.length != _energies.length) return false;
    for (final band in AudioBand.values) {
      final mine = _energies[band];
      final theirs = other._energies[band];
      if ((mine == null) != (theirs == null)) return false;
      if (mine == null || theirs == null) continue;
      if (mine.length != theirs.length) return false;
      for (var i = 0; i < mine.length; i++) {
        if (mine[i] != theirs[i]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    for (final band in AudioBand.values)
      if (_energies[band] case final Float64List energies)
        Object.hash(band, Object.hashAll(energies)),
  ]);

  @override
  String toString() => 'BandTable(totalFrames: $totalFrames, bands: ${_energies.keys.toList()})';
}

/// Resamples one band's per-hop [hops] onto [totalFrames] per-frame values,
/// nearest-hop, then peak-normalized into `[0, 1]`.
Float64List _resampleHops(
  Float64List hops, {
  required int hopSize,
  required int sampleRate,
  required int fps,
  required int totalFrames,
}) {
  final out = Float64List(totalFrames);
  if (hops.isEmpty || totalFrames == 0) return out;
  var peak = 0.0;
  for (var frame = 0; frame < totalFrames; frame++) {
    final seconds = frame / fps;
    final hop = (seconds * sampleRate / hopSize).round().clamp(0, hops.length - 1);
    final value = hops[hop];
    out[frame] = value;
    if (value > peak) peak = value;
  }
  if (peak > 0) {
    for (var frame = 0; frame < totalFrames; frame++) {
      out[frame] = out[frame] / peak;
    }
  }
  return out;
}
