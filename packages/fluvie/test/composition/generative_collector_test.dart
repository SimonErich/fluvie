import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/generative_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/generative_media.dart';

void main() {
  const img = GenerativeSource.image(providerId: 'flux', prompt: 'a');
  const vid = GenerativeSource.video(providerId: 'veo', prompt: 'b');

  Scene scene(List<Widget> children) => Scene(duration: const Time.frames(30), children: children);

  test('collects generative sources from scene children', () {
    final found = collectGenerativeSources([
      scene(const [GenerativeMedia(source: img), GenerativeMedia(source: vid)]),
    ]);
    expect(found, {img, vid});
  });

  test('recurses through layout widgets', () {
    final found = collectGenerativeSources([
      scene([
        const Align(child: GenerativeMedia(source: img)),
        const Column(children: [GenerativeMedia(source: vid)]),
      ]),
    ]);
    expect(found, {img, vid});
  });

  test('deduplicates identical sources across scenes', () {
    final found = collectGenerativeSources([
      scene(const [GenerativeMedia(source: img)]),
      scene(const [GenerativeMedia(source: img)]),
    ]);
    expect(found, {img});
  });

  test('ignores non-generative widgets', () {
    final found = collectGenerativeSources([
      scene(const [SizedBox(), Text('x', textDirection: TextDirection.ltr)]),
    ]);
    expect(found, isEmpty);
  });
}
