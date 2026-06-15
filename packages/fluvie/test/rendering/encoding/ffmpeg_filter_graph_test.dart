import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph_builder.dart';

void main() {
  group('FilterNode', () {
    test('serializes name only when there are no arguments', () {
      expect(FilterNode('format').serialize(), 'format');
    });

    test('serializes key=value pairs joined by ":" after the name', () {
      final node = FilterNode('scale', args: {'w': '320', 'h': '240'});
      expect(node.serialize(), 'scale=w=320:h=240');
    });

    test('escapes backslash in values', () {
      final node = FilterNode('format', args: {'pix_fmts': r'a\b'});
      expect(node.serialize(), r'format=pix_fmts=a\\b');
    });

    test('escapes colon in values', () {
      final node = FilterNode('format', args: {'pix_fmts': 'a:b'});
      expect(node.serialize(), r'format=pix_fmts=a\:b');
    });

    test('escapes comma in values', () {
      final node = FilterNode('format', args: {'pix_fmts': 'a,b'});
      expect(node.serialize(), r'format=pix_fmts=a\,b');
    });

    test('escapes single quote in values', () {
      final node = FilterNode('format', args: {'pix_fmts': "a'b"});
      expect(node.serialize(), r"format=pix_fmts=a\'b");
    });

    test('escapes the backslash itself before other specials (no double-escaping)', () {
      final node = FilterNode('format', args: {'pix_fmts': r'\:'});
      expect(node.serialize(), r'format=pix_fmts=\\\:');
    });

    test('rejects node names outside the known-safe set', () {
      expect(() => FilterNode('drawtext'), throwsAssertionError);
      expect(() => FilterNode('movie'), throwsAssertionError);
    });
  });

  group('FfmpegFilterGraph', () {
    test('starts empty and reports non-empty after add', () {
      final graph = FfmpegFilterGraph();
      expect(graph.isEmpty, isTrue);
      graph.add(FilterNode('format', args: {'pix_fmts': 'yuv420p'}));
      expect(graph.isEmpty, isFalse);
    });

    test('known graph serializes to the exact golden string', () {
      final graph = FfmpegFilterGraph()
        ..add(FilterNode('format', args: {'pix_fmts': 'yuv420p'}))
        ..add(FilterNode('scale', args: {'w': '320', 'h': '240'}));
      expect(graph.serialize(), 'format=pix_fmts=yuv420p,scale=w=320:h=240');
    });

    test('serializes nodes in insertion order (deterministic)', () {
      final forward = FfmpegFilterGraph()
        ..add(FilterNode('scale', args: {'w': '64', 'h': '64'}))
        ..add(FilterNode('format', args: {'pix_fmts': 'yuv420p'}));
      final reverse = FfmpegFilterGraph()
        ..add(FilterNode('format', args: {'pix_fmts': 'yuv420p'}))
        ..add(FilterNode('scale', args: {'w': '64', 'h': '64'}));
      expect(forward.serialize(), 'scale=w=64:h=64,format=pix_fmts=yuv420p');
      expect(reverse.serialize(), 'format=pix_fmts=yuv420p,scale=w=64:h=64');
    });
  });

  group('FfmpegFilterGraphBuilder', () {
    test('emits the yuv420p format node for a frame-sized output', () {
      const builder = FfmpegFilterGraphBuilder();
      final graph = builder.forFrames(width: 320, height: 240);
      expect(graph.isEmpty, isFalse);
      expect(graph.serialize(), 'format=pix_fmts=yuv420p');
    });

    test('output is stable across two calls (deterministic plan)', () {
      const builder = FfmpegFilterGraphBuilder();
      final first = builder.forFrames(width: 1920, height: 1080).serialize();
      final second = builder.forFrames(width: 1920, height: 1080).serialize();
      expect(first, second);
    });

    test('rejects odd dimensions (yuv420p needs even width and height)', () {
      const builder = FfmpegFilterGraphBuilder();
      expect(() => builder.forFrames(width: 321, height: 240), throwsArgumentError);
      expect(() => builder.forFrames(width: 320, height: 241), throwsArgumentError);
    });
  });
}
