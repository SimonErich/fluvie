import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slides/render_stage.dart';

void main() {
  test('off the web, the app root passes through unchanged', () {
    // The desktop renders through its own off-screen pipeline; only the web
    // build mounts a FluvieWebStage capture surface around the app.
    const app = SizedBox.shrink();
    expect(wrapWithRenderStage(app), same(app));
  });
}
