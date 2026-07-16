import 'package:fluvie_cli/src/templates/file_harness_template.dart';
import 'package:test/test.dart';

void main() {
  group('fileHarnessSource', () {
    test('statically imports the target so flutter test JIT-compiles it', () {
      // The static import is the only way to load arbitrary user code into a
      // pre-built tester.
      final source = fileHarnessSource(targetImport: '../../example_video.dart');

      expect(source, contains("import '../../example_video.dart' as target;"));
    });

    test('imports a package: target as given', () {
      final source = fileHarnessSource(targetImport: 'package:my_app/videos/hero.dart');

      expect(source, contains("import 'package:my_app/videos/hero.dart' as target;"));
    });

    test('calls the default build entry', () {
      final source = fileHarnessSource(targetImport: 'input.dart');

      expect(source, contains('video: target.build(),'));
    });

    test('calls a custom entry', () {
      final source = fileHarnessSource(targetImport: 'input.dart', entry: 'introClipVideo');

      expect(source, contains('video: target.introClipVideo(),'));
      expect(source, isNot(contains('target.build()')));
    });

    test('a null timeout is Timeout.none, which a trusted local render wants', () {
      final source = fileHarnessSource(targetImport: 'input.dart');

      expect(source, contains('timeout: Timeout.none'));
    });

    test('a duration becomes a bounded Timeout so a runaway build() is killed', () {
      final source = fileHarnessSource(
        targetImport: 'input.dart',
        timeout: const Duration(minutes: 6),
      );

      expect(source, contains('timeout: const Timeout(Duration(seconds: 360))'));
      expect(source, isNot(contains('Timeout.none')));
    });

    test('drives the shared capture pipeline and reads the CLI dart-defines', () {
      final source = fileHarnessSource(targetImport: 'input.dart');

      expect(source, contains('renderVideo('));
      expect(source, contains("String.fromEnvironment('FLUVIE_RENDER_OUT_DIR')"));
      expect(source, contains("String.fromEnvironment('FLUVIE_RENDER_KEY')"));
    });

    test('is marked generated so nobody edits it by hand', () {
      expect(fileHarnessSource(targetImport: 'input.dart'), startsWith('// GENERATED'));
    });

    test('is a pure function: the same arguments give the same source', () {
      // No IO, so the template is unit-tested without a Flutter toolchain.
      expect(
        fileHarnessSource(targetImport: 'input.dart'),
        fileHarnessSource(targetImport: 'input.dart'),
      );
    });
  });
}
