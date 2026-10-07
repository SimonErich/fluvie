import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/snippets/render_request_snippets.dart';

void main() {
  test('documented custom adapter receives exact canvas and authored frame window', () {
    const composition = SizedBox();
    final cancellation = RenderCancellation();
    final request = excerptRequest(composition, cancellation);
    expect(request.composition, same(composition));
    expect((request.width, request.height, request.fps), (480, 270, 30));
    expect((request.startFrame, request.frameCount, request.posterFrame), (120, 60, 15));
    expect(request.audio, isTrue);
    expect(request.cancellation, same(cancellation));
  });
}
