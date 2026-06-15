/// Builds the headless-Chrome launch argument **array** for a snapshot capture
/// — never a shell string, never concatenated paths.
///
/// The flags pin determinism and isolation: `--headless=new --disable-gpu`
/// (software raster), `--hide-scrollbars`, `--force-device-scale-factor=1`, a
/// fresh `--user-data-dir` sandbox, and `--remote-debugging-port` for the CDP
/// channel. [userDataDir] is validated like an FFmpeg arg name (no leading `-`,
/// no separators) so it can never inject a flag, mirroring the
/// `FfmpegArgsBuilder._validateName` discipline.
List<String> buildChromeArgs({required String userDataDir, required int remoteDebuggingPort}) {
  _validateArgValue(userDataDir, 'userDataDir');
  if (remoteDebuggingPort < 0) {
    throw ArgumentError.value(remoteDebuggingPort, 'remoteDebuggingPort', 'must not be negative');
  }
  return [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--force-device-scale-factor=1',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
    '--remote-debugging-port=$remoteDebuggingPort',
    '--user-data-dir=$userDataDir',
  ];
}

/// Builds the `Page.captureScreenshot` CDP command for a [width]x[height]
/// viewport at [deviceScale], as a plain JSON-encodable map (order-stable).
///
/// The clip pins the captured region to the declared viewport so the raster is
/// deterministic regardless of page content height.
Map<String, Object?> buildScreenshotCommand({
  required int width,
  required int height,
  required num deviceScale,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('width and height must be positive (got ${width}x$height)');
  }
  if (deviceScale <= 0) {
    throw ArgumentError.value(deviceScale, 'deviceScale', 'must be positive');
  }
  return {
    'method': 'Page.captureScreenshot',
    'params': {
      'format': 'png',
      'clip': {'x': 0, 'y': 0, 'width': width, 'height': height, 'scale': deviceScale},
    },
  };
}

/// Rejects an argument value that is empty, starts with `-` (flag injection),
/// or contains a path separator — the Chrome-arg analogue of the FFmpeg
/// name guard.
void _validateArgValue(String value, String parameter) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, parameter, 'must not be empty');
  }
  if (value.startsWith('-')) {
    throw ArgumentError.value(value, parameter, 'must not start with "-" (flag injection)');
  }
  if (value.contains('/') || value.contains(r'\') || value.contains(' ')) {
    throw ArgumentError.value(
      value,
      parameter,
      'must be a bare sandbox directory name without separators or spaces',
    );
  }
}
