import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/code_composition.dart';

void main() {
  group('playgroundHarnessSource', () {
    final source = playgroundHarnessSource();

    test('statically imports the sibling input.dart as user', () {
      expect(source, contains("import 'input.dart' as user;"));
    });

    test('builds the entry from the user builder', () {
      expect(source, contains('compositionFromVideo(user.build)'));
    });

    test('loads the real fonts before capturing', () {
      expect(source, contains('await loadFonts()'));
    });

    test('reads the same export defines the permanent harness reads', () {
      for (final name in [
        'FLUVIE_RENDER_OUT_DIR',
        'FLUVIE_RENDER_FRAMES',
        'FLUVIE_RENDER_FORMAT',
        'FLUVIE_RENDER_QUALITY',
        'FLUVIE_RENDER_ASPECT',
        'FLUVIE_RENDER_POSTER',
      ]) {
        expect(source, contains(name), reason: name);
      }
    });

    test('reads FLUVIE_PROGRESS_FILE from the environment', () {
      expect(source, contains("Platform.environment['FLUVIE_PROGRESS_FILE']"));
    });

    test('drives the shared runCaptureHarness via the test-tree helper', () {
      expect(source, contains('runCaptureHarness('));
      // render_harness lives in the test tree, so it is reached by a relative
      // import that climbs out of the generated per-render directory.
      expect(source, contains("import '../../test/render/render_harness.dart'"));
    });

    test('the harness-helper directory is configurable', () {
      final custom = playgroundHarnessSource(harnessHelperDir: '../helpers');
      expect(custom, contains("import '../helpers/render_harness.dart'"));
    });

    test('a custom input import name is honored', () {
      final custom = playgroundHarnessSource(inputImport: 'snippet.dart');
      expect(custom, contains("import 'snippet.dart' as user;"));
    });
  });
}
