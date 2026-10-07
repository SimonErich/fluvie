import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _doc(Map<String, Object?> element) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [element],
    },
  ],
};

void main() {
  group('wave-2 text elements print their constructors', () {
    test('Text extras', () {
      expect(
        printVideoSpecJson(
          _doc({'type': 'Text', 'text': 'Centered', 'textAlign': 'center', 'maxLines': 2}),
        ),
        allOf(
          contains("Text('Centered'"),
          contains('textAlign: TextAlign.center'),
          contains('maxLines: 2'),
        ),
      );
    });

    test('Typewriter', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Typewriter',
            'text': 'typed',
            'speed': '3f',
            'caret': true,
            'style': {'fontSize': 40},
          }),
        ),
        allOf(
          contains("Typewriter('typed'"),
          contains('speed: 3.frames'),
          contains('caret: true'),
          contains('fontSize: 40'),
        ),
      );
      expect(
        printVideoSpecJson(_doc({'type': 'Typewriter', 'text': 'bare'})),
        allOf(contains("Typewriter('bare')"), isNot(contains('caret:'))),
      );
    });

    test('Counter completion', () {
      expect(
        printVideoSpecJson(
          _doc({'type': 'Counter', 'to': 100, 'ease': 'out', 'variant': 'currency', 'symbol': '€'}),
        ),
        allOf(
          contains('Counter.currency('),
          contains('ease: Ease.out'),
          contains("symbol: '€'"),
        ),
      );
      expect(
        printVideoSpecJson(_doc({'type': 'Counter', 'to': 0.87, 'variant': 'percent'})),
        contains('Counter.percent('),
      );
    });

    test('Clip audio fade', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'volume': 0.5,
            'fadeIn': '12f',
          }),
        ),
        contains('audio: ClipAudio.included(volume: 0.5, fadeIn: 12.frames)'),
      );
    });

    test('Box decoration', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Box',
            'decoration': {
              'color': '#2D3436',
              'cornerRadius': 24,
              'border': {'color': '#6C5CE7', 'width': 2},
              'gradient': {
                'colors': ['#101018', '#2D3436'],
                'begin': 'topLeft',
                'end': 'bottomRight',
              },
              'shadow': {
                'color': '#80000000',
                'blur': 16,
                'offset': {'x': 0, 'y': 8},
              },
            },
          }),
        ),
        allOf([
          contains('decoration: BoxDecoration('),
          contains('borderRadius: BorderRadius.circular(24)'),
          contains('border: Border.all('),
          contains('gradient: LinearGradient('),
          contains('begin: Alignment.topLeft'),
          contains('boxShadow: ['),
          contains('BoxShadow('),
          contains('offset: Offset(0, 8)'),
        ]),
      );
    });

    test('Box decoration gradient stops', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Box',
            'decoration': {
              'gradient': {
                'colors': ['#101018', '#6C5CE7', '#2D3436'],
                'stops': [0, 0.2, 1],
              },
            },
          }),
        ),
        contains('stops: [0, 0.2, 1]'),
      );
    });

    test('Markdown', () {
      expect(
        printVideoSpecJson(
          _doc({'type': 'Markdown', 'source': '# Title', 'reveal': '30f'}),
        ),
        allOf(contains("Markdown('# Title'"), contains('reveal: 30.frames')),
      );
      expect(
        printVideoSpecJson(_doc({'type': 'Markdown', 'source': 'plain'})),
        allOf(contains("Markdown('plain')"), isNot(contains('reveal:'))),
      );
    });

    test('Terminal', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Terminal',
            'lines': [
              {'cmd': 'npm install', 'prompt': '>'},
              {'out': 'added 120 packages'},
            ],
            'prompt': r'~ $ ',
            'chrome': {'title': 'zsh'},
            'typingSpeed': '3f',
            'lineGap': '24f',
          }),
        ),
        allOf(
          contains('Terminal('),
          contains("TerminalLine.cmd('npm install', prompt: '>')"),
          contains("TerminalLine.out('added 120 packages')"),
          contains(r"prompt: '~ \$ '"),
          contains("chrome: TerminalChrome(title: 'zsh')"),
          contains('typingSpeed: 3.frames'),
          contains('lineGap: 24.frames'),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Terminal',
            'lines': [
              {'out': 'quiet'},
            ],
            'chrome': {'showDots': false},
          }),
        ),
        allOf(contains('chrome: TerminalChrome(showDots: false)'), isNot(contains('prompt:'))),
      );
    });

    test('Code', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Code',
            'source': 'void main() {}',
            'language': 'dart',
            'theme': 'light',
            'reveal': {'kind': 'typing', 'speed': '2f'},
            'focusLines': [1, 2],
            'highlightLines': [2],
          }),
        ),
        allOf(
          contains('Code('),
          contains("'void main() {}'"),
          contains("language: 'dart'"),
          contains('theme: CodeTheme.light()'),
          contains('reveal: CodeReveal.typing(2.frames)'),
          contains('focusLines: {1, 2}'),
          contains('highlightLines: {2}'),
        ),
      );
      expect(
        printVideoSpecJson(_doc({'type': 'Code', 'source': 'bare'})),
        allOf(contains("Code('bare')"), isNot(contains('language:'))),
      );
    });

    test('Code.diff', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Code',
            'source': 'final x = 1;',
            'after': 'final x = 2;',
            'language': 'dart',
            'theme': 'dark',
            'reveal': {'kind': 'lineByLine', 'perLine': '12f'},
          }),
        ),
        allOf(
          contains('Code.diff('),
          contains("'final x = 1;'"),
          contains("'final x = 2;'"),
          contains('theme: CodeTheme.dark()'),
          contains('reveal: CodeReveal.lineByLine(12.frames)'),
        ),
      );
    });

    test('Chart bar, pie, and donut', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Chart',
            'variant': 'bar',
            'data': {'Jan': 30, 'Feb': 45},
            'reveal': '45f',
            'stagger': {'each': '3f'},
          }),
        ),
        allOf(
          contains('Chart.bar('),
          contains("data: {'Jan': 30, 'Feb': 45}"),
          contains('reveal: 45.frames'),
          contains('stagger: Stagger.each(3.frames)'),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Chart',
            'variant': 'pie',
            'data': {'a': 1},
          }),
        ),
        allOf(contains('Chart.pie('), isNot(contains('reveal:'))),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Chart',
            'variant': 'donut',
            'data': {'a': 1},
            'innerRadius': 0.4,
          }),
        ),
        allOf(contains('Chart.donut('), contains('innerRadius: 0.4')),
      );
    });

    test('Chart line and area call the factory like user code', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Chart',
            'variant': 'line',
            'data': {'Jan': 30},
          }),
        ),
        contains("Chart.line(data: {'Jan': 30})"),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Chart',
            'variant': 'area',
            'series': [
              {
                'name': 'Sales',
                'color': '#6C5CE7',
                'data': {'Jan': 30},
              },
            ],
            'reveal': '0.5r',
          }),
        ),
        allOf(
          contains('Chart.area.series('),
          contains(
            "ChartSeries.values(name: 'Sales', data: {'Jan': 30}, color: Color(0xFF6C5CE7))",
          ),
          contains('reveal: 0.5.relative'),
        ),
      );
    });

    test('Chart scatter prints each data shape', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Chart',
            'variant': 'scatter',
            'points': [
              {'x': 1, 'y': 2, 'label': 'Q1'},
            ],
            'stagger': {'evenly': '30f'},
          }),
        ),
        allOf(
          contains('Chart.scatter('),
          contains("points: [ChartPoint(x: 1, y: 2, label: 'Q1')]"),
          contains('stagger: Stagger.evenly(over: 30.frames)'),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Chart',
            'variant': 'scatter',
            'series': [
              {
                'name': 'Cloud',
                'points': [
                  {'x': 1, 'y': 2},
                ],
              },
            ],
          }),
        ),
        allOf(
          contains('Chart.scatter.series('),
          contains("ChartSeries.points(name: 'Cloud', data: [ChartPoint(x: 1, y: 2)])"),
        ),
      );
    });

    test('Mermaid', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Mermaid',
            'source': 'graph TD; A-->B;',
            'theme': 'dark',
            'reveal': {'kind': 'fadeNodes', 'window': '30f'},
            'fit': 'cover',
          }),
        ),
        allOf(
          contains('Mermaid('),
          contains("'graph TD; A-->B;'"),
          contains('theme: MermaidTheme.dark()'),
          contains('reveal: MermaidReveal.fadeNodes(30.frames)'),
          contains('fit: BoxFit.cover'),
        ),
      );
      expect(
        printVideoSpecJson(_doc({'type': 'Mermaid', 'source': 'graph LR; A-->B;'})),
        allOf(contains("Mermaid('graph LR; A-->B;')"), isNot(contains('reveal:'))),
      );
    });

    test('WebView', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'WebView',
            'uri': 'https://example.com/pricing',
            'viewport': {'width': 1280, 'height': 800, 'deviceScale': 2},
            'scroll': {'x': 0, 'y': 240},
            'clip': {'x': 0, 'y': 0, 'w': 1280, 'h': 400},
            'fit': 'contain',
          }),
        ),
        allOf(
          contains('WebView.url('),
          contains("'https://example.com/pricing'"),
          contains('viewport: SnapshotViewport(width: 1280, height: 800, deviceScale: 2)'),
          contains('scroll: Offset(0, 240)'),
          contains('clip: Rect.fromLTWH(0, 0, 1280, 400)'),
          contains('fit: BoxFit.contain'),
        ),
      );
    });

    test('Html', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Html',
            'source': '<h1>Hello</h1>',
            'viewport': {'width': 800, 'height': 200},
          }),
        ),
        allOf(
          contains("Html('<h1>Hello</h1>'"),
          contains('viewport: SnapshotViewport(width: 800, height: 200)'),
          isNot(contains('deviceScale:')),
        ),
      );
    });

    test('Bars declares its track anchor and passes it by variable', () {
      expect(
        printVideoSpecJson(
          _doc({'type': 'Bars', 'count': 32, 'band': 'treble', 'gain': 1.5, 'track': 'music'}),
        ),
        allOf(
          contains("final music = Anchor('music');"),
          contains('Bars('),
          contains('count: 32'),
          contains('band: AudioBand.treble'),
          contains('track: music'),
          contains('gain: 1.5'),
        ),
      );
      expect(printVideoSpecJson(_doc({'type': 'Bars'})), contains('Bars()'));
    });

    test('LowerThird', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'LowerThird',
            'name': 'Ada Lovelace',
            'title': 'Mathematician',
            'reveal': '12f',
            'color': '#CC101418',
          }),
        ),
        allOf(
          contains('LowerThird('),
          contains("name: 'Ada Lovelace'"),
          contains("title: 'Mathematician'"),
          contains('reveal: 12.frames'),
          contains('color: Color(0xCC101418)'),
        ),
      );
      expect(
        printVideoSpecJson(_doc({'type': 'LowerThird', 'name': 'Ada'})),
        allOf(contains("LowerThird(name: 'Ada')"), isNot(contains('color:'))),
      );
    });

    test('TitleCard', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'TitleCard',
            'title': 'Chapter One',
            'subtitle': 'The beginning',
            'reveal': '20f',
          }),
        ),
        allOf(
          contains('TitleCard('),
          contains("title: 'Chapter One'"),
          contains("subtitle: 'The beginning'"),
          contains('reveal: 20.frames'),
        ),
      );
    });
  });
}
