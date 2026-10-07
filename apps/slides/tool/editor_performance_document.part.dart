part of 'editor_performance.dart';

Map<String, Object?> _project() => {
  'fluvieSpec': 1,
  'fps': 24,
  'size': {'width': 3840, 'height': 2160},
  'editor': {
    'editorSchema': 1,
    'deck': {'mode': 'video'},
  },
  'lanes': [
    for (var lane = 0; lane < 8; lane++) {'id': 'v$lane', 'kind': 'video'},
  ],
  'scenes': [
    {
      'duration': '180s',
      'layout': 'canvas',
      'children': [
        for (var index = 0; index < 240; index++)
          {
            'id': 'clip-$index',
            'type': 'Clip',
            'lane': 'v${index % 8}',
            'source': {'kind': 'file', 'value': _source},
            'show': {'from': '${(index ~/ 8) * 144}f', 'to': '${(index ~/ 8 + 1) * 144}f'},
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.85, 'h': 0.85},
          },
      ],
    },
  ],
};

Map<String, Object> _summary(List<double> samples) {
  final sorted = [...samples]..sort();
  return {
    'samples': samples.length,
    'medianMs': sorted[sorted.length ~/ 2],
    'p95Ms': sorted[((sorted.length - 1) * .95).round()],
    'maxMs': sorted.last,
  };
}

Map<String, Object> _measure(int count, void Function() action) {
  final samples = <double>[];
  for (var i = 0; i < count; i++) {
    final clock = Stopwatch()..start();
    action();
    clock.stop();
    samples.add(clock.elapsedMicroseconds / 1000);
  }
  return _summary(samples);
}

typedef _PerformanceDocument = ({
  Map<String, Object?> results,
  EditorDocument document,
  VideoLaneModel model,
});

_PerformanceDocument _measureDocument() {
  expect(_source, isNotEmpty, reason: 'Supply FLUVIE_PERF_CLIP with the generated 4K fixture');
  final json = _project();
  final results = <String, Object?>{
    'runtime': Platform.version,
    'os': Platform.operatingSystemVersion,
    'project': {
      'seconds': 180,
      'fps': 24,
      'width': 3840,
      'height': 2160,
      'lanes': 8,
      'clips': 240,
      'uniqueMediaSources': 1,
      'sourceSeconds': 6,
      'activeClipsAtStart': 8,
    },
    'mode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
    'assertionsEnabled': kDebugMode,
    'measurement': 'operation wall-time plus engine build/raster FrameTiming',
  };
  results['documentLoad'] = _measure(15, () => EditorDocument.fromJson(json));
  results['loadAndColdDigest'] = _measure(15, () => EditorDocument.fromJson(json).renderDigest);
  final document = EditorDocument.fromJson(json)..renderDigest;
  results['repeatedRenderDigest'] = _measure(100, () => document.renderDigest);
  results['timelineModel'] = _measure(15, () => VideoLaneModel.build(document: document));
  results['canvasMoveCommand'] = _measure(
    30,
    () => const SetTransformCommand(
      id: 'clip-0',
      transform: {'x': 0.55, 'y': 0.55, 'w': 0.85, 'h': 0.85},
    ).apply(document),
  );
  final model = VideoLaneModel.build(document: document);
  return (results: results, document: document, model: model);
}
