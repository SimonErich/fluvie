import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake platform clipboard for tests: an unmocked platform channel never
/// answers in the test environment (the call hangs), so every test that
/// copies or pastes installs this store on `SystemChannels.platform`.
final class FakeSystemClipboard {
  /// The text the fake clipboard holds; seed it to simulate foreign text.
  String? text;

  /// Routes `Clipboard.setData`/`Clipboard.getData` into [text].
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          text = (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          final held = text;
          return held == null ? null : <String, Object?>{'text': held};
        }
        return null;
      },
    );
  }

  /// Removes the fake handler.
  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  }
}
