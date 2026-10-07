part of 'spec_validation.dart';

/// The audio lists' unknown-property check: each track is closed over its
/// kind's key set ([AudioTrackSpec.musicKeys]/[AudioTrackSpec.sfxKeys]), with
/// the nested `source` and `trim` objects closed too.
///
/// Name-level only, like the rest of the validator: a non-list `audio`, a
/// non-object track, and an unknown `kind` are skipped here because the
/// parser reports them with types and structure.
void _checkAudioTracks(Object? audio, List<String> path, List<FluvieSpecWarning> out) {
  if (audio is! List) return;
  for (var i = 0; i < audio.length; i++) {
    final track = audio[i];
    if (track is! Map<String, Object?>) continue;
    final trackPath = [...path, '$i'];
    final (Set<String> allowed, String subject) = switch (track['kind']) {
      'music' => (AudioTrackSpec.musicKeys, 'a music audio track'),
      'sfx' => (AudioTrackSpec.sfxKeys, 'an sfx audio track'),
      _ => (const <String>{}, ''), // Unknown kind: the parser reports it.
    };
    if (allowed.isEmpty) continue;
    _checkKeys(track, allowed, subject, trackPath, out);
    _checkNested(track, 'source', const {'kind', 'value'}, 'an audio source', trackPath, out);
    _checkNested(track, 'trim', const {'from', 'to'}, 'an audio trim', trackPath, out);
  }
}
