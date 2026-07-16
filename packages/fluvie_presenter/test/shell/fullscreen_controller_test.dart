import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller.dart';
import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller_io.dart';

final class _FakeDesktopWindow implements DesktopWindowBridge {
  bool fullscreen = false;
  int calls = 0;

  @override
  Future<void> setFullScreen({required bool fullscreen}) async {
    this.fullscreen = fullscreen;
    calls++;
  }

  @override
  Future<bool> isFullScreen() async => fullscreen;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('on mobile', () {
    final uiModes = <String>[];

    setUp(() {
      uiModes.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            uiModes.add(call.arguments as String);
          }
          return null;
        },
      );
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    test('enter goes immersive, exit restores edge-to-edge', () async {
      final controller = IoFullscreenController(desktop: _FakeDesktopWindow());
      await controller.enter();
      expect(uiModes, ['SystemUiMode.immersiveSticky']);
      expect(await controller.isFullscreen, isTrue);
      await controller.exit();
      expect(uiModes, ['SystemUiMode.immersiveSticky', 'SystemUiMode.edgeToEdge']);
      expect(await controller.isFullscreen, isFalse);
    });

    test('toggle flips the tracked state', () async {
      final controller = IoFullscreenController(desktop: _FakeDesktopWindow());
      await controller.toggle();
      expect(await controller.isFullscreen, isTrue);
      await controller.toggle();
      expect(await controller.isFullscreen, isFalse);
    });
  });

  group('on desktop', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('enter and exit drive the window bridge', () async {
      final window = _FakeDesktopWindow();
      final controller = IoFullscreenController(desktop: window);
      await controller.enter();
      expect(window.fullscreen, isTrue);
      expect(await controller.isFullscreen, isTrue);
      await controller.exit();
      expect(window.fullscreen, isFalse);
      expect(window.calls, 2);
    });

    test('toggle reads the real window state', () async {
      final window = _FakeDesktopWindow()..fullscreen = true;
      final controller = IoFullscreenController(desktop: window);
      await controller.toggle();
      expect(window.fullscreen, isFalse);
    });
  });

  test('the noop controller is honest about never being fullscreen', () async {
    const controller = NoopFullscreenController();
    await controller.enter();
    expect(await controller.isFullscreen, isFalse);
    await controller.exit();
    await controller.toggle();
    expect(await controller.isFullscreen, isFalse);
  });
}
