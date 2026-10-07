import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/audio/volume_automation_editor.dart';
import 'package:obers_ui/obers_ui.dart';

EditorDocument _document() => EditorDocument.fromJson(const {
  'fluvieSpec': 1,
  'fps': 10,
  'size': {'width': 100, 'height': 100},
  'lanes': [
    {'id': 'voice', 'kind': 'audio', 'name': 'Voice'},
    {'id': 'bed', 'kind': 'video'},
  ],
  'scenes': [
    {
      'duration': '4s',
      'children': [
        {
          'id': 'clip',
          'type': 'Clip',
          'lane': 'bed',
          'source': {'kind': 'asset', 'value': 'clip.mp4'},
        },
      ],
    },
  ],
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'voice.wav'},
      'lane': 'voice',
      'at': {'kind': 'at', 'time': '1s'},
      'trim': {'from': '0s', 'to': '1s'},
    },
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'bed.wav'},
      'lane': 'bed',
      'trim': {'from': '0s', 'to': '4s'},
    },
  ],
});

Future<void> _panel(
  WidgetTester tester,
  DocumentHistory history, {
  AudioMonitorController? monitor,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    OiApp(
      title: 'audio',
      theme: OiThemeData.dark(),
      home: Center(
        child: SizedBox(
          width: 460,
          child: ListenableBuilder(
            listenable: history,
            builder: (context, _) => AudioWorkspacePanel(
              document: history.document,
              timebase: VideoTimebase.of(history.document),
              currentFrame: 15,
              monitor: monitor,
              onCommand: history.dispatch,
              envelopes: const {
                'voice.wav': WaveformEnvelope(
                  sampleRate: 10,
                  durationSeconds: 4,
                  buckets: [WaveformBucket(min: -1, max: 1, rms: 0.5)],
                ),
                'bed.wav': WaveformEnvelope(
                  sampleRate: 10,
                  durationSeconds: 4,
                  buckets: [WaveformBucket(min: -1, max: 1, rms: 0.5)],
                ),
                'clip.mp4': WaveformEnvelope(
                  sampleRate: 10,
                  durationSeconds: 4,
                  buckets: [WaveformBucket(min: -1, max: 1, rms: 0.5)],
                ),
              },
            ),
          ),
        ),
      ),
    ),
  );
}

MathNumberInput _number(WidgetTester tester, String label) => tester.widget<MathNumberInput>(
  find.byWidgetPredicate((widget) => widget is MathNumberInput && widget.label == label).first,
);
OiSelect<String> _select(WidgetTester tester, String label) => tester.widget<OiSelect<String>>(
  find.byWidgetPredicate((widget) => widget is OiSelect<String> && widget.label == label),
);

