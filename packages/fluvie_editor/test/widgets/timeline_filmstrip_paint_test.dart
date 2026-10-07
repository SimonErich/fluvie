import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

ui.Image swatch(Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(4, 4);
  picture.dispose();
  return image;
}

void main() {
  testWidgets('filmstrip arrival repaints stable bars and maps images to their frame spans', (
    tester,
  ) async {
    final red = swatch(const Color(0xffff0000));
    final blue = swatch(const Color(0xff0000ff));
    addTearDown(red.dispose);
    addTearDown(blue.dispose);
    final frames = ValueNotifier<List<TimelineThumbnail>>(const []);
    addTearDown(frames.dispose);
    final zoom = TrackTimelineController(pixelsPerFrame: 2);
    addTearDown(zoom.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      OiApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 620,
              height: 200,
              child: ValueListenableBuilder(
                valueListenable: frames,
                builder: (context, images, _) => TrackTimeline(
                  fps: 30,
                  controller: zoom,
                  totalFrames: 120,
                  playhead: 100,
                  tracks: [
                    TimelineTrack(
                      id: 'picture',
                      label: 'Picture',
                      bars: [
                        TimelineBar(
                          id: 'clip',
                          start: 0,
                          end: 60,
                          color: const Color(0xff00ff00),
                          thumbnails: images,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<List<int>> pixel(int x, int y) async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(render.toImage);
      final bytes = await tester.runAsync(() => image!.toByteData());
      final offset = (y * image!.width + x) * 4;
      final rgba = bytes!.buffer.asUint8List().sublist(offset, offset + 4);
      image.dispose();
      return rgba;
    }

    expect((await pixel(170, 36))[1], greaterThan(200));
    frames.value = [TimelineThumbnail(0, red), TimelineThumbnail(30, blue)];
    await tester.pump();
    expect(await pixel(170, 36), [255, 0, 0, 255]);
    expect(await pixel(230, 36), [0, 0, 255, 255]);
    frames.value = [TimelineThumbnail(0, blue), TimelineThumbnail(30, red)];
    await tester.pump();
    expect(
      identical(
        tester
            .widget<TrackTimeline>(find.byType(TrackTimeline))
            .tracks
            .single
            .bars
            .single
            .thumbnails
            .first
            .image,
        blue,
      ),
      isTrue,
    );
    expect(await pixel(170, 36), [0, 0, 255, 255]);
    expect(await pixel(230, 36), [255, 0, 0, 255]);
  });
  test('filmstrip image identity and frame position participate in immutable bar equality', () {
    final image = swatch(const Color(0xffff0000));
    final replacement = swatch(const Color(0xff0000ff));
    addTearDown(image.dispose);
    addTearDown(replacement.dispose);
    TimelineBar bar(ui.Image thumb, double frame) => TimelineBar(
      id: 'clip',
      start: 0,
      end: 60,
      color: const Color(0xff00ff00),
      thumbnails: [TimelineThumbnail(frame, thumb)],
    );
    expect(bar(image, 0), bar(image, 0));
    expect(bar(image, 0).hashCode, bar(image, 0).hashCode);
    expect(bar(image, 0), isNot(bar(replacement, 0)));
    expect(bar(image, 0), isNot(bar(image, 30)));
  });
}
