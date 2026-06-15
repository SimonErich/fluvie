// WI-12 (D-LineModel/D-Chrome): the Terminal line model and window chrome. A
// sealed `TerminalLine` with `.cmd`/`.out` factories carries the text + kind +
// an optional per-line prompt override, value-equal and const. `TerminalChrome`
// is an @immutable value with `.macos`/`.none` factories carrying the title and
// the traffic-light dot config.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/terminal/terminal_chrome.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';

void main() {
  group('TerminalLine.cmd', () {
    test('carries its text and a null prompt override by default', () {
      const line = TerminalLine.cmd('npm i');
      expect(line, isA<TerminalCmd>());
      expect((line as TerminalCmd).text, 'npm i');
      expect(line.prompt, isNull);
    });

    test('carries an optional per-line prompt override', () {
      const line = TerminalLine.cmd('git push', prompt: '> ');
      expect((line as TerminalCmd).prompt, '> ');
    });

    test('is const and value-equal by text and prompt', () {
      const a = TerminalLine.cmd('ls', prompt: r'$ ');
      const b = TerminalLine.cmd('ls', prompt: r'$ ');
      const different = TerminalLine.cmd('ls', prompt: '> ');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(different));
    });
  });

  group('TerminalLine.out', () {
    test('carries its text', () {
      const line = TerminalLine.out('added 120 packages');
      expect(line, isA<TerminalOut>());
      expect((line as TerminalOut).text, 'added 120 packages');
    });

    test('is const and value-equal by text', () {
      const a = TerminalLine.out('done');
      const b = TerminalLine.out('done');
      const different = TerminalLine.out('failed');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(different));
    });

    test('a Cmd and an Out with the same text are not equal', () {
      const cmd = TerminalLine.cmd('x');
      const out = TerminalLine.out('x');
      expect(cmd, isNot(out));
    });
  });

  group('TerminalChrome', () {
    test('macos carries its title and shows the dots', () {
      const chrome = TerminalChrome.macos(title: 'zsh');
      expect(chrome.title, 'zsh');
      expect(chrome.showDots, isTrue);
    });

    test('macos defaults to a null (empty) title', () {
      const chrome = TerminalChrome.macos();
      expect(chrome.title, isNull);
      expect(chrome.showDots, isTrue);
    });

    test('none carries no title and hides the dots', () {
      const chrome = TerminalChrome.none;
      expect(chrome.title, isNull);
      expect(chrome.showDots, isFalse);
    });

    test('is value-equal by title and dot config', () {
      const a = TerminalChrome.macos(title: 'bash');
      const b = TerminalChrome.macos(title: 'bash');
      const different = TerminalChrome.macos(title: 'zsh');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(different));
      expect(a, isNot(TerminalChrome.none));
    });
  });

  group('toString and hashCode', () {
    test('each line variant has a stable hashCode and a readable toString', () {
      expect(const TerminalLine.cmd('ls').hashCode, const TerminalLine.cmd('ls').hashCode);
      expect(const TerminalLine.cmd('ls').toString(), contains('cmd'));
      expect(const TerminalLine.out('ok').hashCode, const TerminalLine.out('ok').hashCode);
      expect(const TerminalLine.out('ok').toString(), contains('out'));
    });

    test('chrome has a stable hashCode and a readable toString', () {
      expect(const TerminalChrome.macos(title: 'zsh').hashCode, isA<int>());
      expect(const TerminalChrome.macos(title: 'zsh').toString(), contains('zsh'));
      expect(TerminalChrome.none.toString(), contains('showDots: false'));
    });
  });
}
