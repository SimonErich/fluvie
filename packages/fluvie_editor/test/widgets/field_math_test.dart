import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  test('plain numbers and expressions evaluate absolutely', () {
    expect(evalFieldMath('42', current: 0), 42);
    expect(evalFieldMath('960/2', current: 0), 480);
    expect(evalFieldMath('2+3*4', current: 0), 14);
    expect(evalFieldMath('(2+3)*4', current: 0), 20);
    expect(evalFieldMath(' 12.5 ', current: 0), 12.5);
    expect(evalFieldMath('-10', current: 99), -10);
    expect(evalFieldMath('10-4', current: 99), 6);
  });

  test('a leading operator applies to the current value', () {
    expect(evalFieldMath('+10', current: 30), 40);
    expect(evalFieldMath('*2', current: 30), 60);
    expect(evalFieldMath('/3', current: 30), 10);
    expect(evalFieldMath('+2*5', current: 30), 40);
  });

  test('garbage evaluates to null', () {
    expect(evalFieldMath('', current: 1), isNull);
    expect(evalFieldMath('abc', current: 1), isNull);
    expect(evalFieldMath('2+', current: 1), isNull);
    expect(evalFieldMath('(2', current: 1), isNull);
    expect(evalFieldMath('1/0', current: 1), isNull);
  });
}