void main() {
  testWidgets('lane gain and mute are undoable while monitoring solo stays ephemeral', (
    tester,
  ) async {
    final history = DocumentHistory(_document());
    final monitor = AudioMonitorController();
    addTearDown(history.dispose);
    addTearDown(monitor.dispose);
    await _panel(tester, history, monitor: monitor);
    expect(find.textContaining('CLIP'), findsWidgets);
    _number(tester, 'Gain dB').onChanged(-6.020599913);
    await tester.pump();
    expect(history.document.spec.lanes.first.gain, closeTo(0.5, 1e-9));
    await tester.tap(find.text('Mute').first);
    await tester.pump();
    expect(history.document.spec.lanes.first.muted, isTrue);
    await tester.tap(find.text('Unmute').first);
    await tester.pump();
    expect(history.document.spec.lanes.first.muted, isFalse);
    final digest = history.document.documentDigest;
    await tester.tap(find.text('Solo monitor').first);
    await tester.pump();
    expect(monitor.soloLaneIds, {'voice'});
    expect(monitor.gainForLane(null), 0);
    await tester.tap(find.text('Unsolo monitor'));
    await tester.pump();
    expect(monitor.soloLaneIds, isEmpty);
    monitor
      ..toggleSolo('bed')
      ..clearSolo()
      ..clearSolo();
    expect(monitor.gainForLane(null), 1);
    expect(history.document.documentDigest, digest);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ducking controls update declared and embedded audio in one undo step', (
    tester,
  ) async {
    final history = DocumentHistory(_document());
    addTearDown(history.dispose);
    await _panel(tester, history);
    await tester.scrollUntilVisible(
      find.text('Apply ducking'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    _select(tester, 'Trigger lane').onChanged!('voice');
    await tester.pump();
    _select(tester, 'Target lane').onChanged!('bed');
    await tester.pump();
    _number(tester, 'Reduction dB').onChanged(-6.020599913);
    _number(tester, 'Attack seconds').onChanged(0.2);
    _number(tester, 'Hold seconds').onChanged(0.2);
    _number(tester, 'Release seconds').onChanged(0.5);
    await tester.pump();
    final original = history.document.renderDigest;
    await tester.tap(find.text('Apply ducking'));
    await tester.pump();
    final bed = history.document.spec.audio.last.automation.resolve(fps: 10, windowFrames: 40);
    final clip = decodeAudioAutomation(
      history.document.elementJson('clip')!['automation'],
    ).resolve(fps: 10, windowFrames: 40);
    expect(audioVolumeAt(bed, 1.5), closeTo(0.5, 1e-9));
    expect(audioVolumeAt(clip, 1.5), closeTo(0.5, 1e-9));
    expect(audioVolumeAt(clip, 3), 1);
    history.undo();
    expect(history.canUndo, isFalse);
    expect(history.document.renderDigest, original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('volume stops edit time, gain, easing, insert, remove and clear', (tester) async {
    var automation = decodeAudioAutomation(const {
      'volume': {
        'values': [0.2, 0.8],
        'positions': ['0f', '20f'],
        'easings': [
          {
            'cubic': [0.2, 0.1, 0.8, 0.9],
          },
        ],
      },
    });
    Map<String, Object?>? changed;
    late StateSetter rebuild;
    await tester.pumpWidget(
      OiApp(
        title: 'stops',
        theme: OiThemeData.dark(),
        home: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return VolumeAutomationEditor(
                  automation: automation,
                  span: const FrameSpan(10, 30),
                  fps: 10,
                  currentFrame: 20,
                  onChanged: (value) => setState(() {
                    changed = value;
                    automation = value == null
                        ? const AudioAutomation()
                        : decodeAudioAutomation(value);
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(_select(tester, 'To stop 2').value, 'custom');
    final custom = encodeAudioAutomation(automation);
    _select(tester, 'To stop 2').onChanged!('custom');
    await tester.pump();
    expect(encodeAudioAutomation(automation), custom);
    expect(changed, isNull);
    _number(tester, 'Stop 1 gain').onChanged(0.3);
    await tester.pump();
    expect(automation.values.first, 0.3);
    _number(tester, 'Stop 2 frame').onChanged(19);
    await tester.pump();
    expect(encodeAudioAutomation(automation)['volume'], containsPair('positions', ['0f', '19f']));
    _select(tester, 'To stop 2').onChanged!('bounce');
    await tester.pump();
    _select(tester, 'To stop 2').onChanged!(null);
    await tester.tap(find.text('Add volume stop'));
    await tester.pump();
    expect(automation.values, [0.3, 0.5, 0.8]);
    expect(
      encodeAudioAutomation(automation)['volume'],
      containsPair('easings', ['bounce', 'bounce']),
    );
    await tester.tap(find.bySemanticsLabel('Remove volume stop 2'));
    await tester.pump();
    expect(automation.values, [0.3, 0.8]);
    await tester.tap(find.bySemanticsLabel('Remove volume stop 2'));
    await tester.pump();
    expect(automation.values, [0.3]);
    await tester.tap(find.text('Add volume stop'));
    await tester.pump();
    expect(automation.values, [0.3, 0.5, 0.3]);
    await tester.tap(find.text('Clear automation'));
    await tester.pump();
    expect(changed, isNull);
    rebuild(() => automation = const AudioAutomation(values: [0.4]));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Remove volume stop 1'));
    await tester.pump();
    expect(changed, isNull);
    expect(tester.takeException(), isNull);
  });
}
