import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/serialization/spec_validation.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

/// The conformance corpus: every fixture under `corpus/` must parse clean,
/// re-serialize canonically, keep a stable digest, and build. Every spec
/// change adds a fixture here, so the codecs, the validator, and the
/// documents they describe can never drift apart.
void main() {
  final corpus = Directory('test/serialization/corpus')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.fluvie.json'))
      .toList(growable: false);

  test('the corpus is not empty', () {
    expect(corpus, isNotEmpty);
  });

  for (final file in corpus) {
    final name = file.uri.pathSegments.last;

    group(name, () {
      late Map<String, Object?> json;

      setUp(() {
        json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      });

      test('has no unknown properties', () {
        expect(unknownSpecProps(json), isEmpty);
      });

      test('re-serializes canonically (idempotent round-trip)', () {
        final once = VideoSpec.fromJson(json).toJson();
        final twice = VideoSpec.fromJson(once).toJson();
        expect(twice, once);
      });

      test('keeps a stable digest across a round-trip', () {
        final spec = VideoSpec.fromJson(json);
        final reparsed = VideoSpec.fromJson(spec.toJson());
        expect(reparsed.digest(), spec.digest());
      });

      test('builds a Video', () {
        expect(VideoSpec.fromJson(json).build(), isA<Video>());
      });
    });
  }
}
