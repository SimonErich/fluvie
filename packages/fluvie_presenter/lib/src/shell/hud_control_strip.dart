import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/shell/presentation_shortcuts.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:obers_ui/obers_ui.dart' show OiButtonSize, OiIconButton, OiIcons, OiTooltip;

/// The clickable half of the HUD: one small ghost button per piece of
/// chrome (plus close, set apart, when the host wired one), reusing the
/// exact intentions the keyboard fires.
///
/// While the presenter is fullscreen the strip gets out of the way: it
/// fades out after [hideDelay], a hover over its corner brings it back,
/// and it hides again [revealDelay] after the last hover.
final class HudControlStrip extends ConsumerStatefulWidget {
  /// Creates the strip wired to [handlers].
  const HudControlStrip({
    required this.handlers,
    this.hideDelay = const Duration(seconds: 4),
    this.revealDelay = const Duration(seconds: 5),
    super.key,
  });

  /// The same intentions the keyboard fires.
  final PresenterHandlers handlers;

  /// How long after entering fullscreen the strip stays visible.
  final Duration hideDelay;

  /// How long a hover keeps the strip visible in fullscreen.
  final Duration revealDelay;

  @override
  ConsumerState<HudControlStrip> createState() => _HudControlStripState();
}

final class _HudControlStripState extends ConsumerState<HudControlStrip> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(fullscreenActiveProvider, (previous, active) {
      _timer?.cancel();
      if (active) {
        _hideAfter(widget.hideDelay);
      } else {
        setState(() => _visible = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _hideAfter(Duration delay) {
    _timer = Timer(delay, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  /// Any hover over the strip's corner: reveal, and restart the clock.
  void _poke() {
    if (!ref.read(fullscreenActiveProvider)) return;
    _timer?.cancel();
    if (!_visible) setState(() => _visible = true);
    _hideAfter(widget.revealDelay);
  }

  @override
  Widget build(BuildContext context) {
    final handlers = widget.handlers;
    return MouseRegion(
      onEnter: (_) => _poke(),
      onHover: (_) => _poke(),
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_visible,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HudButton(
                  icon: OiIcons.panelLeft,
                  label: 'Slide list',
                  shortcut: 'T',
                  onTap: handlers.onToggleSidebar,
                ),
                _HudButton(
                  icon: OiIcons.notepadText,
                  label: 'Speaker notes',
                  shortcut: 'N',
                  onTap: handlers.onToggleNotes,
                ),
                _HudButton(
                  icon: OiIcons.layoutGrid,
                  label: 'Overview',
                  shortcut: 'O',
                  onTap: handlers.onOverview,
                ),
                _HudButton(
                  icon: OiIcons.presentation,
                  label: 'Speaker window',
                  shortcut: 'S',
                  onTap: handlers.onSpeakerWindow,
                ),
                _HudButton(
                  icon: OiIcons.maximize,
                  label: 'Fullscreen',
                  shortcut: 'F',
                  onTap: handlers.onToggleFullscreen,
                ),
                if (handlers.onClose case final close?) ...[
                  const SizedBox(width: 16),
                  _HudButton(icon: OiIcons.x, label: 'Close presentation', onTap: close),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One strip button: a ghost icon with its shortcut in the tooltip. The
/// tooltip needs an `Overlay` (an `OiApp` provides one); without it the
/// button still works, just without the hover hint.
final class _HudButton extends StatelessWidget {
  const _HudButton({required this.icon, required this.label, required this.onTap, this.shortcut});

  final IconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OiTooltip(
    label: label,
    message: shortcut == null ? label : '$label ($shortcut)',
    child: OiIconButton(
      icon: icon,
      semanticLabel: label,
      size: OiButtonSize.small,
      onTap: onTap,
    ),
  );
}
