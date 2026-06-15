import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime_bindings.dart';
import 'package:mocktail/mocktail.dart';

class _MockWasmRuntime extends Mock implements WasmRuntime {}

void main() {
  group('createWasmRuntime (VM stub)', () {
    test('throws UnsupportedError on the VM', () {
      expect(createWasmRuntime, throwsUnsupportedError);
    });

    test('the error names the web-only nature of the runtime', () {
      expect(
        createWasmRuntime,
        throwsA(
          isA<UnsupportedError>().having((e) => e.message, 'message', contains('web')),
        ),
      );
    });
  });

  group('WasmRuntime contract', () {
    test('is implementable: a mocktail mock satisfies it end to end', () async {
      final runtime = _MockWasmRuntime();
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(runtime.load).thenAnswer((_) async {});
      when(() => runtime.writeFile('in.rgba', bytes)).thenAnswer((_) async {});
      when(() => runtime.exec(const ['-i', 'in.rgba', 'out.mp4'])).thenAnswer((_) async => 0);
      when(() => runtime.readFile('out.mp4')).thenAnswer((_) async => Uint8List(4));

      final WasmRuntime contract = runtime;
      await contract.load();
      await contract.writeFile('in.rgba', bytes);
      expect(await contract.exec(const ['-i', 'in.rgba', 'out.mp4']), 0);
      expect(await contract.readFile('out.mp4'), hasLength(4));
    });
  });
}
