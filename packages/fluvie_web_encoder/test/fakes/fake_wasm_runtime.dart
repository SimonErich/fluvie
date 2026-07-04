import 'dart:typed_data';

import 'package:fluvie/rendering.dart';

/// An in-memory [WasmRuntime] for tests: records every write, returns a fake
/// MP4 (an `ftyp` header) from [exec], and serves files back from memory.
class FakeWasmRuntime implements WasmRuntime {
  /// Creates a fake whose [exec] returns [exitCode].
  FakeWasmRuntime({this.exitCode = 0});

  /// The exit code [exec] reports.
  final int exitCode;

  /// The virtual file system: every [writeFile] and the synthesized output.
  final Map<String, Uint8List> files = {};

  /// The args of the last [exec] call.
  List<String>? lastArgs;

  @override
  Future<void> load() async {}

  @override
  Future<void> writeFile(String name, Uint8List bytes) async {
    files[name] = bytes;
  }

  @override
  Future<int> exec(List<String> args) async {
    lastArgs = args;
    // The output file is the last argument; synthesize an `ftyp`-headed blob.
    files[args.last] = Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]);
    return exitCode;
  }

  @override
  Future<Uint8List> readFile(String name) async => files[name]!;
}
