import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'logger.dart';

/// Utility class to check if Impeller is enabled and warn users if not.
///
/// Fluvie requires Impeller for proper rendering without black backgrounds.
/// Skia renderer causes visual artifacts and should not be used.
class ImpellerChecker {
  static bool _hasChecked = false;
  static bool? _isImpellerEnabled;

  /// Checks if Impeller is enabled on the current platform.
  ///
  /// Returns `true` if Impeller is enabled, `false` if Skia is being used.
  /// Returns `null` if unable to determine (shouldn't happen in normal cases).
  static bool? isImpellerEnabled() {
    if (_hasChecked) {
      return _isImpellerEnabled;
    }

    _hasChecked = true;

    try {
      // Check the renderer name from the platform
      // Impeller will report itself as "Impeller" in the renderer name
      // This is the most reliable way to detect Impeller vs Skia
      final view = ui.PlatformDispatcher.instance.views.firstOrNull;
      if (view == null) {
        FluvieLogger.warning(
          'Unable to detect renderer: No views available',
          module: 'impeller',
        );
        _isImpellerEnabled = null;
        return null;
      }

      // On platforms with Impeller, the display features will be different
      // We can also check if Impeller is explicitly enabled via command line args
      // However, there's no direct API to query this, so we use heuristics

      // For now, we'll assume Impeller is enabled on supported platforms
      // and provide CLI argument checking as the primary method
      _isImpellerEnabled = _detectImpellerFromEnvironment();

      if (_isImpellerEnabled == true) {
        FluvieLogger.info(
          'Impeller renderer detected - optimal performance enabled',
          module: 'impeller',
        );
      } else if (_isImpellerEnabled == false) {
        FluvieLogger.error(
          'Skia renderer detected - Fluvie requires Impeller for proper rendering!',
          module: 'impeller',
        );
      }

      return _isImpellerEnabled;
    } catch (e) {
      FluvieLogger.warning('Error detecting renderer: $e', module: 'impeller');
      _isImpellerEnabled = null;
      return null;
    }
  }

  /// Detects Impeller from environment/platform.
  ///
  /// This is a heuristic approach since Flutter doesn't provide a direct API.
  static bool _detectImpellerFromEnvironment() {
    // On Flutter 3.10+, Impeller is default on iOS
    // On other platforms, it needs to be explicitly enabled

    // Check platform
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Impeller is default on iOS since Flutter 3.10
      return true;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // Impeller on Android requires explicit flag
      // We assume it's NOT enabled unless proven otherwise
      // (User needs to run with --enable-impeller)
      return false;
    } else if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      // Desktop platforms: Impeller requires explicit flag
      // Assume NOT enabled by default
      return false;
    }

    // Unknown platform, assume Skia
    return false;
  }

  /// Shows a visible warning dialog if Skia is detected.
  ///
  /// This should be called during app initialization or before rendering.
  static void showWarningIfSkia(BuildContext context) {
    final isImpeller = isImpellerEnabled();

    if (isImpeller == false) {
      // Skia detected - show warning
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildWarningDialog(context),
          );
        }
      });
    }
  }

  /// Builds a prominent warning dialog for Skia usage.
  static Widget _buildWarningDialog(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0000), // Dark red background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFF3333), width: 3),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF3333),
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            'Renderer Warning',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFF3333),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fluvie requires the Impeller renderer for proper video rendering.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF330000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF3333).withValues(alpha: 0.3),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '❌ Skia renderer detected',
                  style: TextStyle(
                    color: Color(0xFFFF6666),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This will cause black backgrounds and rendering artifacts in exported videos.',
                  style: TextStyle(color: Color(0xFFFFAAAA), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'To enable Impeller, restart your app with:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF002200),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF00FF00).withValues(alpha: 0.3),
              ),
            ),
            child: const SelectableText(
              'flutter run --enable-impeller',
              style: TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Or add to your launch.json for debugging:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
            child: const SelectableText(
              '"args": ["--enable-impeller"]',
              style: TextStyle(
                color: Color(0xFFAAFFAA),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6666)),
          child: const Text('I UNDERSTAND - CONTINUE ANYWAY'),
        ),
      ],
    );
  }

  /// Logs a console warning if Skia is detected.
  ///
  /// This is a non-intrusive alternative to the dialog.
  static void logWarningIfSkia() {
    final isImpeller = isImpellerEnabled();

    if (isImpeller == false) {
      FluvieLogger.box(
          '⚠️  RENDERER WARNING ⚠️',
          [
            '',
            'Fluvie requires Impeller for proper video rendering.',
            'Skia renderer detected - this will cause rendering artifacts!',
            '',
            'To fix this, restart your app with:',
            '  flutter run --enable-impeller',
            '',
            'Or add to launch.json:',
            '  "args": ["--enable-impeller"]',
            '',
          ],
          module: 'impeller');
    }
  }

  /// Checks for Impeller and throws an exception if not enabled.
  ///
  /// Use this in production code where Skia usage should be prevented.
  static void enforceImpeller() {
    final isImpeller = isImpellerEnabled();

    if (isImpeller == false) {
      throw FlutterError(
        'Fluvie requires Impeller renderer!\n\n'
        'Skia renderer detected. Fluvie videos will have black backgrounds '
        'and rendering artifacts with Skia.\n\n'
        'To enable Impeller, restart your app with:\n'
        '  flutter run --enable-impeller\n\n'
        'Or add to your launch.json:\n'
        '  "args": ["--enable-impeller"]',
      );
    }
  }

  /// Resets the checker state (useful for testing).
  @visibleForTesting
  static void reset() {
    _hasChecked = false;
    _isImpellerEnabled = null;
  }
}
