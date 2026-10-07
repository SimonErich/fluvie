import 'package:flutter/rendering.dart'
    show Alignment, BorderRadius, BoxFit, Color, LinearGradient, Offset, Rect, TextAlign;
import 'package:flutter/widgets.dart' show SizedBox, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show
        AudioBand,
        Bars,
        Box,
        Chart,
        ChartPoint,
        ChartSeries,
        Clip,
        Code,
        CodeReveal,
        CodeTheme,
        Counter,
        Ease,
        Html,
        LowerThird,
        Markdown,
        Mermaid,
        MermaidReveal,
        MermaidTheme,
        SnapshotViewport,
        Stagger,
        Terminal,
        TerminalChrome,
        TerminalLine,
        TitleCard,
        Typewriter,
        WebView,
        unknownSpecProps;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// Round-trips one element through the spec layer and returns the widget it
/// builds (annotations unwrap their scene-filling expand box).
Object _build(Map<String, Object?> json) {
  final spec = ElementSpec.fromJson(json, AnchorTable());
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  final built = spec.build(AnchorTable());
  return built is SizedBox ? built.child! : built;
}

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
  group('Text extras', () {
    test('textAlign and maxLines decode onto the widget', () {
      final widget =
          _build({
                'type': 'Text',
                'text': 'Centered',
                'textAlign': 'center',
                'maxLines': 2,
              })
              as Text;
      expect(widget.textAlign, TextAlign.center);
      expect(widget.maxLines, 2);
    });

    test('both elide when absent', () {
      final widget = _build({'type': 'Text', 'text': 'Plain'}) as Text;
      expect(widget.textAlign, isNull);
      expect(widget.maxLines, isNull);
    });

    test('an unknown alignment name errors with its path', () {
      expect(
        () => _build({'type': 'Text', 'text': 'x', 'textAlign': 'wavy'}),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.message, 'message', contains('wavy')),
        ),
      );
    });
  });

  group('Typewriter', () {
    test('round-trips and builds with every prop', () {
      final widget =
          _build({
                'type': 'Typewriter',
                'text': 'typed out',
                'speed': '3f',
                'caret': true,
                'style': {'fontSize': 40},
              })
              as Typewriter;
      expect(widget.text, 'typed out');
      expect(widget.speed, const Time.frames(3));
      expect(widget.caret, isTrue);
      expect(widget.style!.fontSize, 40);
    });

    test('defaults apply when only text is given', () {
      final widget = _build({'type': 'Typewriter', 'text': 'bare'}) as Typewriter;
      expect(widget.speed, const Time.frames(2));
      expect(widget.caret, isFalse);
      expect(widget.style, isNull);
    });

    test('a document using it reports no unknown props', () {
      expect(
        unknownSpecProps(
          _doc({'type': 'Typewriter', 'text': 'x', 'speed': '2f', 'caret': false}),
        ),
        isEmpty,
      );
    });
  });

  group('Counter completion', () {
    test('ease decodes a named curve', () {
      final widget = _build({'type': 'Counter', 'to': 100, 'ease': 'out'}) as Counter;
      expect(widget.ease, Ease.out);
    });

    test('the currency variant carries its symbol', () {
      final widget =
          _build({'type': 'Counter', 'to': 4999, 'variant': 'currency', 'symbol': '€'}) as Counter;
      expect(widget.format!.format(4999), contains('€'));
    });

    test('the percent variant formats fractions', () {
      final widget = _build({'type': 'Counter', 'to': 0.87, 'variant': 'percent'}) as Counter;
      expect(widget.format!.format(0.87), contains('%'));
    });

    test('an unknown variant errors', () {
      expect(
        () => _build({'type': 'Counter', 'to': 1, 'variant': 'roman'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('Clip audio fade-out', () {
    test('fadeOut reaches ClipAudio alongside fadeIn', () {
      final widget =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
                'volume': 0.5,
                'fadeIn': '6f',
                'fadeOut': '12f',
              })
              as Clip;
      expect(widget.audio.fadeIn, const Time.frames(6));
      expect(widget.audio.fadeOut, const Time.frames(12));
    });

    test('fadeOut elides to zero and rides a volume-less clip', () {
      final plain =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
              })
              as Clip;
      expect(plain.audio.fadeOut, Time.zero);

      final ramped =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
                'fadeOut': '9f',
              })
              as Clip;
      expect(ramped.audio.fadeOut, const Time.frames(9));
      expect(ramped.audio.volume, 1.0, reason: 'an unstated volume is still full');
    });

    test('a muted clip carries no ramps at all', () {
      final widget =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
                'volume': 0,
                'fadeOut': '9f',
              })
              as Clip;
      expect(widget.audio.muted, isTrue);
      expect(widget.audio.fadeOut, Time.zero);
    });
  });

  group('Clip speed', () {
    test('a rate reaches the element and defaults to source speed', () {
      final ramped =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
                'speed': 0.5,
              })
              as Clip;
      expect(ramped.speed, 0.5);

      final plain =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
              })
              as Clip;
      expect(plain.speed, 1);
    });

    test('a negative rate is a reverse, not an error', () {
      final widget =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
                'speed': -1,
              })
              as Clip;
      expect(widget.speed, -1);
    });

    test('zero and non-numeric rates are refused by name', () {
      for (final bad in <Object>[0, 'fast', true]) {
        expect(
          () => _build({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'speed': bad,
          }),
          throwsA(
            isA<FluvieSpecError>().having(
              (error) => error.path,
              'path',
              contains('speed'),
            ),
          ),
          reason: 'a rate of $bad advances no frames or is not a rate at all',
        );
      }
    });
  });

  group('Clip audio fade', () {
    test('fadeIn reaches ClipAudio', () {
      final widget =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
                'volume': 0.5,
                'fadeIn': '12f',
              })
              as Clip;
      expect(widget.audio.volume, 0.5);
      expect(widget.audio.fadeIn, const Time.frames(12));
    });

    test('fadeIn elides to zero', () {
      final widget =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'a.mp4'},
              })
              as Clip;
      expect(widget.audio.fadeIn, Time.zero);
    });
  });

  group('Box decoration', () {
    test('the subset decodes onto a BoxDecoration', () {
      final widget =
          _build({
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
              })
              as Box;
      final decoration = widget.decoration!;
      expect(decoration.color, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(24));
      expect(decoration.border!.top.width, 2);
      expect((decoration.gradient! as LinearGradient).begin, Alignment.topLeft);
      expect(decoration.boxShadow!.single.blurRadius, 16);
      expect(decoration.boxShadow!.single.offset.dy, 8);
    });

    test('gradient stop offsets thread to the LinearGradient', () {
      final widget =
          _build({
                'type': 'Box',
                'decoration': {
                  'gradient': {
                    'colors': ['#101018', '#6C5CE7', '#2D3436'],
                    'stops': [0, 0.2, 1],
                  },
                },
              })
              as Box;
      expect((widget.decoration!.gradient! as LinearGradient).stops, [0, 0.2, 1]);
    });

    test('a gradient without stops stays evenly spaced', () {
      final widget =
          _build({
                'type': 'Box',
                'decoration': {
                  'gradient': {
                    'colors': ['#101018', '#2D3436'],
                  },
                },
              })
              as Box;
      expect((widget.decoration!.gradient! as LinearGradient).stops, isNull);
    });

    test('malformed gradient stops error with a located path', () {
      Matcher throwsAt(List<String> path) =>
          throwsA(isA<FluvieSpecError>().having((e) => e.path, 'path', path));
      Map<String, Object?> boxWith(Object? stops) => {
        'type': 'Box',
        'decoration': {
          'gradient': {
            'colors': ['#101018', '#2D3436'],
            'stops': stops,
          },
        },
      };
      expect(() => _build(boxWith('no')), throwsAt(const ['decoration', 'gradient', 'stops']));
      expect(
        () => _build(boxWith(const [0, 0.5, 1])),
        throwsAt(const ['decoration', 'gradient', 'stops']),
        reason: 'the stops list must match the colors list in length',
      );
      expect(
        () => _build(boxWith(const [-0.1, 1])),
        throwsAt(const ['decoration', 'gradient', 'stops', '0']),
      );
      expect(
        () => _build(boxWith(const [0.8, 0.2])),
        throwsAt(const ['decoration', 'gradient', 'stops', '1']),
      );
    });

    test('color and decoration together error like the widget assert', () {
      expect(
        () => _build({
          'type': 'Box',
          'color': '#FF0000',
          'decoration': {'color': '#00FF00'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a typo inside decoration reports as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Box',
            'decoration': {'colour': '#FF0000'},
          }),
        ),
        isNotEmpty,
      );
    });
  });

  group('Markdown', () {
    test('round-trips and builds', () {
      final widget =
          _build({
                'type': 'Markdown',
                'source': '# Title\n\n- a\n- b',
                'reveal': '30f',
              })
              as Markdown;
      expect(widget.source, '# Title\n\n- a\n- b');
      expect(widget.reveal, const Time.frames(30));
    });

    test('reveal elides to null', () {
      final widget = _build({'type': 'Markdown', 'source': 'plain'}) as Markdown;
      expect(widget.reveal, isNull);
    });

    test('style is not a spec prop yet and reports as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Markdown',
            'source': 'x',
            'style': {'anything': 1},
          }),
        ),
        isNotEmpty,
        reason: 'MarkdownStyle has no codec; the spec must say so loudly',
      );
    });
  });

  group('Terminal', () {
    test('round-trips and builds with every prop', () {
      final widget =
          _build({
                'type': 'Terminal',
                'lines': [
                  {'cmd': 'npm install', 'prompt': '>'},
                  {'out': 'added 120 packages'},
                  {'cmd': 'npm test'},
                ],
                'prompt': r'~ $ ',
                'chrome': {'title': 'zsh'},
                'typingSpeed': '3f',
                'lineGap': '24f',
                'style': {'fontSize': 13},
              })
              as Terminal;
      expect(widget.lines, [
        const TerminalLine.cmd('npm install', prompt: '>'),
        const TerminalLine.out('added 120 packages'),
        const TerminalLine.cmd('npm test'),
      ]);
      expect(widget.prompt, r'~ $ ');
      expect(widget.chrome, const TerminalChrome(title: 'zsh'));
      expect(widget.typingSpeed, const Time.frames(3));
      expect(widget.lineGap, const Time.frames(24));
      expect(widget.style!.fontSize, 13);
    });

    test('defaults apply when only lines are given', () {
      final widget =
          _build({
                'type': 'Terminal',
                'lines': [
                  {'cmd': 'ls'},
                ],
              })
              as Terminal;
      expect(widget.prompt, r'$ ');
      expect(widget.chrome, isNull);
      expect(widget.typingSpeed, const Time.frames(2));
      expect(widget.lineGap, const Time.frames(18));
      expect(widget.style, isNull);
    });

    test('chrome with dots off decodes', () {
      final widget =
          _build({
                'type': 'Terminal',
                'lines': [
                  {'out': 'quiet'},
                ],
                'chrome': {'showDots': false},
              })
              as Terminal;
      expect(widget.chrome, TerminalChrome.none);
    });

    test('a line that is neither cmd nor out errors with its path', () {
      expect(
        () => _build({
          'type': 'Terminal',
          'lines': [
            {'echo': 'hi'},
          ],
        }),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.path, 'path', containsAll(['lines', '0'])),
        ),
      );
    });

    test('a missing lines list errors', () {
      expect(() => _build({'type': 'Terminal'}), throwsA(isA<FluvieSpecError>()));
    });

    test('a typo inside chrome or a line reports as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Terminal',
            'lines': [
              {'cmd': 'ls', 'promt': '>'},
            ],
            'chrome': {'titel': 'zsh'},
          }),
        ),
        hasLength(2),
      );
    });
  });

  group('Code', () {
    test('round-trips and builds with every prop', () {
      final widget =
          _build({
                'type': 'Code',
                'source': 'void main() {}',
                'language': 'dart',
                'theme': 'light',
                'reveal': {'kind': 'typing', 'speed': '2f'},
                'focusLines': [1, 2],
                'highlightLines': [2],
                'style': {'fontSize': 15},
              })
              as Code;
      expect(widget.source, 'void main() {}');
      expect(widget.language, 'dart');
      expect(widget.theme, const CodeTheme.light());
      expect(widget.reveal, const CodeReveal.typing(Time.frames(2)));
      expect(widget.focusLines, {1, 2});
      expect(widget.highlightLines, {2});
      expect(widget.style!.fontSize, 15);
    });

    test('defaults apply when only source is given', () {
      final widget = _build({'type': 'Code', 'source': 'plain text'}) as Code;
      expect(widget.language, 'plaintext');
      expect(widget.theme, isNull);
      expect(widget.reveal, CodeReveal.instant);
      expect(widget.focusLines, isNull);
      expect(widget.highlightLines, isNull);
    });

    test('a lineByLine reveal decodes', () {
      final widget =
          _build({
                'type': 'Code',
                'source': 'a\nb',
                'reveal': {'kind': 'lineByLine', 'perLine': '6f'},
              })
              as Code;
      expect(widget.reveal, const CodeReveal.lineByLine(Time.frames(6)));
    });

    test('after selects Code.diff', () {
      final widget =
          _build({
                'type': 'Code',
                'source': 'final x = 1;',
                'after': 'final x = 2;',
                'language': 'dart',
                'theme': 'dark',
                'reveal': {'kind': 'lineByLine', 'perLine': '12f'},
              })
              as Code;
      expect(widget.source, 'final x = 1;');
      expect(widget.after, 'final x = 2;');
      expect(widget.theme, const CodeTheme.dark());
    });

    test('focus or highlight lines on a diff error', () {
      expect(
        () => _build({
          'type': 'Code',
          'source': 'a',
          'after': 'b',
          'focusLines': [1],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'Code',
          'source': 'a',
          'after': 'b',
          'highlightLines': [1],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('an unknown theme errors', () {
      expect(
        () => _build({'type': 'Code', 'source': 'x', 'theme': 'solarized'}),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.message, 'message', contains('solarized')),
        ),
      );
    });

    test('an unknown reveal kind errors', () {
      expect(
        () => _build({
          'type': 'Code',
          'source': 'x',
          'reveal': {'kind': 'sparkle'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a typo inside reveal reports as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Code',
            'source': 'x',
            'reveal': {'kind': 'typing', 'sped': '2f'},
          }),
        ),
        isNotEmpty,
      );
    });
  });

  group('Chart', () {
    test('bar round-trips with data, reveal, and stagger', () {
      final widget =
          _build({
                'type': 'Chart',
                'variant': 'bar',
                'data': {'Jan': 30, 'Feb': 45},
                'reveal': '45f',
                'stagger': {'each': '3f'},
              })
              as Chart;
      expect(widget.data, {'Jan': 30, 'Feb': 45});
      expect(widget.reveal, const Time.frames(45));
      expect(widget.stagger, const Stagger.each(Time.frames(3)));
    });

    test('reveal defaults to the 0.6 relative window', () {
      final widget =
          _build({
                'type': 'Chart',
                'variant': 'pie',
                'data': {'a': 1, 'b': 2},
              })
              as Chart;
      expect(widget.reveal, const Time.relative(0.6));
    });

    test('donut carries its innerRadius and defaults to 0.6', () {
      final authored =
          _build({
                'type': 'Chart',
                'variant': 'donut',
                'data': {'a': 1},
                'innerRadius': 0.4,
              })
              as Chart;
      expect(authored.innerRadius, 0.4);
      final defaulted =
          _build({
                'type': 'Chart',
                'variant': 'donut',
                'data': {'a': 1},
              })
              as Chart;
      expect(defaulted.innerRadius, 0.6);
    });

    test('line takes data or series, never both or neither', () {
      final single =
          _build({
                'type': 'Chart',
                'variant': 'line',
                'data': {'Jan': 30},
              })
              as Chart;
      expect(single.data, {'Jan': 30});
      final multi =
          _build({
                'type': 'Chart',
                'variant': 'line',
                'series': [
                  {
                    'name': 'Sales',
                    'color': '#6C5CE7',
                    'data': {'Jan': 30, 'Feb': 45},
                  },
                ],
              })
              as Chart;
      expect(multi.series, [
        const ChartSeries.values(
          name: 'Sales',
          data: {'Jan': 30, 'Feb': 45},
          color: Color(0xFF6C5CE7),
        ),
      ]);
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'line',
          'data': {'a': 1},
          'series': [
            {
              'name': 's',
              'data': {'a': 1},
            },
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({'type': 'Chart', 'variant': 'line'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'line',
          'points': [
            {'x': 1, 'y': 2},
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('area mirrors line', () {
      final widget =
          _build({
                'type': 'Chart',
                'variant': 'area',
                'data': {'Jan': 30},
              })
              as Chart;
      expect(widget.data, {'Jan': 30});
    });

    test('scatter takes points, data, or one series', () {
      final fromPoints =
          _build({
                'type': 'Chart',
                'variant': 'scatter',
                'points': [
                  {'x': 1, 'y': 2, 'label': 'Q1'},
                  {'x': 3, 'y': 4},
                ],
                'stagger': {'evenly': '30f'},
              })
              as Chart;
      expect(fromPoints.points, [
        const ChartPoint(x: 1, y: 2, label: 'Q1'),
        const ChartPoint(x: 3, y: 4),
      ]);
      expect(fromPoints.stagger, const Stagger.evenly(over: Time.frames(30)));
      final fromData =
          _build({
                'type': 'Chart',
                'variant': 'scatter',
                'data': {'a': 1},
              })
              as Chart;
      expect(fromData.data, {'a': 1});
      final fromSeries =
          _build({
                'type': 'Chart',
                'variant': 'scatter',
                'series': [
                  {
                    'name': 'Cloud',
                    'color': '#00B894',
                    'points': [
                      {'x': 1, 'y': 2},
                    ],
                  },
                ],
              })
              as Chart;
      expect(fromSeries.series, [
        const ChartSeries.points(
          name: 'Cloud',
          data: [ChartPoint(x: 1, y: 2)],
          color: Color(0xFF00B894),
        ),
      ]);
      expect(fromSeries.color, const Color(0xFF00B894));
    });

    test('scatter rejects two series or no data shape at all', () {
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'scatter',
          'series': [
            {'name': 'a', 'points': <Object?>[]},
            {'name': 'b', 'points': <Object?>[]},
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({'type': 'Chart', 'variant': 'scatter'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('bar rejects series and points', () {
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'bar',
          'series': [
            {
              'name': 's',
              'data': {'a': 1},
            },
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'bar',
          'data': {'a': 1},
          'points': [
            {'x': 1, 'y': 2},
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a series needs a name and exactly one data shape', () {
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'line',
          'series': [
            {
              'data': {'a': 1},
            },
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'line',
          'series': [
            {
              'name': 's',
              'data': {'a': 1},
              'points': [
                {'x': 1, 'y': 2},
              ],
            },
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'line',
          'series': [
            {'name': 's'},
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('an unknown or missing variant errors naming the allowed set', () {
      expect(
        () => _build({
          'type': 'Chart',
          'variant': 'radar',
          'data': {'a': 1},
        }),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.message,
            'message',
            allOf(contains('radar'), contains('bar'), contains('scatter')),
          ),
        ),
      );
      expect(
        () => _build({
          'type': 'Chart',
          'data': {'a': 1},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('typos inside series, points, and stagger report as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Chart',
            'variant': 'line',
            'series': [
              {
                'name': 's',
                'colour': '#FF0000',
                'data': {'a': 1},
              },
            ],
          }),
        ),
        isNotEmpty,
      );
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Chart',
            'variant': 'scatter',
            'points': [
              {'x': 1, 'y': 2, 'lable': 'Q1'},
            ],
          }),
        ),
        isNotEmpty,
      );
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Chart',
            'variant': 'bar',
            'data': {'a': 1},
            'stagger': {'each': '3f', 'wave': true},
          }),
        ),
        isNotEmpty,
      );
    });
  });

  group('Mermaid', () {
    test('round-trips and builds with every prop', () {
      final widget =
          _build({
                'type': 'Mermaid',
                'source': 'graph TD; A-->B;',
                'theme': 'dark',
                'reveal': {'kind': 'fadeNodes', 'window': '30f'},
                'fit': 'cover',
              })
              as Mermaid;
      expect(widget.source, 'graph TD; A-->B;');
      expect(widget.theme, const MermaidTheme.dark());
      expect(widget.reveal, const MermaidReveal.fadeNodes(Time.frames(30)));
      expect(widget.fit, BoxFit.cover);
    });

    test('defaults apply when only source is given', () {
      final widget = _build({'type': 'Mermaid', 'source': 'graph TD; A-->B;'}) as Mermaid;
      expect(widget.theme, isNull);
      expect(widget.reveal, MermaidReveal.none);
      expect(widget.fit, BoxFit.contain);
    });

    test('drawEdges decodes and light themes resolve', () {
      final widget =
          _build({
                'type': 'Mermaid',
                'source': 'graph LR; A-->B;',
                'theme': 'light',
                'reveal': {'kind': 'drawEdges', 'window': '20f'},
              })
              as Mermaid;
      expect(widget.theme, const MermaidTheme.light());
      expect(widget.reveal, const MermaidReveal.drawEdges(Time.frames(20)));
    });

    test('unknown reveal kinds and themes error', () {
      expect(
        () => _build({
          'type': 'Mermaid',
          'source': 'x',
          'reveal': {'kind': 'sparkle'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({'type': 'Mermaid', 'source': 'x', 'theme': 'forest'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a typo inside reveal reports as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Mermaid',
            'source': 'x',
            'reveal': {'kind': 'fadeNodes', 'windw': '30f'},
          }),
        ),
        isNotEmpty,
      );
    });
  });

  group('WebView', () {
    test('round-trips and builds with every prop', () {
      final widget =
          _build({
                'type': 'WebView',
                'uri': 'https://example.com/pricing',
                'viewport': {'width': 1280, 'height': 800, 'deviceScale': 2},
                'scroll': {'x': 0, 'y': 240},
                'clip': {'x': 0, 'y': 0, 'w': 1280, 'h': 400},
                'fit': 'contain',
              })
              as WebView;
      expect(widget.uri, Uri.parse('https://example.com/pricing'));
      expect(widget.viewport, const SnapshotViewport(width: 1280, height: 800, deviceScale: 2));
      expect(widget.scroll, const Offset(0, 240));
      expect(widget.clip, const Rect.fromLTWH(0, 0, 1280, 400));
      expect(widget.fit, BoxFit.contain);
    });

    test('scroll, clip, and fit default', () {
      final widget =
          _build({
                'type': 'WebView',
                'uri': 'https://example.com',
                'viewport': {'width': 800, 'height': 600},
              })
              as WebView;
      expect(widget.scroll, isNull);
      expect(widget.clip, isNull);
      expect(widget.fit, BoxFit.cover);
      expect(widget.viewport.deviceScale, 1.0);
    });

    test('a relative or non-http URL errors', () {
      expect(
        () => _build({
          'type': 'WebView',
          'uri': 'not a url',
          'viewport': {'width': 800, 'height': 600},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'WebView',
          'uri': 'ftp://example.com',
          'viewport': {'width': 800, 'height': 600},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('the viewport is required and integer-sized', () {
      expect(
        () => _build({'type': 'WebView', 'uri': 'https://example.com'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'WebView',
          'uri': 'https://example.com',
          'viewport': {'width': 12.5, 'height': 600},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a typo inside the viewport reports as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'WebView',
            'uri': 'https://example.com',
            'viewport': {'width': 800, 'height': 600, 'scale': 2},
          }),
        ),
        isNotEmpty,
      );
    });
  });

  group('Html', () {
    test('round-trips and builds', () {
      final widget =
          _build({
                'type': 'Html',
                'source': '<h1>Hello</h1>',
                'viewport': {'width': 800, 'height': 200},
                'fit': 'contain',
              })
              as Html;
      expect(widget.source, '<h1>Hello</h1>');
      expect(widget.viewport, const SnapshotViewport(width: 800, height: 200));
      expect(widget.fit, BoxFit.contain);
    });

    test('fit defaults to cover and the viewport is required', () {
      final widget =
          _build({
                'type': 'Html',
                'source': '<p>x</p>',
                'viewport': {'width': 640, 'height': 480},
              })
              as Html;
      expect(widget.fit, BoxFit.cover);
      expect(() => _build({'type': 'Html', 'source': '<p>x</p>'}), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('Bars', () {
    test('round-trips and builds with every prop', () {
      final widget = _build({'type': 'Bars', 'count': 32, 'band': 'treble', 'gain': 1.5}) as Bars;
      expect(widget.count, 32);
      expect(widget.band, AudioBand.treble);
      expect(widget.gain, 1.5);
      expect(widget.track, isNull);
    });

    test('defaults apply when bare', () {
      final widget = _build({'type': 'Bars'}) as Bars;
      expect(widget.count, 24);
      expect(widget.band, AudioBand.bass);
      expect(widget.gain, 1.0);
    });

    test('track resolves through the shared anchor table', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({'type': 'Bars', 'track': 'music'}, anchors);
      final widget = spec.build(anchors) as Bars;
      expect(
        widget.track,
        same(anchors.resolve('music')),
        reason: 'anchor identity is by reference; the table must mint one instance per id',
      );
    });

    test('an unknown band errors', () {
      expect(
        () => _build({'type': 'Bars', 'band': 'sub'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('LowerThird', () {
    test('round-trips and builds with every prop, unwrapped', () {
      final widget =
          _build({
                'type': 'LowerThird',
                'name': 'Ada Lovelace',
                'title': 'Mathematician',
                'reveal': '12f',
                'color': '#CC101418',
              })
              as LowerThird;
      expect(widget.name, 'Ada Lovelace');
      expect(widget.title, 'Mathematician');
      expect(widget.reveal, const Time.frames(12));
      expect(widget.color, const Color(0xCC101418));
    });

    test('defaults apply when only the name is given', () {
      final widget = _build({'type': 'LowerThird', 'name': 'Ada'}) as LowerThird;
      expect(widget.title, isNull);
      expect(widget.reveal, isNull);
      expect(widget.color, const Color(0xCC101418));
      expect(widget.child, isNull);
    });

    // The nested-child round-trip lives in codec_wave2_wrappers_test.dart with
    // the other child-bearing elements.
  });

  group('TitleCard', () {
    test('round-trips and builds with every prop, unwrapped', () {
      final widget =
          _build({
                'type': 'TitleCard',
                'title': 'Chapter One',
                'subtitle': 'The beginning',
                'reveal': '20f',
                'color': '#FFD166',
              })
              as TitleCard;
      expect(widget.title, 'Chapter One');
      expect(widget.subtitle, 'The beginning');
      expect(widget.reveal, const Time.frames(20));
      expect(widget.color, const Color(0xFFFFD166));
    });

    test('defaults apply when only the title is given', () {
      final widget = _build({'type': 'TitleCard', 'title': 'One'}) as TitleCard;
      expect(widget.subtitle, isNull);
      expect(widget.reveal, isNull);
      expect(widget.color, const Color(0xFFFFFFFF));
      expect(widget.child, isNull);
    });

    // The nested-child round-trip lives in codec_wave2_wrappers_test.dart with
    // the other child-bearing elements.
  });
}
